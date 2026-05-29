import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:busgo_mobile/core/api/public_service.dart';
import 'package:busgo_mobile/features/booking/presentation/providers/booking_provider.dart';
import 'package:busgo_mobile/features/booking/data/booking_service.dart';
import 'package:busgo_mobile/features/auth/presentation/providers/auth_provider.dart';

// Đồng bộ 100% danh sách Tỉnh/Thành phố từ Web (VIETNAM_PROVINCES)
const List<String> _vietnamProvinces = [
  'An Giang', 'Bà Rịa - Vũng Tàu', 'Bắc Giang', 'Bắc Kạn', 'Bạc Liêu', 'Bắc Ninh', 'Bến Tre', 'Bình Định', 'Bình Dương', 'Bình Phước', 'Bình Thuận',
  'Cà Mau', 'Cần Thơ', 'Cao Bằng', 'Đà Nẵng', 'Đắk Lắk', 'Đắk Nông', 'Điện Biên', 'Đồng Nai', 'Đồng Tháp', 'Gia Lai', 'Hà Giang', 'Hà Nam', 'Hà Nội',
  'Hà Tĩnh', 'Hải Dương', 'Hải Phòng', 'Hậu Giang', 'Hòa Bình', 'Hưng Yên', 'Khánh Hòa', 'Kiên Giang', 'Kon Tum', 'Lai Châu', 'Lâm Đồng', 'Lạng Sơn',
  'Lào Cai', 'Long An', 'Nam Định', 'Nghệ An', 'Ninh Bình', 'Ninh Thuận', 'Phú Thọ', 'Phú Yên', 'Quảng Bình', 'Quảng Nam', 'Quảng Ngãi', 'Quảng Ninh',
  'Quảng Trị', 'Sóc Trăng', 'Sơn La', 'Tây Ninh', 'Thái Bình', 'Thái Nguyên', 'Thanh Hóa', 'Thừa Thiên Huế', 'Tiền Giang', 'TP. Hồ Chí Minh', 'Trà Vinh',
  'Tuyên Quang', 'Vĩnh Long', 'Vĩnh Phúc', 'Yên Bái'
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _departureController = TextEditingController(text: 'Hà Nội');
  final TextEditingController _destinationController = TextEditingController(text: 'Sa Pa');
  late final TextEditingController _dateController;

  final PublicService _publicService = PublicService();
  List<dynamic> _promotions = [];
  List<dynamic> _companies = [];
  List<dynamic> _popularRoutes = [];
  bool _isLoadingData = false;
  String? _lastToken;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year;
    _dateController = TextEditingController(text: '$day/$month/$year');
    _fetchPublicData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context);
    if (authProvider.token != _lastToken) {
      _lastToken = authProvider.token;
      _fetchPublicData();
    }
  }

  Future<void> _fetchPublicData() async {
    if (!mounted) return;
    setState(() => _isLoadingData = true);
    try {
      final promoRes = await _publicService.getPromotions();
      final companyRes = await _publicService.getCompanies();

      if (mounted) {
        setState(() {
          _promotions = promoRes.data['items'] ?? promoRes.data['promotions'] ?? promoRes.data['data'] ?? [];
          _companies = companyRes.data['companies'] ?? companyRes.data['data'] ?? [];
        });
      }

      // Fetch dynamic popular routes matching the React web client logic
      final BookingService bookingService = BookingService();
      try {
        final tripRes = await bookingService.getTripSchedules(limit: 50, orderBy: 'asc');
        final trips = tripRes.data['trip'] ?? tripRes.data['data'] ?? [];
        if (trips is List && trips.isNotEmpty) {
          final Map<String, dynamic> routesMap = {};
          for (var trip in trips) {
            final fromLoc = trip['fromLocation'] ?? trip['from_location'];
            final toLoc = trip['toLocation'] ?? trip['to_location'];
            if (fromLoc == null || toLoc == null) continue;
            final key = '$fromLoc-$toLoc';
            
            // Trích xuất giá vé đồng bộ với React web client: trip.price là số nguyên
            double priceVal = 0;
            final dynamic rawPrice = trip['price'] ?? 
                               trip['ticketPrice'] ?? 
                               trip['ticket_price'] ?? 
                               trip['fare'];
            if (rawPrice != null) {
              if (rawPrice is num) {
                priceVal = rawPrice.toDouble();
              } else {
                // Parse từ string, loại bỏ ký tự không phải số
                final cleanStr = rawPrice.toString().replaceAll(RegExp('[^0-9]'), '');
                if (cleanStr.isNotEmpty) {
                  priceVal = double.tryParse(cleanStr) ?? 0;
                }
              }
            }
            
            // Format giá theo định dạng Việt Nam (ví dụ: 150000 -> "Từ 150.000đ")
            String formatPrice(double val) {
              if (val <= 0) return 'Liên hệ';
              final intVal = val.toInt();
              final str = intVal.toString();
              final buffer = StringBuffer();
              for (int i = 0; i < str.length; i++) {
                if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
                buffer.write(str[i]);
              }
              return 'Từ ${buffer.toString()}đ';
            }
            final String priceStr = formatPrice(priceVal);
            final durationMinutes = int.tryParse(trip['durationMinutes']?.toString() ?? trip['duration_minutes']?.toString() ?? '180') ?? 180;
            final String durationStr = 'Khoảng ${durationMinutes ~/ 60}h ${durationMinutes % 60}m';

            if (!routesMap.containsKey(key)) {
              routesMap[key] = {
                'id': trip['id'],
                'from': fromLoc,
                'to': toLoc,
                'title': '$fromLoc ➔ $toLoc',
                'image': 'https://picsum.photos/seed/${Uri.encodeComponent(key)}/800/1000',
                'price': priceStr,
                'priceValue': priceVal,
                'duration': durationStr,
              };
            } else {
              // Nếu đã có lộ trình này, cập nhật giá nhỏ nhất/giá đúng hơn
              final double currentPrice = routesMap[key]['priceValue'] ?? 999999.0;
              if (priceVal < currentPrice && priceVal > 0) {
                routesMap[key]['price'] = priceStr;
                routesMap[key]['priceValue'] = priceVal;
              }
            }
          }
          if (mounted) {
            setState(() {
              _popularRoutes = routesMap.values.toList().take(4).toList();
            });
          }
        }
      } catch (_) {
        // Safe fallback in case of unauthenticated API access or network error
        if (mounted) {
          setState(() {
            _popularRoutes = [
              { 'id': 1, 'from': 'Hà Nội', 'to': 'Sapa', 'title': 'Hà Nội ➔ Sapa', 'image': 'https://images.unsplash.com/photo-1509060464153-4466739f7840?w=600&auto=format&fit=crop', 'price': 'Từ 250.000đ', 'duration': 'Khoảng 6 giờ' },
              { 'id': 2, 'from': 'TP. Hồ Chí Minh', 'to': 'Đà Lạt', 'title': 'TP. Hồ Chí Minh ➔ Đà Lạt', 'image': 'https://images.unsplash.com/photo-1583258292688-d0213df4a3a8?w=600&auto=format&fit=crop', 'price': 'Từ 300.000đ', 'duration': 'Khoảng 8 giờ' },
              { 'id': 3, 'from': 'Đà Nẵng', 'to': 'Hội An', 'title': 'Đà Nẵng ➔ Hội An', 'image': 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&auto=format&fit=crop', 'price': 'Từ 100.000đ', 'duration': 'Khoảng 1 giờ' },
              { 'id': 4, 'from': 'Hà Nội', 'to': 'Hải Phòng', 'title': 'Hà Nội ➔ Hải Phòng', 'image': 'https://images.unsplash.com/photo-1624467024411-b551600b2a3a?w=600&auto=format&fit=crop', 'price': 'Từ 120.000đ', 'duration': 'Khoảng 2 giờ' }
            ];
          });
        }
      }
    } catch (_) {
      // Clean fallback if network is offline or loading fails, ensuring stability
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  void _swapLocations() {
    setState(() {
      final temp = _departureController.text;
      _departureController.text = _destinationController.text;
      _destinationController.text = temp;
    });
  }

  void _navigateToCompanyTrips(String companyName, {String companyId = ''}) {
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    bookingProvider.setCompanyFilter(companyName, id: companyId);
    bookingProvider.searchTrips(
      from: '',
      to: '',
      date: _dateController.text.trim(),
    );
    context.push('/search-results');
  }

  // Mở hộp chọn Tỉnh/Thành phố thông minh (tương thích LocationDropdown của Web)
  void _showLocationSelector(BuildContext context, bool isDeparture) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _LocationSearchSheet(
          title: isDeparture ? 'Chọn điểm khởi hành' : 'Chọn điểm đến',
          onSelected: (province) {
            setState(() {
              if (isDeparture) {
                _departureController.text = province;
              } else {
                _destinationController.text = province;
              }
            });
          },
        );
      },
    );
  }

  // Mở hộp chọn ngày trực quan kiểu Native Premium
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xff006e1c), // Emerald Green
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateController.text = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  @override
  void dispose() {
    _departureController.dispose();
    _destinationController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gorgeous Emerald Green Header Frame (Giao diện giống Web cao cấp)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xff006e1c), Color(0xff004d13)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                              image: const DecorationImage(
                                image: AssetImage('busgo.jpg'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Bus',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Text(
                                    'Go',
                                    style: TextStyle(
                                      color: Colors.yellow.shade400,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const Text(
                                'Hành trình trọn vẹn',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.notifications_none_outlined, color: Colors.white),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Chào bạn đồng hành! 👋',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Bạn muốn đi đâu hôm nay?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Fields Card (Đồng bộ UX với LocationDropdown & DatePicker trên Web)
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Departure selection field
                          InkWell(
                            onTap: () => _showLocationSelector(context, true),
                            borderRadius: BorderRadius.circular(8),
                            child: IgnorePointer(
                              child: TextField(
                                controller: _departureController,
                                decoration: const InputDecoration(
                                  labelText: 'Điểm khởi hành',
                                  prefixIcon: Icon(Icons.location_on_outlined, color: Colors.green),
                                ),
                              ),
                            ),
                          ),

                          // Swap Locations Button
                          GestureDetector(
                            onTap: _swapLocations,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.swap_vert, color: Colors.green),
                            ),
                          ),

                          // Destination selection field
                          InkWell(
                            onTap: () => _showLocationSelector(context, false),
                            borderRadius: BorderRadius.circular(8),
                            child: IgnorePointer(
                              child: TextField(
                                controller: _destinationController,
                                decoration: const InputDecoration(
                                  labelText: 'Điểm đến',
                                  prefixIcon: Icon(Icons.location_on, color: Colors.green),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Date Picker selection field
                          InkWell(
                            onTap: () => _selectDate(context),
                            borderRadius: BorderRadius.circular(8),
                            child: IgnorePointer(
                              child: TextField(
                                controller: _dateController,
                                decoration: const InputDecoration(
                                  labelText: 'Ngày đi',
                                  prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Submit CTA Search
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () {
                                final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
                                bookingProvider.clearCompanyFilter();
                                bookingProvider.searchTrips(
                                  from: _departureController.text.trim(),
                                  to: _destinationController.text.trim(),
                                  date: _dateController.text.trim(),
                                );
                                context.push('/search-results');
                              },
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text(
                                'Tìm chuyến xe ngay',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Popular Routes Section (Đồng bộ 100% các tuyến đường đặc sắc từ Web)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 24),
                          const SizedBox(width: 6),
                          Text(
                            'Tuyến đường phổ biến',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 210,
                    child: _popularRoutes.isNotEmpty
                        ? ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _popularRoutes.length,
                            itemBuilder: (context, index) {
                              final route = _popularRoutes[index];
                              return _buildPopularRouteCard(
                                context,
                                title: route['title'] ?? '',
                                from: route['from'] ?? '',
                                to: route['to'] ?? '',
                                image: route['image'] ?? '',
                                price: route['price'] ?? '',
                                duration: route['duration'] ?? '',
                              );
                            },
                          )
                        : const Center(
                            child: CircularProgressIndicator(),
                          ),
                  ),
                  const SizedBox(height: 28),

                  // Promotion Banner Cards (Đồng bộ danh sách khuyến mãi của Web)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Khuyến mãi hot 🔥',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () => context.go('/promotions'),
                        child: const Text('Xem tất cả'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: _promotions.isNotEmpty
                        ? ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _promotions.length,
                            itemBuilder: (context, index) {
                              final promo = _promotions[index];
                              return _buildPromoCard(
                                context,
                                title: promo['title'] ?? 'Khuyến mãi hot',
                                code: promo['code'] ?? 'BUSGO',
                                desc: promo['description'] ?? 'Ưu đãi đặt vé hấp dẫn nhất',
                                color1: index % 2 == 0 ? const Color(0xffff9800) : const Color(0xff2196f3),
                                color2: index % 2 == 0 ? const Color(0xffe65100) : const Color(0xff0d47a1),
                              );
                            },
                          )
                        : ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _buildPromoCard(
                                context,
                                title: 'Flash Sale 30%',
                                code: 'BUSGO30',
                                desc: 'Giảm tối đa 50k toàn tuyến',
                                color1: const Color(0xffff9800),
                                color2: const Color(0xffe65100),
                              ),
                              _buildPromoCard(
                                context,
                                title: 'Tuyến Sapa Cực Hot',
                                code: 'SAPAFREE',
                                desc: 'Đồng giá cabin đơn 199k',
                                color1: const Color(0xff2196f3),
                                color2: const Color(0xff0d47a1),
                              ),
                              _buildPromoCard(
                                context,
                                title: 'Bạn Mới Trải Nghiệm',
                                code: 'HELLOBUS',
                                desc: 'Tặng ngay 50k chuyến đầu',
                                color1: const Color(0xffe91e63),
                                color2: const Color(0xff880e4f),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 28),

                  // Operator Partners Section (Đồng bộ danh sách nhà xe của Web)
                  Text(
                    'Nhà xe uy tín đối tác',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_companies.isNotEmpty)
                    ..._companies.map((company) {
                      final companyName = company['name'] ?? company['company_name'] ?? 'Nhà xe đối tác';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildOperatorListItem(
                          context,
                          name: companyName,
                          rating: '4.8',
                          reviews: '320 đánh giá',
                          features: 'Wifi • Tivi • Sạc • Nước uống',
                          onTap: () => _navigateToCompanyTrips(
                            companyName,
                            companyId: (company['id'] ?? company['_id'] ?? '').toString(),
                          ),
                        ),
                      );
                    })
                  else ...[
                    _buildOperatorListItem(
                      context,
                      name: 'Futa Bus Lines (Phương Trang)',
                      rating: '4.9',
                      reviews: '1,250 đánh giá',
                      features: 'Wifi • Tivi • Sạc • Nước uống',
                      onTap: () => _navigateToCompanyTrips('Futa'),
                    ),
                    const SizedBox(height: 12),
                    _buildOperatorListItem(
                      context,
                      name: 'Đất Cảng Bus',
                      rating: '4.7',
                      reviews: '840 đánh giá',
                      features: 'Ghế da • Điều hòa • Nước uống',
                      onTap: () => _navigateToCompanyTrips('Đất Cảng'),
                    ),
                    const SizedBox(height: 12),
                    _buildOperatorListItem(
                      context,
                      name: 'Sapa Express',
                      rating: '4.8',
                      reviews: '410 đánh giá',
                      features: 'Cabin Royal VIP • Cổng sạc Type-C',
                      onTap: () => _navigateToCompanyTrips('Sapa Express'),
                    ),
                  ],
                  const SizedBox(height: 28),

                  // Core Value Features Section (Đồng bộ các tính năng đặc sắc của Web)
                  Text(
                    'Tại sao chọn BusGo?',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCoreValueCard(
                          context,
                          icon: Icons.flash_on,
                          title: 'Đặt cực nhanh',
                          desc: 'Chỉ 3 bước đặt vé thành công',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCoreValueCard(
                          context,
                          icon: Icons.verified_user_outlined,
                          title: 'Thanh toán Stripe',
                          desc: 'Bảo mật chuẩn quốc tế PCI-DSS',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCoreValueCard(
                          context,
                          icon: Icons.support_agent_outlined,
                          title: 'Hỗ trợ 24/7',
                          desc: 'Tổng đài viên xử lý vé lập tức',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCoreValueCard(
                          context,
                          icon: Icons.local_offer_outlined,
                          title: 'Cam kết giá tốt',
                          desc: 'Luôn đúng giá, nhiều ưu đãi',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 1:
              context.go('/my-tickets');
              break;
            case 2:
              context.go('/promotions');
              break;
            case 3:
              context.go('/profile');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Tìm kiếm'),
          BottomNavigationBarItem(icon: Icon(Icons.confirmation_number_outlined), label: 'Vé của tôi'),
          BottomNavigationBarItem(icon: Icon(Icons.local_offer_outlined), label: 'Ưu đãi'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Tài khoản'),
        ],
      ),
    );
  }

  Widget _buildPopularRouteCard(
    BuildContext context, {
    required String title,
    required String from,
    required String to,
    required String image,
    required String price,
    required String duration,
  }) {
    return GestureDetector(
      onTap: () {
        _departureController.text = from;
        _destinationController.text = to;
        
        final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
        bookingProvider.clearCompanyFilter();
        bookingProvider.searchTrips(
          from: from,
          to: to,
          date: _dateController.text.trim(),
        );
        context.push('/search-results');
      },
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background Image
              Image.network(
                image,
                width: 170,
                height: 210,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.green.shade50,
                    child: const Icon(Icons.image_not_supported, color: Colors.green),
                  );
                },
              ),
              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.85),
                      Colors.black.withOpacity(0.2),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
              // Text Content
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, color: Colors.white70, size: 12),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            duration,
                            style: const TextStyle(color: Colors.white70, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.sell_outlined, color: Colors.yellow.shade400, size: 12),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            price,
                            style: TextStyle(
                              color: Colors.yellow.shade400,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

  Widget _buildPromoCard(
    BuildContext context, {
    required String title,
    required String code,
    required String desc,
    required Color color1,
    required Color color2,
  }) {
    return Container(
      width: 250,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color1, color2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color2.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Semi-circle cutout patterns on left/right for ticket style
          Positioned(
            left: -8,
            top: 42,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: -8,
            top: 42,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: Text(
                        code,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                // Dashed separator line
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  height: 1,
                  child: Row(
                    children: List.generate(
                      14,
                      (index) => Expanded(
                        child: Container(
                          color: index % 2 == 0 ? Colors.transparent : Colors.white30,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorListItem(
    BuildContext context, {
    required String name,
    required String rating,
    required String reviews,
    required String features,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade50,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 6,
                  color: const Color(0xff006e1c),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xff006e1c).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.directions_bus_filled_outlined,
                            color: Color(0xff006e1c),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xff006e1c).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Độc quyền',
                                      style: TextStyle(
                                        color: Color(0xff006e1c),
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    rating,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '($reviews)',
                                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                features,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoreValueCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.green, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// Bảng tìm kiếm Tỉnh/Thành phố thông minh (Location Search Bottom Sheet)
class _LocationSearchSheet extends StatefulWidget {
  final String title;
  final ValueChanged<String> onSelected;

  const _LocationSearchSheet({
    required this.title,
    required this.onSelected,
  });

  @override
  State<_LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<_LocationSearchSheet> {
  String _searchQuery = '';
  late List<String> _filteredProvinces;

  @override
  void initState() {
    super.initState();
    _filteredProvinces = _vietnamProvinces;
  }

  void _filterProvinces(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredProvinces = _vietnamProvinces;
      } else {
        _filteredProvinces = _vietnamProvinces
            .where((province) => _removeDiacritics(province.toLowerCase())
                .contains(_removeDiacritics(query.toLowerCase())))
            .toList();
      }
    });
  }

  // Hàm chuyển đổi tiếng Việt không dấu (giống removeAccents trên Web)
  String _removeDiacritics(String str) {
    const withDiacritics = 'àáảãạâầấẩẫậăằắẳẵặèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđđ';
    const withoutDiacritics = 'aaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydd';
    
    String result = str;
    for (int i = 0; i < withDiacritics.length; i++) {
      result = result.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Drag Indicator handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              
              // Header Title
              Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              
              // Search Input Box
              TextField(
                onChanged: _filterProvinces,
                decoration: InputDecoration(
                  hintText: 'Nhập tên tỉnh/thành phố để tìm kiếm...',
                  prefixIcon: const Icon(Icons.search, color: Colors.green),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _filterProvinces('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Provinces List View
              Expanded(
                child: _filteredProvinces.isNotEmpty
                    ? ListView.builder(
                        controller: scrollController,
                        itemCount: _filteredProvinces.length,
                        itemBuilder: (context, index) {
                          final province = _filteredProvinces[index];
                          return ListTile(
                            leading: const Icon(Icons.location_on_outlined, color: Colors.grey),
                            title: Text(
                              province,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () {
                              widget.onSelected(province);
                              Navigator.pop(context);
                            },
                          );
                        },
                      )
                    : const Center(
                        child: Text(
                          'Không tìm thấy tỉnh/thành phố nào.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
