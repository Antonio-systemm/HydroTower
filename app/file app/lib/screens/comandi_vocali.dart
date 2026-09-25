class ComandiVocali {
  static String normalizza(String testo) => testo
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-zàèéìòù0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool contiene(String testo, List<String> parole) {
    final valore = normalizza(testo);
    return parole.any((parola) => valore.contains(normalizza(parola)));
  }

  static int? numero(String testo, {int minimo = 1, int massimo = 31}) {
    final valore = normalizza(testo);
    final cifre = RegExp(r'\b\d{1,2}\b').firstMatch(valore);
    if (cifre != null) {
      final n = int.tryParse(cifre.group(0)!);
      if (n != null && n >= minimo && n <= massimo) return n;
    }

    const numeri = <String, int>{
      'uno': 1,
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
      'ventitré': 23,
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
    for (final voce in numeri.entries) {
      if (valore.contains(voce.key) &&
          voce.value >= minimo &&
          voce.value <= massimo) {
        return voce.value;
      }
    }
    return null;
  }
}
