import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:busgo_mobile/core/api/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _notificationService = NotificationService();
  
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  bool _isLoggedIn = false;
  int? _nextCursor;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _checkLoginAndFetch();
  }

  Future<void> _checkLoginAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null && token.isNotEmpty) {
      setState(() {
        _isLoggedIn = true;
      });
      _fetchNotifications();
    } else {
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchNotifications({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _nextCursor = null;
      });
    }

    try {
      if (!isRefresh && _nextCursor == null) {
        setState(() => _isLoading = true);
      } else if (_nextCursor != null) {
        setState(() => _isLoadingMore = true);
      }

      final response = await _notificationService.getNotifications(
        limit: 20,
        next: isRefresh ? null : _nextCursor,
      );

      final data = response.data;
      if (data != null) {
        final List<dynamic> fetchedList = data['notifications'] ?? [];
        final int? next = data['next'];

        setState(() {
          if (isRefresh || _nextCursor == null) {
            _notifications = fetchedList;
          } else {
            _notifications.addAll(fetchedList);
          }
          // Sắp xếp ID từ lớn đến nhỏ (mới nhất lên trên)
          _notifications.sort((a, b) => (b['id'] ?? 0).compareTo(a['id'] ?? 0));
          _nextCursor = next;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _markAsRead(Map<String, dynamic> notification) async {
    final int? id = notification['id'];
    if (id == null) return;

    // Đánh dấu đã đọc trên UI ngay lập tức để đem lại trải nghiệm tức thì
    setState(() {
      notification['isRead'] = true;
    });

    try {
      await _notificationService.markNotificationRead(id);
    } catch (_) {
      // Bỏ qua lỗi ngầm để tránh ngắt quãng trải nghiệm người dùng
    }
  }

  Future<void> _markAllAsRead() async {
    final unreadList = _notifications.where((n) => n['isRead'] == false || n['isRead'] == 0).toList();
    if (unreadList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tất cả thông báo đã được đọc rồi!')),
      );
      return;
    }

    // Cập nhật UI hàng loạt
    setState(() {
      for (var n in _notifications) {
        n['isRead'] = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã đánh dấu đọc tất cả thông báo thành công!')),
    );

    // Gọi API ngầm cho từng thông báo chưa đọc
    for (var n in unreadList) {
      final int? id = n['id'];
      if (id != null) {
        try {
          await _notificationService.markNotificationRead(id);
        } catch (_) {}
      }
    }
  }

  void _showNotificationDetail(Map<String, dynamic> notification) {
    _markAsRead(notification);

    final String title = notification['title'] ?? 'Thông báo';
    final String body = notification['body'] ?? 'Không có nội dung';
    final bool isTicketRelated = title.toLowerCase().contains('vé') || 
                                 body.toLowerCase().contains('vé') ||
                                 title.toLowerCase().contains('đặt vé') ||
                                 body.toLowerCase().contains('thanh toán');

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Chi tiết thông báo',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeInOutBack);
        return ScaleTransition(
          scale: curve,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.only(top: 20, left: 24, right: 24, bottom: 8),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xff006e1c).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isTicketRelated ? Icons.confirmation_number : Icons.notifications,
                    color: const Color(0xff006e1c),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              body,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actionsPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Đóng',
                  style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                ),
              ),
              if (isTicketRelated)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // Điều hướng sang trang vé của tôi
                    context.push('/my-tickets');
                  },
                  icon: const Icon(Icons.confirmation_number_outlined, size: 16),
                  label: const Text('Xem vé của tôi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff006e1c),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  IconData _getIconForNotification(String title, String body) {
    final t = title.toLowerCase();
    final b = body.toLowerCase();
    if (t.contains('thành công') || b.contains('thành công') || t.contains('hoàn tất') || b.contains('hoàn tất')) {
      return Icons.check_circle_outline;
    }
    if (t.contains('vé') || b.contains('vé')) {
      return Icons.confirmation_number_outlined;
    }
    if (t.contains('hủy') || b.contains('hủy') || t.contains('thất bại') || b.contains('thất bại')) {
      return Icons.cancel_outlined;
    }
    return Icons.notifications_none_outlined;
  }

  Color _getIconColorForNotification(String title, String body) {
    final t = title.toLowerCase();
    final b = body.toLowerCase();
    if (t.contains('thành công') || b.contains('thành công') || t.contains('hoàn tất') || b.contains('hoàn tất')) {
      return Colors.green;
    }
    if (t.contains('vé') || b.contains('vé')) {
      return const Color(0xff006e1c);
    }
    if (t.contains('hủy') || b.contains('hủy') || t.contains('thất bại') || b.contains('thất bại')) {
      return Colors.red;
    }
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Thông báo của tôi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xff006e1c), Color(0xff004d13)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          if (_isLoggedIn && _notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all, color: Colors.white),
              tooltip: 'Đọc tất cả',
              onPressed: _markAllAsRead,
            ),
        ],
      ),
      body: !_isLoggedIn
          ? _buildRequireLoginState()
          : _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xff006e1c)),
                  ),
                )
              : _notifications.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: () => _fetchNotifications(isRefresh: true),
                      color: const Color(0xff006e1c),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        itemCount: _notifications.length + (_nextCursor != null ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _notifications.length) {
                            if (!_isLoadingMore) {
                              // Tự động tải thêm khi cuộn tới cuối trang
                              _fetchNotifications();
                            }
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xff006e1c)),
                                  ),
                                ),
                              ),
                            );
                          }

                          final notification = _notifications[index];
                          final bool isRead = notification['isRead'] == true || notification['isRead'] == 1;
                          final String title = notification['title'] ?? 'Thông báo';
                          final String body = notification['body'] ?? '';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: isRead ? 0.5 : 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isRead ? Colors.grey.shade100 : const Color(0xff006e1c).withOpacity(0.15),
                                width: isRead ? 1 : 1.5,
                              ),
                            ),
                            color: isRead ? Colors.white : const Color(0xff006e1c).withOpacity(0.02),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _showNotificationDetail(notification),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Icon container
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isRead
                                            ? Colors.grey.shade100
                                            : _getIconColorForNotification(title, body).withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _getIconForNotification(title, body),
                                        color: isRead ? Colors.grey.shade500 : _getIconColorForNotification(title, body),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    
                                    // Text content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  style: TextStyle(
                                                    fontWeight: isRead ? FontWeight.bold : FontWeight.w900,
                                                    fontSize: 14,
                                                    color: isRead ? Colors.grey.shade700 : Colors.black87,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (!isRead)
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  margin: const EdgeInsets.only(left: 6),
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xff006e1c),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            body,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              height: 1.4,
                                              fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                                              color: isRead ? Colors.grey.shade600 : Colors.grey.shade800,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildRequireLoginState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xff006e1c).withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_person_outlined,
                color: Color(0xff006e1c),
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Yêu cầu Đăng nhập',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Vui lòng đăng nhập tài khoản của bạn để xem và quản lý danh sách thông báo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Đi sang trang Login (phần tài khoản)
                context.go('/profile');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff006e1c),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                elevation: 1,
              ),
              child: const Text(
                'ĐĂNG NHẬP NGAY',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade100, width: 2),
              ),
              child: Icon(
                Icons.notifications_paused_outlined,
                color: Colors.grey.shade400,
                size: 56,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Chưa có thông báo nào',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Mọi thông báo về đặt vé, lịch trình và ưu đãi hấp dẫn của bạn sẽ xuất hiện tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _fetchNotifications(isRefresh: true),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('TẢI LẠI TRANG'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xff006e1c),
                side: const BorderSide(color: Color(0xff006e1c)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
