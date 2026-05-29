import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:busgo_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:busgo_mobile/features/payment/presentation/providers/payment_provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    _nameController = TextEditingController(text: user?['fullName'] ?? 'Nguyễn Văn Khách');
    _phoneController = TextEditingController(text: user?['phone'] ?? user?['contactInfo']?['phone'] ?? '0912345678');
    _emailController = TextEditingController(text: user?['email'] ?? user?['contactInfo']?['email'] ?? 'khach.nguyen@example.com');

    // Tải thẻ thanh toán thật của User từ Stripe
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (authProvider.isAuthenticated) {
        Provider.of<PaymentProvider>(context, listen: false).fetchPaymentMethods();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final paymentProvider = Provider.of<PaymentProvider>(context);
    final user = authProvider.user;

    final String initialChar = (user?['fullName']?.toString().isNotEmpty ?? false)
        ? user!['fullName'].toString()[0].toUpperCase()
        : 'K';

    // Trả về giao diện yêu cầu đăng nhập nếu người dùng chưa đăng nhập
    if (!authProvider.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Tài khoản'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.account_circle_outlined,
                  size: 100,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Chào mừng bạn đến với BusGo',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Đăng nhập để xem hồ sơ cá nhân, đổi thông tin liên lạc và quản lý các phương thức thanh toán Stripe của bạn.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => context.push('/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'ĐĂNG NHẬP NGAY',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: 3,
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
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Tìm kiếm'),
            BottomNavigationBarItem(icon: Icon(Icons.confirmation_number_outlined), label: 'Vé của tôi'),
            BottomNavigationBarItem(icon: Icon(Icons.local_offer_outlined), label: 'Ưu đãi'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Tài khoản'),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản của tôi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar profile card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        initialChar,
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              user?['fullName'] ?? 'Nguyễn Văn Khách',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, color: Colors.green, size: 16),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?['phone'] ?? user?['contactInfo']?['phone'] ?? '0912345678',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Profile info inputs
            const Text('Thông tin cá nhân', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Họ và tên',
                prefixIcon: Icon(Icons.person_outline),
              ),
              controller: _nameController,
              readOnly: true, // Swagger profile endpoint handles fields updates via specific flows
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Số điện thoại',
                prefixIcon: Icon(Icons.phone_android_outlined),
              ),
              controller: _phoneController,
              readOnly: true,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              controller: _emailController,
              readOnly: true,
            ),
            const SizedBox(height: 24),

            // Saved Credit Cards Section (Đồng bộ cổng thanh toán Stripe)
            const Text('Phương thức thanh toán đã lưu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),

            paymentProvider.isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.green)),
                    ),
                  )
                : paymentProvider.paymentMethods.isNotEmpty
                    ? Column(
                        children: paymentProvider.paymentMethods.map((card) {
                          final brand = card['brand'] ?? 'Visa';
                          final last4 = card['last4'] ?? '4444';
                          final expMonth = card['expMonth'] ?? 12;
                          final expYear = card['expYear'] ?? 29;
                          final isDefault = card['isDefault'] ?? false;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: _buildCreditCardWidget(
                              brand: brand.toString().toUpperCase(),
                              last4: last4.toString(),
                              expiry: '$expMonth/$expYear',
                              holderName: user?['fullName']?.toString().toUpperCase() ?? 'NGUYEN VAN KHACH',
                              isDefault: isDefault,
                            ),
                          );
                        }).toList(),
                      )
                    : _buildCreditCardWidget(
                        brand: 'VISA',
                        last4: '4444',
                        expiry: '12/29',
                        holderName: user?['fullName']?.toString().toUpperCase() ?? 'NGUYEN VAN KHACH',
                        isDefault: true,
                      ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  // Gọi API Setup Intent từ Stripe để liên kết thẻ mới
                  final clientSecret = await paymentProvider.generateStripeClientSecret();
                  if (clientSecret != null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Khởi tạo liên kết Stripe thành công! Vui lòng nhập thẻ.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.add, color: Colors.green),
                label: const Text('Liên kết thẻ mới', style: TextStyle(color: Colors.green)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.green),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Settings list
            const Divider(height: 1),
            _buildSettingMenuItem(context, 'Lịch sử giao dịch', Icons.receipt_long_outlined),
            _buildSettingMenuItem(context, 'Đổi mật khẩu', Icons.lock_outline),
            
            // Logout
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Đăng xuất', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () async {
                  await authProvider.logout();
                  if (mounted) {
                    context.go('/');
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 3,
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
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Tìm kiếm'),
          BottomNavigationBarItem(icon: Icon(Icons.confirmation_number_outlined), label: 'Vé của tôi'),
          BottomNavigationBarItem(icon: Icon(Icons.local_offer_outlined), label: 'Ưu đãi'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Tài khoản'),
        ],
      ),
    );
  }

  Widget _buildCreditCardWidget({
    required String brand,
    required String last4,
    required String expiry,
    required String holderName,
    required bool isDefault,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDefault 
              ? [const Color(0xff006e1c), const Color(0xff003c0b)]
              : [Colors.grey.shade700, Colors.grey.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(brand, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
              if (isDefault)
                const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
            ],
          ),
          const SizedBox(height: 20),
          Text('**** **** **** $last4', style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(holderName, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text('Hết hạn: $expiry', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingMenuItem(BuildContext context, String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade700),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      contentPadding: EdgeInsets.zero,
      onTap: () {},
    );
  }
}
