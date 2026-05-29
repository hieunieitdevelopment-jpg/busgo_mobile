import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:busgo_mobile/features/booking/presentation/providers/booking_provider.dart';

class SearchResultsPage extends StatefulWidget {
  const SearchResultsPage({super.key});

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  String _selectedSort = 'Giờ chạy sớm';

  double _parsePrice(dynamic trip) {
    if (trip == null) return 250000.0;
    final dynamic rawPrice = trip['price'] ?? 
                             trip['ticketPrice'] ?? 
                             trip['ticket_price'] ?? 
                             trip['fare'] ??
                             (trip['tripSchedule'] is Map ? trip['tripSchedule']['price'] : null);
    if (rawPrice == null) return 250000.0;
    final String cleanPriceStr = rawPrice.toString().replaceAll(RegExp(r'[^\d]'), '');
    return double.tryParse(cleanPriceStr) ?? 250000.0;
  }

  String _formatCurrency(double amount) {
    final String str = amount.toInt().toString();
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return '${str.replaceAllMapped(reg, (Match m) => '${m[1]}.')}đ';
  }

  @override
  void initState() {
    super.initState();
    // Tự động tìm kiếm nếu chưa tải dữ liệu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
      if (bookingProvider.schedules.isEmpty && !bookingProvider.isLoading) {
        if (bookingProvider.companyFilter.isNotEmpty) {
          // Nếu đang lọc theo nhà xe đối tác, giữ nguyên tham số tìm kiếm rỗng của điểm đi/đến để load tất cả các chuyến chạy hôm đó
          final now = DateTime.now();
          final day = now.day.toString().padLeft(2, '0');
          final month = now.month.toString().padLeft(2, '0');
          final year = now.year;
          final fallbackDate = '$day/$month/$year';
          bookingProvider.searchTrips(
            from: '',
            to: '',
            date: bookingProvider.currentDate.isEmpty ? fallbackDate : bookingProvider.currentDate,
          );
        } else {
          final now = DateTime.now();
          final day = now.day.toString().padLeft(2, '0');
          final month = now.month.toString().padLeft(2, '0');
          final year = now.year;
          final fallbackDate = '$day/$month/$year';
          
          bookingProvider.searchTrips(
            from: bookingProvider.currentFrom.isEmpty ? 'Hà Nội' : bookingProvider.currentFrom,
            to: bookingProvider.currentTo.isEmpty ? 'Sa Pa' : bookingProvider.currentTo,
            date: bookingProvider.currentDate.isEmpty ? fallbackDate : bookingProvider.currentDate,
          );
        }
      }
    });
  }

  Widget _buildSortTab(String value, IconData icon) {
    final bool isSelected = _selectedSort == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSort = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.green : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.green : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);

    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year;
    final fallbackDate = '$day/$month/$year';

    final String fromTo = bookingProvider.companyFilter.isNotEmpty
        ? 'Nhà xe: ${bookingProvider.companyFilter}'
        : '${bookingProvider.currentFrom.isEmpty ? 'Hà Nội' : bookingProvider.currentFrom} ➔ ${bookingProvider.currentTo.isEmpty ? 'Sa Pa' : bookingProvider.currentTo}';
    final String searchDate = bookingProvider.currentDate.isEmpty ? fallbackDate : bookingProvider.currentDate;

    // Lọc theo nhà xe
    final rawSchedules = bookingProvider.schedules;
    final List<dynamic> schedules = bookingProvider.companyFilter.isEmpty
        ? List.from(rawSchedules)
        : List.from(rawSchedules.where((trip) {
            final compObj = trip['company'] ?? (trip['tripSchedule'] is Map ? trip['tripSchedule']['company'] : null);
            final String companyId = (trip['companyId'] ?? 
                                      trip['company_id'] ?? 
                                      (trip['tripSchedule'] is Map ? trip['tripSchedule']['companyId'] ?? trip['tripSchedule']['company_id'] : null) ?? 
                                      (compObj is Map ? compObj['id'] ?? compObj['_id'] : '')).toString();
            final String name = (trip['companyName'] ?? 
                                 trip['company_name'] ?? 
                                 (trip['tripSchedule'] is Map ? trip['tripSchedule']['companyName'] ?? trip['tripSchedule']['company_name'] : null) ?? 
                                 (compObj is Map ? compObj['name'] ?? compObj['companyName'] ?? compObj['company_name'] : '')).toString().toLowerCase();
            
            if (bookingProvider.companyIdFilter.isNotEmpty && companyId.isNotEmpty) {
              return companyId == bookingProvider.companyIdFilter;
            }
            return name.contains(bookingProvider.companyFilter.toLowerCase());
          }));

    // Sắp xếp dữ liệu chuyến xe theo bộ lọc đã chọn
    if (_selectedSort == 'Giá rẻ nhất') {
      schedules.sort((a, b) {
        final double pa = _parsePrice(a);
        final double pb = _parsePrice(b);
        return pa.compareTo(pb);
      });
    } else if (_selectedSort == 'Giờ chạy sớm') {
      schedules.sort((a, b) {
        final String ta = (a['departureTime'] ?? a['departure_time'] ?? '06:00:00').toString();
        final String tb = (b['departureTime'] ?? b['departure_time'] ?? '06:00:00').toString();
        return ta.compareTo(tb);
      });
    } else if (_selectedSort == 'Đánh giá cao') {
      schedules.sort((a, b) {
        final double ra = double.tryParse((a['rating'] ?? a['avgRating'] ?? '4.5').toString()) ?? 4.5;
        final double rb = double.tryParse((b['rating'] ?? b['avgRating'] ?? '4.5').toString()) ?? 4.5;
        return rb.compareTo(ra); // Giảm dần
      });
    }

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xff006e1c), Color(0xff004d13)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 2,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: [
            Text(
              fromTo,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_month_outlined, size: 12, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  searchDate,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Sắp xếp nhanh (Sort Bar)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSortTab('Giờ chạy sớm', Icons.access_time),
                _buildSortTab('Giá rẻ nhất', Icons.sell_outlined),
                _buildSortTab('Đánh giá cao', Icons.star_outline),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 8),

          // Lưới kết quả chuyến xe
          Expanded(
            child: bookingProvider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  )
                : bookingProvider.errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.info_outline, size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(
                                bookingProvider.errorMessage!,
                                style: const TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : schedules.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                bookingProvider.companyFilter.isNotEmpty
                                    ? 'Nhà xe ${bookingProvider.companyFilter} chưa có chuyến xe khả dụng hôm nay.'
                                    : 'Không có chuyến xe nào khả dụng cho hành trình này.',
                                style: const TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: schedules.length,
                            itemBuilder: (context, index) {
                              final trip = schedules[index];
                              
                              final compObj = trip['company'] ?? (trip['tripSchedule'] is Map ? trip['tripSchedule']['company'] : null);
                              final companyName = trip['name'] ?? 
                                                  trip['companyName'] ?? 
                                                  trip['company_name'] ?? 
                                                  (trip['tripSchedule'] is Map ? trip['tripSchedule']['companyName'] ?? trip['tripSchedule']['company_name'] : null) ?? 
                                                  (compObj is Map ? compObj['name'] ?? compObj['companyName'] ?? compObj['company_name'] : null) ?? 
                                                  'Chuyến xe';
                              final logoUrl = trip['logoUrl'] ?? 
                                              trip['logo_url'] ?? 
                                              (trip['tripSchedule'] is Map ? trip['tripSchedule']['logoUrl'] ?? trip['tripSchedule']['logo_url'] : null) ?? 
                                              (compObj is Map ? compObj['logo'] ?? compObj['logoUrl'] ?? compObj['logo_url'] : null);
                              final hotline = trip['hotline'] ?? 
                                              trip['phone'] ?? 
                                              (trip['tripSchedule'] is Map ? trip['tripSchedule']['hotline'] ?? trip['tripSchedule']['phone'] : null) ?? 
                                              (compObj is Map ? compObj['phone'] ?? compObj['phone_number'] ?? compObj['hotline'] : '') ?? 
                                              '0388985684';
                              final distanceKm = trip['distanceKm'] ?? trip['distance_km'];
                              
                              // Lấy địa điểm thực tế từ API
                              final fromLoc = trip['fromLocation'] ?? trip['from_location'] ?? 'Hà Nội';
                              final toLoc = trip['toLocation'] ?? trip['to_location'] ?? 'Sa Pa';

                              // Lấy giờ đi thực tế
                              final rawDepTime = (trip['departureTime'] ?? trip['departure_time'] ?? '06:00:00').toString();
                              final String departureTime = rawDepTime.length >= 5 ? rawDepTime.substring(0, 5) : rawDepTime;
                              
                              // Lấy khoảng thời gian di chuyển thực tế (durationMinutes)
                              final int durationMinutes = int.tryParse(trip['durationMinutes']?.toString() ?? trip['duration_minutes']?.toString() ?? '') ?? 390; 
                              final String duration = '${durationMinutes ~/ 60}h ${durationMinutes % 60}m';

                              // Tính toán giờ đến thực tế (24h)
                              String arrivalTime = '12:30';
                              try {
                                final parts = rawDepTime.split(':');
                                if (parts.length >= 2) {
                                  final int h = int.parse(parts[0]);
                                  final int m = int.parse(parts[1]);
                                  final int totalMin = h * 60 + m + durationMinutes;
                                  final int arrH = (totalMin ~/ 60) % 24;
                                  final int arrM = totalMin % 60;
                                  arrivalTime = '${arrH.toString().padLeft(2, '0')}:${arrM.toString().padLeft(2, '0')}';
                                }
                              } catch (_) {}

                              // Trích xuất loại xe
                              final vehicleObj = trip['vehicle'] ?? (trip['tripSchedule'] is Map ? trip['tripSchedule']['vehicle'] : null);
                              final vehicleName = (trip['vehicleName'] ?? 
                                                   (trip['tripSchedule'] is Map ? trip['tripSchedule']['vehicleName'] : null) ?? 
                                                   (vehicleObj is Map ? vehicleObj['name'] ?? vehicleObj['type'] : null) ?? 
                                                   'Xe giường nằm').toString();

                              // Trích xuất giá vé
                              final double price = _parsePrice(trip);

                              // Trích xuất điểm đánh giá
                              final double rating = double.tryParse((trip['rating'] ?? trip['avgRating'] ?? (trip['tripSchedule'] is Map ? trip['tripSchedule']['avgRating'] : null) ?? '4.5').toString()) ?? 4.5;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: _buildOperatorCard(
                                  context,
                                  onTap: () {
                                    bookingProvider.selectSchedule(trip);
                                    context.push('/seat-selection');
                                  },
                                  operatorName: companyName,
                                  logoUrl: logoUrl,
                                  hotline: hotline,
                                  departureTime: departureTime,
                                  arrivalTime: arrivalTime,
                                  duration: duration,
                                  distanceKm: distanceKm != null ? '$distanceKm KM' : null,
                                  fromStation: fromLoc,
                                  toStation: toLoc,
                                  price: price,
                                  vehicleType: vehicleName,
                                  rating: rating,
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorCard(
    BuildContext context, {
    required VoidCallback onTap,
    required String operatorName,
    required String? logoUrl,
    required String hotline,
    required String departureTime,
    required String arrivalTime,
    required String duration,
    required String? distanceKm,
    required String fromStation,
    required String toStation,
    required double price,
    required String vehicleType,
    required double rating,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.12), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Main Left Info Area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Operator logo, info, distance badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Operator Logo
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: (logoUrl != null && logoUrl.isNotEmpty)
                                ? Image.network(
                                    logoUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.directions_bus, color: Colors.green, size: 20),
                                  )
                                : const Icon(Icons.directions_bus, color: Colors.green, size: 20),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Operator details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      operatorName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF1E1E1E),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star, size: 10, color: Colors.amber),
                                        const SizedBox(width: 2),
                                        Text(
                                          rating.toStringAsFixed(1),
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      vehicleType,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.green.shade800,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (hotline.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Icon(Icons.phone, size: 10, color: Colors.grey.shade600),
                                    const SizedBox(width: 2),
                                    Text(
                                      hotline,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Distance Badge
                        if (distanceKm != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F1F1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              distanceKm,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF555555)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    
                    // Bottom timeline row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Departure time and location
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                departureTime,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: Color(0xFF006E1C),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                fromStation,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        
                        // Timeline Connector Line
                        Expanded(
                          flex: 4,
                          child: Column(
                            children: [
                              Text(
                                duration,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      border: Border.all(color: Colors.grey.shade400, width: 1),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        // Arrival time and location
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                arrivalTime,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: Color(0xFF006E1C),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                toStation,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right Column: Price and Chọn vé button
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(price),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFFFF6D00),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6D00),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6D00).withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Chọn vé',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
