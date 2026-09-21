#!/usr/bin/env python3
from __future__ import annotations

import base64
import io
import json
import os
import random
import sqlite3
import subprocess
import time
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any

from google import genai
from google.genai import types
from groq import Groq
from PIL import Image
from notification_manager import invia_notifica


GEMINI_API_KEY = os.getenv(
    "HYDROTOWER_GEMINI_API_KEY",
    "INSERISCI_QUI_LA_TUA_API_KEY",
)
MODEL_NAME = os.getenv("HYDROTOWER_GEMINI_MODEL", "gemini-3.6-flash")
GROQ_API_KEY = os.getenv("HYDROTOWER_GROQ_API_KEY", "")
GROQ_MODEL = os.getenv("HYDROTOWER_GROQ_MODEL", "qwen/qwen3.8-27b")
AI_PRIMARY = os.getenv("HYDROTOWER_AI_PRIMARY", "gemini").strip().lower()
AI_FALLBACK = os.getenv("HYDROTOWER_AI_FALLBACK", "groq").strip().lower()
PIANTA = os.getenv("HYDROTOWER_PIANTA", "lattuga")
CAMERA_DEVICE = os.getenv("HYDROTOWER_CAMERA", "/dev/video0")

FOTO_DIR = Path("/home/hydrotower/hydrotower-photos")
DB_PATH = "/home/hydrotower/hydrotower.db"
CACHE_SENSORI = Path("/home/hydrotower/ultimo_rilevamento.json")
SETTINGS_PATH = Path("/home/hydrotower/hydrotower_settings.json")
TENTATIVI_GEMINI = 4

FOTO_DIR.mkdir(parents=True, exist_ok=True)


def leggi_sensori() -> dict[str, Any]:
    dati = json.loads(CACHE_SENSORI.read_text(encoding="utf-8"))
    if not isinstance(dati, dict):
        raise RuntimeError("La cache sensori non contiene un oggetto JSON valido")

    return {
        "temperatura": dati.get("temperatura"),
        "umidita": dati.get("umidita_aria", dati.get("umidita")),
        "umidita_terreno": dati.get("umidita_terreno"),
        "luce": dati.get("luce"),
        "tds": dati.get("tds", dati.get("tds_ppm")),
        "tds_raw": dati.get("tds_raw"),
        "ph": dati.get("ph"),
        "livello_acqua": dati.get("livello_acqua"),
        "aggiornato_il": dati.get("aggiornato_il", dati.get("timestamp")),
    }


def scatta_foto_raspberry(destinazione: Path) -> None:
    subprocess.run(
        [
            "fswebcam",
            "--device",
            CAMERA_DEVICE,
            "-r",
            "1280x720",
            "--jpeg",
            "90",
            "-D",
            "2",
            "--no-banner",
            str(destinazione),
        ],
        check=True,
        timeout=30,
    )


def copia_foto_telefono(origine: str | Path, destinazione: Path) -> None:
    with Image.open(origine) as immagine:
        immagine.convert("RGB").save(destinazione, "JPEG", quality=90)


def prepara_immagine(path: str | Path) -> types.Part:
    with Image.open(path) as immagine:
        immagine = immagine.convert("RGB")
        immagine.thumbnail((1024, 1024))
        buffer = io.BytesIO()
        immagine.save(buffer, "JPEG", quality=85)

    return types.Part.from_bytes(
        data=buffer.getvalue(),
        mime_type="image/jpeg",
    )


def errore_temporaneo(errore: object) -> bool:
    messaggio = str(errore).lower()
    return any(
        testo in messaggio
        for testo in (
            "429",
            "503",
            "deadline exceeded",
            "high demand",
            "resource exhausted",
            "temporarily",
            "timeout",
            "unavailable",
        )
    )


