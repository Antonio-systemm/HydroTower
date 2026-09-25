import 'package:flutter/foundation.dart';

import 'app_settings.dart';

class ModalitaAppService {
  static final ValueNotifier<ModalitaInterfaccia> modalita =
      ValueNotifier<ModalitaInterfaccia>(ModalitaInterfaccia.normale);

  static Future<void> inizializza() async {
    modalita.value = await AppSettings.getModalitaInterfaccia();
  }

  static Future<void> imposta(ModalitaInterfaccia nuovaModalita) async {
    await AppSettings.setModalitaInterfaccia(nuovaModalita);
    modalita.value = nuovaModalita;
  }
}
