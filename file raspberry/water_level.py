#!/usr/bin/env python3
"""Sensore digitale del livello acqua HydroTower.

Configurazione hardware:
- BCM GPIO22
- HIGH = acqua presente
- LOW = acqua assente

Il modulo espone sia la classe WaterLevelSensor, usata dal
controller della pompa, sia le funzioni water_present() e
water_status(), usate dal demone dei sensori.
"""

from __future__ import annotations

import os
import threading
from typing import Any

import RPi.GPIO as GPIO


GPIO_ACQUA = int(
    os.getenv(
        "HYDROTOWER_WATER_GPIO",
        "22",
    )
)

WATER_ACTIVE_HIGH = os.getenv(
    "HYDROTOWER_WATER_ACTIVE_HIGH",
    "true",
).strip().lower() in {
    "1",
    "true",
    "yes",
    "on",
}


class WaterLevelSensor:
    """Gestisce la lettura digitale del sensore acqua."""

    def __init__(
        self,
        gpio: int = GPIO_ACQUA,
        active_high: bool = WATER_ACTIVE_HIGH,
    ) -> None:
        self.gpio = int(gpio)
        self.active_high = bool(active_high)

        self._lock = threading.RLock()
        self._closed = False

        GPIO.setwarnings(False)
        GPIO.setmode(GPIO.BCM)

        GPIO.setup(
            self.gpio,
            GPIO.IN,
            pull_up_down=(
                GPIO.PUD_DOWN
                if self.active_high
                else GPIO.PUD_UP
            ),
        )

    @property
    def valore_raw(self) -> int:
        """Restituisce il valore elettrico raw, zero oppure uno."""
        with self._lock:
            if self._closed:
                raise RuntimeError(
                    "Sensore acqua già chiuso"
                )

            return int(
                GPIO.input(self.gpio)
            )

    @property
    def acqua_presente(self) -> bool:
        """Restituisce True quando viene rilevata acqua."""
        valore_alto = (
            self.valore_raw == GPIO.HIGH
        )

        return (
            valore_alto
            if self.active_high
            else not valore_alto
        )

    def stato(self) -> dict[str, Any]:
        """Restituisce lo stato completo per cache, API e app."""
        raw = self.valore_raw

        valore_alto = raw == GPIO.HIGH

        presente = (
            valore_alto
            if self.active_high
            else not valore_alto
        )

        return {
            "acqua_presente": presente,
            "livello_acqua": (
                100.0
                if presente
                else 0.0
            ),
            "livello_acqua_ok": presente,
            "livello_acqua_raw": raw,
            "livello_acqua_stato": (
                "buono"
                if presente
                else "basso"
            ),
            "livello_acqua_testo": (
                "Livello dell'acqua buono"
                if presente
                else
                "Livello dell'acqua basso, aggiungere acqua"
            ),
            "messaggio_acqua": (
                "Livello dell'acqua buono"
                if presente
                else
                "Livello dell'acqua basso, aggiungere acqua"
            ),
            "gpio_acqua": self.gpio,
            "water_active_high": self.active_high,
        }

    def close(self) -> None:
        """Chiude questa istanza senza alterare altri GPIO."""
        with self._lock:
            if self._closed:
                return

            self._closed = True


_default_sensor: WaterLevelSensor | None = None
_default_lock = threading.RLock()


def _get_default_sensor() -> WaterLevelSensor:
    """Crea una sola istanza predefinita per processo."""
    global _default_sensor

    with _default_lock:
        if _default_sensor is None:
            _default_sensor = WaterLevelSensor()

        return _default_sensor


def water_present() -> bool:
    """Compatibilità con il demone dei sensori."""
    return _get_default_sensor().acqua_presente


def water_status() -> dict[str, Any]:
    """Compatibilità con il demone dei sensori."""
    return _get_default_sensor().stato()


def close_water_sensor() -> None:
    """Chiude l'istanza predefinita del modulo."""
    global _default_sensor

    with _default_lock:
        if _default_sensor is not None:
            _default_sensor.close()
            _default_sensor = None
