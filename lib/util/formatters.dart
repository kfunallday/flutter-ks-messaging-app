import 'dart:math';

String formatBytes(int bytes, {int decimals = 1}) {
  if (bytes <= 0) return '0 B';
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
  var i = (log(bytes) / log(1024)).floor();
  i = i.clamp(0, suffixes.length - 1);
  double num = bytes / pow(1024, i);
  return '${num.toStringAsFixed(decimals)} ${suffixes[i]}';
}

int parseToBytes(double value, String unit) {
  switch (unit.toUpperCase()) {
    case 'KB':
      return (value * 1024).toInt();
    case 'MB':
      return (value * 1024 * 1024).toInt();
    case 'GB':
      return (value * 1024 * 1024 * 1024).toInt();
    case 'TB':
      return (value * 1024 * 1024 * 1024 * 1024).toInt();
    default:
      return value.toInt();
  }
}
