class ComandiVocali {
  static String normalizza(String testo) => testo
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll('à', 'a')
      .replaceAll('è', 'e')
      .replaceAll('é', 'e')
      .replaceAll('ì', 'i')
      .replaceAll('ò', 'o')
      .replaceAll('ù', 'u')
      .replaceAll(RegExp(r"[^a-z0-9' ]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool contiene(String testo, List<String> alternative) {
    final String valore = normalizza(testo);

    return alternative.any(
      (String alternativa) => valore.contains(normalizza(alternativa)),
    );
  }

  /// Riconosce le principali trascrizioni vocali del comando Menu.
  ///
  /// Non considera globalmente la parola "meno", perché nelle schermate
  /// numeriche viene usata per diminuire un valore.
  static bool comandoMenu(String testo) {
    final String valore = normalizza(testo);

    const List<String> comandiEsatti = <String>[
      'menu',
      'menu principale',
      'apri menu',
      'vai al menu',
      'torna al menu',
      'ritorna al menu',
      'indietro',
      'torna indietro',
      'vai indietro',
      'esci',
    ];

    if (comandiEsatti.any((String comando) => valore == normalizza(comando))) {
      return true;
    }

    return valore.startsWith('menu ') ||
        valore.endsWith(' menu') ||
        valore.contains(' torna al menu ') ||
        valore.contains(' vai al menu ');
  }

  static int? numero(String testo, {int minimo = 0, int massimo = 9999}) {
    final String valore = normalizza(testo);
    final RegExpMatch? cifre = RegExp(r'\b\d{1,4}\b').firstMatch(valore);

    if (cifre != null) {
      final int? numero = int.tryParse(cifre.group(0)!);

      if (numero != null && numero >= minimo && numero <= massimo) {
        return numero;
      }
    }

    const Map<String, int> parole = <String, int>{
      'zero': 0,
      'uno': 1,
      'una': 1,
      'due': 2,
      'tre': 3,
      'quattro': 4,
      'cinque': 5,
      'sei': 6,
      'sette': 7,
      'otto': 8,
      'nove': 9,
      'dieci': 10,
      'undici': 11,
      'dodici': 12,
      'tredici': 13,
      'quattordici': 14,
      'quindici': 15,
      'sedici': 16,
      'diciassette': 17,
      'diciotto': 18,
      'diciannove': 19,
      'venti': 20,
      'ventuno': 21,
      'ventidue': 22,
      'ventitre': 23,
      'ventiquattro': 24,
      'venticinque': 25,
      'ventisei': 26,
      'ventisette': 27,
      'ventotto': 28,
      'ventinove': 29,
      'trenta': 30,
      'trentuno': 31,
    };

    final List<MapEntry<String, int>> voci = parole.entries.toList()
      ..sort(
        (MapEntry<String, int> a, MapEntry<String, int> b) =>
            b.key.length.compareTo(a.key.length),
      );

    for (final MapEntry<String, int> voce in voci) {
      final bool presente = RegExp(
        '\\b${RegExp.escape(voce.key)}\\b',
      ).hasMatch(valore);

      if (presente && voce.value >= minimo && voce.value <= massimo) {
        return voce.value;
      }
    }

    return null;
  }

  static DateTime? dataCompleta(String testo, {DateTime? riferimento}) {
    final String valore = normalizza(testo);
    final DateTime base = riferimento ?? DateTime.now();

    if (contiene(valore, <String>['oggi'])) {
      return DateTime(base.year, base.month, base.day);
    }

    if (contiene(valore, <String>['ieri'])) {
      final DateTime ieri = base.subtract(const Duration(days: 1));
      return DateTime(ieri.year, ieri.month, ieri.day);
    }

    if (contiene(valore, <String>['domani'])) {
      final DateTime domani = base.add(const Duration(days: 1));
      return DateTime(domani.year, domani.month, domani.day);
    }

    final RegExpMatch? numerica = RegExp(
      r'\b(\d{1,2})[\/\- ](\d{1,2})[\/\- ](\d{2,4})\b',
    ).firstMatch(valore);

    if (numerica != null) {
      var anno = int.parse(numerica.group(3)!);

      if (anno < 100) {
        anno += 2000;
      }

      return _valida(
        int.parse(numerica.group(1)!),
        int.parse(numerica.group(2)!),
        anno,
      );
    }

    const Map<String, int> mesi = <String, int>{
      'gennaio': 1,
      'febbraio': 2,
      'marzo': 3,
      'aprile': 4,
      'maggio': 5,
      'giugno': 6,
      'luglio': 7,
      'agosto': 8,
      'settembre': 9,
      'ottobre': 10,
      'novembre': 11,
      'dicembre': 12,
    };

    int? mese;

    for (final MapEntry<String, int> voce in mesi.entries) {
      if (valore.contains(voce.key)) {
        mese = voce.value;
        break;
      }
    }

    if (mese == null) {
      return null;
    }

    int? giorno;
    int? anno;

    for (final String parte in valore.split(' ')) {
      final int? n = int.tryParse(parte);

      if (n == null) {
        continue;
      }

      if (n >= 2000 && n <= 2100) {
        anno = n;
      } else if (n >= 1 && n <= 31 && giorno == null) {
        giorno = n;
      }
    }

    giorno ??= numero(valore, minimo: 1, massimo: 31);
    anno ??= base.year;

    if (giorno == null) {
      return null;
    }

    return _valida(giorno, mese, anno);
  }

  static int? ora(String testo) {
    final String valore = normalizza(testo);
    final RegExpMatch? corrispondenza = RegExp(
      r'(?:ore|ora)\s+(\d{1,2})',
    ).firstMatch(valore);

    if (corrispondenza != null) {
      final int? n = int.tryParse(corrispondenza.group(1)!);

      if (n != null && n >= 0 && n <= 23) {
        return n;
      }
    }

    final int indice = valore.indexOf('ore ');

    if (indice >= 0) {
      return numero(valore.substring(indice + 4), minimo: 0, massimo: 23);
    }

    return null;
  }

  static DateTime? _valida(int giorno, int mese, int anno) {
    final DateTime data = DateTime(anno, mese, giorno);

    return data.year == anno && data.month == mese && data.day == giorno
        ? data
        : null;
  }
}