def costruisci_prompt(sensori: dict[str, Any]) -> str:
    return f"""
Sei un agronomo esperto in coltura idroponica verticale.
Analizza una pianta di {PIANTA} usando la fotografia e soltanto i dati realmente disponibili.
Non inventare valori mancanti.

DATI SENSORI:
- Temperatura aria: {sensori.get('temperatura')} C
- Umidita aria: {sensori.get('umidita')} %
- Umidita terreno: {sensori.get('umidita_terreno')} %
- TDS: {sensori.get('tds')} ppm
- TDS grezzo: {sensori.get('tds_raw')}
- pH: {sensori.get('ph')}
- Luce: {sensori.get('luce')} lux
- Livello acqua: {sensori.get('livello_acqua')} %

REGOLE OBBLIGATORIE PER LA LETTURA VOCALE:
- Non rappresentare mai un intervallo con un trattino.
- Scrivi sempre gli intervalli nella forma "da X a Y".
- Per TDS usa "parti per milione" e per le percentuali usa "per cento".
- Restituisci esclusivamente JSON valido, senza testo esterno e senza blocchi Markdown.

Rispondi con questo oggetto JSON:
{{
  "punteggio": 1,
  "stato": "Ottimo, Buono, Discreto oppure Critico",
  "sommario": "Descrizione generale",
  "osservazioni_foto": "Osservazioni visive",
  "analisi_sensori": "Analisi dei dati disponibili",
  "condizioni_ottimali": "Condizioni ideali consigliate",
  "azioni": ["Azione 1", "Azione 2", "Azione 3"],
  "azioni_urgenti": 0,
  "soglie_consigliate": {{
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
    "humiditySoilMax": 75.0
  }}
}}
Le soglie devono essere prudenti, realistiche e adatte alla pianta indicata.
""".strip()


def normalizza_risultato_ai(risultato: Any) -> dict[str, Any]:
    if not isinstance(risultato, dict):
        raise RuntimeError("Il provider AI non ha restituito un oggetto JSON valido.")

    azioni = risultato.get("azioni")
    if isinstance(azioni, list):
        risultato["azioni"] = [str(azione) for azione in azioni]
    elif azioni is None:
        risultato["azioni"] = []
    else:
        risultato["azioni"] = [str(azioni)]

    return risultato


def genera_analisi_gemini(
    foto_path: Path,
    prompt: str,
) -> dict[str, Any]:
    if (
        not GEMINI_API_KEY
        or GEMINI_API_KEY == "INSERISCI_QUI_LA_TUA_API_KEY"
    ):
        raise RuntimeError("Chiave Gemini non configurata.")

    immagine = prepara_immagine(foto_path)
    ultimo_errore: Exception | None = None

    for tentativo in range(1, TENTATIVI_GEMINI + 1):
        try:
            client = genai.Client(api_key=GEMINI_API_KEY.strip())
            risposta = client.models.generate_content(
                model=MODEL_NAME,
                contents=[prompt, immagine],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    thinking_config=types.ThinkingConfig(
                        thinking_level=types.ThinkingLevel.HIGH,
                    ),
                ),
            )

            if not risposta.text:
                raise RuntimeError("Gemini non ha restituito alcun testo.")

            return normalizza_risultato_ai(json.loads(risposta.text))

        except Exception as errore:
            ultimo_errore = errore
            if (
                not errore_temporaneo(errore)
                or tentativo >= TENTATIVI_GEMINI
            ):
                break

            attesa = min(
                30.0,
                (2**tentativo) + random.uniform(0.0, 2.0),
            )
            print(
                "Gemini non disponibile. "
                f"Tentativo {tentativo}/{TENTATIVI_GEMINI}; "
                f"attesa {attesa:.1f}s.",
                flush=True,
            )
            time.sleep(attesa)

    raise RuntimeError(f"Analisi Gemini non riuscita: {ultimo_errore}") from ultimo_errore


