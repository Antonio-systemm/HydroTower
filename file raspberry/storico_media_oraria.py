#!/usr/bin/env python3
"""HydroTower: medie orarie complete di sensori e pompa."""

from __future__ import annotations

import json
import os
import sqlite3
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

DB_PATH = Path("/home/hydrotower/hydrotower.db")
CACHE_SENSORI = Path("/home/hydrotower/ultimo_rilevamento.json")
STATO_POMPA = Path("/home/hydrotower/hydrotower_pump_state.json")
SETTINGS_PATH = Path("/home/hydrotower/hydrotower_settings.json")
RETENTION_DEFAULT = 30
RETENTION_ALLOWED = {0, 7, 30, 90, 365}
INTERVALLO_CAMPIONAMENTO = 10
MAX_ETA_CACHE = 30

CAMPI_MEDI = (
    "temperatura",
    "umidita_aria",
    "umidita_terreno",
    "umidita_terreno_raw",
    "luce",
    "tds",
    "tds_raw",
    "ph",
    "ph_raw",
    "ph_voltage",
    "livello_acqua",
)
CAMPI_BOOLEANI = ("acqua_presente", "livello_acqua_ok")


def leggi_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except (FileNotFoundError, json.JSONDecodeError, UnicodeDecodeError, OSError):
        return {}


def numero_o_none(value: Any) -> float | None:
    if value is None or isinstance(value, bool):
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def booleano_o_none(value: Any) -> int | None:
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, (int, float)):
        return int(value != 0)
    if isinstance(value, str):
        normalized = value.strip().lower()
        if normalized in {"true", "1", "yes", "si", "sì", "on"}:
            return 1
        if normalized in {"false", "0", "no", "off"}:
            return 0
    return None


def parse_timestamp(value: Any) -> datetime | None:
    if not value:
        return None
    text = str(value).strip().replace(" T", "T")
    try:
        return datetime.fromisoformat(text)
    except ValueError:
        return None


def connessione_db() -> sqlite3.Connection:
    connection = sqlite3.connect(DB_PATH, timeout=15)
    connection.execute("PRAGMA journal_mode=WAL")
    connection.execute("PRAGMA busy_timeout=15000")
    return connection


def aggiungi_colonne(
    connection: sqlite3.Connection,
    table: str,
    columns: dict[str, str],
) -> None:
    existing = {
        row[1]
        for row in connection.execute(f"PRAGMA table_info({table})").fetchall()
    }
    for name, definition in columns.items():
        if name not in existing:
            connection.execute(
                f"ALTER TABLE {table} ADD COLUMN {name} {definition}"
            )


