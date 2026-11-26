import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Lembretes locais de medicamento (RF21), agendados no próprio aparelho.
class NotificacoesMedicacao {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _inicializado = false;

  static const _detalhes = NotificationDetails(
    android: AndroidNotificationDetails(
      'lembretes_medicacao',
      'Lembretes de medicamentos',
      channelDescription: 'Horários para administrar medicamentos aos pets',
      importance: Importance.max,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
    ),
  );

  /// Inicializa o serviço de notificações (Android e iOS).
  static Future<void> inicializar() async {
    if (_inicializado) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // No iOS a permissão é pedida na primeira abertura do app.
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const configuracoes = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings: configuracoes);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    _inicializado = true;
  }

  /// Agenda um lembrete para cada horário futuro recebido da API.
  /// Devolve quantos lembretes foram agendados.
  ///
  /// [idBase] deve ser um identificador numérico único da prescrição.
  static Future<int> agendarLembretes({
    required int idBase,
    required String animal,
    required String medicamento,
    required List<String> horarios,
  }) async {
    if (!_inicializado) {
      await inicializar();
    }

    var agendados = 0;
    for (var i = 0; i < horarios.length; i++) {
      final data = DateTime.parse(horarios[i]);
      final horario = tz.TZDateTime.from(data, tz.local);

      if (!horario.isAfter(tz.TZDateTime.now(tz.local))) {
        continue;
      }

      await _plugin.zonedSchedule(
        id: idBase + i,
        title: 'Hora do medicamento!',
        body: 'Está na hora de administrar $medicamento para $animal.',
        scheduledDate: horario,
        notificationDetails: _detalhes,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'medicacao:$idBase',
      );
      agendados++;
    }
    return agendados;
  }

  /// Agenda um lembrete de teste para daqui a [segundos] segundos.
  /// Serve para conferir no aparelho que as notificações chegam (apresentação).
  static Future<void> agendarTeste({
    required String animal,
    required String medicamento,
    int segundos = 60,
  }) async {
    if (!_inicializado) {
      await inicializar();
    }
    await _plugin.zonedSchedule(
      id: 1999999999,
      title: 'Hora do medicamento! (teste)',
      body: 'Está na hora de administrar $medicamento para $animal.',
      scheduledDate: tz.TZDateTime.now(
        tz.local,
      ).add(Duration(seconds: segundos)),
      notificationDetails: _detalhes,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'medicacao:teste',
    );
  }

  /// Cancela os lembretes de uma prescrição.
  static Future<void> cancelarLembretes({
    required int idBase,
    required int quantidade,
  }) async {
    for (var i = 0; i < quantidade; i++) {
      await _plugin.cancel(id: idBase + i);
    }
  }
}
