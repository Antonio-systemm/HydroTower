#!/usr/bin/env python3
"""
HydroTower - Demone di lettura sensori

Legge continuamente:
- Arduino Nano via USB seriale:
  - umidita del terreno
  - TDS della soluzione
  - pH della soluzione
  - valori diagnostici grezzi di terreno, TDS e pH
- DHT22 sul GPIO4:
  - temperatura dell'aria
  - umidita dell'aria
- TSL25911FN via I2C, indirizzo 0x29:
  - illuminamento in lux

Salva l'ultima lettura completa in:
/home/hydrotower/ultimo_rilevamento.json
"""

import json
import os
import time
from pathlib import Path
from typing import Any

import adafruit_dht
import adafruit_tsl2591
import board
import busio
import serial
from water_level import water_status

# -----------------------------------------------------------------------------
# Configurazione
# -----------------------------------------------------------------------------

PORTA_ARDUINO = os.getenv(
    "HYDROTOWER_ARDUINO_PORT",
    "/dev/ttyUSB0",
)

BAUD = int(os.getenv("HYDROTOWER_ARDUINO_BAUD", "9600"))
DHT_PIN = board.D4
DHT_TIPO = adafruit_dht.DHT22

CACHE_FILE = Path(
    "/home/hydrotower/ultimo_rilevamento.json"
)

INTERVALLO = 1
RITARDO_RICONNESSIONE_SERIALE = 5

# -----------------------------------------------------------------------------
# Inizializzazione dei sensori Raspberry Pi
# -----------------------------------------------------------------------------

dht = DHT_TIPO(DHT_PIN)

i2c = busio.I2C(board.SCL, board.SDA)
sensore_luce = adafruit_tsl2591.TSL2591(i2c)

# -----------------------------------------------------------------------------
# Funzioni comuni
# -----------------------------------------------------------------------------


def numero_o_none(
    valore: Any,
    *,
    minimo: float | None = None,
    massimo: float | None = None,
) -> float | None:
    """Converte un valore in float e applica limiti facoltativi."""
    if valore is None or isinstance(valore, bool):
        return None

    try:
        numero = float(valore)
    except (TypeError, ValueError):
        return None

    if minimo is not None and numero < minimo:
        return None

    if massimo is not None and numero > massimo:
        return None

    return numero


def intero_o_none(
    valore: Any,
    *,
    minimo: int | None = None,
    massimo: int | None = None,
) -> int | None:
    """Converte un valore in intero e applica limiti facoltativi."""
    numero = numero_o_none(
        valore,
        minimo=float(minimo) if minimo is not None else None,
        massimo=float(massimo) if massimo is not None else None,
    )

    if numero is None:
        return None

    return int(round(numero))


# -----------------------------------------------------------------------------
# Lettura Arduino: terreno, TDS e pH
# -----------------------------------------------------------------------------


def leggi_arduino(
    ser: serial.Serial,
) -> dict[str, int | float | None] | None:
    """Legge e valida una riga JSON completa inviata da Arduino.

    Formato atteso:
    {
      "terreno_percentuale": 50,
      "terreno_raw": 600,
      "tds_ppm": 700,
      "tds_raw": 400,
      "ph": 6.90,
      "ph_raw": 736,
      "ph_voltage": 3.594,
      "ph_to_raw": 739
    }
    """
    linea = ""

    try:
        linea = ser.readline().decode(
            "utf-8",
            errors="ignore",
        ).strip()

        if not linea:
            return None

        if not linea.startswith("{") or not linea.endswith("}"):
            print(
                "Riga Arduino incompleta ignorata:",
                repr(linea),
                flush=True,
            )
            return None

        dati = json.loads(linea)

        if not isinstance(dati, dict):
            print(
                "Il JSON Arduino non e un oggetto:",
                repr(linea),
                flush=True,
            )
            return None

        tds = dati.get("tds_ppm")
        if tds is None:
            tds = dati.get("tds")

        risultato: dict[str, int | float | None] = {
            "umidita_terreno": numero_o_none(
                dati.get("terreno_percentuale"),
                minimo=0,
                massimo=100,
            ),
            "umidita_terreno_raw": intero_o_none(
                dati.get("terreno_raw"),
                minimo=0,
                massimo=1023,
            ),
            "tds": numero_o_none(
                tds,
                minimo=0,
                massimo=10000,
            ),
            "tds_raw": intero_o_none(
                dati.get("tds_raw"),
                minimo=0,
                massimo=1023,
            ),
            "ph": numero_o_none(
                dati.get("ph"),
                minimo=0,
                massimo=14,
            ),
            "ph_raw": intero_o_none(
                dati.get("ph_raw"),
                minimo=0,
                massimo=1023,
            ),
            "ph_voltage": numero_o_none(
                dati.get("ph_voltage"),
                minimo=0,
                massimo=5.5,
            ),
            "ph_to_raw": intero_o_none(
                dati.get("ph_to_raw"),
                minimo=0,
                massimo=1023,
            ),
        }

        if risultato["ph"] is None and dati.get("ph") is not None:
            print(
                "Valore pH Arduino non valido:",
                repr(dati.get("ph")),
                flush=True,
            )

        return risultato

    except json.JSONDecodeError as errore:
        print(
            "JSON Arduino non valido:",
            repr(linea),
            errore,
            flush=True,
        )
        return None

    except (UnicodeDecodeError, serial.SerialException) as errore:
        print(
            "Errore durante la lettura seriale:",
            errore,
            flush=True,
        )
        return None


