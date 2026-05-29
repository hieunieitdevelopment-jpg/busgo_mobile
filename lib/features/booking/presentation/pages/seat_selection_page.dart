import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:busgo_mobile/features/booking/presentation/providers/booking_provider.dart';

class SeatSelectionPage extends StatefulWidget {
  const SeatSelectionPage({super.key});

  @override
  State<SeatSelectionPage> createState() => _SeatSelectionPageState();
}

class _SeatSelectionPageState extends State<SeatSelectionPage> with SingleTickerProviderStateMixin {
  late TabController _deckController;

  @override
  void initState() {
    super.initState();
    _deckController = TabController(length: 2, vsync: this);
    
    // Tải thông tin chuẩn bị đặt chỗ, điểm đón/trả và sơ đồ ghế từ API động
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
      final bool prepareSuccess = await bookingProvider.prepareBooking();
      if (prepareSuccess) {
        await bookingProvider.fetchStops();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(bookingProvider.errorMessage ?? 'Không thể chuẩn bị chuyến xe. Vui lòng thử lại.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _deckController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bookingProvider = Provider.of<BookingProvider>(context);
    final selectedSchedule = bookingProvider.selectedSchedule;

    if (selectedSchedule == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chọn chỗ ngồi')),
        body: const Center(child: Text('Vui lòng chọn chuyến xe trước.')),
      );
    }

    final fromTo = '${bookingProvider.currentFrom.isEmpty ? 'Hà Nội' : bookingProvider.currentFrom} ➔ ${bookingProvider.currentTo.isEmpty ? 'Sa Pa' : bookingProvider.currentTo}';

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
            const Text(
              'Chọn Chỗ Ngồi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              fromTo,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _deckController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Tầng dưới (Deck A)'),
            Tab(text: 'Tầng trên (Deck B)'),
          ],
        ),
      ),
      body: bookingProvider.isLoading || bookingProvider.isLoadingStops
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xff006e1c))),
                  SizedBox(height: 16),
                  Text('Đang kết nối API chuẩn bị chuyến xe...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : Column(
              children: [
                // Dropdowns chọn điểm đón/trả thiết kế sang trọng
                _buildStationSelectors(context, bookingProvider),

                // Seats map legend
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  color: Colors.grey.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildLegendItem('Trống', Colors.white, Colors.grey.shade300),
                      _buildLegendItem('Đang chọn', const Color(0xff006e1c), const Color(0xff006e1c)),
                      _buildLegendItem('Đã bán', Colors.grey.shade300, Colors.grey.shade300),
                    ],
                  ),
                ),

                // Decks Grid
                Expanded(
                  child: bookingProvider.isLoadingSeats
                      ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xff006e1c))))
                      : bookingProvider.seats.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.info_outline, size: 48, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Không lấy được sơ đồ ghế thực tế của chuyến xe từ API. Vui lòng chọn điểm đón/trả khác hoặc liên hệ nhà xe.',
                                      style: TextStyle(color: Colors.grey),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : TabBarView(
                              controller: _deckController,
                              children: [
                                _buildSeatGrid(bookingProvider, 'A'),
                                _buildSeatGrid(bookingProvider, 'B'),
                              ],
                            ),
                ),

                // Selection summary footer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                bookingProvider.selectedSeatNumbers.isEmpty
                                    ? 'Chưa chọn ghế (Tối đa 1 ghế)'
                                    : 'Ghế đã chọn: ${bookingProvider.selectedSeatNumbers.join(", ")}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: bookingProvider.selectedSeatNumbers.isEmpty ? Colors.grey : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${bookingProvider.totalPrice.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}đ',
                                style: const TextStyle(
                                  color: Color(0xff006e1c),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: bookingProvider.selectedSeatIds.isEmpty
                                ? null
                                : () => context.push('/booking'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff006e1c),
                              disabledBackgroundColor: Colors.grey.shade300,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              elevation: 0,
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Tiếp tục',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLegendItem(String label, Color fillColor, Color borderColor) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildStationSelectors(BuildContext context, BookingProvider bookingProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Chọn Điểm Đón
          Row(
            children: [
              const Icon(Icons.circle, color: Color(0xff006e1c), size: 12),
              const SizedBox(width: 12),
              const Expanded(
                flex: 2,
                child: Text(
                  'Điểm đón',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54),
                ),
              ),
              Expanded(
                flex: 5,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<dynamic>(
                    value: bookingProvider.selectedPickup,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.green),
                    hint: const Text('Chọn điểm đón'),
                    items: bookingProvider.pickups.map<DropdownMenuItem<dynamic>>((dynamic stop) {
                      final timeStr = stop['time'] ?? '06:00 AM';
                      final stationObj = stop['station'];
                      final stationName = stop['address'] ?? stop['stationName'] ?? stop['station_name'] ?? (stationObj is Map ? stationObj['name'] : null) ?? 'Trạm đón';
                      return DropdownMenuItem<dynamic>(
                        value: stop,
                        child: Text(
                          '$timeStr - $stationName',
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (dynamic val) {
                      if (val != null) {
                        bookingProvider.selectPickup(val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16, thickness: 0.5),
          // Chọn Điểm Trả
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 14),
              const SizedBox(width: 12),
              const Expanded(
                flex: 2,
                child: Text(
                  'Điểm trả',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54),
                ),
              ),
              Expanded(
                flex: 5,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<dynamic>(
                    value: bookingProvider.selectedDropoff,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.green),
                    hint: const Text('Chọn điểm trả'),
                    items: bookingProvider.dropoffs.map<DropdownMenuItem<dynamic>>((dynamic stop) {
                      final timeStr = stop['time'] ?? '12:00 PM';
                      final stationObj = stop['station'];
                      final stationName = stop['address'] ?? stop['stationName'] ?? stop['station_name'] ?? (stationObj is Map ? stationObj['name'] : null) ?? 'Trạm trả';
                      
                      final dynamic stopPrice = stop['price'] ?? 250000;
                      final formattedStopPrice = '${(double.tryParse(stopPrice.toString()) ?? 250000.0)
                          .toStringAsFixed(0)
                          .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}đ';

                      return DropdownMenuItem<dynamic>(
                        value: stop,
                        child: Text(
                          '$timeStr - $stationName ($formattedStopPrice)',
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (dynamic val) {
                      if (val != null) {
                        bookingProvider.selectDropoff(val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeatGrid(BookingProvider bookingProvider, String deckPrefix) {
    // Phân loại ghế theo tầng dựa trên ký tự bắt đầu của số ghế
    final List<dynamic> deckSeats = bookingProvider.seats.where((seat) {
      final name = (seat['name'] ?? seat['seatNumber'] ?? seat['seat_number'] ?? '').toString().toUpperCase();
      if (deckPrefix == 'A') {
        return name.startsWith('A') || (!name.startsWith('B') && !name.startsWith('C'));
      } else {
        return name.startsWith('B') || name.startsWith('C');
      }
    }).toList();

    if (deckSeats.isEmpty) {
      return const Center(
        child: Text('Không có ghế nào ở tầng này.', style: TextStyle(color: Colors.grey)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: deckSeats.length,
      itemBuilder: (context, index) {
        final seat = deckSeats[index];
        final String seatName = (seat['name'] ?? seat['seatNumber'] ?? seat['seat_number'] ?? 'G${seat['id']}').toString();
        final int seatId = int.tryParse(seat['id']?.toString() ?? '0') ?? 0;
        
        // Trạng thái ghế từ API: check status = 'sold', 'reserved' hoặc isBooked = true
        final String status = (seat['status'] ?? '').toString().toLowerCase();
        final bool isBooked = seat['isBooked'] == true || seat['is_booked'] == true || status == 'sold' || status == 'reserved';
        
        final bool isSelected = bookingProvider.selectedSeatIds.contains(seatId);

        Color seatColor = Colors.white;
        Color textColor = Colors.black87;
        Color borderColor = Colors.grey.shade300;

        if (isBooked) {
          seatColor = Colors.grey.shade200;
          textColor = Colors.grey.shade400;
          borderColor = Colors.grey.shade200;
        } else if (isSelected) {
          seatColor = const Color(0xff006e1c);
          textColor = Colors.white;
          borderColor = const Color(0xff004d13);
        }

        return InkWell(
          onTap: isBooked
              ? null
              : () {
                  bookingProvider.toggleSeat(seatId, seatName);
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: seatColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xff006e1c).withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                // Driver icon at index 0 on lower deck
                if (deckPrefix == 'A' && index == 0)
                  const Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(Icons.drive_eta, color: Colors.grey, size: 14),
                  ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_seat,
                        color: isSelected ? Colors.white : (isBooked ? Colors.grey.shade300 : const Color(0xff006e1c)),
                        size: 20,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        seatName,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
