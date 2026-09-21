import base64
import io
import json
import os
import sqlite3
import tempfile
import time
import uuid
from datetime import datetime
from pathlib import Path

from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
from google import genai
from google.genai import types
from PIL import Image, UnidentifiedImageError

from notification_manager import registra_token, rimuovi_token
from report_routine import esegui as esegui_report

# -----------------------------------------------------------------------------
# Configurazione
# -----------------------------------------------------------------------------

GEMINI_API_KEY = os.getenv(
    "HYDROTOWER_GEMINI_API_KEY",
    "INSERISCI_QUI_LA_TUA_API_KEY",
)
MODEL_NAME = os.getenv(
    "HYDROTOWER_GEMINI_MODEL",
    "gemini-3.6-flash",
)

DB_PATH = "/home/hydrotower/hydrotower.db"
CACHE_SENSORI = "/home/hydrotower/ultimo_rilevamento.json"
FOTO_DIR = "/home/hydrotower/hydrotower-photos"
SETTINGS_PATH = "/home/hydrotower/hydrotower_settings.json"
PUMP_STATE_PATH = Path("/home/hydrotower/hydrotower_pump_state.json")
PUMP_COMMAND_PATH = Path("/home/hydrotower/hydrotower_pump_command.json")

RETENTION_ALLOWED = {0, 7, 30, 90, 365}
MAX_UPLOAD_BYTES = 12 * 1024 * 1024

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = MAX_UPLOAD_BYTES
CORS(app)


# -----------------------------------------------------------------------------
# Funzioni comuni
# -----------------------------------------------------------------------------


def chiave_gemini_configurata():
    return bool(
        GEMINI_API_KEY
        and GEMINI_API_KEY != "INSERISCI_QUI_LA_TUA_API_KEY"
    )


def nuovo_client_gemini():
    """Crea un client nuovo per ogni richiesta AI."""
    if not chiave_gemini_configurata():
        raise RuntimeError(
            "Chiave Gemini non configurata. Controlla /etc/hydrotower.env."
        )

    return genai.Client(api_key=GEMINI_API_KEY)


