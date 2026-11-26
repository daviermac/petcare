import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificacoesMedicacao {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _inicializado = false;

  /// Inicializa o serviço de notificações.
  static Future<void> inicializar() async {
    if (_inicializado) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const configuracoes = InitializationSettings(android: android);

    await _plugin.initialize(settings: configuracoes);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    _inicializado = true;
  }

  /// Agenda um lembrete para cada horário recebido da API.
  ///
  /// [idBase] deve ser um identificador numérico único da prescrição.
  static Future<void> agendarLembretes({
    required int idBase,
    required String animal,
    required String medicamento,
    required List<String> horarios,
  }) async {
    if (!_inicializado) {
      await inicializar();
    }

    const detalhes = NotificationDetails(
      android: AndroidNotificationDetails(
        'lembretes_medicacao',
        'Lembretes de medicamentos',
        channelDescription: 'Horários para administrar medicamentos aos pets',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );

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
        notificationDetails: detalhes,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'medicacao:$idBase',
      );
    }
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
