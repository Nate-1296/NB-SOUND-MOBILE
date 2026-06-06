// Helpers de formato de duración, sin dependencias de Flutter (testeables).

/// Formatea segundos como `m:ss` (o `h:mm:ss` si supera la hora).
/// Espejo de `window.fmt` del diseño.
String formatClock(num seconds) {
  final int total = seconds.round();
  final int s = total % 60;
  final int m = (total ~/ 60) % 60;
  final int h = total ~/ 3600;
  final String ss = s.toString().padLeft(2, '0');
  if (h > 0) {
    final String mm = m.toString().padLeft(2, '0');
    return '$h:$mm:$ss';
  }
  return '$m:$ss';
}

/// Formatea una duración total de forma compacta: `1h 21m`, `52m`, `3m`.
String formatLongDuration(num seconds) {
  final int total = seconds.round();
  final int h = total ~/ 3600;
  final int m = (total % 3600) ~/ 60;
  if (h > 0) {
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
  if (m > 0) {
    return '${m}m';
  }
  return '${total}s';
}