def query_db(query, args=(), one=False):
    conn = sqlite3.connect(DB_PATH, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")

    try:
        righe = conn.execute(query, args).fetchall()
        return (righe[0] if righe else None) if one else righe
    finally:
        conn.close()


def leggi_json_file(percorso):
    with open(percorso, "r", encoding="utf-8") as file_json:
        return json.load(file_json)


def normalizza_azioni(valore):
    if isinstance(valore, list):
        return [str(elemento) for elemento in valore]

    if valore is None:
        return []

    try:
        decodificato = json.loads(valore)
        if isinstance(decodificato, list):
            return [str(elemento) for elemento in decodificato]
    except (json.JSONDecodeError, TypeError):
        pass

    return [str(valore)]


def aggiungi_url_foto(risultato):
    """Aggiunge foto_nome e foto_url se il file esiste sul Raspberry."""
    foto_salvata = risultato.get("foto")

    if not foto_salvata:
        risultato["foto_nome"] = None
        risultato["foto_url"] = None
        return risultato

    nome_foto = os.path.basename(str(foto_salvata))
    percorso_foto = os.path.join(FOTO_DIR, nome_foto)

    if os.path.isfile(percorso_foto):
        risultato["foto_nome"] = nome_foto
        risultato["foto_url"] = f"/foto/{nome_foto}"
    else:
        risultato["foto_nome"] = None
        risultato["foto_url"] = None

    return risultato


def build_prompt(sensori):
    return f"""Sei un agronomo esperto in colture idroponiche verticali.
Analizza lo stato della pianta in base ai dati disponibili e alla fotografia,
se presente. Non inventare valori mancanti.

DATI SENSORI ATTUALI:
- Temperatura aria: {sensori.get('temperatura')} C
- Umidita aria: {sensori.get('umidita', sensori.get('umidita_aria'))} %
- Umidita terreno: {sensori.get('umidita_terreno')} %
- TDS: {sensori.get('tds', sensori.get('tds_ppm'))} ppm
- pH: {sensori.get('ph')}
- Luce: {sensori.get('luce')} lux
- Livello acqua: {sensori.get('livello_acqua')} %

REGOLE OBBLIGATORIE PER LA LETTURA VOCALE:
- Non rappresentare mai un intervallo con un trattino.
- Non scrivere mai forme come "18-28", "5,5-6,8" oppure "600-1100".
- Scrivi sempre "da 18 a 28", "da 5,5 a 6,8" e "da 600 a 1100".
- Usa questa forma in sommario, analisi, azioni, condizioni ottimali e osservazioni.
- Per una durata scrivi "irrigare da 10 a 15 minuti".
- Per la temperatura scrivi "da 18 a 28 gradi Celsius".
- Per una percentuale scrivi "da 40 a 75 per cento".
- Per TDS scrivi "da 600 a 1100 parti per milione".
- Prima di rispondere controlla che nessun intervallo numerico contenga un trattino.
- Non inventare osservazioni visive se la fotografia non è presente o non è leggibile.

Rispondi esclusivamente con un oggetto JSON valido con questa struttura:
{{
  "punteggio": 1,
  "stato": "Ottimo, Buono, Discreto oppure Critico",
  "sommario": "Descrizione generale",
  "visivo": "Osservazioni sulla fotografia o Nessuna immagine fornita",
  "sensori_analisi": "Analisi dei valori disponibili",
  "azioni": ["Azione 1", "Azione 2", "Azione 3"],
  "azioni_urgenti": 0
}}
"""


def prepara_foto_base64(foto_base64):
    if "," in foto_base64:
        foto_base64 = foto_base64.split(",", 1)[1]

    raw = base64.b64decode(foto_base64, validate=True)

    with Image.open(io.BytesIO(raw)) as immagine:
        immagine = immagine.convert("RGB")
        immagine.thumbnail((1024, 1024))
        buffer = io.BytesIO()
        immagine.save(buffer, "JPEG", quality=85)

    return types.Part.from_bytes(
        data=buffer.getvalue(),
        mime_type="image/jpeg",
    )




def leggi_stato_pompa() -> dict:
    try:
        data = json.loads(PUMP_STATE_PATH.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return {}


def scrivi_comando_pompa(action: str, **data) -> dict:
    payload = {
        "id": uuid.uuid4().hex,
        "action": action,
        "created": time.time(),
        **data,
    }
    temporary = PUMP_COMMAND_PATH.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, PUMP_COMMAND_PATH)
    return payload


@app.get("/api/automazione/stato")
def stato_automazione():
    return jsonify({"ok": True, "stato": leggi_stato_pompa()})


@app.post("/api/pompa/avvia")
def avvia_pompa():
    body = request.get_json(silent=True) or {}
    try:
        seconds = float(body.get("seconds", 5))
    except (TypeError, ValueError):
        return jsonify({"ok": False, "error": "seconds non valido"}), 400
    if not 0.5 <= seconds <= 15:
        return jsonify({"ok": False, "error": "seconds deve essere tra 0.5 e 15"}), 400
    return jsonify({
        "ok": True,
        "comando": scrivi_comando_pompa("start", seconds=seconds, reason="api-manuale"),
    }), 202


@app.post("/api/pompa/ferma")
def ferma_pompa():
    return jsonify({
        "ok": True,
        "comando": scrivi_comando_pompa("stop", reason="api-manuale"),
    }), 202


@app.post("/api/pompa/reset-sicurezza")
def reset_sicurezza_pompa():
    return jsonify({"ok": True, "comando": scrivi_comando_pompa("reset")}), 202


@app.post("/api/notifiche/token")
def registra_token_notifiche():
    body = request.get_json(silent=True) or {}
    try:
        total = registra_token(body.get("token"))
        return jsonify({"ok": True, "tokensRegistrati": total})
    except Exception as error:
        return jsonify({"ok": False, "error": str(error)}), 400


@app.delete("/api/notifiche/token")
def rimuovi_token_notifiche():
    body = request.get_json(silent=True) or {}
    total = rimuovi_token(body.get("token"))
    return jsonify({"ok": True, "tokensRegistrati": total})


# -----------------------------------------------------------------------------
# Analisi AI immediata
# -----------------------------------------------------------------------------


@app.post("/api/analizza")
def analizza():
    try:
        dati = request.get_json(silent=True)

        if not isinstance(dati, dict):
            return jsonify({"error": "Richiesta JSON non valida"}), 400

        sensori = dati.get("sensori", {})
        if not isinstance(sensori, dict):
            sensori = {}

        contenuti = [build_prompt(sensori)]
        foto_base64 = dati.get("foto")

        if isinstance(foto_base64, str) and foto_base64.strip():
            contenuti.append(prepara_foto_base64(foto_base64))

        client_gemini = nuovo_client_gemini()
        risposta = client_gemini.models.generate_content(
            model=MODEL_NAME,
            contents=contenuti,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                thinking_config=types.ThinkingConfig(
                    thinking_level=types.ThinkingLevel.HIGH,
                ),
            ),
        )

        if not risposta.text:
            raise RuntimeError("Gemini non ha restituito alcun testo")

        risultato = json.loads(risposta.text)
        if not isinstance(risultato, dict):
            raise RuntimeError("Gemini non ha restituito un oggetto JSON")

        risultato["azioni"] = normalizza_azioni(risultato.get("azioni"))
        return jsonify(risultato)

    except (ValueError, UnidentifiedImageError) as errore:
        return jsonify({"error": f"Fotografia non valida: {errore}"}), 400
    except Exception as errore:
        app.logger.exception("Analisi AI fallita")
        return jsonify({"error": str(errore)}), 500


