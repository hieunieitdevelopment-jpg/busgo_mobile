import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:busgo_mobile/core/routes/app_routes.dart';

/// Trang Onboarding - Hiện thực hóa chính xác thiết kế từ Stitch
/// Phong cách: Organic Editorial Minimalism (Tối giản Biên tập Hữu cơ)
/// Tông màu chủ đạo: Xanh lục bảo (#006e1c) kết hợp Cam urget (#FF6D00)
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    AppRoutes.setOnboardingCompleted(true);
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == 3;

    return Scaffold(
      backgroundColor: const Color(0xfff9f9f9), // Surface nền sáng sang trọng theo Stitch
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header: Logo + Bỏ qua ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xff006e1c).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.directions_bus_rounded,
                          color: Color(0xff006e1c),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'BusGo',
                        style: TextStyle(
                          color: Color(0xff1a1c1c),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _completeOnboarding,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      backgroundColor: const Color(0xffeeeeee),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Bỏ qua',
                      style: TextStyle(
                        color: Color(0xff3f4a3c),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Slide Content ───
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildSlide1(),
                  _buildSlide2(),
                  _buildSlide3(),
                  _buildSlide4(),
                ],
              ),
            ),

            // ─── Bottom Navigation ───
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dot Indicators
                  Row(
                    children: List.generate(
                      4,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? const Color(0xff006e1c)
                              : const Color(0xffbecab9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  // Button Tiếp / Bắt đầu
                  GestureDetector(
                    onTap: () {
                      if (isLastPage) {
                        _completeOnboarding();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: EdgeInsets.symmetric(
                        horizontal: isLastPage ? 28 : 22,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xff006e1c),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xff006e1c).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLastPage ? 'Bắt đầu ngay' : 'Tiếp theo',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            isLastPage ? Icons.done_all_rounded : Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SLIDE 1: CHÀO MỪNG ───
  Widget _buildSlide1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Minh họa dạng tạp chí/ảnh
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xffeeeeee),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(
                      'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?w=600&auto=format&fit=crop',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xffbecab9).withOpacity(0.3),
                        child: const Icon(Icons.image, size: 64, color: Color(0xff006e1c)),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.location_on, color: Color(0xff006e1c), size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Khám phá Việt Nam',
                          style: TextStyle(
                            color: Color(0xff1a1c1c),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Chào mừng bạn đến với BusGo',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xff1a1c1c),
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Khám phá mọi nẻo đường Việt Nam với hệ thống đặt vé xe khách hiện đại và nhanh chóng nhất.',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xff3f4a3c),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),

          // Hai mục đặc trưng từ Stitch
          _buildFeatureTile(
            icon: Icons.explore_rounded,
            title: 'Điểm đến phổ biến',
            desc: 'Sapa, Hà Giang, Đà Lạt đang chờ bạn khám phá.',
          ),
          const SizedBox(height: 12),
          _buildFeatureTile(
            icon: Icons.local_offer_rounded,
            title: 'Ưu đãi hôm nay',
            desc: 'Giảm đến 20% cho hành trình đầu tiên của bạn.',
          ),
        ],
      ),
    );
  }

  // ─── SLIDE 2: CHỌN CHỖ NGỒI ───
  Widget _buildSlide2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Đồ họa sơ đồ chọn ghế ảo sang trọng
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sài Gòn → Đà Lạt',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xff1a1c1c),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Khởi hành: 24 Tháng 5, 2024',
                          style: TextStyle(
                            color: Color(0xff6f7a6b),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.directions_bus, color: Color(0xff006e1c)),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                // Trực quan ghế xe
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSeatIcon(label: '01', isSelected: true),
                    _buildSeatIcon(label: '02', isSelected: false),
                    _buildSeatIcon(label: '03', isBooked: true),
                    _buildSeatIcon(label: '04', isSelected: false),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Chọn chỗ ngồi ưng ý',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xff1a1c1c),
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tự do lựa chọn vị trí ngồi mong muốn với sơ đồ xe trực quan và thông tin minh bạch.',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xff3f4a3c),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),

          _buildFeatureTile(
            icon: Icons.airline_seat_recline_normal_rounded,
            title: 'Ghế Limousine cao cấp',
            desc: 'Được trang bị hệ thống massage hơi cực kỳ êm ái.',
          ),
          const SizedBox(height: 12),
          _buildFeatureTile(
            icon: Icons.wifi_rounded,
            title: 'Đầy đủ tiện ích',
            desc: 'Hỗ trợ sạc USB & hệ thống Wifi tốc độ cao miễn phí.',
          ),
        ],
      ),
    );
  }

  // ─── SLIDE 3: THANH TOÁN & ƯU ĐÃI ───
  Widget _buildSlide3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Mô phỏng ví tiền / Voucher ưu đãi
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mã giảm giá độc quyền',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xff1a1c1c),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xffffdbcb),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xff9f4200).withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GIAM50K',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Color(0xff9f4200),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Giảm ngay 50.000đ lần đầu',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xff9f4200),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xff9f4200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Dùng ngay',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Ưu đãi ngập tràn',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xff1a1c1c),
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Thanh toán an toàn, đa dạng phương thức và nhận ngay hàng ngàn mã giảm giá độc quyền.',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xff3f4a3c),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),

          _buildFeatureTile(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Đa dạng phương thức',
            desc: 'Ví điện tử MoMo/ZaloPay, Thẻ Visa/Master, Napas 24/7.',
          ),
          const SizedBox(height: 12),
          _buildFeatureTile(
            icon: Icons.security_rounded,
            title: 'Bảo mật tuyệt đối',
            desc: 'Mọi thông tin giao dịch đều được mã hóa theo chuẩn PCI-DSS.',
          ),
        ],
      ),
    );
  }

  // ─── SLIDE 4: SẴN SÀNG KHỞI HÀNH ───
  Widget _buildSlide4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Mô phỏng vé xe/QR check-in
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VÉ XE ĐIỆN TỬ',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: Color(0xff006e1c),
                            letterSpacing: 1.0,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Mã đặt vé: BG-8899',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xff1a1c1c),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.qr_code_2_rounded, size: 36, color: Color(0xff1a1c1c)),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xfff3f3f3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('GIỜ ĐI', style: TextStyle(fontSize: 10, color: Color(0xff6f7a6b))),
                          SizedBox(height: 2),
                          Text('08:00', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      Icon(Icons.arrow_forward_rounded, color: Color(0xffbecab9), size: 16),
                      Column(
                        children: [
                          Text('GHẾ', style: TextStyle(fontSize: 10, color: Color(0xff6f7a6b))),
                          SizedBox(height: 2),
                          Text('A03 (VIP)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xff006e1c))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Sẵn sàng khởi hành?',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xff1a1c1c),
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Đăng ký ngay để nhận ưu đãi 50.000đ cho chuyến đi đầu tiên của bạn cùng BusGo.',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xff3f4a3c),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),

          _buildFeatureTile(
            icon: Icons.verified_user_rounded,
            title: 'An toàn tối đa',
            desc: 'Mọi chuyến đi của bạn đều được bảo vệ toàn diện.',
          ),
          const SizedBox(height: 12),
          _buildFeatureTile(
            icon: Icons.update_rounded,
            title: 'Đúng giờ đến 99%',
            desc: 'Cam kết lịch trình chính xác tuyệt đối trên mỗi chặng.',
          ),
        ],
      ),
    );
  }

  // Helper widget xây dựng các dòng lợi ích / thông tin
  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffeeeeee)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xff006e1c).withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: const Color(0xff006e1c),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xff1a1c1c),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xff6f7a6b),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Trực quan vẽ ghế ảo
  Widget _buildSeatIcon({
    required String label,
    bool isSelected = false,
    bool isBooked = false,
  }) {
    Color bgColor = Colors.white;
    Color textColor = const Color(0xff6f7a6b);
    BorderSide border = const BorderSide(color: Color(0xffbecab9));

    if (isSelected) {
      bgColor = const Color(0xff006e1c);
      textColor = Colors.white;
      border = BorderSide.none;
    } else if (isBooked) {
      bgColor = const Color(0xffeeeeee);
      textColor = const Color(0xffbecab9);
      border = BorderSide.none;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: border != BorderSide.none ? Border.fromBorderSide(border) : null,
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
