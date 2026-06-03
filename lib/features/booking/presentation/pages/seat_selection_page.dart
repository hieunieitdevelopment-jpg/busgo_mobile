import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:busgo_mobile/core/api/rating_service.dart';
import 'package:busgo_mobile/features/booking/presentation/providers/booking_provider.dart';

/// Trang Chọn chỗ ngồi — phong cách đồng bộ My Tickets / Boarding Pass:
/// - AppBar gradient #006e1c → #4caf50 + rating badge read-only
/// - Card chọn điểm đón/trả với pill "AM/PM" và mũi tên tròn
/// - Legend chip pill có icon, ghế dạng thẻ vuông với gradient khi selected
/// - Footer gradient + button gradient có icon mũi tên
class SeatSelectionPage extends StatefulWidget {
  const SeatSelectionPage({super.key});

  @override
  State<SeatSelectionPage> createState() => _SeatSelectionPageState();
}

class _SeatSelectionPageState extends State<SeatSelectionPage>
    with SingleTickerProviderStateMixin {
  late TabController _deckController;

  CompanyRatingSummary? _ratingSummary;
  bool _ratingFetched = false;

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
    _deckController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bookingProvider =
          Provider.of<BookingProvider>(context, listen: false);
      _fetchRatingForSelectedSchedule(bookingProvider);
      final bool prepareSuccess = await bookingProvider.prepareBooking();
      if (prepareSuccess) {
        await bookingProvider.fetchStops();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(bookingProvider.errorMessage ??
                  'Không thể chuẩn bị chuyến xe. Vui lòng thử lại.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  Future<void> _fetchRatingForSelectedSchedule(BookingProvider bp) async {
    if (_ratingFetched) return;
    _ratingFetched = true;
    final trip = bp.selectedSchedule;
    if (trip is! Map) return;
    final compObj = trip['company'] ??
        (trip['tripSchedule'] is Map ? trip['tripSchedule']['company'] : null);
    final raw = trip['companyId'] ??
        trip['company_id'] ??
        (trip['tripSchedule'] is Map
            ? trip['tripSchedule']['companyId'] ??
                trip['tripSchedule']['company_id']
            : null) ??
        (compObj is Map ? compObj['id'] ?? compObj['_id'] : null);
    final cid = int.tryParse(raw?.toString() ?? '');
    if (cid == null) return;
    final summary = await RatingService()
        .getCompanySummary(companyId: cid, scanLimit: 100);
    if (!mounted) return;
    setState(() => _ratingSummary = summary);
  }

  @override
  void dispose() {
    _deckController.dispose();
    super.dispose();
  }

  String _formatPrice(double v) {
    return '${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}đ';
  }

  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final selectedSchedule = bookingProvider.selectedSchedule;

    if (selectedSchedule == null) {
      return Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: _primaryGradient),
          ),
          foregroundColor: Colors.white,
          title: const Text('Chọn chỗ ngồi',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: const Center(child: Text('Vui lòng chọn chuyến xe trước.')),
      );
    }

    final fromTo =
        '${bookingProvider.currentFrom.isEmpty ? 'Hà Nội' : bookingProvider.currentFrom} ➔ ${bookingProvider.currentTo.isEmpty ? 'Sa Pa' : bookingProvider.currentTo}';

    return Scaffold(
      backgroundColor: const Color(0xfff5f7f5),
      appBar: _buildAppBar(fromTo),
      body: bookingProvider.isLoading || bookingProvider.isLoadingStops
          ? _buildLoadingState()
          : Column(
              children: [
                _buildStationSelectors(context, bookingProvider),
                _buildLegend(),
                Expanded(child: _buildSeatArea(bookingProvider)),
                _buildFooter(context, bookingProvider),
              ],
            ),
    );
  }

  // ---------- AppBar ----------
  PreferredSizeWidget _buildAppBar(String fromTo) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(140),
      child: Container(
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
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Top row: back + title + rating chip
              SizedBox(
                height: 52,
                child: Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.pop(),
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          margin: const EdgeInsets.only(left: 6),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Chọn chỗ ngồi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 13, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            (_ratingSummary != null &&
                                    _ratingSummary!.totalReviews > 0)
                                ? _ratingSummary!.avgRating
                                    .toStringAsFixed(1)
                                : '5.0',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Sub-line: hành trình
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(
                  children: [
                    const Icon(Icons.directions_bus_filled_rounded,
                        size: 14, color: Colors.white70),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        fromTo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // TabBar đặt trên nền cong, sát mép dưới
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: TabBar(
                  controller: _deckController,
                  labelColor: _primary,
                  unselectedLabelColor: Colors.white,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(4),
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 12.5),
                  unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12.5),
                  tabs: [
                    _buildDeckTab(
                        icon: Icons.airline_seat_recline_normal_rounded,
                        label: 'Tầng dưới'),
                    _buildDeckTab(
                        icon: Icons.airline_seat_flat_rounded,
                        label: 'Tầng trên'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeckTab({required IconData icon, required String label}) {
    return Tab(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }

  // ---------- Loading ----------
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_primary),
          ),
          SizedBox(height: 16),
          Text(
            'Đang tải sơ đồ ghế...',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ---------- Station selectors ----------
  Widget _buildStationSelectors(BuildContext context, BookingProvider bp) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          _buildStationRow(
            label: 'Điểm đón',
            iconColor: _primary,
            iconBgGradient: const LinearGradient(
              colors: [_primary, _primaryLight],
            ),
            icon: Icons.adjust_rounded,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<dynamic>(
                value: bp.selectedPickup,
                isExpanded: true,
                isDense: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: _primary),
                hint: Text('Chọn điểm đón',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 13)),
                items: bp.pickups.map<DropdownMenuItem<dynamic>>((stop) {
                  final timeStr = stop['time'] ?? '06:00 AM';
                  final stationObj = stop['station'];
                  final stationName = stop['address'] ??
                      stop['stationName'] ??
                      stop['station_name'] ??
                      (stationObj is Map ? stationObj['name'] : null) ??
                      'Trạm đón';
                  return DropdownMenuItem<dynamic>(
                    value: stop,
                    child: Text(
                      '$timeStr  •  $stationName',
                      style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) bp.selectPickup(val);
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const SizedBox(width: 10),
                _buildVerticalConnector(),
                const SizedBox(width: 24),
                Expanded(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.grey.shade200,
                          Colors.grey.shade300,
                          Colors.grey.shade200,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildStationRow(
            label: 'Điểm trả',
            iconColor: Colors.red.shade600,
            iconBgGradient: LinearGradient(
              colors: [Colors.red.shade400, Colors.red.shade700],
            ),
            icon: Icons.location_on_rounded,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<dynamic>(
                value: bp.selectedDropoff,
                isExpanded: true,
                isDense: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: _primary),
                hint: Text('Chọn điểm trả',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 13)),
                items: bp.dropoffs.map<DropdownMenuItem<dynamic>>((stop) {
                  final timeStr = stop['time'] ?? '12:00 PM';
                  final stationObj = stop['station'];
                  final stationName = stop['address'] ??
                      stop['stationName'] ??
                      stop['station_name'] ??
                      (stationObj is Map ? stationObj['name'] : null) ??
                      'Trạm trả';
                  final dynamic stopPrice = stop['price'] ?? 250000;
                  final priceStr = _formatPrice(
                      double.tryParse(stopPrice.toString()) ?? 250000.0);
                  return DropdownMenuItem<dynamic>(
                    value: stop,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$timeStr  •  $stationName',
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            priceStr,
                            style: const TextStyle(
                                fontSize: 10.5,
                                color: _primary,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) bp.selectDropoff(val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationRow({
    required String label,
    required Color iconColor,
    required Gradient iconBgGradient,
    required IconData icon,
    required Widget child,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: iconBgGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: iconColor.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildVerticalConnector() {
    return Container(
      width: 2,
      height: 12,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  // ---------- Legend ----------
  Widget _buildLegend() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _legendItem(
              label: 'Trống',
              fill: Colors.white,
              border: Colors.grey.shade300,
              iconColor: _primary),
          _legendItem(
              label: 'Đang chọn',
              fill: _primary,
              border: _primary,
              iconColor: Colors.white,
              gradient: _primaryGradient),
          _legendItem(
              label: 'Đã bán',
              fill: Colors.grey.shade200,
              border: Colors.grey.shade300,
              iconColor: Colors.grey.shade400),
        ],
      ),
    );
  }

  Widget _legendItem({
    required String label,
    required Color fill,
    required Color border,
    required Color iconColor,
    Gradient? gradient,
  }) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: gradient == null ? fill : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border, width: 1.2),
          ),
          child: Icon(Icons.event_seat_rounded, size: 13, color: iconColor),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ---------- Seat area ----------
  Widget _buildSeatArea(BookingProvider bp) {
    if (bp.isLoadingSeats) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_primary),
        ),
      );
    }
    if (bp.seats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.event_seat_outlined,
                    size: 44, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 14),
              const Text(
                'Chưa có sơ đồ ghế',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Vui lòng chọn điểm đón/trả khác hoặc liên hệ nhà xe.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12.5,
                    height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      controller: _deckController,
      children: [
        _buildSeatGrid(bp, 'A'),
        _buildSeatGrid(bp, 'B'),
      ],
    );
  }

  Widget _buildSeatGrid(BookingProvider bp, String deckPrefix) {
    final List<dynamic> deckSeats = bp.seats.where((seat) {
      final name = (seat['name'] ??
              seat['seatNumber'] ??
              seat['seat_number'] ??
              '')
          .toString()
          .toUpperCase()
          .trim();
      final dynamic floor = seat['floor'] ??
          seat['floorNumber'] ??
          seat['floor_number'] ??
          seat['deck'];
      if (floor != null) {
        final String fStr = floor.toString().toUpperCase();
        if (deckPrefix == 'A') {
          return fStr == '1' ||
              fStr == 'A' ||
              fStr.contains('DƯỚI') ||
              fStr.contains('DUOI');
        } else {
          return fStr == '2' ||
              fStr == 'B' ||
              fStr.contains('TRÊN') ||
              fStr.contains('TREN');
        }
      }
      if (deckPrefix == 'A') {
        return name.startsWith('A') ||
            name.endsWith('A') ||
            (!name.startsWith('B') &&
                !name.endsWith('B') &&
                !name.startsWith('C') &&
                !name.endsWith('C'));
      } else {
        return name.startsWith('B') ||
            name.endsWith('B') ||
            name.startsWith('C') ||
            name.endsWith('C');
      }
    }).toList();

    if (deckSeats.isEmpty) {
      return const Center(
        child: Text(
          'Không có ghế nào ở tầng này.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bus front indicator
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.drive_eta_rounded,
                    color: Colors.grey.shade500, size: 16),
                const SizedBox(width: 6),
                Text(
                  deckPrefix == 'A'
                      ? 'Đầu xe (tài xế)'
                      : 'Tầng trên - Đầu xe',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.05,
            ),
            itemCount: deckSeats.length,
            itemBuilder: (context, index) {
              final seat = deckSeats[index];
              final String seatName = (seat['name'] ??
                      seat['seatNumber'] ??
                      seat['seat_number'] ??
                      'G${seat['id']}')
                  .toString();
              final int seatId =
                  int.tryParse(seat['id']?.toString() ?? '0') ?? 0;
              final String status =
                  (seat['status'] ?? '').toString().toLowerCase();
              final bool isBooked = seat['isBooked'] == true ||
                  seat['is_booked'] == true ||
                  status == 'sold' ||
                  status == 'reserved';
              final bool isSelected = bp.selectedSeatIds.contains(seatId);

              return _buildSeatTile(
                seatName: seatName,
                seatId: seatId,
                isBooked: isBooked,
                isSelected: isSelected,
                isFirst: deckPrefix == 'A' && index == 0,
                onTap: isBooked ? null : () => bp.toggleSeat(seatId, seatName),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSeatTile({
    required String seatName,
    required int seatId,
    required bool isBooked,
    required bool isSelected,
    required bool isFirst,
    required VoidCallback? onTap,
  }) {
    final Color bgColor = isBooked
        ? Colors.grey.shade100
        : (isSelected ? Colors.transparent : Colors.white);
    final Color iconColor = isBooked
        ? Colors.grey.shade400
        : (isSelected ? Colors.white : _primary);
    final Color textColor = isBooked
        ? Colors.grey.shade400
        : (isSelected ? Colors.white : Colors.grey.shade800);
    final Color borderColor = isBooked
        ? Colors.grey.shade200
        : (isSelected ? _primary : Colors.grey.shade200);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: bgColor,
            gradient: isSelected ? _primaryGradient : null,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.4),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _primary.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : isBooked
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
          ),
          child: Stack(
            children: [
              if (isFirst)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    Icons.drive_eta_rounded,
                    size: 12,
                    color: isSelected
                        ? Colors.white70
                        : Colors.grey.shade400,
                  ),
                ),
              if (isBooked)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(Icons.lock_rounded,
                      size: 12, color: Colors.grey),
                ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_seat_rounded,
                      color: iconColor,
                      size: 26,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      seatName,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.3,
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

  // ---------- Footer ----------
  Widget _buildFooter(BuildContext context, BookingProvider bp) {
    final hasSeat = bp.selectedSeatIds.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          hasSeat
                              ? Icons.event_seat_rounded
                              : Icons.event_seat_outlined,
                          size: 13,
                          color: hasSeat ? _primary : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            hasSeat
                                ? 'Ghế ${bp.selectedSeatNumbers.join(", ")}'
                                : 'Chưa chọn ghế (Tối đa 1 ghế)',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: hasSeat
                                  ? _primary
                                  : Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatPrice(bp.totalPrice),
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: hasSeat ? () => context.push('/booking') : null,
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  decoration: BoxDecoration(
                    gradient: hasSeat ? _primaryGradient : null,
                    color: hasSeat ? null : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: hasSeat
                        ? [
                            BoxShadow(
                              color: _primary.withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Tiếp tục',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
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
      ),
    );
  }
}