# -----------------------------------------------------------------------------
# Sensori e storico
# -----------------------------------------------------------------------------


@app.get("/api/sensori/attuali")
def sensori_attuali():
    try:
        return jsonify(leggi_json_file(CACHE_SENSORI))
    except (FileNotFoundError, json.JSONDecodeError) as errore:
        return jsonify({"error": str(errore)}), 404


@app.get("/api/storico")
def storico():
    if not os.path.exists(DB_PATH):
        return jsonify([])

    try:
        righe = query_db(
            "SELECT * FROM storico_orario "
            "ORDER BY timestamp DESC LIMIT 3000"
        )
    except sqlite3.OperationalError:
        return jsonify([])

    return jsonify([dict(riga) for riga in righe])


# -----------------------------------------------------------------------------
# Report giornalieri
# -----------------------------------------------------------------------------


@app.get("/api/report/dates")
def report_dates():
    if not os.path.exists(DB_PATH):
        return jsonify([])

    try:
        righe = query_db(
            "SELECT data, punteggio, stato FROM report ORDER BY data"
        )
    except sqlite3.OperationalError:
        return jsonify([])

    return jsonify([dict(riga) for riga in righe])


@app.get("/api/report/<data_str>")
def report_singolo(data_str):
    try:
        datetime.strptime(data_str, "%Y-%m-%d")
    except ValueError:
        return jsonify({"error": "Data non valida"}), 400

    try:
        riga = query_db(
            "SELECT * FROM report WHERE data = ?",
            (data_str,),
            one=True,
        )
    except sqlite3.OperationalError:
        riga = None

    if not riga:
        return jsonify({"error": "Nessun report per questa data"}), 404

    risultato = dict(riga)
    risultato["azioni"] = normalizza_azioni(risultato.get("azioni"))
    aggiungi_url_foto(risultato)
    return jsonify(risultato)


@app.get("/foto/<path:nome>")
def foto(nome):
    return send_from_directory(
        FOTO_DIR,
        nome,
        conditional=True,
        max_age=300,
    )


# -----------------------------------------------------------------------------
# Impostazioni condivise
# -----------------------------------------------------------------------------


def leggi_impostazioni():
    valori = {
        "tempMin": 18.0,
        "tempMax": 28.0,
        "phMin": 5.5,
        "phMax": 7.0,
        "tdsMin": 600.0,
        "tdsMax": 1200.0,
        "waterMin": 20.0,
        "humidityAirMin": 40.0,
        "humidityAirMax": 75.0,
        "humiditySoilMin": 35.0,
        "humiditySoilMax": 75.0,
        "interval": 5,
        "retention": 30,
        "notifications": True,
        "reportNotifications": True,
        "geminiAutoThresholds": False,
        "thresholdUpdatedAt": None,
        "towerName": "Torre #1",
        "thresholdSource": "manual",
        "irrigationEnabled": False,
        "startBelowSoilHumidity": 35.0,
        "targetSoilHumidity": 60.0,
        "wateringPulseSeconds": 3.0,
        "wateringTimesPerDay": 2,
        "absorptionPauseMinutes": 5.0,
        "minimumMinutesBetweenCycles": 180.0,
        "minimumObservedHumidityIncrease": 2.0,
        "maximumTimeBelowMinimumMinutes": 120.0,
        "maximumTimeAboveTargetMinutes": 180.0,
        "lightRecommendationEnabled": True,
        "targetAmbientLux": 12000.0,
        "lightHoursPerDay": 14.0,
        "lightPowerPercent": 60.0,
        "minimumDarkHours": 8.0,
    }

    try:
        salvate = leggi_json_file(SETTINGS_PATH)
        if isinstance(salvate, dict):
            valori.update(salvate)
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        pass

    return valori


