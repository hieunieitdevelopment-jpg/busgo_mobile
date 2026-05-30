import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:busgo_mobile/core/api/rating_service.dart';
import 'package:busgo_mobile/features/booking/presentation/providers/booking_provider.dart';
import 'package:busgo_mobile/features/rating/presentation/widgets/company_reviews_modal.dart';

/// Trang Kết quả tìm kiếm chuyến xe — phong cách đồng bộ với Boarding Pass / My Tickets:
/// - AppBar gradient #006e1c → #4caf50
/// - Header tóm tắt hành trình + số chuyến
/// - Filter chips: gradient khi active, có icon, shadow nhẹ
/// - Card chuyến xe redesign: timeline có icon bus, giá tiền tone xanh, button gradient
class SearchResultsPage extends StatefulWidget {
  const SearchResultsPage({super.key});

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  String _selectedSort = 'Giờ chạy sớm';

  final RatingService _ratingService = RatingService();
  Map<int, CompanyRatingSummary> _ratings = {};

  static const Color _primary = Color(0xff006e1c);
  static const Color _primaryLight = Color(0xff4caf50);
  static const LinearGradient _primaryGradient = LinearGradient(
    colors: [_primary, _primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  double _parsePrice(dynamic trip) {
    if (trip == null) return 300000.0;

    dynamic rawPrice = trip['price'] ??
        trip['ticketPrice'] ??
        trip['ticket_price'] ??
        trip['fare'] ??
        trip['pricePerSeat'] ??
        trip['price_per_seat'];

    if (rawPrice == null && trip['tripSchedule'] is Map) {
      final sMap = trip['tripSchedule'] as Map;
      rawPrice = sMap['price'] ??
          sMap['ticketPrice'] ??
          sMap['ticket_price'] ??
          sMap['fare'] ??
          sMap['pricePerSeat'] ??
          sMap['price_per_seat'];
    }

    if (rawPrice == null) return 300000.0;
    if (rawPrice is num) return rawPrice.toDouble();
    final String cleanPriceStr =
        rawPrice.toString().replaceAll(RegExp(r'[^\d]'), '');
    return double.tryParse(cleanPriceStr) ?? 300000.0;
  }

  String _formatCurrency(double amount) {
    final String str = amount.toInt().toString();
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return '${str.replaceAllMapped(reg, (Match m) => '${m[1]}.')}đ';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bookingProvider =
          Provider.of<BookingProvider>(context, listen: false);
      bookingProvider.addListener(_onBookingChanged);
      if (bookingProvider.schedules.isEmpty && !bookingProvider.isLoading) {
        final now = DateTime.now();
        final day = now.day.toString().padLeft(2, '0');
        final month = now.month.toString().padLeft(2, '0');
        final year = now.year;
        final fallbackDate = '$day/$month/$year';

        if (bookingProvider.companyFilter.isNotEmpty) {
          bookingProvider.searchTrips(
            from: '',
            to: '',
            date: bookingProvider.currentDate.isEmpty
                ? fallbackDate
                : bookingProvider.currentDate,
          );
        } else {
          bookingProvider.searchTrips(
            from: bookingProvider.currentFrom.isEmpty
                ? 'Hà Nội'
                : bookingProvider.currentFrom,
            to: bookingProvider.currentTo.isEmpty
                ? 'Sa Pa'
                : bookingProvider.currentTo,
            date: bookingProvider.currentDate.isEmpty
                ? fallbackDate
                : bookingProvider.currentDate,
          );
        }
      } else if (bookingProvider.schedules.isNotEmpty) {
        _fetchRatingsForSchedules(bookingProvider.schedules);
      }
    });
  }

  @override
  void dispose() {
    Provider.of<BookingProvider>(context, listen: false)
        .removeListener(_onBookingChanged);
    super.dispose();
  }

  void _onBookingChanged() {
    final bp = Provider.of<BookingProvider>(context, listen: false);
    if (bp.schedules.isNotEmpty) {
      _fetchRatingsForSchedules(bp.schedules);
    }
  }

