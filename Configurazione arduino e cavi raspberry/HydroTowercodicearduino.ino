/*
  HydroTower - Arduino Nano

  Sensori:
  - Umidita terreno: A0
  - Uscita TO scheda pH: A2
  - TDS analogico: A3
  - Uscita PO scheda pH: A5

  Comunicazione Raspberry Pi:
  - 9600 baud
  - una riga JSON ogni 2 secondi

  Il pH viene inviato quando:
  - il segnale non e vicino alla saturazione ADC;
  - l'oscillazione filtrata dei campioni e accettabile;
  - la calibrazione software e abilitata;
  - il valore calcolato e plausibile.
*/

#include <Arduino.h>

// =====================================================
// PIN
// =====================================================

const uint8_t PIN_TERRENO = A0;
const uint8_t PIN_PH_TO = A2;
const uint8_t PIN_TDS = A3;
const uint8_t PIN_PH_PO = A5;

// =====================================================
// ADC
// =====================================================

const float VREF = 5.0;
const float ADC_DIVISORE = 1024.0;

// =====================================================
// CAMPIONAMENTO
// =====================================================

const uint8_t NUM_CAMPIONI_TDS = 30;
const uint8_t NUM_CAMPIONI_PH = 30;
const uint8_t PH_CAMPIONI_ESTREMI_DA_IGNORARE = 3;

const unsigned long INTERVALLO_CAMPIONE_MS = 40;
const unsigned long INTERVALLO_INVIO_MS = 2000;

// =====================================================
// TERRENO
// =====================================================

const int TERRENO_ASCIUTTO = 850;
const int TERRENO_BAGNATO = 405;

// =====================================================
// CALIBRAZIONE PH PROVVISORIA
// =====================================================

/*
  Punto provvisorio disponibile:

  Acqua Monviso:
  - pH dichiarato sulla bottiglia: 6.90
  - ADC mediano osservato: 736
  - tensione PO osservata: 3.594 V

  Per una calibrazione definitiva usare almeno:
  - soluzione tampone pH 7.00;
  - soluzione tampone pH 4.00 oppure pH 10.00.
*/

const bool PH_CALIBRATO = true;
const float PH_CAL_PH = 6.900;
const float PH_CAL_VOLT = 3.594;
const float PH_VOLT_PER_UNITA = 0.180;

// =====================================================
// VALIDAZIONE PH
// =====================================================

const int PH_ADC_MIN_VALIDO = 50;
const int PH_ADC_MAX_VALIDO = 950;

/*
  L'escursione viene calcolata dopo aver ignorato i tre
  campioni piu bassi e i tre piu alti. In questo modo un
  singolo disturbo non annulla l'intera lettura.
*/
const int PH_ESCURSIONE_MASSIMA = 100;

const float PH_MIN_PLAUSIBILE = 3.0;
const float PH_MAX_PLAUSIBILE = 10.0;

// =====================================================
// BUFFER
// =====================================================

int campioniTds[NUM_CAMPIONI_TDS];
int campioniPh[NUM_CAMPIONI_PH];

uint8_t indiceTds = 0;
uint8_t indicePh = 0;

unsigned long ultimoCampione = 0;
unsigned long ultimoInvio = 0;

// =====================================================
// FUNZIONI STATISTICHE
// =====================================================

void ordinaValori(
  int valori[],
  const uint8_t numeroValori
) {
  for (uint8_t i = 0; i < numeroValori - 1; i++) {
    for (uint8_t j = 0; j < numeroValori - i - 1; j++) {
      if (valori[j] > valori[j + 1]) {
        const int temporaneo = valori[j];
        valori[j] = valori[j + 1];
        valori[j + 1] = temporaneo;
      }
    }
  }
}

