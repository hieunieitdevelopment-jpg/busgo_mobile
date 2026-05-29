import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:busgo_mobile/features/booking/presentation/providers/booking_provider.dart';
import 'package:busgo_mobile/features/ticket/presentation/providers/ticket_provider.dart';

class BoardingPassPage extends StatelessWidget {
  const BoardingPassPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final ticketProvider = Provider.of<TicketProvider>(context);

    // Ưu tiên thông tin chi tiết vé được chọn từ Lịch sử vé, nếu không có mới dùng Booking vừa tạo
    final dynamic realTicket = ticketProvider.selectedTicket ?? bookingProvider.lastCreatedBooking;
    final schedule = bookingProvider.selectedSchedule;

    final String fromTo = realTicket != null && realTicket['fromLocation'] != null && realTicket['toLocation'] != null
        ? '${realTicket['fromLocation']} ➔ ${realTicket['toLocation']}'
        : (bookingProvider.currentFrom.isNotEmpty && bookingProvider.currentTo.isNotEmpty
            ? '${bookingProvider.currentFrom} ➔ ${bookingProvider.currentTo}'
            : 'Hành trình của bạn');

    final String travelDate = realTicket != null && realTicket['departureDate'] != null
        ? realTicket['departureDate'].toString()
        : (bookingProvider.currentDate.isNotEmpty ? bookingProvider.currentDate : 'Hôm nay');

    final String departureTime = realTicket != null && realTicket['departureTime'] != null
        ? realTicket['departureTime'].toString()
        : (bookingProvider.selectedPickup != null ? bookingProvider.selectedPickup['time'] ?? '08:00 AM' : '08:00 AM');

    final String arrivalTime = realTicket != null && realTicket['arrivalTime'] != null
        ? realTicket['arrivalTime'].toString()
        : (bookingProvider.selectedDropoff != null ? bookingProvider.selectedDropoff['time'] ?? '02:30 PM' : '02:30 PM');

    final String seatsSelected = realTicket != null && (realTicket['seatNumber'] != null || realTicket['seatNumbers'] != null)
        ? (realTicket['seatNumber'] ?? realTicket['seatNumbers']).toString()
        : (bookingProvider.selectedSeatNumbers.isNotEmpty ? bookingProvider.selectedSeatNumbers.join(', ') : 'Chưa chọn');

    final compObj = schedule != null ? (schedule['company'] ?? (schedule['tripSchedule'] is Map ? schedule['tripSchedule']['company'] : null)) : null;
    final String operatorName = realTicket != null && (realTicket['companyName'] ?? realTicket['operatorName']) != null
        ? (realTicket['companyName'] ?? realTicket['operatorName']).toString()
        : (schedule != null
            ? (schedule['name'] ?? 
               schedule['companyName'] ?? 
               schedule['company_name'] ?? 
               (schedule['tripSchedule'] is Map ? schedule['tripSchedule']['companyName'] ?? schedule['tripSchedule']['company_name'] : null) ?? 
               (compObj is Map ? compObj['name'] ?? compObj['companyName'] ?? compObj['company_name'] : null) ?? 
               'Futa Bus Lines')
            : 'Đối tác BusGo');

    final int bookingId = int.tryParse((realTicket != null ? realTicket['id'] ?? realTicket['bookingId'] ?? '108249' : '108249').toString()) ?? 108249;

    return Scaffold(
      backgroundColor: const Color(0xff121212), // High-End Dark Frame
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xff1e1e1e), Color(0xff121212)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('Vé lên xe của bạn', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            if (ticketProvider.selectedTicket != null) {
              // Quay lại lịch sử vé và refresh danh sách
              ticketProvider.fetchMyTickets();
              context.go('/my-tickets');
            } else {
              bookingProvider.clearSelectionAfterBooking();
              context.go('/');
            }
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ticket Card Mockup
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header Segment (Emerald Green Gradient style)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xff006e1c), Color(0xff4caf50)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'VÉ LÊN XE (BOARDING PASS)',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.95),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  fromTo,
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.directions_bus_outlined, color: Colors.white, size: 28),
                        ],
                      ),
                    ),

                    // Logistical Ticket Body
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(bookingProvider.currentFrom.isNotEmpty ? bookingProvider.currentFrom.toUpperCase() : 'ĐIỂM ĐI', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                                    const SizedBox(height: 4),
                                    Text(departureTime, style: const TextStyle(color: Color(0xff006e1c), fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text(travelDate, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.swap_horiz, color: Colors.grey),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(bookingProvider.currentTo.isNotEmpty ? bookingProvider.currentTo.toUpperCase() : 'ĐIỂM ĐẾN', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                                    const SizedBox(height: 4),
                                    Text(arrivalTime, style: const TextStyle(color: Color(0xff006e1c), fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text(travelDate, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32, thickness: 0.8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Số ghế (Seats)', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text(seatsSelected, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Nhà xe đối tác', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text(operatorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Mã đặt vé (Ref Code)', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text('BUSGO-$bookingId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xff006e1c))),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Tổng tiền', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${bookingProvider.totalPrice.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}đ',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          
                          // Dashed Tear-Line Representation
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20.0),
                            child: Row(
                              children: List.generate(
                                20,
                                (index) => Expanded(
                                  child: Container(
                                    height: 1,
                                    color: index % 2 == 0 ? Colors.transparent : Colors.grey.shade300,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // QR Code Container
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade100),
                            ),
                            child: Column(
                              children: [
                                // Mock QR graphic lines
                                Container(
                                  width: 140,
                                  height: 140,
                                  color: Colors.white,
                                  child: const Center(
                                    child: Icon(Icons.qr_code_2, size: 120, color: Colors.black87),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'MÃ LÊN XE (BOARDING QR CODE)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5, color: Colors.black87),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Trình mã này cho lái xe để soát vé nhanh',
                                  style: TextStyle(fontSize: 10, color: Colors.grey),
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
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    bookingProvider.clearSelectionAfterBooking();
                    context.go('/');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Về trang chủ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
