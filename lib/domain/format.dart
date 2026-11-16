/// Mise en forme des durées, en français.
library;

import 'models.dart';

/// « < 1 min », « 10 min », « 3 h », « 12 j », « 2,5 mois », « 1,3 an ».
String formatDelay(Duration delay) {
  final minutes = delay.inMinutes;
  if (minutes < 1) return '< 1 min';
  if (minutes < 60) return '$minutes min';
  final hours = delay.inHours;
  if (hours < 24) return '$hours h';
  final days = delay.inDays;
  if (days < 31) return '$days j';
  if (days < 365) return '${_oneDecimal(days / 30.4375)} mois';
  final years = days / 365.25;
  return '${_oneDecimal(years)} ${years < 1.95 ? 'an' : 'ans'}';
}

String _oneDecimal(double value) {
  final rounded = (value * 10).round() / 10;
  if (rounded == rounded.roundToDouble()) return rounded.round().toString();
  return rounded.toStringAsFixed(1).replaceAll('.', ',');
}

/// Quand une carte revient, vu depuis [now] : « nouvelle », « à revoir »,
/// « dans 3 j ».
String describeDue(Memory memory, DateTime now) {
  if (memory.isNew) return 'nouvelle';
  final delay = memory.due.difference(now.toUtc());
  if (delay <= Duration.zero) return 'à revoir';
  return 'dans ${formatDelay(delay)}';
}
