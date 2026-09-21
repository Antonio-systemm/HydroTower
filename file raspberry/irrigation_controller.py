#!/usr/bin/env python3
"""Controller principale dell'irrigazione HydroTower.

Il processo:
- gestisce i comandi manuali provenienti dall'API;
- esegue ogni comando una sola volta;
- controlla il livello dell'acqua;
- avvia l'irrigazione automatica quando il terreno e secco;
- non interrompe gli avvii manuali quando il terreno e umido;
- verifica l'effetto del ciclo senza bloccare se il target e raggiunto;
- conserva lo stato dello scheduler tra i riavvii.
"""

from __future__ import annotations

import json
import os
import time
from pathlib import Path
from typing import Any

from pump_controller import PumpController, PumpSafetyError


CACHE_FILE = Path("/home/hydrotower/ultimo_rilevamento.json")
SETTINGS_FILE = Path("/home/hydrotower/hydrotower_settings.json")
COMMAND_FILE = Path("/home/hydrotower/hydrotower_pump_command.json")
SCHEDULER_STATE_FILE = Path("/home/hydrotower/hydrotower_irrigation_state.json")

LOOP_SECONDS = 0.25
COMMAND_MAX_AGE_SECONDS = 60.0


def load_json(path: Path) -> dict[str, Any]:
    """Legge un file JSON e restituisce sempre un dizionario."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(data, dict):
            return data
    except (
        FileNotFoundError,
        json.JSONDecodeError,
        UnicodeDecodeError,
        OSError,
    ):
        pass
    return {}


def save_json(path: Path, data: dict[str, Any]) -> None:
    """Salva un dizionario JSON in modo atomico."""
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    os.replace(temporary, path)


def number_value(data: dict[str, Any], key: str) -> float | None:
    """Converte un campo del dizionario in float."""
    value = data.get(key)
    if value is None or isinstance(value, bool):
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def safe_float(value: Any, default: float) -> float:
    """Converte un valore in float usando un valore predefinito."""
    if value is None or isinstance(value, bool):
        return default
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def load_scheduler_state() -> dict[str, Any]:
    """Carica lo stato persistente dello scheduler."""
    saved = load_json(SCHEDULER_STATE_FILE)
    return {
        "last_command_id": saved.get("last_command_id"),
        "last_cycle_epoch": safe_float(saved.get("last_cycle_epoch"), 0.0),
        "baseline_soil": number_value(saved, "baseline_soil"),
        "waiting_until_epoch": safe_float(
            saved.get("waiting_until_epoch"),
            0.0,
        ),
        "last_scheduler_error": saved.get("last_scheduler_error"),
    }


def save_scheduler_state(scheduler: dict[str, Any]) -> None:
    """Salva lo stato persistente dello scheduler."""
    save_json(SCHEDULER_STATE_FILE, scheduler)


def update_pump_state(pump: PumpController, **values: Any) -> None:
    """Aggiorna lo stato persistente del controller pompa."""
    with pump._lock:
        pump._state.update(values)
        pump._save()


def command_is_recent(command: dict[str, Any], now: float) -> bool:
    """Verifica che il comando non sia scaduto."""
    try:
        created = float(command.get("created", 0.0))
    except (TypeError, ValueError):
        return False
    age = now - created
    return -5.0 <= age <= COMMAND_MAX_AGE_SECONDS


def process_command(
    pump: PumpController,
    command: dict[str, Any],
    scheduler: dict[str, Any],
    now: float,
) -> None:
    """Elabora un comando API una sola volta."""
    command_id = str(command.get("id") or "").strip()
    if not command_id:
        return
    if command_id == scheduler.get("last_command_id"):
        return

    scheduler["last_command_id"] = command_id

    if not command_is_recent(command, now):
        scheduler["last_scheduler_error"] = "Comando scaduto ignorato"
        save_scheduler_state(scheduler)
        print("Comando pompa ignorato perche scaduto", flush=True)
        return

    action = str(command.get("action") or "").strip().lower()
    reason = str(command.get("reason", "api-manuale")).strip()

    try:
        if action == "start":
            seconds = safe_float(command.get("seconds"), 5.0)
            pump.start(seconds, reason)
            update_pump_state(pump, last_command_error=None)
            scheduler["last_scheduler_error"] = None
            print(
                "Comando START eseguito: "
                f"{seconds:.2f} secondi, motivo={reason}",
                flush=True,
            )
        elif action == "stop":
            pump.off(reason or "api-manuale")
            update_pump_state(pump, last_command_error=None)
            scheduler["last_scheduler_error"] = None
            print(f"Comando STOP eseguito: motivo={reason}", flush=True)
        elif action == "reset":
            pump.reset_lockout()
            update_pump_state(pump, last_command_error=None)
            scheduler["last_scheduler_error"] = None
            print("Blocco di sicurezza ripristinato", flush=True)
        else:
            raise ValueError(f"Azione sconosciuta: {action!r}")
    except (PumpSafetyError, TypeError, ValueError) as error:
        message = str(error)
        update_pump_state(pump, last_command_error=message)
        scheduler["last_scheduler_error"] = message
        print(f"Comando pompa rifiutato: {message}", flush=True)
    finally:
        save_scheduler_state(scheduler)


def check_water_safety(pump: PumpController) -> None:
    """Ferma la pompa soltanto se l'acqua e esplicitamente assente."""
    status = pump.status()
    if status.get("pump_on") is not True:
        return

    water_ok = status.get("livello_acqua_ok")
    water_present = status.get("acqua_presente")

    if water_ok is False or water_present is False:
        pump.off("WATER_LOW")
        print("Pompa arrestata: acqua assente", flush=True)