  /// Lấy uniqueCompanyIds từ list trip và fetch song song (tránh N+1).
  Future<void> _fetchRatingsForSchedules(List<dynamic> schedules) async {
    final ids = <int>{};
    for (final trip in schedules) {
      final compObj = trip['company'] ??
          (trip['tripSchedule'] is Map
              ? trip['tripSchedule']['company']
              : null);
      final raw = trip['companyId'] ??
          trip['company_id'] ??
          (trip['tripSchedule'] is Map
              ? trip['tripSchedule']['companyId'] ??
                  trip['tripSchedule']['company_id']
              : null) ??
          (compObj is Map ? compObj['id'] ?? compObj['_id'] : null);
      final cid = int.tryParse(raw?.toString() ?? '');
      if (cid != null && cid > 0) ids.add(cid);
    }
    if (ids.isEmpty) return;
    final pending = ids.where((id) => !_ratings.containsKey(id)).toList();
    if (pending.isEmpty) return;
    final summaries = await _ratingService.getSummariesParallel(
      companyIds: pending,
      scanLimit: 100,
    );
    if (!mounted) return;
    setState(() {
      _ratings = {..._ratings, ...summaries};
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);

    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year;
    final fallbackDate = '$day/$month/$year';

    final bool isCompanyMode = bookingProvider.companyFilter.isNotEmpty;
    final String fromName = bookingProvider.currentFrom.isEmpty
        ? 'Hà Nội'
        : bookingProvider.currentFrom;
    final String toName = bookingProvider.currentTo.isEmpty
        ? 'Sa Pa'
        : bookingProvider.currentTo;
    final String searchDate = bookingProvider.currentDate.isEmpty
        ? fallbackDate
        : bookingProvider.currentDate;

    // Lọc theo nhà xe
    final rawSchedules = bookingProvider.schedules;
    final List<dynamic> schedules = bookingProvider.companyFilter.isEmpty
        ? List.from(rawSchedules)
        : List.from(rawSchedules.where((trip) {
            final compObj = trip['company'] ??
                (trip['tripSchedule'] is Map
                    ? trip['tripSchedule']['company']
                    : null);
            final String companyId = (trip['companyId'] ??
                    trip['company_id'] ??
                    (trip['tripSchedule'] is Map
                        ? trip['tripSchedule']['companyId'] ??
                            trip['tripSchedule']['company_id']
                        : null) ??
                    (compObj is Map ? compObj['id'] ?? compObj['_id'] : ''))
                .toString();
            final String name = (trip['companyName'] ??
                    trip['company_name'] ??
                    (trip['tripSchedule'] is Map
                        ? trip['tripSchedule']['companyName'] ??
                            trip['tripSchedule']['company_name']
                        : null) ??
                    (compObj is Map
                        ? compObj['name'] ??
                            compObj['companyName'] ??
                            compObj['company_name']
                        : ''))
                .toString()
                .toLowerCase();

            if (bookingProvider.companyIdFilter.isNotEmpty &&
                companyId.isNotEmpty) {
              return companyId == bookingProvider.companyIdFilter;
            }
            return name.contains(bookingProvider.companyFilter.toLowerCase());
          }));

    // Sắp xếp dữ liệu chuyến xe theo bộ lọc đã chọn
    if (_selectedSort == 'Giá rẻ nhất') {
      schedules.sort((a, b) => _parsePrice(a).compareTo(_parsePrice(b)));
    } else if (_selectedSort == 'Giờ chạy sớm') {
      schedules.sort((a, b) {
        final String ta = (a['departureTime'] ??
                a['departure_time'] ??
                '06:00:00')
            .toString();
        final String tb = (b['departureTime'] ??
                b['departure_time'] ??
                '06:00:00')
            .toString();
        return ta.compareTo(tb);
      });
    } else if (_selectedSort == 'Đánh giá cao') {
      schedules.sort((a, b) {
        final double ra =
            double.tryParse((a['rating'] ?? a['avgRating'] ?? '4.5').toString()) ??
                4.5;
        final double rb =
            double.tryParse((b['rating'] ?? b['avgRating'] ?? '4.5').toString()) ??
                4.5;
        return rb.compareTo(ra);
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xfff5f7f5),
      appBar: _buildAppBar(context, isCompanyMode, fromName, toName,
          bookingProvider.companyFilter, searchDate),
      body: Column(
        children: [
          _buildJourneyHeader(
            isCompanyMode: isCompanyMode,
            companyName: bookingProvider.companyFilter,
            from: fromName,
            to: toName,
            date: searchDate,
            count: schedules.length,
            isLoading: bookingProvider.isLoading,
          ),
          _buildSortBar(),
          Expanded(child: _buildBody(bookingProvider, schedules)),
        ],
      ),
    );
  }

  // ---------- AppBar ----------
  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    bool isCompanyMode,
    String from,
    String to,
    String companyName,
    String date,
  ) {
    return AppBar(
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: _primaryGradient),
      ),
      elevation: 0,
      centerTitle: true,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        onPressed: () => context.pop(),
      ),
      title: Text(
        isCompanyMode ? 'Nhà xe: $companyName' : 'Tìm chuyến xe',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ---------- Journey Header ----------
  Widget _buildJourneyHeader({
    required bool isCompanyMode,
    required String companyName,
    required String from,
    required String to,
    required String date,
    required int count,
    required bool isLoading,
  }) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: _primaryGradient),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          // Card hành trình
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: isCompanyMode
                ? Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.business_outlined,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'NHÀ XE',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              companyName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildDateChip(date),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ĐIỂM ĐI',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              from,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'ĐIỂM ĐẾN',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              to,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
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
          ),
          if (!isCompanyMode) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _buildDateChip(date),
                const SizedBox(width: 8),
                _buildCountChip(count, isLoading),
              ],
            ),
          ] else ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _buildCountChip(count, isLoading),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateChip(String date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month_outlined,
              color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(
            date,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountChip(int count, bool isLoading) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.directions_bus_filled_outlined,
              color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(
            isLoading ? 'Đang tìm...' : '$count chuyến',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Sort Bar ----------
  Widget _buildSortBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(child: _buildSortTab('Giờ chạy sớm', Icons.access_time_rounded)),
          const SizedBox(width: 8),
          Expanded(child: _buildSortTab('Giá rẻ nhất', Icons.local_offer_rounded)),
          const SizedBox(width: 8),
          Expanded(child: _buildSortTab('Đánh giá cao', Icons.star_rounded)),
        ],
      ),
    );
  }

  Widget _buildSortTab(String value, IconData icon) {
    final bool isSelected = _selectedSort == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedSort = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          gradient: isSelected ? _primaryGradient : null,
          color: isSelected ? null : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(22),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _primary.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Body ----------
  Widget _buildBody(BookingProvider bookingProvider, List<dynamic> schedules) {
    if (bookingProvider.isLoading) {
      return _buildLoadingSkeleton();
    }
    if (bookingProvider.errorMessage != null) {
      return _buildErrorState(bookingProvider.errorMessage!);
    }
    if (schedules.isEmpty) {
      return _buildEmptyState(bookingProvider.companyFilter);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: schedules.length,
      itemBuilder: (context, index) {
        final trip = schedules[index];

        final compObj = trip['company'] ??
            (trip['tripSchedule'] is Map
                ? trip['tripSchedule']['company']
                : null);
        final companyName = trip['name'] ??
            trip['companyName'] ??
            trip['company_name'] ??
            (trip['tripSchedule'] is Map
                ? trip['tripSchedule']['companyName'] ??
                    trip['tripSchedule']['company_name']
                : null) ??
            (compObj is Map
                ? compObj['name'] ??
                    compObj['companyName'] ??
                    compObj['company_name']
                : null) ??
            'Chuyến xe';
        final logoUrl = trip['logoUrl'] ??
            trip['logo_url'] ??
            (trip['tripSchedule'] is Map
                ? trip['tripSchedule']['logoUrl'] ??
                    trip['tripSchedule']['logo_url']
                : null) ??
            (compObj is Map
                ? compObj['logo'] ?? compObj['logoUrl'] ?? compObj['logo_url']
                : null);
        final hotline = trip['hotline'] ??
            trip['phone'] ??
            (trip['tripSchedule'] is Map
                ? trip['tripSchedule']['hotline'] ??
                    trip['tripSchedule']['phone']
                : null) ??
            (compObj is Map
                ? compObj['phone'] ??
                    compObj['phone_number'] ??
                    compObj['hotline']
                : '') ??
            '0388985684';
        final distanceKm = trip['distanceKm'] ?? trip['distance_km'];

        final fromLoc =
            trip['fromLocation'] ?? trip['from_location'] ?? 'Hà Nội';
        final toLoc = trip['toLocation'] ?? trip['to_location'] ?? 'Sa Pa';

        final rawDepTime =
            (trip['departureTime'] ?? trip['departure_time'] ?? '06:00:00')
                .toString();
        final String departureTime = rawDepTime.length >= 5
            ? rawDepTime.substring(0, 5)
            : rawDepTime;

        final int durationMinutes = int.tryParse(trip['durationMinutes']
                    ?.toString() ??
                trip['duration_minutes']?.toString() ??
                '') ??
            390;
        final String duration =
            '${durationMinutes ~/ 60}h ${durationMinutes % 60}m';

        String arrivalTime = '12:30';
        try {
          final parts = rawDepTime.split(':');
          if (parts.length >= 2) {
            final int h = int.parse(parts[0]);
            final int m = int.parse(parts[1]);
            final int totalMin = h * 60 + m + durationMinutes;
            final int arrH = (totalMin ~/ 60) % 24;
            final int arrM = totalMin % 60;
            arrivalTime =
                '${arrH.toString().padLeft(2, '0')}:${arrM.toString().padLeft(2, '0')}';
          }
        } catch (_) {}

        final vehicleObj = trip['vehicle'] ??
            (trip['tripSchedule'] is Map
                ? trip['tripSchedule']['vehicle']
                : null);
        final vehicleName = (trip['vehicleName'] ??
                (trip['tripSchedule'] is Map
                    ? trip['tripSchedule']['vehicleName']
                    : null) ??
                (vehicleObj is Map
                    ? vehicleObj['name'] ?? vehicleObj['type']
                    : null) ??
                'Xe giường nằm')
            .toString();

        final double price = _parsePrice(trip);

        // Lấy companyId để tra cứu rating thật từ _ratings
        final compObj2 = trip['company'] ??
            (trip['tripSchedule'] is Map
                ? trip['tripSchedule']['company']
                : null);
        final int? cid = int.tryParse((trip['companyId'] ??
                trip['company_id'] ??
                (trip['tripSchedule'] is Map
                    ? trip['tripSchedule']['companyId'] ??
                        trip['tripSchedule']['company_id']
                    : null) ??
                (compObj2 is Map ? compObj2['id'] ?? compObj2['_id'] : null) ??
                '0')
            .toString());
        final summary = cid != null ? _ratings[cid] : null;
        final double rating = summary != null && summary.totalReviews > 0
            ? summary.avgRating
            : 5.0; // fallback theo spec
        final int totalReviews = summary?.totalReviews ?? 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
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
            totalReviews: totalReviews,
            onTapRating: cid == null
                ? null
                : () => showCompanyReviewsModal(
                      context,
                      companyId: cid,
                      companyName: companyName,
                    ),
          ),
        );
      },
    );
  }

  // ---------- Operator Card ----------
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
    int totalReviews = 0,
    VoidCallback? onTapRating,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ----- Header: logo + name + rating + distance -----
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.grey.shade200, width: 1),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: (logoUrl != null && logoUrl.isNotEmpty)
                            ? Image.network(
                                logoUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, s) => Container(
                                  decoration: BoxDecoration(
                                    gradient: _primaryGradient,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: const Icon(Icons.directions_bus_filled,
                                      color: Colors.white, size: 22),
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  gradient: _primaryGradient,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: const Icon(Icons.directions_bus_filled,
                                    color: Colors.white, size: 22),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            operatorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Color(0xFF1E1E1E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              // Vehicle type tag
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _primary.withOpacity(0.12),
                                      _primaryLight.withOpacity(0.12),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: _primary.withOpacity(0.2),
                                      width: 0.8),
                                ),
                                child: Text(
                                  vehicleType,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: _primary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              if (hotline.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.phone,
                                    size: 11, color: Colors.grey.shade500),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    hotline,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Rating badge — tap để xem chi tiết đánh giá
                    GestureDetector(
                      onTap: onTapRating,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.shade300,
                              Colors.amber.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 12, color: Colors.white),
                            const SizedBox(width: 2),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            if (totalReviews > 0) ...[
                              const SizedBox(width: 3),
                              Text(
                                '($totalReviews)',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                // Divider mảnh
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.grey.shade100,
                        Colors.grey.shade200,
                        Colors.grey.shade100,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ----- Timeline đi/đến -----
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            departureTime,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: _primary,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            fromStation,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Timeline với icon bus
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                duration,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: _primaryGradient,
                                  ),
                                ),
                                Expanded(
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        height: 1.5,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              _primary.withOpacity(0.3),
                                              _primaryLight.withOpacity(0.3),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: _primary.withOpacity(0.3),
                                              width: 1),
                                        ),
                                        child: const Icon(
                                          Icons.directions_bus_filled,
                                          size: 11,
                                          color: _primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(
                                        color: _primary, width: 1.8),
                                  ),
                                ),
                              ],
                            ),
                            if (distanceKm != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                distanceKm,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            arrivalTime,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: _primary,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            toStation,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w700,
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

                const SizedBox(height: 14),
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.grey.shade100,
                        Colors.grey.shade200,
                        Colors.grey.shade100,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ----- Footer: price + button -----
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chỉ từ',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatCurrency(price),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: _primary,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 11),
                        decoration: BoxDecoration(
                          gradient: _primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Chọn vé',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Loading skeleton ----------
  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: 4,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _skBox(44, 44, radius: 10),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _skBox(double.infinity, 12),
                          const SizedBox(height: 8),
                          _skBox(120, 10),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _skBox(70, 18),
                    _skBox(80, 12),
                    _skBox(70, 18),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _skBox(80, 22),
                    _skBox(110, 38, radius: 12),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _skBox(double w, double h, {double radius = 6}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  // ---------- Error / empty ----------
  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline,
                  size: 44, color: Colors.red.shade400),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String companyFilter) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _primary.withOpacity(0.08),
                    _primaryLight.withOpacity(0.08),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                    color: _primary.withOpacity(0.15), width: 2),
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 56,
                color: _primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Không tìm thấy chuyến xe',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              companyFilter.isNotEmpty
                  ? 'Nhà xe $companyFilter chưa có chuyến xe khả dụng. Hãy thử chọn ngày khác hoặc nhà xe khác.'
                  : 'Không có chuyến xe nào khả dụng cho hành trình này. Hãy thử thay đổi ngày hoặc địa điểm.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('QUAY LẠI TÌM CHUYẾN'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: _primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