def _numero_configurazione(dati, chiave, minimo, massimo):
    valore = dati.get(chiave)
    if isinstance(valore, bool):
        raise ValueError(f"{chiave} non è un numero valido")

    try:
        numero = float(valore)
    except (TypeError, ValueError) as errore:
        raise ValueError(f"{chiave} non è un numero valido") from errore

    if not minimo <= numero <= massimo:
        raise ValueError(f"{chiave} deve essere tra {minimo} e {massimo}")

    return numero


def valida_impostazioni(dati):
    valori = {
        "tempMin": _numero_configurazione(dati, "tempMin", 0, 50),
        "tempMax": _numero_configurazione(dati, "tempMax", 0, 50),
        "phMin": _numero_configurazione(dati, "phMin", 0, 14),
        "phMax": _numero_configurazione(dati, "phMax", 0, 14),
        "tdsMin": _numero_configurazione(dati, "tdsMin", 0, 5000),
        "tdsMax": _numero_configurazione(dati, "tdsMax", 0, 5000),
        "waterMin": _numero_configurazione(dati, "waterMin", 0, 100),
        "humidityAirMin": _numero_configurazione(
            dati, "humidityAirMin", 0, 100
        ),
        "humidityAirMax": _numero_configurazione(
            dati, "humidityAirMax", 0, 100
        ),
        "humiditySoilMin": _numero_configurazione(
            dati, "humiditySoilMin", 0, 100
        ),
        "humiditySoilMax": _numero_configurazione(
            dati, "humiditySoilMax", 0, 100
        ),
    }

    coppie = (
        ("tempMin", "tempMax", "temperatura"),
        ("phMin", "phMax", "pH"),
        ("tdsMin", "tdsMax", "TDS"),
        ("humidityAirMin", "humidityAirMax", "umidità aria"),
        ("humiditySoilMin", "humiditySoilMax", "umidità terreno"),
    )

    for minimo, massimo, nome in coppie:
        if valori[minimo] >= valori[massimo]:
            raise ValueError(
                f"Il minimo di {nome} deve essere inferiore al massimo"
            )

    return valori


@app.get("/api/impostazioni")
def api_leggi_impostazioni():
    return jsonify(leggi_impostazioni())


