import 'package:intl/intl.dart';

/// `12,500.00` — money / cost figures (currency is org-wide, not shown).
String formatMoney(num value) =>
    NumberFormat.decimalPatternDigits(decimalDigits: 2).format(value);

/// `27 Sep 2026` — the one date format used across list and detail screens.
String formatDate(DateTime date) =>
    DateFormat('d MMM y').format(date.toLocal());

/// `27 Sep 2026, 14:05`.
String formatDateTime(DateTime date) =>
    DateFormat('d MMM y, HH:mm').format(date.toLocal());

/// Human due-date phrasing relative to today: "Due today", "Due tomorrow",
/// "Due in 5 days", "Overdue by 2 days", falling back to the date itself
/// beyond two weeks out.
String describeDue(DateTime due, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final days = _dateOnly(due).difference(today).inDays;
  if (days < 0) {
    final n = -days;
    return 'Overdue by $n ${n == 1 ? 'day' : 'days'}';
  }
  if (days == 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';
  if (days <= 14) return 'Due in $days days';
  return 'Due ${formatDate(due)}';
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// `AWAITING_APPROVAL` / `InProgress` / `in progress` → `Awaiting approval`,
/// `In progress` — for showing raw API enum values as labels.
String humanizeStatus(String raw) {
  final spaced = raw
      .trim()
      .replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ')
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .toLowerCase();
  if (spaced.isEmpty) return raw;
  return spaced[0].toUpperCase() + spaced.substring(1);
}

/// "Just now", "5 min ago", "3 h ago", "Yesterday", "4 days ago", then the
/// date — for feeds such as notifications.
String describeAgo(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) return '${diff.inHours} h ago';
  final days = _dateOnly(current).difference(_dateOnly(time.toLocal())).inDays;
  if (days <= 1) return 'Yesterday';
  if (days < 7) return '$days days ago';
  return formatDate(time);
}