int calcolaMediana(
  const int valori[],
  const uint8_t numeroValori
) {
  int copia[NUM_CAMPIONI_PH];

  for (uint8_t i = 0; i < numeroValori; i++) {
    copia[i] = valori[i];
  }

  ordinaValori(copia, numeroValori);

  if (numeroValori % 2 == 0) {
    return (
      copia[numeroValori / 2 - 1] +
      copia[numeroValori / 2]
    ) / 2;
  }

  return copia[numeroValori / 2];
}

int calcolaEscursioneFiltrata(
  const int valori[],
  const uint8_t numeroValori
) {
  int copia[NUM_CAMPIONI_PH];

  for (uint8_t i = 0; i < numeroValori; i++) {
    copia[i] = valori[i];
  }

  ordinaValori(copia, numeroValori);

  const uint8_t estremi = PH_CAMPIONI_ESTREMI_DA_IGNORARE;

  if (numeroValori <= estremi * 2) {
    return copia[numeroValori - 1] - copia[0];
  }

  const int minimoFiltrato = copia[estremi];
  const int massimoFiltrato = copia[numeroValori - estremi - 1];

  return massimoFiltrato - minimoFiltrato;
}

// =====================================================
// LETTURA ANALOGICA STABILIZZATA
// =====================================================

int leggiAnalogicoStabilizzato(const uint8_t pin) {
  analogRead(pin);
  delayMicroseconds(250);
  return analogRead(pin);
}

// =====================================================
// CONVERSIONI
// =====================================================

float rawInVolt(const int valoreRaw) {
  return (valoreRaw * VREF) / ADC_DIVISORE;
}

int calcolaUmiditaTerrenoPercentuale(const int valoreRaw) {
  long percentuale = map(
    valoreRaw,
    TERRENO_ASCIUTTO,
    TERRENO_BAGNATO,
    0,
    100
  );

  percentuale = constrain(percentuale, 0, 100);
  return static_cast<int>(percentuale);
}

float calcolaTdsPpm(const int valoreRaw) {
  const float tensione = rawInVolt(valoreRaw);

  float valoreTds = (
    133.42 * tensione * tensione * tensione
    - 255.86 * tensione * tensione
    + 857.39 * tensione
  ) * 0.5;

  if (valoreTds < 0.0) {
    valoreTds = 0.0;
  }

  return valoreTds;
}

float calcolaPh(const int valoreRaw) {
  const float tensione = rawInVolt(valoreRaw);

  return PH_CAL_PH + (
    (PH_CAL_VOLT - tensione) /
    PH_VOLT_PER_UNITA
  );
}

// =====================================================
// CONTROLLO VALIDITA PH
// =====================================================

bool phAdcValido(const int phRaw) {
  return (
    phRaw >= PH_ADC_MIN_VALIDO &&
    phRaw <= PH_ADC_MAX_VALIDO
  );
}

bool phNumeroValido(const float ph) {
  return (
    !isnan(ph) &&
    !isinf(ph) &&
    ph >= PH_MIN_PLAUSIBILE &&
    ph <= PH_MAX_PLAUSIBILE
  );
}

bool phLetturaValida(
  const int phRaw,
  const bool phStabile,
  const float ph
) {
  if (!PH_CALIBRATO) {
    return false;
  }

  if (!phAdcValido(phRaw)) {
    return false;
  }

  if (!phStabile) {
    return false;
  }

  if (!phNumeroValido(ph)) {
    return false;
  }

  return true;
}

// =====================================================
// INVIO JSON
// =====================================================