def foto_data_uri(foto_path: Path) -> str:
    with Image.open(foto_path) as immagine:
        immagine = immagine.convert("RGB")
        immagine.thumbnail((1024, 1024))
        buffer = io.BytesIO()
        immagine.save(buffer, "JPEG", quality=85)

    encoded = base64.b64encode(buffer.getvalue()).decode("ascii")
    return f"data:image/jpeg;base64,{encoded}"


def genera_analisi_groq(
    foto_path: Path,
    prompt: str,
) -> dict[str, Any]:
    if not GROQ_API_KEY.strip():
        raise RuntimeError("Chiave Groq non configurata.")

    client = Groq(api_key=GROQ_API_KEY.strip())
    risposta = client.chat.completions.create(
        model=GROQ_MODEL,
        messages=[
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {
                        "type": "image_url",
                        "image_url": {"url": foto_data_uri(foto_path)},
                    },
                ],
            }
        ],
        response_format={"type": "json_object"},
        temperature=0.2,
        max_completion_tokens=4096,
        stream=False,
    )

    contenuto = risposta.choices[0].message.content
    if not contenuto:
        raise RuntimeError("Groq non ha restituito alcun testo.")

    return normalizza_risultato_ai(json.loads(contenuto))


def genera_analisi(
    foto_path: Path,
    sensori: dict[str, Any],
) -> tuple[dict[str, Any], dict[str, Any]]:
    prompt = costruisci_prompt(sensori)
    providers = [AI_PRIMARY]
    if AI_FALLBACK and AI_FALLBACK not in providers:
        providers.append(AI_FALLBACK)

    errori: dict[str, str] = {}

    for indice, provider in enumerate(providers):
        try:
            if provider == "gemini":
                analisi = genera_analisi_gemini(foto_path, prompt)
            elif provider == "groq":
                analisi = genera_analisi_groq(foto_path, prompt)
            else:
                raise RuntimeError(f"Provider AI non supportato: {provider}")

            return analisi, {
                "provider_usato": provider,
                "modello_usato": MODEL_NAME if provider == "gemini" else GROQ_MODEL,
                "fallback_usato": indice > 0,
                "errori_provider": errori,
            }

        except Exception as errore:
            errori[provider] = str(errore)
            print(
                f"Provider {provider} non disponibile: {errore}",
                flush=True,
            )

    dettagli = "; ".join(
        f"{provider}: {messaggio}"
        for provider, messaggio in errori.items()
    )
    raise RuntimeError(f"Tutti i provider AI hanno fallito. {dettagli}")

def _leggi_impostazioni() -> dict[str, Any]:
    try:
        dati = json.loads(SETTINGS_PATH.read_text(encoding="utf-8"))
        return dati if isinstance(dati, dict) else {}
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return {}


def _numero_soglia(
    dati: dict[str, Any],
    chiave: str,
    minimo: float,
    massimo: float,
) -> float:
    valore = dati.get(chiave)
    if isinstance(valore, bool):
        raise ValueError(f"Soglia {chiave} non valida")

    numero = float(valore)
    if not minimo <= numero <= massimo:
        raise ValueError(f"Soglia {chiave} fuori intervallo")

    return round(numero, 2)


