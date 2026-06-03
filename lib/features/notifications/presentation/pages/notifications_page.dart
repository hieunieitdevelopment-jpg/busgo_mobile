import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:busgo_mobile/core/api/notification_service.dart';
import 'package:busgo_mobile/features/notifications/presentation/providers/notification_provider.dart';

/// Trang Thông báo của tôi — phong cách đồng bộ với My Tickets / Boarding Pass.
/// - AppBar gradient #006e1c → #4caf50 (cùng tone với app)
/// - 2 tab: Tất cả / Chưa đọc
/// - Card thông báo có icon container gradient theo loại, badge #id, tag loại
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _notificationService = NotificationService();

  bool _isLoading = true;
  bool _isLoggedIn = false;
  int? _nextCursor;
  bool _isLoadingMore = false;

  bool _showUnreadOnly = false;

  static const Color _primary = Color(0xff006e1c);
  static const Color _primaryLight = Color(0xff4caf50);
  static const LinearGradient _primaryGradient = LinearGradient(
    colors: [_primary, _primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _checkLoginAndFetch();
  }

  Future<void> _checkLoginAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null && token.isNotEmpty) {
      setState(() => _isLoggedIn = true);
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
      setState(() => _nextCursor = null);
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
        if (!mounted) return;
        final List<dynamic> fetchedList = data['notifications'] ?? [];
        final int? next = data['next'];

        final notiProvider =
            Provider.of<NotificationProvider>(context, listen: false);
        List<dynamic> merged;
        if (isRefresh || _nextCursor == null) {
          merged = List<dynamic>.from(fetchedList);
        } else {
          merged = List<dynamic>.from(notiProvider.notifications)
            ..addAll(fetchedList);
        }
        merged.sort((a, b) => (b['id'] ?? 0).compareTo(a['id'] ?? 0));
        notiProvider.setNotifications(merged);

        setState(() => _nextCursor = next);
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
    await Provider.of<NotificationProvider>(context, listen: false)
        .markAsRead(id);
  }

  Future<void> _markAllAsRead() async {
    final notiProvider =
        Provider.of<NotificationProvider>(context, listen: false);
    final hasUnread = notiProvider.notifications
        .any((n) => n['isRead'] == false || n['isRead'] == 0);
    if (!hasUnread) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tất cả thông báo đã được đọc rồi!')),
      );
      return;
    }
    await notiProvider.markAllAsRead();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đánh dấu đọc tất cả thông báo thành công!')),
      );
    }
  }

  void _showNotificationDetail(Map<String, dynamic> notification) {
    _markAsRead(notification);

    final String title = notification['title'] ?? 'Thông báo';
    final String body = notification['body'] ?? 'Không có nội dung';
    final _NotiKind kind = _classifyNotification(title, body);
    final bool isTicketRelated = kind == _NotiKind.ticket ||
        kind == _NotiKind.success ||
        title.toLowerCase().contains('vé') ||
        body.toLowerCase().contains('vé') ||
        body.toLowerCase().contains('thanh toán');

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Chi tiết thông báo',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curve,
          child: Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header với icon + tag loại
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: _gradientForKind(kind),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _accentColorForKind(kind).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          _iconForKind(kind),
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _labelForKind(kind),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _accentColorForKind(kind),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      body,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.grey.shade800,
                        height: 1.55,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade600,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        ),
                        child: const Text(
                          'Đóng',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isTicketRelated)
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            context.push('/my-tickets');
                          },
                          icon: const Icon(Icons.confirmation_number_outlined, size: 16),
                          label: const Text('Xem vé của tôi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------- Phân loại & style theo loại ----------

  _NotiKind _classifyNotification(String title, String body) {
    final t = title.toLowerCase();
    final b = body.toLowerCase();
    if (t.contains('thanh toán') && (t.contains('thành công') || b.contains('thành công'))) {
      return _NotiKind.success;
    }
    if (t.contains('hủy') || b.contains('hủy')) return _NotiKind.cancelled;
    if (t.contains('thất bại') || b.contains('thất bại')) return _NotiKind.failed;
    if (t.contains('khởi hành') || b.contains('khởi hành')) return _NotiKind.departure;
    if (t.contains('đặt vé') || b.contains('đặt vé') || t.contains('giữ chỗ') || b.contains('giữ chỗ')) {
      return _NotiKind.ticket;
    }
    if (t.contains('đánh giá') || b.contains('đánh giá')) return _NotiKind.review;
    if (t.contains('khuyến mãi') || b.contains('ưu đãi') || t.contains('ưu đãi')) {
      return _NotiKind.promo;
    }
    return _NotiKind.general;
  }

  IconData _iconForKind(_NotiKind kind) {
    switch (kind) {
      case _NotiKind.success:
        return Icons.check_circle_outline;
      case _NotiKind.ticket:
        return Icons.confirmation_number_outlined;
      case _NotiKind.departure:
        return Icons.directions_bus_filled_outlined;
      case _NotiKind.cancelled:
        return Icons.cancel_outlined;
      case _NotiKind.failed:
        return Icons.error_outline;
      case _NotiKind.review:
        return Icons.star_outline;
      case _NotiKind.promo:
        return Icons.local_offer_outlined;
      case _NotiKind.general:
        return Icons.notifications_none_outlined;
    }
  }

  Color _accentColorForKind(_NotiKind kind) {
    switch (kind) {
      case _NotiKind.success:
        return Colors.green.shade600;
      case _NotiKind.ticket:
        return _primary;
      case _NotiKind.departure:
        return Colors.blue.shade600;
      case _NotiKind.cancelled:
        return Colors.red.shade600;
      case _NotiKind.failed:
        return Colors.deepOrange.shade600;
      case _NotiKind.review:
        return Colors.amber.shade700;
      case _NotiKind.promo:
        return Colors.pink.shade400;
      case _NotiKind.general:
        return Colors.orange.shade600;
    }
  }

  LinearGradient _gradientForKind(_NotiKind kind) {
    final c = _accentColorForKind(kind);
    final c2 = HSLColor.fromColor(c).withLightness(0.55).toColor();
    return LinearGradient(
      colors: [c, c2],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  String _labelForKind(_NotiKind kind) {
    switch (kind) {
      case _NotiKind.success:
        return 'THANH TOÁN';
      case _NotiKind.ticket:
        return 'ĐẶT VÉ';
      case _NotiKind.departure:
        return 'KHỞI HÀNH';
      case _NotiKind.cancelled:
        return 'HỦY VÉ';
      case _NotiKind.failed:
        return 'GIAO DỊCH';
      case _NotiKind.review:
        return 'ĐÁNH GIÁ';
      case _NotiKind.promo:
        return 'ƯU ĐÃI';
      case _NotiKind.general:
        return 'THÔNG BÁO';
    }
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7f5),
      appBar: AppBar(
        title: const Text(
          'Thông báo của tôi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: _primaryGradient),
        ),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notiProvider, _) {
              if (!_isLoggedIn || notiProvider.notifications.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: IconButton(
                  icon: const Icon(Icons.done_all, color: Colors.white),
                  tooltip: 'Đọc tất cả',
                  onPressed: _markAllAsRead,
                ),
              );
            },
          ),
        ],
      ),
      body: !_isLoggedIn
          ? _buildRequireLoginState()
          : Column(
              children: [
                _buildHeaderSummary(),
                _buildTabBar(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(_primary),
                          ),
                        )
                      : _buildNotificationsList(),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderSummary() {
    return Consumer<NotificationProvider>(
      builder: (context, notiProvider, _) {
        final total = notiProvider.notifications.length;
        final unread = notiProvider.unreadCount;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: const BoxDecoration(gradient: _primaryGradient),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unread > 0
                          ? 'Bạn có $unread thông báo chưa đọc'
                          : 'Tất cả thông báo đã được đọc',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tổng số: $total thông báo',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      unread > 0
                          ? Icons.mark_email_unread_outlined
                          : Icons.mark_email_read_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$unread / $total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _buildTab(
              label: 'Tất cả',
              selected: !_showUnreadOnly,
              onTap: () => setState(() => _showUnreadOnly = false),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Consumer<NotificationProvider>(
              builder: (context, notiProvider, _) {
                final unread = notiProvider.unreadCount;
                return _buildTab(
                  label: unread > 0 ? 'Chưa đọc ($unread)' : 'Chưa đọc',
                  selected: _showUnreadOnly,
                  onTap: () => setState(() => _showUnreadOnly = true),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? _primaryGradient : null,
          color: selected ? null : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _primary.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsList() {
    return Consumer<NotificationProvider>(
      builder: (context, notiProvider, _) {
        final all = notiProvider.notifications;
        final filtered = _showUnreadOnly
            ? all.where((n) => n['isRead'] == false || n['isRead'] == 0).toList()
            : all;

        if (filtered.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () => _fetchNotifications(isRefresh: true),
          color: _primary,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: filtered.length + (_nextCursor != null && !_showUnreadOnly ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == filtered.length) {
                if (!_isLoadingMore) {
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
                        valueColor: AlwaysStoppedAnimation<Color>(_primary),
                      ),
                    ),
                  ),
                );
              }
              return _buildNotificationCard(filtered[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> n) {
    final bool isRead = n['isRead'] == true || n['isRead'] == 1;
    final String title = n['title'] ?? 'Thông báo';
    final String body = n['body'] ?? '';
    final int? id = n['id'];
    final _NotiKind kind = _classifyNotification(title, body);
    final Color accent = _accentColorForKind(kind);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead ? Colors.grey.shade200 : accent.withOpacity(0.3),
          width: isRead ? 1 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: isRead
                ? Colors.black.withOpacity(0.03)
                : accent.withOpacity(0.08),
            blurRadius: isRead ? 4 : 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showNotificationDetail(n),
          child: Stack(
            children: [
              // Dải màu trái nếu chưa đọc
              if (!isRead)
                Positioned.fill(
                  left: 0,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        gradient: _gradientForKind(kind),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon container có gradient theo loại
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: isRead
                            ? LinearGradient(
                                colors: [Colors.grey.shade200, Colors.grey.shade100],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : _gradientForKind(kind),
                        shape: BoxShape.circle,
                        boxShadow: isRead
                            ? null
                            : [
                                BoxShadow(
                                  color: accent.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Icon(
                        _iconForKind(kind),
                        color: isRead ? Colors.grey.shade500 : Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Nội dung
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: tag loại + badge id + dot chưa đọc
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accent.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _labelForKind(kind),
                                  style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 9.5,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              if (id != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '#$id',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 9.5,
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if (!isRead)
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    gradient: _gradientForKind(kind),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: accent.withOpacity(0.5),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            title,
                            style: TextStyle(
                              fontWeight: isRead ? FontWeight.w700 : FontWeight.w800,
                              fontSize: 14,
                              color: isRead ? Colors.grey.shade700 : Colors.black87,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            body,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
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
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Empty / require login ----------

  Widget _buildRequireLoginState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                gradient: _primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _primary.withOpacity(0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_person_outlined,
                color: Colors.white,
                size: 52,
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
              style: TextStyle(color: Colors.grey.shade600, height: 1.5, fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.go('/profile'),
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text(
                  'ĐĂNG NHẬP NGAY',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isFiltered = _showUnreadOnly;
    return ListView(
      // Cho RefreshIndicator hoạt động dù danh sách rỗng
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade200, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      isFiltered
                          ? Icons.mark_email_read_outlined
                          : Icons.notifications_paused_outlined,
                      color: Colors.grey.shade400,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isFiltered
                        ? 'Không có thông báo chưa đọc'
                        : 'Chưa có thông báo nào',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isFiltered
                        ? 'Bạn đã đọc hết mọi thông báo. Quay lại tab "Tất cả" để xem lịch sử.'
                        : 'Mọi thông báo về đặt vé, lịch trình và ưu đãi hấp dẫn của bạn sẽ xuất hiện tại đây.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 22),
                  OutlinedButton.icon(
                    onPressed: () {
                      if (isFiltered) {
                        setState(() => _showUnreadOnly = false);
                      } else {
                        _fetchNotifications(isRefresh: true);
                      }
                    },
                    icon: Icon(
                      isFiltered ? Icons.list_alt_outlined : Icons.refresh,
                      size: 16,
                    ),
                    label: Text(isFiltered ? 'XEM TẤT CẢ' : 'TẢI LẠI TRANG'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      side: const BorderSide(color: _primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Phân loại thông báo dựa trên tiêu đề/nội dung.
enum _NotiKind {
  success,    // Thanh toán thành công
  ticket,     // Đặt vé / giữ chỗ
  departure,  // Sắp khởi hành
  cancelled,  // Hủy vé
  failed,     // Thất bại
  review,     // Đánh giá
  promo,      // Khuyến mãi / ưu đãi
  general,    // Khác
}