@app.post("/api/impostazioni")
def api_salva_impostazioni():
    ricevute = request.get_json(silent=True)
    if not isinstance(ricevute, dict):
        return jsonify({
            "ok": False,
            "error": "Configurazione JSON non valida",
        }), 400

    complete = {**leggi_impostazioni(), **ricevute}

    try:
        soglie = valida_impostazioni(complete)
        retention = int(complete.get("retention", 30))
        interval = int(complete.get("interval", 5))
        watering_times_per_day = int(complete.get("wateringTimesPerDay", 2))
        operational = {
            "startBelowSoilHumidity": _numero_configurazione(
                complete, "startBelowSoilHumidity", 0, 100
            ),
            "targetSoilHumidity": _numero_configurazione(
                complete, "targetSoilHumidity", 0, 100
            ),
            "wateringPulseSeconds": _numero_configurazione(
                complete, "wateringPulseSeconds", 0.5, 15
            ),
            "absorptionPauseMinutes": _numero_configurazione(
                complete, "absorptionPauseMinutes", 1, 1440
            ),
            "minimumMinutesBetweenCycles": _numero_configurazione(
                complete, "minimumMinutesBetweenCycles", 5, 1440
            ),
            "minimumObservedHumidityIncrease": _numero_configurazione(
                complete, "minimumObservedHumidityIncrease", 0, 100
            ),
            "maximumTimeBelowMinimumMinutes": _numero_configurazione(
                complete, "maximumTimeBelowMinimumMinutes", 1, 10080
            ),
            "maximumTimeAboveTargetMinutes": _numero_configurazione(
                complete, "maximumTimeAboveTargetMinutes", 1, 10080
            ),
            "targetAmbientLux": _numero_configurazione(
                complete, "targetAmbientLux", 0, 200000
            ),
            "lightHoursPerDay": _numero_configurazione(
                complete, "lightHoursPerDay", 0, 24
            ),
            "lightPowerPercent": _numero_configurazione(
                complete, "lightPowerPercent", 0, 100
            ),
            "minimumDarkHours": _numero_configurazione(
                complete, "minimumDarkHours", 0, 24
            ),
        }
        if not 1 <= watering_times_per_day <= 24:
            raise ValueError("wateringTimesPerDay deve essere tra 1 e 24")
        if operational["startBelowSoilHumidity"] >= operational["targetSoilHumidity"]:
            raise ValueError(
                "startBelowSoilHumidity deve essere inferiore a targetSoilHumidity"
            )
        if operational["lightHoursPerDay"] + operational["minimumDarkHours"] > 24:
            raise ValueError(
                "lightHoursPerDay + minimumDarkHours non può superare 24"
            )
    except (TypeError, ValueError) as errore:
        return jsonify({"ok": False, "error": str(errore)}), 400

    if retention not in RETENTION_ALLOWED:
        return jsonify({
            "ok": False,
            "error": "Conservazione consentita: 0, 7, 30, 90 o 365",
        }), 400

    if interval not in {1, 5, 10, 30, 60}:
        return jsonify({
            "ok": False,
            "error": "Intervallo consentito: 1, 5, 10, 30 o 60",
        }), 400

    correnti = leggi_impostazioni()
    correnti.update(soglie)
    correnti.update({
        "interval": interval,
        "retention": retention,
        "notifications": bool(complete.get("notifications", True)),
        "reportNotifications": bool(
            complete.get("reportNotifications", True)
        ),
        "geminiAutoThresholds": bool(
            complete.get("geminiAutoThresholds", False)
        ),
        "thresholdUpdatedAt": complete.get("thresholdUpdatedAt"),
        "towerName": (
            str(complete.get("towerName", "Torre #1")).strip()[:80]
            or "Torre #1"
        ),
        "thresholdSource": str(complete.get("thresholdSource", "manual")),
        "irrigationEnabled": bool(complete.get("irrigationEnabled", False)),
        "startBelowSoilHumidity": operational["startBelowSoilHumidity"],
        "targetSoilHumidity": operational["targetSoilHumidity"],
        "wateringPulseSeconds": operational["wateringPulseSeconds"],
        "wateringTimesPerDay": watering_times_per_day,
        "absorptionPauseMinutes": operational["absorptionPauseMinutes"],
        "minimumMinutesBetweenCycles": operational["minimumMinutesBetweenCycles"],
        "minimumObservedHumidityIncrease": operational["minimumObservedHumidityIncrease"],
        "maximumTimeBelowMinimumMinutes": operational["maximumTimeBelowMinimumMinutes"],
        "maximumTimeAboveTargetMinutes": operational["maximumTimeAboveTargetMinutes"],
        "lightRecommendationEnabled": bool(complete.get("lightRecommendationEnabled", True)),
        "targetAmbientLux": operational["targetAmbientLux"],
        "lightHoursPerDay": operational["lightHoursPerDay"],
        "lightPowerPercent": operational["lightPowerPercent"],
        "minimumDarkHours": operational["minimumDarkHours"],
    })

    percorso_temporaneo = SETTINGS_PATH + ".tmp"
    with open(
        percorso_temporaneo,
        "w",
        encoding="utf-8",
    ) as file_impostazioni:
        json.dump(
            correnti,
            file_impostazioni,
            ensure_ascii=False,
            indent=2,
        )

    os.replace(percorso_temporaneo, SETTINGS_PATH)
    return jsonify({"ok": True, "impostazioni": correnti})


# -----------------------------------------------------------------------------
# Routine AI archiviata
# -----------------------------------------------------------------------------


@app.post("/api/analisi-routine/raspberry")
def analisi_routine_raspberry():
    try:
        risultato = esegui_report(
            sorgente="raspberry",
            elimina_vecchia=True,
        )

        if not isinstance(risultato, dict):
            return jsonify({
                "ok": False,
                "error": "La routine non ha restituito un oggetto JSON valido",
            }), 500

        if risultato.get("ok") is not True:
            return jsonify(risultato), 500

        return jsonify(risultato), 200

    except Exception as errore:
        app.logger.exception("Routine Raspberry fallita")
        return jsonify({
            "ok": False,
            "error": str(errore),
            "provider_principale": os.getenv(
                "HYDROTOWER_AI_PRIMARY",
                "gemini",
            ),
            "provider_fallback": os.getenv(
                "HYDROTOWER_AI_FALLBACK",
                "groq",
            ),
        }), 500


