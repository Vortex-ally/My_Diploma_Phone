const _months = [
  'січ',
  'лют',
  'бер',
  'кві',
  'тра',
  'чер',
  'лип',
  'сер',
  'вер',
  'жов',
  'лис',
  'гру',
];

String formatDate(DateTime date) {
  final m = _months[(date.month - 1) % 12];
  return '${date.day} $m ${date.year}';
}

String formatDateTime(DateTime date) {
  final h = date.hour.toString().padLeft(2, '0');
  final min = date.minute.toString().padLeft(2, '0');
  return '${formatDate(date)}, $h:$min';
}

String formatTimeOnly(DateTime date) {
  final h = date.hour.toString().padLeft(2, '0');
  final min = date.minute.toString().padLeft(2, '0');
  return '$h:$min';
}

String relativeTime(DateTime when, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final diff = ref.difference(when);
  if (diff.inMinutes < 1) return 'щойно';
  if (diff.inMinutes < 60) return '${diff.inMinutes} хв тому';
  if (diff.inHours < 24) return '${diff.inHours} год тому';
  if (diff.inDays < 7) return '${diff.inDays} дн тому';
  return formatDate(when);
}
