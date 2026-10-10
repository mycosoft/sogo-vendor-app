import 'package:intl/intl.dart';

/// Parses a Laravel API date string correctly.
/// The backend stores UTC; when the string carries no timezone marker we
/// treat it as UTC and convert to the phone's local time.
DateTime? parseServerDate(dynamic iso) {
  if (iso == null) return null;
  var s = iso.toString().trim();
  if (s.isEmpty || s == 'null') return null;
  final hasZone = s.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s);
  if (!hasZone) s = '${s}Z';
  return DateTime.tryParse(s)?.toLocal();
}

/// "Oct 3, 14:22" in the phone's local time.
String formatServerDate(dynamic iso) {
  final d = parseServerDate(iso);
  if (d == null) return '-';
  return DateFormat('MMM d, HH:mm').format(d);
}

/// "3 min ago" style relative time.
String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  if (diff.inDays < 7) {
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }
  return DateFormat('MMM d').format(d);
}

/// Relative time + absolute local time, e.g. "5 min ago - Oct 3, 14:22".
String relativeServerDate(dynamic iso) {
  final d = parseServerDate(iso);
  if (d == null) return '-';
  return '${timeAgo(d)} - ${DateFormat('MMM d, HH:mm').format(d)}';
}
