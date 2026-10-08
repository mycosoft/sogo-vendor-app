import 'package:intl/intl.dart';

/// UGX currency formatter with thousands separators: UGX 1,250,000.
String ugx(num? v) => 'UGX ${NumberFormat('#,###').format((v ?? 0).round())}';