def process_absorption_check(
    pump: PumpController,
    scheduler: dict[str, Any],
    soil: float,
    target: float,
    now: float,
    minimum_rise: float,
) -> None:
    """Verifica l'effetto del ciclo automatico dopo la pausa.

    Se il terreno ha raggiunto il target, il controllo e superato anche quando
    l'incremento rispetto alla baseline e inferiore a minimum_rise.
    """
    waiting_until = safe_float(
        scheduler.get("waiting_until_epoch"),
        0.0,
    )

    if waiting_until <= 0.0 or now < waiting_until:
        return

    baseline = number_value(scheduler, "baseline_soil")

    if baseline is not None:
        increase = soil - baseline
        target_reached = soil >= target

        if not target_reached and increase < minimum_rise:
            update_pump_state(
                pump,
                lockout="NO_MOISTURE_RESPONSE",
                last_command_error="NO_MOISTURE_RESPONSE",
            )
            scheduler["last_scheduler_error"] = "NO_MOISTURE_RESPONSE"
            print(
                "Irrigazione bloccata: "
                f"aumento osservato={increase:.2f}, "
                f"aumento minimo={minimum_rise:.2f}",
                flush=True,
            )
        else:
            update_pump_state(
                pump,
                lockout=None,
                last_command_error=None,
            )
            scheduler["last_scheduler_error"] = None
            print(
                "Controllo irrigazione completato: "
                f"umidita={soil:.2f}%, "
                f"aumento={increase:.2f}",
                flush=True,
            )

    scheduler["baseline_soil"] = None
    scheduler["waiting_until_epoch"] = 0.0
    save_scheduler_state(scheduler)


def process_automatic_irrigation(
    pump: PumpController,
    settings: dict[str, Any],
    sensors: dict[str, Any],
    scheduler: dict[str, Any],
    now: float,
) -> None:
    """Gestisce esclusivamente l'irrigazione automatica."""
    if not bool(settings.get("irrigationEnabled", False)):
        return

    soil = number_value(sensors, "umidita_terreno")
    if soil is None:
        if scheduler.get("last_scheduler_error") != "Umidita terreno non disponibile":
            scheduler["last_scheduler_error"] = "Umidita terreno non disponibile"
            save_scheduler_state(scheduler)
        return

    start_below = safe_float(
        settings.get("startBelowSoilHumidity"),
        35.0,
    )
    target = safe_float(
        settings.get("targetSoilHumidity"),
        60.0,
    )
    pulse = max(
        0.5,
        min(safe_float(settings.get("wateringPulseSeconds"), 5.0), 15.0),
    )
    pause_seconds = max(
        safe_float(settings.get("absorptionPauseMinutes"), 5.0) * 60.0,
        60.0,
    )
    between_seconds = max(
        safe_float(settings.get("minimumMinutesBetweenCycles"), 180.0) * 60.0,
        300.0,
    )
    minimum_rise = max(
        safe_float(settings.get("minimumObservedHumidityIncrease"), 2.0),
        1.0,
    )

    process_absorption_check(
        pump=pump,
        scheduler=scheduler,
        soil=soil,
        target=target,
        now=now,
        minimum_rise=minimum_rise,
    )

    status = pump.status()
    pump_running = status.get("pump_on") is True
    automatic_run = status.get("last_start_reason") == "automatico-umidita"

    if pump_running and automatic_run and soil >= target:
        pump.off("TARGET_REACHED")
        print(
            "Ciclo automatico fermato: umidita obiettivo raggiunta",
            flush=True,
        )
        return

    if pump_running:
        return

    waiting_until = safe_float(
        scheduler.get("waiting_until_epoch"),
        0.0,
    )
    last_cycle = safe_float(
        scheduler.get("last_cycle_epoch"),
        0.0,
    )

    if waiting_until > 0.0:
        return
    if soil >= start_below:
        return
    if now - last_cycle < between_seconds:
        return

    try:
        pump.start(pulse, "automatico-umidita")
        update_pump_state(pump, last_command_error=None)
        scheduler["baseline_soil"] = soil
        scheduler["last_cycle_epoch"] = now
        scheduler["waiting_until_epoch"] = now + pulse + pause_seconds
        scheduler["last_scheduler_error"] = None
        save_scheduler_state(scheduler)
        print(
            "Irrigazione automatica avviata: "
            f"terreno={soil:.1f}%, "
            f"soglia={start_below:.1f}%, "
            f"durata={pulse:.1f}s",
            flush=True,
        )
    except PumpSafetyError as error:
        message = str(error)
        update_pump_state(pump, last_command_error=message)
        scheduler["last_scheduler_error"] = message
        save_scheduler_state(scheduler)
        print(
            f"Irrigazione automatica non avviata: {message}",
            flush=True,
        )


def main() -> None:
    """Avvia il ciclo principale del controller."""
    pump = PumpController()
    scheduler = load_scheduler_state()

    print("HydroTower irrigation controller avviato", flush=True)

    try:
        while True:
            now = time.time()
            settings = load_json(SETTINGS_FILE)
            sensors = load_json(CACHE_FILE)
            command = load_json(COMMAND_FILE)

            process_command(
                pump=pump,
                command=command,
                scheduler=scheduler,
                now=now,
            )
            check_water_safety(pump)
            process_automatic_irrigation(
                pump=pump,
                settings=settings,
                sensors=sensors,
                scheduler=scheduler,
                now=now,
            )
            time.sleep(LOOP_SECONDS)
    except KeyboardInterrupt:
        print("Arresto richiesto", flush=True)
    finally:
        pump.close()


if __name__ == "__main__":
    main()
