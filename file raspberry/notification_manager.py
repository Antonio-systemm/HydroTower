#!/usr/bin/env python3
"""Gestione dei token FCM e invio delle notifiche HydroTower."""

import json
import os
from pathlib import Path
from typing import Any

import firebase_admin
from firebase_admin import credentials, exceptions, messaging

TOKENS = Path(
    os.getenv(
        "HYDROTOWER_FCM_TOKENS",
        "/home/hydrotower/hydrotower_fcm_tokens.json",
    )
)

CREDENTIALS = os.getenv(
    "HYDROTOWER_FIREBASE_CREDENTIALS",
    "/etc/hydrotower-firebase.json",
)


def _tokens() -> list[str]:
    """Legge dal disco i token FCM registrati e rimuove i duplicati."""
    try:
        dati = json.loads(TOKENS.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return []

    if isinstance(dati, dict):
        valori = dati.get("tokens", [])
    elif isinstance(dati, list):
        valori = dati
    else:
        return []

    risultato: list[str] = []

    for valore in valori:
        token = str(valore or "").strip()

        if token and token not in risultato:
            risultato.append(token)

    return risultato


def _scrivi_tokens(tokens: list[str]) -> None:
    """Salva i token in modo atomico."""
    TOKENS.parent.mkdir(parents=True, exist_ok=True)

    tokens_puliti = sorted(
        {
            str(token or "").strip()
            for token in tokens
            if str(token or "").strip()
        }
    )

    percorso_temporaneo = TOKENS.with_suffix(
        TOKENS.suffix + ".tmp"
    )

    percorso_temporaneo.write_text(
        json.dumps(
            {"tokens": tokens_puliti},
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )

    os.replace(percorso_temporaneo, TOKENS)


def _inizializza_firebase() -> None:
    """Inizializza Firebase Admin una sola volta."""
    if firebase_admin._apps:
        return

    percorso_credenziali = Path(CREDENTIALS)

    if not percorso_credenziali.is_file():
        raise FileNotFoundError(
            "Credenziale Firebase non trovata: "
            f"{percorso_credenziali}"
        )

    credenziale = credentials.Certificate(
        str(percorso_credenziali)
    )

    firebase_admin.initialize_app(credenziale)


def registra_token(token: str | None) -> int:
    """Registra un token FCM e restituisce il numero totale di token."""
    token_pulito = str(token or "").strip()

    if len(token_pulito) < 20:
        raise ValueError("Token FCM non valido")

    if any(carattere.isspace() for carattere in token_pulito):
        raise ValueError("Il token FCM contiene spazi non validi")

    tokens = _tokens()

    if token_pulito not in tokens:
        tokens.append(token_pulito)
        _scrivi_tokens(tokens)

    return len(tokens)


def rimuovi_token(token: str | None) -> int:
    """Rimuove un token FCM e restituisce quanti token rimangono."""
    token_pulito = str(token or "").strip()
    tokens = [
        token_salvato
        for token_salvato in _tokens()
        if token_salvato != token_pulito
    ]

    _scrivi_tokens(tokens)
    return len(tokens)


def invia_notifica(
    titolo: str,
    corpo: str,
    tipo: str = "alarm",
    dati: dict[str, Any] | None = None,
) -> dict[str, int]:
    """Invia una notifica a tutti i dispositivi registrati."""
    tokens = _tokens()

    if not tokens:
        print("Nessun token FCM registrato.", flush=True)
        return {
            "inviate": 0,
            "fallite": 0,
            "registrati": 0,
        }

    _inizializza_firebase()

    payload = {
        "type": str(tipo),
        **{
            str(chiave): str(valore)
            for chiave, valore in (dati or {}).items()
        },
    }

    canale = (
        "hydrotower_report"
        if tipo == "report"
        else "hydrotower_allarmi"
    )

    inviate = 0
    falliti: list[str] = []

    for token in tokens:
        messaggio = messaging.Message(
            token=token,
            notification=messaging.Notification(
                title=str(titolo),
                body=str(corpo),
            ),
            data=payload,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id=canale,
                    sound="default",
                ),
            ),
        )

        try:
            messaging.send(messaggio)
            inviate += 1

        except (
            messaging.UnregisteredError,
            messaging.SenderIdMismatchError,
        ) as errore:
            print(
                "Token FCM scaduto, non registrato o appartenente "
                f"a un altro progetto. Verrà eliminato: {errore}",
                flush=True,
            )
            falliti.append(token)

        except exceptions.InvalidArgumentError as errore:
            messaggio_errore = str(errore)

            print(
                "Token o messaggio FCM non valido: "
                f"{messaggio_errore}",
                flush=True,
            )

            testo_errore = messaggio_errore.lower()

            if (
                "registration token" in testo_errore
                or "invalid token" in testo_errore
            ):
                falliti.append(token)

        except Exception as errore:
            print(
                f"Invio FCM fallito: {errore}",
                flush=True,
            )

    if falliti:
        tokens_validi = [
            token_salvato
            for token_salvato in tokens
            if token_salvato not in falliti
        ]
        _scrivi_tokens(tokens_validi)

    return {
        "inviate": inviate,
        "fallite": len(falliti),
        "registrati": len(_tokens()),
    }
