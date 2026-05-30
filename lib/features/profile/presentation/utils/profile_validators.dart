/// Regex validate dùng chung cho toàn module Profile.
class ProfileValidators {
  static final RegExp emailRegex =
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final RegExp phoneRegex = RegExp(r'^(?:\+84|0)\d{9}$');
  static final RegExp otpRegex = RegExp(r'^\d{4,8}$');

  static bool isValidEmail(String s) => emailRegex.hasMatch(s.trim());
  static bool isValidPhone(String s) => phoneRegex.hasMatch(s.trim());
  static bool isValidOtp(String s) => otpRegex.hasMatch(s.trim());
}

/// Tính thời điểm hết cooldown 12 giờ theo timestamp lần đổi gần nhất.
/// Nhận về null nếu không có timestamp hợp lệ.
DateTime? resolveCooldownDeadline(dynamic raw,
    {Duration cooldown = const Duration(hours: 12)}) {
  if (raw == null) return null;
  if (raw is num) {
    // > 1e12 → đã là milliseconds; ngược lại là seconds → x1000
    final ms = raw > 1000000000000 ? raw.toInt() : (raw * 1000).toInt();
    return DateTime.fromMillisecondsSinceEpoch(ms).add(cooldown);
  }
  final s = raw.toString();
  if (s.isEmpty) return null;
  // Số ở dạng string?
  final asNum = num.tryParse(s);
  if (asNum != null) {
    final ms = asNum > 1000000000000
        ? asNum.toInt()
        : (asNum * 1000).toInt();
    return DateTime.fromMillisecondsSinceEpoch(ms).add(cooldown);
  }
  final parsed = DateTime.tryParse(s);
  if (parsed == null) return null;
  return parsed.add(cooldown);
}

/// Tính cooldown deadline cho 1 field (email/phone) bằng cách thử nhiều
/// tên trường mà backend có thể gửi.
DateTime? cooldownDeadlineForField({
  required Map<String, dynamic>? user,
  required String field, // 'email' | 'phone'
  Duration cooldown = const Duration(hours: 12),
}) {
  if (user == null) return null;
  final List<String> fieldKeys = field == 'email'
      ? ['lastChangeEmail', 'last_change_email']
      : ['lastChangePhone', 'last_change_phone'];
  final List<String> genericKeys = [
    'lastChangeContact',
    'lastchangeContact',
    'last_change_contact',
  ];
  for (final k in [...fieldKeys, ...genericKeys]) {
    if (user.containsKey(k) && user[k] != null) {
      final deadline =
          resolveCooldownDeadline(user[k], cooldown: cooldown);
      if (deadline != null) return deadline;
    }
  }
  return null;
}

/// Format thời gian còn lại của cooldown thành "X giờ Y phút" / chỉ giờ / chỉ phút.
String formatRemaining(Duration remaining) {
  if (remaining.isNegative || remaining == Duration.zero) return '';
  final h = remaining.inHours;
  final m = remaining.inMinutes - h * 60;
  if (h > 0 && m > 0) return '$h giờ $m phút';
  if (h > 0) return '$h giờ';
  if (m > 0) return '$m phút';
  return 'dưới 1 phút';
}
