import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:busgo_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:busgo_mobile/features/profile/presentation/utils/profile_validators.dart';
import 'package:busgo_mobile/features/profile/presentation/widgets/profile_status_badge.dart';
import 'package:busgo_mobile/features/profile/presentation/widgets/update_contact_modal.dart';

/// Trang Hồ sơ cá nhân — phong cách đồng bộ My Tickets / Boarding Pass.
/// - Header gradient #006e1c → #4caf50 + avatar lớn
/// - Card thông tin: tên (read-only), email + nút "Xác thực để cập nhật",
///   số điện thoại + nút tương tự
/// - Cooldown 12h: nếu chưa hết → disable nút + hiện thời gian còn lại
/// - Modal 3 bước cho luồng đổi (skip step 1 nếu phone null)
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color _primary = Color(0xff006e1c);
  static const Color _primaryLight = Color(0xff4caf50);
  static const LinearGradient _primaryGradient = LinearGradient(
    colors: [_primary, _primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  Timer? _cooldownTicker;

  @override
  void initState() {
    super.initState();
    // Tự refresh profile mới nhất khi mở trang
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        auth.fetchLatestProfile();
      }
    });
    // Tick mỗi 30s để cập nhật thời gian còn lại của cooldown
    _cooldownTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    super.dispose();
  }

  // Resolve cooldown deadline cho 1 field. null = không trong cooldown.
  ({DateTime deadline, Duration remaining})? _cooldownState(
    Map<String, dynamic>? user,
    String field,
  ) {
    final deadline = cooldownDeadlineForField(user: user, field: field);
    if (deadline == null) return null;
    final remaining = deadline.difference(DateTime.now());
    if (remaining.isNegative || remaining == Duration.zero) return null;
    return (deadline: deadline, remaining: remaining);
  }

  Future<void> _openUpdateContact(ContactField field, String? currentValue) async {
    final ok = await showUpdateContactModal(
      context,
      field: field,
      currentValue: currentValue,
    );
    if (ok == true && mounted) {
      // Lấy lại profile để chắc chắn có timestamp cooldown mới
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.fetchLatestProfile();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    if (!auth.isAuthenticated) {
      return _buildRequireLoginScaffold();
    }

    return Scaffold(
      backgroundColor: const Color(0xfff5f7f5),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(user),
          _buildContactCard(user),
          _buildSettingsCard(),
          _buildLogoutButton(auth),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ---------- Header ----------
  Widget _buildHeader(Map<String, dynamic>? user) {
    final fullName = user?['fullName'] ?? 'Khách hàng BusGo';
    final email = user?['email'] ?? '';
    final initial = (fullName.toString().trim().isNotEmpty)
        ? fullName.toString().trim().substring(0, 1).toUpperCase()
        : 'K';

    return Container(
      decoration: BoxDecoration(
        gradient: _primaryGradient,
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 12,
        20,
        24,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.go('/'),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Hồ sơ cá nhân',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              ProfileStatusBadge(status: user?['status']?.toString()),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              // Avatar
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (email.toString().isNotEmpty)
                      Text(
                        email.toString(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- Contact Card ----------
  Widget _buildContactCard(Map<String, dynamic>? user) {
    final email = user?['email']?.toString() ?? '';
    final phone = user?['phone']?.toString();
    final fullName = user?['fullName']?.toString() ?? '';

    final emailCooldown = _cooldownState(user, 'email');
    final phoneCooldown = _cooldownState(user, 'phone');

    return Transform.translate(
      offset: const Offset(0, -16),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông tin tài khoản',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 14),
            // Họ và tên (read-only)
            _buildField(
              icon: Icons.person_outline_rounded,
              label: 'Họ và tên',
              value: fullName.isEmpty ? 'Chưa có thông tin' : fullName,
              isReadOnly: true,
            ),
            const SizedBox(height: 12),
            // Email
            _buildField(
              icon: Icons.alternate_email_rounded,
              label: 'Email',
              value: email.isEmpty ? 'Chưa có email' : email,
              actionLabel: emailCooldown != null
                  ? 'Còn ${formatRemaining(emailCooldown.remaining)}'
                  : 'Xác thực để cập nhật',
              actionEnabled: emailCooldown == null,
              tooltip: emailCooldown != null
                  ? 'Bạn vừa cập nhật thông tin liên hệ. Vui lòng thử lại sau ${formatRemaining(emailCooldown.remaining)}.'
                  : null,
              onActionTap: () => _openUpdateContact(ContactField.email, email),
            ),
            const SizedBox(height: 12),
            // Số điện thoại
            _buildField(
              icon: Icons.phone_iphone_rounded,
              label: 'Số điện thoại',
              value: (phone == null || phone.isEmpty)
                  ? 'Chưa có số điện thoại'
                  : phone,
              actionLabel: phoneCooldown != null
                  ? 'Còn ${formatRemaining(phoneCooldown.remaining)}'
                  : ((phone == null || phone.isEmpty)
                      ? 'Thêm số điện thoại'
                      : 'Xác thực để cập nhật'),
              actionEnabled: phoneCooldown == null,
              tooltip: phoneCooldown != null
                  ? 'Bạn vừa cập nhật thông tin liên hệ. Vui lòng thử lại sau ${formatRemaining(phoneCooldown.remaining)}.'
                  : null,
              onActionTap: () => _openUpdateContact(ContactField.phone, phone),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required IconData icon,
    required String label,
    required String value,
    String? actionLabel,
    bool actionEnabled = true,
    bool isReadOnly = false,
    String? tooltip,
    VoidCallback? onActionTap,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E1E1E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isReadOnly)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: Colors.grey.shade400,
              ),
            )
          else if (actionLabel != null)
            Tooltip(
              message: tooltip ?? '',
              triggerMode: tooltip == null
                  ? TooltipTriggerMode.manual
                  : TooltipTriggerMode.tap,
              child: TextButton(
                onPressed: actionEnabled ? onActionTap : null,
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  disabledForegroundColor: Colors.grey.shade500,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- Settings card ----------
  Widget _buildSettingsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _settingTile(
            icon: Icons.confirmation_number_outlined,
            label: 'Vé đã đặt',
            onTap: () => context.push('/my-tickets'),
          ),
          _divider(),
          _settingTile(
            icon: Icons.local_offer_outlined,
            label: 'Ví khuyến mãi',
            onTap: () => context.push('/promotions'),
          ),
          _divider(),
          _settingTile(
            icon: Icons.credit_card_rounded,
            label: 'Phương thức thanh toán',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tính năng đang được hoàn thiện.'),
                ),
              );
            },
          ),
          _divider(),
          _settingTile(
            icon: Icons.notifications_outlined,
            label: 'Thông báo',
            onTap: () => context.push('/notifications'),
          ),
        ],
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      height: 1,
      color: Colors.grey.shade100,
    );
  }

  // ---------- Logout ----------
  Widget _buildLogoutButton(AuthProvider auth) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text(
            'ĐĂNG XUẤT',
            style:
                TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.3),
          ),
          onPressed: () async {
            await auth.logout();
            if (mounted) context.go('/');
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade600,
            side: BorderSide(color: Colors.red.shade300),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Require login state ----------
  Widget _buildRequireLoginScaffold() {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7f5),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: _primaryGradient),
        ),
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Tài khoản',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
                child: const Icon(Icons.person_outline_rounded,
                    size: 54, color: Colors.white),
              ),
              const SizedBox(height: 22),
              const Text(
                'Chào mừng đến BusGo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Đăng nhập để xem hồ sơ cá nhân, đổi thông tin liên lạc và quản lý các phương thức thanh toán.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: InkWell(
                  onTap: () => context.push('/login'),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: _primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _primary.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      'ĐĂNG NHẬP NGAY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 3,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: _primary,
      unselectedItemColor: Colors.grey.shade500,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
      onTap: (index) {
        switch (index) {
          case 0:
            context.go('/');
            break;
          case 1:
            context.go('/my-tickets');
            break;
          case 2:
            context.go('/promotions');
            break;
          case 3:
            // đang ở /profile
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.search_rounded), label: 'Tìm kiếm'),
        BottomNavigationBarItem(
            icon: Icon(Icons.confirmation_number_outlined),
            label: 'Vé của tôi'),
        BottomNavigationBarItem(
            icon: Icon(Icons.local_offer_outlined), label: 'Ưu đãi'),
        BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded), label: 'Tài khoản'),
      ],
    );
  }
}
