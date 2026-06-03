import 'package:flutter/material.dart';
import 'package:busgo_mobile/core/api/notification_service.dart';

/// Provider toàn cục quản lý số lượng thông báo chưa đọc.
/// Đảm bảo chuông số liệu được đồng bộ giữa các trang.
class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();

  int _unreadCount = 0;
  List<dynamic> _notifications = [];
  bool _isLoading = false;

  int get unreadCount => _unreadCount;
  List<dynamic> get notifications => _notifications;
  bool get isLoading => _isLoading;

  /// Tải danh sách thông báo và tính số lượng chưa đọc.
  Future<void> fetchNotifications({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final response = await _notificationService.getNotifications(limit: 100);
      final data = response.data;
      if (data != null) {
        final List<dynamic> list = data['notifications'] ?? [];
        _notifications = list;
        _unreadCount = list
            .where((n) => n['isRead'] == false || n['isRead'] == 0)
            .length;
      }
    } catch (_) {
      // Lỗi mạng/auth: không thay đổi cache hiện tại
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Đánh dấu một thông báo đã đọc (cập nhật state ngay lập tức + gọi API ngầm).
  Future<void> markAsRead(int id) async {
    bool changed = false;
    for (var n in _notifications) {
      if (n['id'] == id && (n['isRead'] == false || n['isRead'] == 0)) {
        n['isRead'] = true;
        changed = true;
        break;
      }
    }
    if (changed) {
      _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
      notifyListeners();
    }
    try {
      await _notificationService.markNotificationRead(id);
    } catch (_) {
      // Bỏ qua lỗi ngầm để không phá vỡ trải nghiệm người dùng
    }
  }

  /// Đánh dấu tất cả thông báo đã đọc.
  Future<void> markAllAsRead() async {
    final unreadList = _notifications
        .where((n) => n['isRead'] == false || n['isRead'] == 0)
        .toList();
    if (unreadList.isEmpty) return;

    for (var n in _notifications) {
      n['isRead'] = true;
    }
    _unreadCount = 0;
    notifyListeners();

    for (var n in unreadList) {
      final int? id = n['id'];
      if (id != null) {
        try {
          await _notificationService.markNotificationRead(id);
        } catch (_) {}
      }
    }
  }

  /// Xóa cache khi đăng xuất.
  void clear() {
    _notifications = [];
    _unreadCount = 0;
    notifyListeners();
  }

  /// Tạo một thông báo mới cho người dùng (gọi từ các luồng đặt vé/thanh toán/hủy vé).
  /// Sau khi tạo xong sẽ tự động tải lại danh sách để chuông và trang thông báo cập nhật.
  Future<void> pushUserNotification({
    required int userId,
    required String title,
    required String body,
    String? data,
  }) async {
    if (userId <= 0) return;
    try {
      await _notificationService.createNotification(
        userId: userId,
        title: title,
        body: body,
        data: data,
      );
      // Tải lại để hiển thị thông báo mới ngay lập tức.
      await fetchNotifications(silent: true);
    } catch (_) {
      // Bỏ qua lỗi ngầm để không phá vỡ trải nghiệm người dùng
    }
  }

  /// Cập nhật / merge danh sách thông báo từ trang chi tiết (hỗ trợ pagination).
  void setNotifications(List<dynamic> list) {
    _notifications = list;
    _unreadCount = list
        .where((n) => n['isRead'] == false || n['isRead'] == 0)
        .length;
    notifyListeners();
  }
}