def valida_soglie_ai(soglie: Any) -> dict[str, float]:
    if not isinstance(soglie, dict):
        raise ValueError("Gemini non ha restituito soglie valide")

    valori = {
        "tempMin": _numero_soglia(soglie, "tempMin", 0, 50),
        "tempMax": _numero_soglia(soglie, "tempMax", 0, 50),
        "phMin": _numero_soglia(soglie, "phMin", 0, 14),
        "phMax": _numero_soglia(soglie, "phMax", 0, 14),
        "tdsMin": _numero_soglia(soglie, "tdsMin", 0, 5000),
        "tdsMax": _numero_soglia(soglie, "tdsMax", 0, 5000),
        "waterMin": _numero_soglia(soglie, "waterMin", 0, 100),
        "humidityAirMin": _numero_soglia(
            soglie, "humidityAirMin", 0, 100
        ),
        "humidityAirMax": _numero_soglia(
            soglie, "humidityAirMax", 0, 100
        ),
        "humiditySoilMin": _numero_soglia(
            soglie, "humiditySoilMin", 0, 100
        ),
        "humiditySoilMax": _numero_soglia(
            soglie, "humiditySoilMax", 0, 100
        ),
    }

    for minimo, massimo in (
        ("tempMin", "tempMax"),
        ("phMin", "phMax"),
        ("tdsMin", "tdsMax"),
        ("humidityAirMin", "humidityAirMax"),
        ("humiditySoilMin", "humiditySoilMax"),
    ):
        if valori[minimo] >= valori[massimo]:
            raise ValueError(
                f"Soglie AI incoerenti: {minimo} >= {massimo}"
            )

    return valori


