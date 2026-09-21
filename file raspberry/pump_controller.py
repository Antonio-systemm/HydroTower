#!/usr/bin/env python3
"""Controllore fail-safe della pompa HydroTower su BCM GPIO27.

Configurazione confermata:
- GPIO27 HIGH = rele acceso
- GPIO27 LOW = rele spento
- GPIO22 HIGH = acqua presente
- GPIO22 LOW = acqua assente

La pompa deve essere comandata tramite PumpController o tramite le API.
Un comando pinctrl diretto non aggiorna il file di stato e quindi non e
visibile nell'applicazione.
"""

from __future__ import annotations

import json
import os
import threading
import time
from datetime import datetime
from pathlib import Path
from typing import Any

from gpiozero import OutputDevice

from water_level import WaterLevelSensor


GPIO_POMPA = int(os.getenv("HYDROTOWER_PUMP_GPIO", "27"))

# Nel tuo impianto HIGH accende e LOW spegne.
RELE_ACTIVE_HIGH = os.getenv(
    "HYDROTOWER_RELAY_ACTIVE_HIGH",
    "true",
).strip().lower() in {"1", "true", "yes", "on"}

STATE_FILE = Path(
    os.getenv(
        "HYDROTOWER_PUMP_STATE_FILE",
        "/home/hydrotower/hydrotower_pump_state.json",
    )
)

HARD_MAX_PULSE_SECONDS = 15.0
HARD_MAX_DAILY_SECONDS = 120.0
HARD_MAX_STARTS_HOUR = 3
HARD_MAX_STARTS_DAY = 12
MAX_EVENTS = 500


class PumpSafetyError(RuntimeError):
    """Errore causato da un blocco di sicurezza della pompa."""