# -----------------------------------------------------------------------------
# Lettura DHT22
# -----------------------------------------------------------------------------


def leggi_ambiente() -> dict[str, float] | None:
    """Legge temperatura e umidita dell'aria dal DHT22."""
    try:
        temperatura = dht.temperature
        umidita = dht.humidity

        if temperatura is None or umidita is None:
            return None

        return {
            "temperatura": round(float(temperatura), 1),
            "umidita_aria": round(float(umidita), 1),
        }

    except RuntimeError:
        # Gli errori temporanei del DHT22 sono comuni.
        return None

    except Exception as errore:
        print(
            "Errore imprevisto durante la lettura del DHT:",
            errore,
            flush=True,
        )
        return None


# -----------------------------------------------------------------------------
# Lettura TSL25911FN
# -----------------------------------------------------------------------------


def leggi_luce() -> dict[str, float] | None:
    """Legge l'intensita luminosa dal sensore TSL25911FN."""
    try:
        lux = sensore_luce.lux

        if lux is None:
            return None

        return {
            "luce": round(float(lux), 1),
        }

    except Exception as errore:
        print(
            "Errore durante la lettura del sensore di luce:",
            errore,
            flush=True,
        )
        return None


# -----------------------------------------------------------------------------
# Cache condivisa
# -----------------------------------------------------------------------------


def aggiorna_valori_validi(
    destinazione: dict[str, Any],
    nuovi_valori: dict[str, Any] | None,
) -> None:
    """Aggiorna solo i campi presenti e non nulli."""
    if nuovi_valori is None:
        return

    for chiave, valore in nuovi_valori.items():
        if valore is not None:
            destinazione[chiave] = valore


def scrivi_cache(dati: dict[str, Any]) -> None:
    """Scrive la cache JSON in modo atomico."""
    CACHE_FILE.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    percorso_temporaneo = CACHE_FILE.with_suffix(
        CACHE_FILE.suffix + ".tmp"
    )

    percorso_temporaneo.write_text(
        json.dumps(
            dati,
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )

    os.replace(
        percorso_temporaneo,
        CACHE_FILE,
    )


# -----------------------------------------------------------------------------
# Porta seriale
# -----------------------------------------------------------------------------


def apri_seriale() -> serial.Serial:
    """Apre la porta Arduino e attende il riavvio del Nano."""
    seriale = serial.Serial(
        PORTA_ARDUINO,
        BAUD,
        timeout=1,
    )

    time.sleep(2)
    seriale.reset_input_buffer()

    print(
        "Arduino collegato. Porta:",
        PORTA_ARDUINO,
        "Baud:",
        BAUD,
        flush=True,
    )

    return seriale


# -----------------------------------------------------------------------------
# Ciclo principale
# -----------------------------------------------------------------------------


def main() -> None:
    print(
        "Avvio del demone sensori HydroTower.",
        flush=True,
    )

    seriale: serial.Serial | None = None
    stato_sensori: dict[str, Any] = {}

    while True:
        try:
            if seriale is None or not seriale.is_open:
                seriale = apri_seriale()

            dati_arduino = leggi_arduino(seriale)
            aggiorna_valori_validi(
                stato_sensori,
                dati_arduino,
            )

        except serial.SerialException as errore:
            print(
                "Arduino non raggiungibile:",
                errore,
                flush=True,
            )

            if seriale is not None:
                try:
                    seriale.close()
                except Exception:
                    pass

            seriale = None
            time.sleep(RITARDO_RICONNESSIONE_SERIALE)

        ambiente = leggi_ambiente()
        aggiorna_valori_validi(
            stato_sensori,
            ambiente,
        )

        luce = leggi_luce()
        aggiorna_valori_validi(
            stato_sensori,
            luce,
        )
        acqua = water_status()
        aggiorna_valori_validi(
            stato_sensori,
            acqua,
        )

        stato_sensori["aggiornato_il"] = time.strftime(
            "%Y-%m-%d %H:%M:%S"
        )

        campi_essenziali = {
            "temperatura",
            "umidita_aria",
            "umidita_terreno",
            "tds",
            "ph",
            "luce",
        }

        campi_mancanti = sorted(
            campi_essenziali.difference(stato_sensori)
        )

        # La cache viene comunque scritta se esiste almeno un dato valido.
        # In questo modo un singolo sensore guasto non blocca tutti gli altri.
        if len(stato_sensori) > 1:
            scrivi_cache(stato_sensori)

            print(
                "Cache aggiornata:",
                json.dumps(
                    stato_sensori,
                    ensure_ascii=False,
                ),
                flush=True,
            )

        if campi_mancanti:
            print(
                "Dati non ancora disponibili:",
                ", ".join(campi_mancanti),
                flush=True,
            )

        time.sleep(INTERVALLO)


if __name__ == "__main__":
    try:
        main()
    finally:
        try:
            dht.exit()
        except Exception:
            pass

