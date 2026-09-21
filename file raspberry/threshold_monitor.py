#!/usr/bin/env python3
"""Monitora le soglie HydroTower e invia notifiche FCM al cambio di stato."""
from __future__ import annotations

import json
import os
import time
from pathlib import Path
from typing import Any

from notification_manager import invia_notifica

CACHE_PATH = Path("/home/hydrotower/ultimo_rilevamento.json")
SETTINGS_PATH = Path("/home/hydrotower/hydrotower_settings.json")
STATE_PATH = Path("/home/hydrotower/hydrotower_alarm_state.json")
CHECK_INTERVAL_SECONDS = 15

RULES = (
    ("temperatura_bassa", "temperatura", "tempMin", "min", "Temperatura", " °C"),
    ("temperatura_alta", "temperatura", "tempMax", "max", "Temperatura", " °C"),
    ("ph_basso", "ph", "phMin", "min", "pH", ""),
    ("ph_alto", "ph", "phMax", "max", "pH", ""),
    ("tds_basso", "tds", "tdsMin", "min", "TDS", " ppm"),
    ("tds_alto", "tds", "tdsMax", "max", "TDS", " ppm"),
    ("acqua_bassa", "livello_acqua", "waterMin", "min", "Livello acqua", "%"),
    ("aria_bassa", "umidita_aria", "humidityAirMin", "min", "Umidità aria", "%"),
    ("aria_alta", "umidita_aria", "humidityAirMax", "max", "Umidità aria", "%"),
    ("terreno_basso", "umidita_terreno", "humiditySoilMin", "min", "Umidità terreno", "%"),
    ("terreno_alto", "umidita_terreno", "humiditySoilMax", "max", "Umidità terreno", "%"),
)


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        return value if isinstance(value, dict) else {}
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return {}


def save_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def number(data: dict[str, Any], key: str) -> float | None:
    value = data.get(key)
    if value is None or isinstance(value, bool):
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def cycle() -> None:
    sensors = load_json(CACHE_PATH)
    settings = load_json(SETTINGS_PATH)
    state = load_json(STATE_PATH)
    if not bool(settings.get("notifications", False)):
        return

    changed = False
    for alarm_key, sensor_key, limit_key, direction, label, unit in RULES:
        sensor_value = number(sensors, sensor_key)
        limit_value = number(settings, limit_key)
        if sensor_value is None or limit_value is None:
            continue

        alarm = sensor_value < limit_value if direction == "min" else sensor_value > limit_value
        previous = bool(state.get(alarm_key, False))
        if alarm and not previous:
            invia_notifica(
                titolo=f"Allarme {label}",
                corpo=f"{label}: {sensor_value}{unit}. Soglia: {limit_value}{unit}.",
                tipo="alarm",
                dati={"alarmKey": alarm_key, "sensor": sensor_key},
            )
        if alarm != previous:
            state[alarm_key] = alarm
            changed = True

    if changed:
        save_json(STATE_PATH, state)


def main() -> None:
    print("HydroTower threshold monitor avviato", flush=True)
    while True:
        try:
            cycle()
        except Exception as error:
            print(f"Errore monitor soglie: {error}", flush=True)
        time.sleep(CHECK_INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