void inviaDatiSeriali(
  const int terrenoPercentuale,
  const int terrenoRaw,
  const float tdsPpm,
  const int tdsRaw,
  const float ph,
  const int phRaw,
  const float phVolt,
  const int phToRaw,
  const int phEscursione,
  const bool phStabile,
  const bool phValido
) {
  Serial.print(F("{\"terreno_percentuale\":"));
  Serial.print(terrenoPercentuale);

  Serial.print(F(",\"terreno_raw\":"));
  Serial.print(terrenoRaw);

  Serial.print(F(",\"tds_ppm\":"));
  Serial.print(tdsPpm, 0);

  Serial.print(F(",\"tds_raw\":"));
  Serial.print(tdsRaw);

  Serial.print(F(",\"ph\":"));
  if (phValido) {
    Serial.print(ph, 2);
  } else {
    Serial.print(F("null"));
  }

  Serial.print(F(",\"ph_raw\":"));
  Serial.print(phRaw);

  Serial.print(F(",\"ph_voltage\":"));
  Serial.print(phVolt, 3);

  Serial.print(F(",\"ph_to_raw\":"));
  Serial.print(phToRaw);

  Serial.print(F(",\"ph_adc_range\":"));
  Serial.print(phEscursione);

  Serial.print(F(",\"ph_stable\":"));
  Serial.print(phStabile ? F("true") : F("false"));

  Serial.print(F(",\"ph_valid\":"));
  Serial.print(phValido ? F("true") : F("false"));

  Serial.print(F(",\"ph_calibrated\":"));
  Serial.print(PH_CALIBRATO ? F("true") : F("false"));

  Serial.println(F("}"));
}

// =====================================================
// SETUP
// =====================================================

void setup() {
  Serial.begin(9600);

  pinMode(PIN_TERRENO, INPUT);
  pinMode(PIN_TDS, INPUT);
  pinMode(PIN_PH_PO, INPUT);
  pinMode(PIN_PH_TO, INPUT);

  for (uint8_t i = 0; i < NUM_CAMPIONI_TDS; i++) {
    campioniTds[i] = leggiAnalogicoStabilizzato(PIN_TDS);
    delayMicroseconds(250);
    campioniPh[i] = leggiAnalogicoStabilizzato(PIN_PH_PO);
    delay(10);
  }

  delay(500);
}

// =====================================================
// LOOP
// =====================================================

void loop() {
  const unsigned long adesso = millis();

  if (
    adesso - ultimoCampione >=
    INTERVALLO_CAMPIONE_MS
  ) {
    ultimoCampione = adesso;

    campioniTds[indiceTds] =
        leggiAnalogicoStabilizzato(PIN_TDS);

    indiceTds = (
      indiceTds + 1
    ) % NUM_CAMPIONI_TDS;

    delayMicroseconds(250);

    campioniPh[indicePh] =
        leggiAnalogicoStabilizzato(PIN_PH_PO);

    indicePh = (
      indicePh + 1
    ) % NUM_CAMPIONI_PH;
  }

  if (
    adesso - ultimoInvio >=
    INTERVALLO_INVIO_MS
  ) {
    ultimoInvio = adesso;

    const int terrenoRaw =
        leggiAnalogicoStabilizzato(PIN_TERRENO);

    const int terrenoPercentuale =
        calcolaUmiditaTerrenoPercentuale(
          terrenoRaw
        );

    const int tdsRaw = calcolaMediana(
      campioniTds,
      NUM_CAMPIONI_TDS
    );

    const float tdsPpm = calcolaTdsPpm(tdsRaw);

    const int phRaw = calcolaMediana(
      campioniPh,
      NUM_CAMPIONI_PH
    );

    const int phEscursione =
        calcolaEscursioneFiltrata(
          campioniPh,
          NUM_CAMPIONI_PH
        );

    const float phVolt = rawInVolt(phRaw);
    const float ph = calcolaPh(phRaw);

    const bool phStabile = (
      phEscursione <= PH_ESCURSIONE_MASSIMA
    );

    const bool phValido = phLetturaValida(
      phRaw,
      phStabile,
      ph
    );

    const int phToRaw =
        leggiAnalogicoStabilizzato(PIN_PH_TO);

    inviaDatiSeriali(
      terrenoPercentuale,
      terrenoRaw,
      tdsPpm,
      tdsRaw,
      ph,
      phRaw,
      phVolt,
      phToRaw,
      phEscursione,
      phStabile,
      phValido
    );
  }
}