@app.post("/api/analisi-routine/telefono")
def analisi_routine_telefono():
    if "foto" not in request.files:
        return jsonify({"ok": False, "error": "Foto mancante"}), 400

    percorso = None

    try:
        foto_file = request.files["foto"]

        if not foto_file or not foto_file.filename:
            return jsonify({"ok": False, "error": "Foto vuota"}), 400

        suffisso = Path(foto_file.filename).suffix.lower()
        if suffisso not in {".jpg", ".jpeg", ".png", ".webp"}:
            suffisso = ".jpg"

        with tempfile.NamedTemporaryFile(
            suffix=suffisso,
            delete=False,
        ) as file_temporaneo:
            foto_file.save(file_temporaneo.name)
            percorso = file_temporaneo.name

        risultato = esegui_report(
            sorgente="telefono",
            foto_path=percorso,
            elimina_vecchia=True,
        )

        if not isinstance(risultato, dict):
            return jsonify({
                "ok": False,
                "error": "La routine non ha restituito un oggetto JSON valido",
            }), 500

        codice = 200 if risultato.get("ok") is True else 500
        return jsonify(risultato), codice

    except Exception as errore:
        app.logger.exception("Routine telefono fallita")
        messaggio = str(errore)
        testo = messaggio.lower()

        quota_esaurita = any(
            valore in testo
            for valore in (
                "quota giornaliera",
                "quota exceeded",
                "resource_exhausted",
                "resource exhausted",
                "generate_content_free_tier_requests",
                "requestsperdayperprojectpermodel",
            )
        )

        if quota_esaurita:
            return jsonify({
                "ok": False,
                "retryable": False,
                "error": "Quota giornaliera Gemini esaurita per il modello configurato.",
                "details": messaggio,
            }), 429

        errore_temporaneo = any(
            valore in testo
            for valore in (
                "503",
                "unavailable",
                "high demand",
                "temporaneamente sovraccarico",
                "timeout",
            )
        )

        if errore_temporaneo:
            return jsonify({
                "ok": False,
                "retryable": True,
                "error": "Gemini è temporaneamente sovraccarico. Riprova tra poco.",
                "details": messaggio,
            }), 503

        return jsonify({
            "ok": False,
            "retryable": False,
            "error": messaggio,
        }), 500

    finally:
        if percorso:
            Path(percorso).unlink(missing_ok=True)


@app.get("/api/analisi-routine/ultima")
def ultima_analisi_routine():
    try:
        riga = query_db(
            "SELECT * FROM analisi_ai "
            "ORDER BY creato_il DESC LIMIT 1",
            one=True,
        )
    except sqlite3.OperationalError:
        riga = None

    if not riga:
        return jsonify({"error": "Nessuna analisi disponibile"}), 404

    risultato = dict(riga)
    risultato["azioni"] = normalizza_azioni(risultato.get("azioni"))
    aggiungi_url_foto(risultato)
    return jsonify(risultato)


# -----------------------------------------------------------------------------
# Stato del servizio
# -----------------------------------------------------------------------------


@app.get("/api/stato")
def stato():
    groq_key = os.getenv("HYDROTOWER_GROQ_API_KEY", "").strip()
    groq_model = os.getenv(
        "HYDROTOWER_GROQ_MODEL",
        "qwen/qwen3.8-27b",
    ).strip()
    provider_principale = os.getenv(
        "HYDROTOWER_AI_PRIMARY",
        "gemini",
    ).strip().lower()
    provider_fallback = os.getenv(
        "HYDROTOWER_AI_FALLBACK",
        "groq",
    ).strip().lower()

    return jsonify({
        "status": "ok",
        "message": "HydroTower backend attivo",
        "provider_ai_principale": provider_principale,
        "provider_ai_fallback": provider_fallback,
        "gemini": {
            "configurato": chiave_gemini_configurata(),
            "modello": MODEL_NAME,
        },
        "groq": {
            "configurato": bool(groq_key),
            "modello": groq_model,
        },
    })


@app.errorhandler(413)
def file_troppo_grande(_errore):
    return jsonify({
        "ok": False,
        "error": "Fotografia troppo grande. Limite: 12 MB.",
    }), 413


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=5000,
        debug=False,
    )
