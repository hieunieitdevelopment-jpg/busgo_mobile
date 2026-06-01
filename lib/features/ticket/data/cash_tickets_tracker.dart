import 'package:shared_preferences/shared_preferences.dart';

/// Theo dõi các vé đã thanh toán tiền mặt phía client.
///
/// Server hiện KHÔNG trả `paymentMethod` trong danh sách vé, nên app cần ghi
/// nhớ lựa chọn này phía client. Vé được đánh dấu cash sẽ:
///   - Hiển thị badge "Đã thanh toán (Tiền mặt)" thay vì "Chờ thanh toán"
///   - Được coi như tương đương `PAID` cho luồng đánh giá (chờ COMPLETED)
class CashTicketsTracker {
  CashTicketsTracker._internal();
  static final CashTicketsTracker _instance = CashTicketsTracker._internal();
  factory CashTicketsTracker() => _instance;

  static const String _ticketKey = 'cash_paid_ticket_ids';
  static const String _bookingKey = 'cash_paid_booking_ids';

  Set<int>? _ticketCache;
  Set<int>? _bookingCache;

  Future<Set<int>> _loadSet(String key, Set<int>? cache) async {
    if (cache != null) return cache;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(key) ?? const [];
    final set = raw.map((s) => int.tryParse(s)).whereType<int>().toSet();
    return set;
  }

  Future<Set<int>> getTicketIds() async {
    _ticketCache ??= await _loadSet(_ticketKey, _ticketCache);
    return _ticketCache!;
  }

  Future<Set<int>> getBookingIds() async {
    _bookingCache ??= await _loadSet(_bookingKey, _bookingCache);
    return _bookingCache!;
  }

  /// Đánh dấu booking + ticket vừa đặt là thanh toán tiền mặt.
  /// Truyền null cho id chưa biết — sẽ bỏ qua an toàn.
  Future<void> markCash({int? ticketId, int? bookingId}) async {
    final prefs = await SharedPreferences.getInstance();
    if (ticketId != null && ticketId > 0) {
      _ticketCache ??= await _loadSet(_ticketKey, null);
      _ticketCache!.add(ticketId);
      await prefs.setStringList(
          _ticketKey, _ticketCache!.map((e) => e.toString()).toList());
    }
    if (bookingId != null && bookingId > 0) {
      _bookingCache ??= await _loadSet(_bookingKey, null);
      _bookingCache!.add(bookingId);
      await prefs.setStringList(
          _bookingKey, _bookingCache!.map((e) => e.toString()).toList());
    }
  }

  /// Kiểm tra một vé có là thanh toán tiền mặt không.
  Future<bool> isCash({int? ticketId, int? bookingId}) async {
    if (ticketId != null) {
      final s = await getTicketIds();
      if (s.contains(ticketId)) return true;
    }
    if (bookingId != null) {
      final s = await getBookingIds();
      if (s.contains(bookingId)) return true;
    }
    return false;
  }

  /// Tải đồng bộ cả 2 set (gọi 1 lần khi vào My Tickets) để check sync.
  Future<({Set<int> tickets, Set<int> bookings})> loadAll() async {
    final t = await getTicketIds();
    final b = await getBookingIds();
    return (tickets: t, bookings: b);
  }
}