def prepara_db(connection: sqlite3.Connection) -> None:
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS storico_orario (
            timestamp TEXT PRIMARY KEY,
            temperatura REAL,
            umidita_aria REAL,
            umidita_terreno REAL,
            umidita_terreno_raw REAL,
            luce REAL,
            tds REAL,
            tds_raw REAL,
            campioni INTEGER DEFAULT 0
        )
        """
    )
    aggiungi_colonne(
        connection,
        "storico_orario",
        {
            "ph": "REAL",
            "ph_raw": "REAL",
            "ph_voltage": "REAL",
            "livello_acqua": "REAL",
            "acqua_presente": "INTEGER",
            "livello_acqua_ok": "INTEGER",
            "pompa_attiva": "INTEGER DEFAULT 0",
            "tempo_pompa_secondi": "REAL DEFAULT 0",
            "irrigazioni": "INTEGER DEFAULT 0",
            "irrigazioni_automatiche": "INTEGER DEFAULT 0",
            "irrigazioni_manuali": "INTEGER DEFAULT 0",
            "campioni": "INTEGER DEFAULT 0",
        },
    )

    definitions = [
        "ora TEXT PRIMARY KEY",
        "ultimo_timestamp_cache TEXT",
        "campioni INTEGER NOT NULL DEFAULT 0",
    ]
    for field in CAMPI_MEDI + CAMPI_BOOLEANI:
        definitions.append(f"somma_{field} REAL NOT NULL DEFAULT 0")
        definitions.append(f"conteggio_{field} INTEGER NOT NULL DEFAULT 0")
    connection.execute(
        "CREATE TABLE IF NOT EXISTS accumulo_orario ("
        + ", ".join(definitions)
        + ")"
    )

    accumulator_columns: dict[str, str] = {
        "ultimo_timestamp_cache": "TEXT",
        "campioni": "INTEGER NOT NULL DEFAULT 0",
    }
    for field in CAMPI_MEDI + CAMPI_BOOLEANI:
        accumulator_columns[f"somma_{field}"] = "REAL NOT NULL DEFAULT 0"
        accumulator_columns[f"conteggio_{field}"] = "INTEGER NOT NULL DEFAULT 0"
    aggiungi_colonne(connection, "accumulo_orario", accumulator_columns)
    connection.commit()


def leggi_cache() -> tuple[dict[str, Any] | None, datetime | None]:
    data = leggi_json(CACHE_SENSORI)
    timestamp = parse_timestamp(data.get("aggiornato_il") or data.get("timestamp"))
    if not data or timestamp is None:
        return None, None
    if datetime.now() - timestamp > timedelta(seconds=MAX_ETA_CACHE):
        return None, None
    return data, timestamp


def aggiungi_campione(
    connection: sqlite3.Connection,
    data: dict[str, Any],
    timestamp: datetime,
) -> bool:
    hour_key = timestamp.replace(minute=0, second=0, microsecond=0).strftime(
        "%Y-%m-%d %H:%M"
    )
    cache_timestamp = timestamp.strftime("%Y-%m-%d %H:%M:%S")
    existing = connection.execute(
        "SELECT ultimo_timestamp_cache FROM accumulo_orario WHERE ora = ?",
        (hour_key,),
    ).fetchone()
    if existing and existing[0] == cache_timestamp:
        return False

    connection.execute(
        "INSERT OR IGNORE INTO accumulo_orario (ora) VALUES (?)",
        (hour_key,),
    )
    assignments = ["ultimo_timestamp_cache = ?", "campioni = campioni + 1"]
    parameters: list[Any] = [cache_timestamp]

    for field in CAMPI_MEDI:
        value = numero_o_none(data.get(field))
        if value is not None:
            assignments.extend(
                [
                    f"somma_{field} = somma_{field} + ?",
                    f"conteggio_{field} = conteggio_{field} + 1",
                ]
            )
            parameters.append(value)

    for field in CAMPI_BOOLEANI:
        value = booleano_o_none(data.get(field))
        if value is not None:
            assignments.extend(
                [
                    f"somma_{field} = somma_{field} + ?",
                    f"conteggio_{field} = conteggio_{field} + 1",
                ]
            )
            parameters.append(value)

    parameters.append(hour_key)
    connection.execute(
        "UPDATE accumulo_orario SET "
        + ", ".join(assignments)
        + " WHERE ora = ?",
        parameters,
    )
    connection.commit()
    return True


def media(row: sqlite3.Row, field: str) -> float | None:
    count = row[f"conteggio_{field}"]
    return round(row[f"somma_{field}"] / count, 2) if count else None


def statistiche_pompa(hour_key: str) -> dict[str, Any]:
    state = leggi_json(STATO_POMPA)
    start = datetime.strptime(hour_key, "%Y-%m-%d %H:%M").timestamp()
    end = start + 3600
    runtime = 0.0
    starts = 0
    automatic = 0
    manual = 0

    events = state.get("events", [])
    if not isinstance(events, list):
        events = []

    for event in events:
        if not isinstance(event, dict):
            continue
        try:
            epoch = float(event.get("epoch", 0))
        except (TypeError, ValueError):
            continue
        if not start <= epoch < end:
            continue
        event_type = str(event.get("type") or "").lower()
        reason = str(event.get("reason") or "").lower()
        if event_type == "run":
            runtime += max(numero_o_none(event.get("seconds")) or 0.0, 0.0)
        elif event_type == "start":
            starts += 1
            if reason == "automatico-umidita":
                automatic += 1
            else:
                manual += 1

    pump_active = 0
    if state.get("pump_on") is True:
        started = parse_timestamp(state.get("started_at"))
        if started is not None and start <= started.timestamp() < end:
            pump_active = 1
            runtime += max(0.0, min(time.time(), end) - started.timestamp())

    return {
        "pompa_attiva": pump_active,
        "tempo_pompa_secondi": round(runtime, 2),
        "irrigazioni": starts,
        "irrigazioni_automatiche": automatic,
        "irrigazioni_manuali": manual,
    }


def aggiorna_storico(connection: sqlite3.Connection) -> None:
    connection.row_factory = sqlite3.Row
    rows = connection.execute(
        "SELECT * FROM accumulo_orario ORDER BY ora"
    ).fetchall()

    for row in rows:
        values = {field: media(row, field) for field in CAMPI_MEDI}
        water_present_avg = media(row, "acqua_presente")
        water_ok_avg = media(row, "livello_acqua_ok")
        pump = statistiche_pompa(row["ora"])

        connection.execute(
            """
            INSERT INTO storico_orario (
                timestamp, temperatura, umidita_aria, umidita_terreno,
                umidita_terreno_raw, luce, tds, tds_raw, campioni,
                ph, ph_raw, ph_voltage, livello_acqua, acqua_presente,
                livello_acqua_ok, pompa_attiva, tempo_pompa_secondi,
                irrigazioni, irrigazioni_automatiche, irrigazioni_manuali
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(timestamp) DO UPDATE SET
                temperatura = excluded.temperatura,
                umidita_aria = excluded.umidita_aria,
                umidita_terreno = excluded.umidita_terreno,
                umidita_terreno_raw = excluded.umidita_terreno_raw,
                luce = excluded.luce,
                tds = excluded.tds,
                tds_raw = excluded.tds_raw,
                campioni = excluded.campioni,
                ph = excluded.ph,
                ph_raw = excluded.ph_raw,
                ph_voltage = excluded.ph_voltage,
                livello_acqua = excluded.livello_acqua,
                acqua_presente = excluded.acqua_presente,
                livello_acqua_ok = excluded.livello_acqua_ok,
                pompa_attiva = excluded.pompa_attiva,
                tempo_pompa_secondi = excluded.tempo_pompa_secondi,
                irrigazioni = excluded.irrigazioni,
                irrigazioni_automatiche = excluded.irrigazioni_automatiche,
                irrigazioni_manuali = excluded.irrigazioni_manuali
            """,
            (
                row["ora"],
                values["temperatura"],
                values["umidita_aria"],
                values["umidita_terreno"],
                values["umidita_terreno_raw"],
                values["luce"],
                values["tds"],
                values["tds_raw"],
                row["campioni"],
                values["ph"],
                values["ph_raw"],
                values["ph_voltage"],
                values["livello_acqua"],
                None if water_present_avg is None else int(water_present_avg >= 0.5),
                None if water_ok_avg is None else int(water_ok_avg >= 0.5),
                pump["pompa_attiva"],
                pump["tempo_pompa_secondi"],
                pump["irrigazioni"],
                pump["irrigazioni_automatiche"],
                pump["irrigazioni_manuali"],
            ),
        )

    limit = (datetime.now() - timedelta(hours=1)).replace(
        minute=0, second=0, microsecond=0
    ).strftime("%Y-%m-%d %H:%M")
    connection.execute("DELETE FROM accumulo_orario WHERE ora < ?", (limit,))
    pulisci_storico(connection)
    connection.commit()



def retention_days() -> int:
    settings = leggi_json(SETTINGS_PATH)
    try:
        days = int(settings.get("retention", RETENTION_DEFAULT))
    except (TypeError, ValueError):
        days = RETENTION_DEFAULT
    return days if days in RETENTION_ALLOWED else RETENTION_DEFAULT


def pulisci_storico(connection: sqlite3.Connection) -> None:
    days = retention_days()
    if days == 0:
        return
    limit = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d %H:%M")
    connection.execute("DELETE FROM storico_orario WHERE timestamp < ?", (limit,))
    connection.execute("DELETE FROM accumulo_orario WHERE ora < ?", (limit,))


def main() -> None:
    connection = connessione_db()
    prepara_db(connection)
    print(
        "Medie orarie complete avviate. "
        f"Campionamento ogni {INTERVALLO_CAMPIONAMENTO} secondi.",
        flush=True,
    )
    try:
        while True:
            data, timestamp = leggi_cache()
            if data is not None and timestamp is not None:
                if aggiungi_campione(connection, data, timestamp):
                    aggiorna_storico(connection)
                    print(
                        f"Campione completo acquisito: {timestamp:%Y-%m-%d %H:%M:%S}",
                        flush=True,
                    )
            time.sleep(INTERVALLO_CAMPIONAMENTO)
    finally:
        connection.close()


if __name__ == "__main__":
    main()