class PumpController:
    """Gestisce il rele, i limiti e lo stato persistente della pompa."""

    def __init__(self) -> None:
        self._lock = threading.RLock()
        self._stop_event = threading.Event()
        self._thread: threading.Thread | None = None
        self._run_started_monotonic: float | None = None
        self._requested_run_seconds = 0.0

        self._relay = OutputDevice(
            GPIO_POMPA,
            active_high=RELE_ACTIVE_HIGH,
            initial_value=False,
        )
        self._water = WaterLevelSensor()
        self._state = self._load_state()

        # Stato fail-safe all'avvio.
        self._relay.off()
        self._state["pump_on"] = False
        self._state["gpio_pompa"] = GPIO_POMPA
        self._state["relay_active_high"] = RELE_ACTIVE_HIGH
        self._state["current_run_seconds"] = 0.0
        self._state["current_run_max_seconds"] = 0.0
        self._state["controller_started_at"] = self._now_iso()
        self._save()

    @staticmethod
    def _now_iso() -> str:
        return datetime.now().isoformat(timespec="seconds")

    def _default_state(self) -> dict[str, Any]:
        return {
            "pump_on": False,
            "gpio_pompa": GPIO_POMPA,
            "relay_active_high": RELE_ACTIVE_HIGH,
            "lockout": None,
            "last_command_error": None,
            "current_run_seconds": 0.0,
            "current_run_max_seconds": 0.0,
            "last_run_seconds": 0.0,
            "last_start_reason": None,
            "last_stop_reason": None,
            "started_at": None,
            "stopped_at": None,
            "events": [],
        }

    def _load_state(self) -> dict[str, Any]:
        defaults = self._default_state()

        try:
            loaded = json.loads(
                STATE_FILE.read_text(encoding="utf-8")
            )
            if isinstance(loaded, dict):
                defaults.update(loaded)
        except (FileNotFoundError, json.JSONDecodeError, OSError):
            pass

        if not isinstance(defaults.get("events"), list):
            defaults["events"] = []

        # Un riavvio non deve lasciare uno stato logico acceso.
        defaults["pump_on"] = False
        defaults["current_run_seconds"] = 0.0
        defaults["current_run_max_seconds"] = 0.0
        return defaults

    def _save(self) -> None:
        STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
        temporary = STATE_FILE.with_suffix(".json.tmp")

        with temporary.open("w", encoding="utf-8") as handle:
            json.dump(
                self._state,
                handle,
                ensure_ascii=False,
                indent=2,
            )
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())

        os.replace(temporary, STATE_FILE)

    def _recent(self, seconds: int) -> list[dict[str, Any]]:
        now = time.time()
        recent: list[dict[str, Any]] = []

        for event in self._state.get("events", []):
            if not isinstance(event, dict):
                continue
            try:
                age = now - float(event.get("epoch", 0.0))
            except (TypeError, ValueError):
                continue
            if 0.0 <= age <= seconds:
                recent.append(event)

        return recent

    def _daily_runtime(self) -> float:
        return sum(
            float(event.get("seconds", 0.0))
            for event in self._recent(86400)
            if event.get("type") == "run"
        )

    def _starts(self, seconds: int) -> int:
        return sum(
            1
            for event in self._recent(seconds)
            if event.get("type") == "start"
        )

    def _record(
        self,
        kind: str,
        reason: str,
        seconds: float = 0.0,
    ) -> None:
        event = {
            "type": kind,
            "reason": reason,
            "seconds": round(max(0.0, seconds), 2),
            "epoch": time.time(),
            "at": self._now_iso(),
        }

        events = self._state.get("events", [])
        if not isinstance(events, list):
            events = []

        self._state["events"] = (events + [event])[-MAX_EVENTS:]
        self._save()

    def _current_run_seconds(self) -> float:
        if (
            not self._state.get("pump_on")
            or self._run_started_monotonic is None
        ):
            return 0.0

        return max(
            0.0,
            time.monotonic() - self._run_started_monotonic,
        )

    def status(self) -> dict[str, Any]:
        with self._lock:
            current = round(self._current_run_seconds(), 2)
            self._state["current_run_seconds"] = current
            self._state["current_run_max_seconds"] = round(
                self._requested_run_seconds,
                2,
            )

            return {
                **self._state,
                **self._water.stato(),
                "daily_runtime_seconds": round(
                    self._daily_runtime(),
                    2,
                ),
                "starts_last_hour": self._starts(3600),
                "starts_today": self._starts(86400),
                "hard_limits": {
                    "pulse_seconds": HARD_MAX_PULSE_SECONDS,
                    "daily_seconds": HARD_MAX_DAILY_SECONDS,
                    "starts_hour": HARD_MAX_STARTS_HOUR,
                    "starts_day": HARD_MAX_STARTS_DAY,
                },
            }

    def _preflight(self, seconds: float) -> float:
        lockout = self._state.get("lockout")
        if lockout:
            raise PumpSafetyError(f"Pompa bloccata: {lockout}")

        if not self._water.acqua_presente:
            raise PumpSafetyError("WATER_LOW")

        if self._thread is not None and self._thread.is_alive():
            raise PumpSafetyError("PUMP_ALREADY_RUNNING")

        try:
            requested = float(seconds)
        except (TypeError, ValueError) as error:
            raise PumpSafetyError("INVALID_DURATION") from error

        requested = max(
            0.5,
            min(requested, HARD_MAX_PULSE_SECONDS),
        )

        if self._daily_runtime() + requested > HARD_MAX_DAILY_SECONDS:
            raise PumpSafetyError("DAILY_RUNTIME_LIMIT")

        if self._starts(3600) >= HARD_MAX_STARTS_HOUR:
            raise PumpSafetyError("TOO_MANY_STARTS_HOUR")

        if self._starts(86400) >= HARD_MAX_STARTS_DAY:
            raise PumpSafetyError("TOO_MANY_STARTS_DAY")

        return requested

    def start(
        self,
        seconds: float,
        reason: str = "manuale",
    ) -> dict[str, Any]:
        with self._lock:
            duration = self._preflight(seconds)
            self._stop_event.clear()
            self._requested_run_seconds = duration
            self._state["last_command_error"] = None

            self._thread = threading.Thread(
                target=self._run,
                args=(duration, reason),
                daemon=True,
                name="hydrotower-pump-run",
            )
            self._thread.start()

        return self.status()

    def _run(self, seconds: float, reason: str) -> None:
        started = time.monotonic()
        stop_reason = "DURATION_COMPLETED"

        try:
            with self._lock:
                self._run_started_monotonic = started
                self._relay.on()
                self._state["pump_on"] = True
                self._state["started_at"] = self._now_iso()
                self._state["last_start_reason"] = reason
                self._state["current_run_seconds"] = 0.0
                self._state["current_run_max_seconds"] = round(
                    seconds,
                    2,
                )
                self._record("start", reason)

            while time.monotonic() - started < seconds:
                if self._stop_event.wait(0.10):
                    stop_reason = "MANUAL_STOP"
                    break

                if not self._water.acqua_presente:
                    stop_reason = "WATER_LOW"
                    with self._lock:
                        self._state["lockout"] = "WATER_LOW"
                    break

                with self._lock:
                    self._state["current_run_seconds"] = round(
                        time.monotonic() - started,
                        2,
                    )
                    self._save()
        except Exception as error:
            stop_reason = "CONTROLLER_ERROR"
            with self._lock:
                self._state["lockout"] = "CONTROLLER_ERROR"
                self._state["last_command_error"] = str(error)
        finally:
            elapsed = max(0.0, time.monotonic() - started)

            with self._lock:
                self._relay.off()
                self._state["pump_on"] = False
                self._state["stopped_at"] = self._now_iso()
                self._state["last_run_seconds"] = round(elapsed, 2)
                self._state["last_stop_reason"] = stop_reason
                self._state["current_run_seconds"] = 0.0
                self._state["current_run_max_seconds"] = 0.0
                self._run_started_monotonic = None
                self._requested_run_seconds = 0.0
                self._record("run", reason, elapsed)
                self._record("stop", stop_reason, elapsed)

    def off(self, reason: str = "arresto") -> dict[str, Any]:
        with self._lock:
            running = (
                self._thread is not None
                and self._thread.is_alive()
            )

            self._stop_event.set()
            self._relay.off()
            self._state["pump_on"] = False
            self._state["stopped_at"] = self._now_iso()
            self._state["last_stop_reason"] = reason

            if not running:
                self._state["current_run_seconds"] = 0.0
                self._state["current_run_max_seconds"] = 0.0
                self._save()

        return self.status()

    def reset_lockout(self) -> dict[str, Any]:
        with self._lock:
            if not self._water.acqua_presente:
                raise PumpSafetyError(
                    "Impossibile resettare: WATER_LOW"
                )

            self._state["lockout"] = None
            self._state["last_command_error"] = None
            self._record("reset", "reset manuale")

        return self.status()

    def close(self) -> None:
        self.off("chiusura")

        thread = self._thread
        if thread is not None and thread.is_alive():
            thread.join(timeout=2.0)

        self._relay.off()
        self._relay.close()
        self._water.close()