def aggiorna_soglie_da_ai(
    analisi: dict[str, Any],
    aggiornato_il: str,
    provider: str,
) -> dict[str, Any]:
    impostazioni = _leggi_impostazioni()
    autorizzato = bool(
        impostazioni.get("geminiAutoThresholds", False)
    )

    if not autorizzato:
        return {
            "autorizzato": False,
            "aggiornate": False,
            "motivo": "Opzione disattivata",
        }

    try:
        soglie = valida_soglie_ai(
            analisi.get("soglie_consigliate")
        )
    except (TypeError, ValueError) as errore:
        return {
            "autorizzato": True,
            "aggiornate": False,
            "motivo": str(errore),
        }

    impostazioni.update(soglie)
    impostazioni["thresholdSource"] = provider
    impostazioni["thresholdUpdatedAt"] = aggiornato_il

    temporaneo = SETTINGS_PATH.with_suffix(
        SETTINGS_PATH.suffix + ".tmp"
    )
    temporaneo.write_text(
        json.dumps(
            impostazioni,
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    os.replace(temporaneo, SETTINGS_PATH)

    return {
        "autorizzato": True,
        "aggiornate": True,
        "soglie": soglie,
    }


def _aggiungi_colonne(
    connessione: sqlite3.Connection,
    tabella: str,
    colonne: dict[str, str],
) -> None:
    presenti = {
        riga[1]
        for riga in connessione.execute(
            f"PRAGMA table_info({tabella})"
        ).fetchall()
    }

    for nome, tipo in colonne.items():
        if nome not in presenti:
            connessione.execute(
                f"ALTER TABLE {tabella} ADD COLUMN {nome} {tipo}"
            )


def prepara_db(connessione: sqlite3.Connection) -> None:
    connessione.execute(
        """
        CREATE TABLE IF NOT EXISTS analisi_ai (
            id TEXT PRIMARY KEY,
            data TEXT,
            creato_il TEXT,
            sorgente_foto TEXT,
            foto TEXT,
            temperatura REAL,
            umidita REAL,
            umidita_terreno REAL,
            luce REAL,
            tds REAL,
            tds_raw REAL,
            ph REAL,
            livello_acqua REAL,
            punteggio REAL,
            stato TEXT,
            sommario TEXT,
            osservazioni_foto TEXT,
            analisi_sensori TEXT,
            condizioni_ottimali TEXT,
            azioni TEXT,
            azioni_urgenti INTEGER
        )
        """
    )

    _aggiungi_colonne(
        connessione,
        "analisi_ai",
        {
            "data": "TEXT",
            "creato_il": "TEXT",
            "sorgente_foto": "TEXT",
            "foto": "TEXT",
            "temperatura": "REAL",
            "umidita": "REAL",
            "umidita_terreno": "REAL",
            "luce": "REAL",
            "tds": "REAL",
            "tds_raw": "REAL",
            "ph": "REAL",
            "livello_acqua": "REAL",
            "punteggio": "REAL",
            "stato": "TEXT",
            "sommario": "TEXT",
            "osservazioni_foto": "TEXT",
            "analisi_sensori": "TEXT",
            "condizioni_ottimali": "TEXT",
            "azioni": "TEXT",
            "azioni_urgenti": "INTEGER",
        },
    )

    connessione.execute(
        """
        UPDATE analisi_ai
        SET data = substr(creato_il, 1, 10)
        WHERE (data IS NULL OR data = '')
          AND creato_il IS NOT NULL
        """
    )


def salva_in_report(
    connessione: sqlite3.Connection,
    data_report: str,
    creato_il: str,
    sorgente: str,
    destinazione: Path,
    sensori: dict[str, Any],
    analisi: dict[str, Any],
) -> None:
    connessione.execute(
        """
        CREATE TABLE IF NOT EXISTS report (
            data TEXT PRIMARY KEY,
            foto TEXT,
            temperatura REAL,
            umidita REAL,
            ph REAL,
            ec REAL,
            livello_acqua REAL,
            ore_luce REAL,
            punteggio REAL,
            stato TEXT,
            sommario TEXT,
            osservazioni_foto TEXT,
            condizioni_ottimali TEXT,
            analisi_sensori TEXT,
            azioni TEXT,
            azioni_urgenti INTEGER,
            creato_il TEXT,
            umidita_terreno REAL,
            luce REAL,
            tds REAL,
            sorgente_foto TEXT
        )
        """
    )

    _aggiungi_colonne(
        connessione,
        "report",
        {
            "foto": "TEXT",
            "temperatura": "REAL",
            "umidita": "REAL",
            "ph": "REAL",
            "ec": "REAL",
            "livello_acqua": "REAL",
            "ore_luce": "REAL",
            "punteggio": "REAL",
            "stato": "TEXT",
            "sommario": "TEXT",
            "osservazioni_foto": "TEXT",
            "condizioni_ottimali": "TEXT",
            "analisi_sensori": "TEXT",
            "azioni": "TEXT",
            "azioni_urgenti": "INTEGER",
            "creato_il": "TEXT",
            "umidita_terreno": "REAL",
            "luce": "REAL",
            "tds": "REAL",
            "sorgente_foto": "TEXT",
        },
    )

    valori = (
        data_report,
        str(destinazione),
        sensori.get("temperatura"),
        sensori.get("umidita"),
        sensori.get("ph"),
        sensori.get("livello_acqua"),
        analisi.get("punteggio"),
        analisi.get("stato"),
        analisi.get("sommario"),
        analisi.get("osservazioni_foto"),
        analisi.get("condizioni_ottimali"),
        analisi.get("analisi_sensori"),
        json.dumps(analisi.get("azioni", []), ensure_ascii=False),
        analisi.get("azioni_urgenti", 0),
        creato_il,
        sensori.get("umidita_terreno"),
        sensori.get("luce"),
        sensori.get("tds"),
        sorgente,
    )

    connessione.execute(
        """
        INSERT INTO report (
            data,
            foto,
            temperatura,
            umidita,
            ph,
            livello_acqua,
            punteggio,
            stato,
            sommario,
            osservazioni_foto,
            condizioni_ottimali,
            analisi_sensori,
            azioni,
            azioni_urgenti,
            creato_il,
            umidita_terreno,
            luce,
            tds,
            sorgente_foto
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(data) DO UPDATE SET
            foto = excluded.foto,
            temperatura = excluded.temperatura,
            umidita = excluded.umidita,
            ph = excluded.ph,
            livello_acqua = excluded.livello_acqua,
            punteggio = excluded.punteggio,
            stato = excluded.stato,
            sommario = excluded.sommario,
            osservazioni_foto = excluded.osservazioni_foto,
            condizioni_ottimali = excluded.condizioni_ottimali,
            analisi_sensori = excluded.analisi_sensori,
            azioni = excluded.azioni,
            azioni_urgenti = excluded.azioni_urgenti,
            creato_il = excluded.creato_il,
            umidita_terreno = excluded.umidita_terreno,
            luce = excluded.luce,
            tds = excluded.tds,
            sorgente_foto = excluded.sorgente_foto
        """,
        valori,
    )


def prepara_pulizia_stesso_giorno(
    connessione: sqlite3.Connection,
    data_report: str,
    nuovo_id: str,
    nuova_foto: Path,
) -> tuple[list[str], list[Path]]:
    """Elimina dal DB le vecchie analisi del giorno e prepara le foto da rimuovere.

    I file vengono cancellati soltanto dopo il commit della transazione. Questo
    evita di perdere una fotografia se il salvataggio del nuovo report fallisce.
    """
    righe = connessione.execute(
        """
        SELECT id, foto
        FROM analisi_ai
        WHERE data = ?
          AND id <> ?
        ORDER BY creato_il ASC
        """,
        (data_report, nuovo_id),
    ).fetchall()

    if not righe:
        return [], []

    nuova_foto_risolta = nuova_foto.resolve()
    cartella_risolta = FOTO_DIR.resolve()
    identificatori: list[str] = []
    fotografie: list[Path] = []

    for identificatore, foto in righe:
        identificatori.append(str(identificatore))

        connessione.execute(
            "DELETE FROM analisi_ai WHERE id = ?",
            (identificatore,),
        )

        if not foto:
            continue

        candidata = Path(str(foto))
        try:
            candidata_risolta = candidata.resolve()
            candidata_risolta.relative_to(cartella_risolta)
        except (OSError, ValueError):
            continue

        if candidata_risolta == nuova_foto_risolta:
            continue

        ancora_usata = connessione.execute(
            """
            SELECT 1
            FROM report
            WHERE foto = ?
              AND data <> ?
            LIMIT 1
            """,
            (str(candidata), data_report),
        ).fetchone()

        if ancora_usata:
            continue

        fotografie.append(candidata_risolta)

    return identificatori, fotografie


def elimina_fotografie(fotografie: list[Path]) -> list[str]:
    """Elimina i vecchi file dopo un commit riuscito."""
    eliminate: list[str] = []

    for fotografia in fotografie:
        try:
            fotografia.unlink(missing_ok=True)
            eliminate.append(str(fotografia))
        except OSError as errore:
            print(
                f"Impossibile eliminare la vecchia fotografia {fotografia}: "
                f"{errore}",
                flush=True,
            )

    return eliminate


def esegui(
    sorgente: str = "raspberry",
    foto_path: str | None = None,
    elimina_vecchia: bool = True,
) -> dict[str, Any]:
    identificatore = uuid.uuid4().hex
    adesso = datetime.now()
    data_report = adesso.strftime("%Y-%m-%d")
    creato_il = adesso.isoformat(timespec="seconds")
    destinazione = FOTO_DIR / (
        f"analisi_{adesso:%Y%m%d_%H%M%S}_{identificatore[:8]}.jpg"
    )

    connessione: sqlite3.Connection | None = None
    analisi_eliminate: list[str] = []
    foto_da_eliminare: list[Path] = []

    try:
        if sorgente == "raspberry":
            scatta_foto_raspberry(destinazione)
        elif sorgente == "telefono" and foto_path:
            copia_foto_telefono(foto_path, destinazione)
        else:
            raise ValueError("Sorgente fotografia non valida")

        sensori = leggi_sensori()
        analisi, info_provider = genera_analisi(destinazione, sensori)
        esito_soglie = aggiorna_soglie_da_ai(
            analisi, creato_il, info_provider["provider_usato"]
        )

        connessione = sqlite3.connect(DB_PATH, timeout=30)
        connessione.execute("PRAGMA busy_timeout=30000")
        prepara_db(connessione)

        connessione.execute(
            """
            INSERT INTO analisi_ai (
                id,
                data,
                creato_il,
                sorgente_foto,
                foto,
                temperatura,
                umidita,
                umidita_terreno,
                luce,
                tds,
                tds_raw,
                ph,
                livello_acqua,
                punteggio,
                stato,
                sommario,
                osservazioni_foto,
                analisi_sensori,
                condizioni_ottimali,
                azioni,
                azioni_urgenti
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                identificatore,
                data_report,
                creato_il,
                sorgente,
                str(destinazione),
                sensori.get("temperatura"),
                sensori.get("umidita"),
                sensori.get("umidita_terreno"),
                sensori.get("luce"),
                sensori.get("tds"),
                sensori.get("tds_raw"),
                sensori.get("ph"),
                sensori.get("livello_acqua"),
                analisi.get("punteggio"),
                analisi.get("stato"),
                analisi.get("sommario"),
                analisi.get("osservazioni_foto"),
                analisi.get("analisi_sensori"),
                analisi.get("condizioni_ottimali"),
                json.dumps(
                    analisi.get("azioni", []),
                    ensure_ascii=False,
                ),
                analisi.get("azioni_urgenti", 0),
            ),
        )

        salva_in_report(
            connessione=connessione,
            data_report=data_report,
            creato_il=creato_il,
            sorgente=sorgente,
            destinazione=destinazione,
            sensori=sensori,
            analisi=analisi,
        )

        if elimina_vecchia:
            analisi_eliminate, foto_da_eliminare = (
                prepara_pulizia_stesso_giorno(
                    connessione=connessione,
                    data_report=data_report,
                    nuovo_id=identificatore,
                    nuova_foto=destinazione,
                )
            )

        connessione.commit()

        # La cancellazione fisica avviene solo dopo il commit riuscito.
        foto_eliminate = elimina_fotografie(foto_da_eliminare)

        return {
            "ok": True,
            "id": identificatore,
            "data": data_report,
            "creato_il": creato_il,
            "sorgente_foto": sorgente,
            "foto": str(destinazione),
            "sensori": sensori,
            "analisi": analisi,
            "analisi_eliminata": (
                analisi_eliminate[0] if analisi_eliminate else None
            ),
            "analisi_eliminate": analisi_eliminate,
            "foto_eliminate": foto_eliminate,
            "salvato_database": True,
            "report_aggiornato": True,
            "aggiornamento_soglie": esito_soglie,
            "provider_usato": info_provider["provider_usato"],
            "modello_usato": info_provider["modello_usato"],
            "fallback_usato": info_provider["fallback_usato"],
            "errori_provider": info_provider["errori_provider"],
        }

    except Exception:
        if connessione is not None:
            try:
                connessione.rollback()
            except Exception:
                pass

        # La nuova foto non deve restare se il report non viene salvato.
        if destinazione.exists():
            destinazione.unlink(missing_ok=True)

        raise

    finally:
        if connessione is not None:
            connessione.close()



def main() -> int:
    try:
        result = esegui(sorgente="raspberry", elimina_vecchia=True)
        print(json.dumps(result, ensure_ascii=False, indent=2), flush=True)
        settings = _leggi_impostazioni()
        if result.get("ok") is True and bool(settings.get("reportNotifications", False)):
            thresholds_updated = bool(result.get("aggiornamento_soglie", {}).get("aggiornate"))
            body = (
                "Il rapporto giornaliero è pronto e le soglie sono state aggiornate."
                if thresholds_updated
                else "Il rapporto giornaliero HydroTower è stato creato."
            )
            invia_notifica(
                titolo="Nuovo rapporto disponibile",
                corpo=body,
                tipo="report",
                dati={
                    "date": result.get("data", ""),
                    "thresholdsUpdated": str(thresholds_updated).lower(),
                    "provider": result.get("provider_usato", ""),
                },
            )
        return 0
    except Exception as error:
        print(f"Rapporto giornaliero fallito: {error}", flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
