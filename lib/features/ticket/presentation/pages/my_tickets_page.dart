import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:busgo_mobile/features/ticket/presentation/providers/ticket_provider.dart';
import 'package:busgo_mobile/features/ticket/data/cash_tickets_tracker.dart';
import 'package:busgo_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:busgo_mobile/features/booking/presentation/providers/booking_provider.dart';
import 'package:busgo_mobile/features/rating/presentation/widgets/review_trip_modal.dart';

class MyTicketsPage extends StatefulWidget {
  const MyTicketsPage({super.key});

  @override
  State<MyTicketsPage> createState() => _MyTicketsPageState();
}

class _MyTicketsPageState extends State<MyTicketsPage> {
  bool _showActiveTab = true; // true: Sắp đi (Active), false: Lịch sử (History)

  // Sets ticketIds & bookingIds đã chọn thanh toán tiền mặt (lưu phía client).
  // Vì server không trả paymentMethod trong list, dùng SharedPreferences để nhớ.
  Set<int> _cashTicketIds = const {};
  Set<int> _cashBookingIds = const {};

  @override
  void initState() {
    super.initState();
    // Tải dữ liệu vé thật khi mở trang
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Provider.of<TicketProvider>(context, listen: false).fetchMyTickets();
      final all = await CashTicketsTracker().loadAll();
      if (mounted) {
        setState(() {
          _cashTicketIds = all.tickets;
          _cashBookingIds = all.bookings;
        });
      }
    });
  }

  /// Kiểm tra một vé có là thanh toán tiền mặt không (theo cache phía client).
  bool _isCashTicket(dynamic ticket) {
    if (ticket is! Map) return false;
    // Ưu tiên field từ server nếu có (forward-compat)
    final paymentRaw =
        (ticket['paymentMethod'] ?? ticket['paymentType'] ?? '').toString().toUpperCase();
    if (paymentRaw == 'CASH') return true;
    final tId = int.tryParse(ticket['id']?.toString() ?? '');
    final bId = int.tryParse(ticket['bookingId']?.toString() ?? '');
    if (tId != null && _cashTicketIds.contains(tId)) return true;
    if (bId != null && _cashBookingIds.contains(bId)) return true;
    return false;
  }

  // Định dạng ngày giờ đi tiếng Việt đẹp mắt
  String _formatDepartureDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return 'N/A';
    try {
      DateTime? parsedDate;
      if (rawDate.contains('T')) {
        parsedDate = DateTime.tryParse(rawDate);
      } else {
        final parts = rawDate.split('/');
        if (parts.length == 3) {
          parsedDate = DateTime.tryParse('${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}');
        }
      }
      
      if (parsedDate != null) {
        final days = ['Chủ Nhật', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy'];
        final weekday = days[parsedDate.weekday % 7];
        final day = parsedDate.day.toString().padLeft(2, '0');
        final month = parsedDate.month.toString().padLeft(2, '0');
        final year = parsedDate.year;
        return '$weekday, $day/$month/$year';
      }
    } catch (_) {}
    return rawDate;
  }

  // Xử lý thanh toán lại cho vé Chờ thanh toán
  Future<void> _handlePayment({
    required int bookingId,
    required String method,
    required BookingProvider bookingProvider,
    required TicketProvider ticketProvider,
  }) async {
    if (method == 'cash') {
      // Thanh toán tiền mặt tại quầy
      final success = await bookingProvider.payExistingBooking(
        bookingId: bookingId,
        method: 'cash',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đăng ký thanh toán bằng Tiền mặt thành công! Trạng thái vé sẽ cập nhật khi thanh toán tại quầy.'),
            backgroundColor: Colors.green,
          ),
        );
        ticketProvider.fetchMyTickets();
      }
      return;
    }

    // Thanh toán online (VNPay / Stripe)
    final paymentUrl = await bookingProvider.payExistingBooking(
      bookingId: bookingId,
      method: method,
    );

    if (paymentUrl != null && paymentUrl.isNotEmpty) {
      final uri = Uri.parse(paymentUrl);
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          _showPaymentProcessingDialog(
            context: context,
            bookingId: bookingId,
            bookingProvider: bookingProvider,
            ticketProvider: ticketProvider,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể mở liên kết thanh toán. Vui lòng thử lại.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(bookingProvider.errorMessage ?? 'Không thể khởi tạo cổng thanh toán. Vui lòng thử lại sau.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Hiển thị Dialog xử lý và Polling kết quả thanh toán trực tiếp cực kỳ Premium
  void _showPaymentProcessingDialog({
    required BuildContext context,
    required int bookingId,
    required BookingProvider bookingProvider,
    required TicketProvider ticketProvider,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        String statusState = 'waiting'; // 'waiting', 'checking', 'success', 'fail'
        String checkMessage = 'Hệ thống đang chờ xác nhận thanh toán trực tuyến của bạn.\n\nSau khi bạn hoàn tất thanh toán trên tab trình duyệt vừa mở, hãy nhấn nút "Kiểm tra giao dịch" ở dưới.';
        Timer? pollTimer;

        // Cơ chế tự động truy vấn trạng thái qua findTicketByBookingId mỗi 3 giây
        void startPolling(StateSetter setState) {
          pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
            if (statusState == 'success' || statusState == 'checking') return;

            try {
              print('=== POLLING TICKET ID: $bookingId ===');
              final ticket = await ticketProvider.findTicketByBookingId(bookingId);
              print('=== POLLING TICKET DATA: $ticket ===');
              final status = ticket != null ? ticket['status']?.toString() : null;
              final statusLower = status?.toLowerCase();
              print('=== POLLING TICKET STATUS RESOLVED: $statusLower ===');

              if (statusLower == 'reserved' || 
                  statusLower == 'completed' || 
                  statusLower == 'paid' || 
                  statusLower == 'checked_in' || 
                  statusLower == 'cash_paid') {
                print('=== POLLING MATCHED SUCCESS STATE! CANCELING TIMER AND REDIRECTING ===');
                timer.cancel();
                if (dialogContext.mounted) {
                  setState(() {
                    statusState = 'success';
                    checkMessage = 'Thanh toán thành công! Vé của bạn đã được xác nhận.';
                  });
                }

                await Future.delayed(const Duration(seconds: 2));
                if (context.mounted) {
                  pollTimer?.cancel();
                  Navigator.pop(dialogContext);
                  ticketProvider.fetchMyTickets(); // Làm mới danh sách vé
                }
              }
            } catch (e) {
              print('=== POLLING ERROR: $e ===');
            }
          });
        }

        return StatefulBuilder(
          builder: (dialogContext, setState) {
            if (pollTimer == null) {
              startPolling(setState);
            }

            return Dialog(
              backgroundColor: const Color(0xff121212),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Colors.white10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (statusState == 'waiting') ...[
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          const SizedBox(
                            width: 80,
                            height: 80,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xff006e1c)),
                              strokeWidth: 4,
                            ),
                          ),
                          Icon(Icons.payment_outlined, size: 36, color: Colors.green.shade400),
                        ],
                      ),
                    ] else if (statusState == 'checking') ...[
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          const SizedBox(
                            width: 80,
                            height: 80,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                              strokeWidth: 4,
                            ),
                          ),
                          Icon(Icons.sync, size: 36, color: Colors.amber.shade400),
                        ],
                      ),
                    ] else if (statusState == 'success') ...[
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xff006e1c).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle, size: 56, color: Color(0xff006e1c)),
                      ),
                    ] else ...[
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.error, size: 56, color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      statusState == 'waiting'
                          ? 'Đang chờ thanh toán...'
                          : (statusState == 'checking'
                              ? 'Đang kiểm tra...'
                              : (statusState == 'success'
                                  ? 'Thanh Toán Thành Công!'
                                  : 'Giao Dịch Chưa Hoàn Tất')),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: statusState == 'success'
                            ? Colors.green
                            : (statusState == 'fail' ? Colors.red : Colors.white),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      checkMessage,
                      style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (statusState == 'waiting' || statusState == 'fail') ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            setState(() {
                              statusState = 'checking';
                              checkMessage = 'Đang truy vấn trạng thái thanh toán từ hệ thống. Vui lòng chờ...';
                            });

                            try {
                              final ticket = await ticketProvider.findTicketByBookingId(bookingId);
                              final status = ticket != null ? ticket['status']?.toString() : null;
                              final statusLower = status?.toLowerCase();

                              if (statusLower == 'reserved' || 
                                  statusLower == 'completed' || 
                                  statusLower == 'paid' || 
                                  statusLower == 'checked_in' || 
                                  statusLower == 'cash_paid') {
                                pollTimer?.cancel();
                                setState(() {
                                  statusState = 'success';
                                  checkMessage = 'Thanh toán thành công! Vé của bạn đã được xác nhận.';
                                });

                                await Future.delayed(const Duration(seconds: 2));
                                if (context.mounted) {
                                  Navigator.pop(dialogContext);
                                  ticketProvider.fetchMyTickets();
                                }
                              } else {
                                setState(() {
                                  statusState = 'fail';
                                  checkMessage = 'Giao dịch chưa hoàn tất hoặc đang được xử lý (Trạng thái: ${status ?? 'chờ xử lý'}).\n\nVui lòng thử lại sau vài giây hoặc kiểm tra tab trình duyệt.';
                                });
                              }
                            } catch (e) {
                              setState(() {
                                statusState = 'fail';
                                checkMessage = 'Lỗi truy vấn trạng thái: $e';
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff006e1c),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Kiểm tra giao dịch', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: TextButton(
                          onPressed: () {
                            pollTimer?.cancel();
                            Navigator.pop(dialogContext);
                            ticketProvider.fetchMyTickets();
                          },
                          child: const Text('Đóng', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Mở Bottom Sheet đánh giá chuyến đi (Rating) cực kỳ xịn sò
  void _openRatingBottomSheet(BuildContext context, dynamic ticket, TicketProvider ticketProvider) {
    final int tripId = int.tryParse(
            (ticket['tripId'] ??
                    ticket['tripScheduleId'] ??
                    (ticket['trip'] is Map ? ticket['trip']['id'] : null) ??
                    ticket['scheduleId'] ??
                    ticket['id'])
                .toString()) ??
        0;
    final int ticketId =
        int.tryParse(ticket['id']?.toString() ?? '') ?? 0;
    final String operatorName =
        ticket['companyName'] ?? ticket['operatorName'] ?? 'Nhà xe đối tác';
    final String fromLoc = ticket['fromLocation'] ?? 'Điểm đi';
    final String toLoc = ticket['toLocation'] ?? 'Điểm đến';
    final String departureDate =
        _formatDepartureDate(ticket['departureDate']?.toString());

    showReviewTripModal(
      context,
      payload: ReviewTicketPayload(
        ticketId: ticketId,
        tripId: tripId,
        companyName: operatorName,
        departureLocation: fromLoc,
        arrivalLocation: toLoc,
        departureDate: departureDate,
      ),
    ).then((submitted) {
      if (submitted == true) {
        ticketProvider.fetchMyTickets();
      }
    });
  }

  // Hủy vé
  void _confirmCancelTicket(BuildContext context, int ticketId, TicketProvider ticketProvider) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Xác nhận hủy giữ chỗ'),
          content: const Text('Bạn có chắc chắn muốn hủy giữ vé này không? Thao tác này sẽ giải phóng ghế của bạn và không thể hoàn tác.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('BỎ QUA', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                
                // Hiển thị vòng xoay tải
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                );

                final success = await ticketProvider.cancelBookingTicket(ticketId);
                
                if (context.mounted) {
                  Navigator.pop(context); // Đóng xoay tải
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã hủy vé thành công!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    ticketProvider.fetchMyTickets();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ticketProvider.errorMessage ?? 'Không thể hủy vé. Vui lòng thử lại sau.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('XÁC NHẬN HỦY', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticketProvider = Provider.of<TicketProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final bookingProvider = Provider.of<BookingProvider>(context);

    // Trả về giao diện yêu cầu đăng nhập nếu chưa đăng nhập
    if (!authProvider.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Vé của tôi', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  Icons.confirmation_number_outlined,
                  size: 100,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Quản lý vé của bạn dễ dàng',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Đăng nhập tài khoản để tra cứu lịch sử mua vé, xem QR Code vé và kiểm tra thông tin check-in nhanh chóng.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
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
          currentIndex: 1,
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            switch (index) {
              case 0:
                context.go('/');
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
            BottomNavigationBarItem(icon: Icon(Icons.confirmation_number), label: 'Vé của tôi'),
            BottomNavigationBarItem(icon: Icon(Icons.local_offer_outlined), label: 'Ưu đãi'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Tài khoản'),
          ],
        ),
      );
    }

    // Lọc danh sách vé theo tab hiện tại (Active vs History)
    final filteredList = ticketProvider.tickets.where((ticket) {
      final status = (ticket['status'] ?? 'pending').toString().toLowerCase();
      final isUpcoming = status == 'pending' || 
                         status == 'reserved' || 
                         status == 'paid' || 
                         status == 'checked_in' || 
                         status == 'cash_paid';
      
      return _showActiveTab ? isUpcoming : !isUpcoming;
    }).toList();

    // Sắp xếp: mới đặt nhất lên đầu (id giảm dần, fallback bookingId).
    // Trong DB id thường tăng theo thời gian tạo, nên đây là proxy đáng tin cho "vừa đặt".
    filteredList.sort((a, b) {
      final ia = int.tryParse(a['id']?.toString() ?? '') ??
          int.tryParse(a['bookingId']?.toString() ?? '') ??
          0;
      final ib = int.tryParse(b['id']?.toString() ?? '') ??
          int.tryParse(b['bookingId']?.toString() ?? '') ??
          0;
      return ib.compareTo(ia);
    });

    return Scaffold(
      backgroundColor: const Color(0xfff8f9fa),
      appBar: AppBar(
        title: const Text('Vé của tôi', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          // Tab switcher capsules xịn sò và có trạng thái tương tác mượt mà
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _showActiveTab = true;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: _showActiveTab
                              ? const LinearGradient(
                                  colors: [Color(0xff006e1c), Color(0xff4caf50)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: _showActiveTab ? null : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: _showActiveTab
                              ? [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            'Sắp đi',
                            style: TextStyle(
                              color: _showActiveTab ? Colors.white : Colors.grey.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _showActiveTab = false;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: !_showActiveTab
                              ? const LinearGradient(
                                  colors: [Color(0xff006e1c), Color(0xff4caf50)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: !_showActiveTab ? null : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: !_showActiveTab
                              ? [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            'Lịch sử',
                            style: TextStyle(
                              color: !_showActiveTab ? Colors.white : Colors.grey.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Active ticket cards list or Loading indicator
          Expanded(
            child: ticketProvider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  )
                : filteredList.isNotEmpty
                    ? ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final ticket = filteredList[index];

                          // Đọc thông tin thực tế từ API (đã được enrich từ chi tiết)
                          final departureDateRaw = ticket['departureDate'];
                          final departureDate = _formatDepartureDate(departureDateRaw);
                          final from = ticket['fromLocation'] ?? '---';
                          final to = ticket['toLocation'] ?? '---';
                          final rawTime = (ticket['departureTime'] ?? '').toString();
                          final time = rawTime.isNotEmpty ? (rawTime.length >= 5 ? rawTime.substring(0, 5) : rawTime) : '--:--';
                          final operator = ticket['companyName'] ?? ticket['operatorName'] ?? 'Nhà xe';
                          final seats = ticket['seatNumber'] ?? '--';
                          final priceValue = double.tryParse(ticket['totalAmount']?.toString() ?? '0') ?? 0.0;
                          
                          // Lấy và chuẩn hóa trạng thái vé giống như trên Web
                          String currentStatus = (ticket['status'] ?? 'pending').toString().toUpperCase();
                          // Vé thanh toán tiền mặt: nâng từ PENDING/RESERVED → CASH_PAID
                          // (vì user đã coi là "đã thanh toán", chỉ chờ nhà xe hoàn thành chuyến để đánh giá).
                          final isCash = _isCashTicket(ticket);
                          if (isCash && (currentStatus == 'PENDING' || currentStatus == 'RESERVED')) {
                            currentStatus = 'CASH_PAID';
                          }

                          Color statusColor = Colors.orange;
                          String statusText = 'Chờ thanh toán';

                          switch (currentStatus) {
                            case 'PAID':
                            case 'CASH_PAID':
                              statusColor = Colors.green;
                              statusText = currentStatus == 'PAID' ? 'Đã thanh toán' : 'Tiền mặt';
                              break;
                            case 'RESERVED':
                              statusColor = Colors.teal;
                              statusText = 'Đã giữ chỗ';
                              break;
                            case 'COMPLETED':
                              statusColor = Colors.blue;
                              statusText = 'Hoàn thành';
                              break;
                            case 'CHECKED_IN':
                              statusColor = Colors.green.shade700;
                              statusText = 'Đã lên xe';
                              break;
                            case 'CANCELLED':
                              statusColor = Colors.red;
                              statusText = 'Đã hủy';
                              break;
                            case 'EXPIRED':
                              statusColor = Colors.grey;
                              statusText = 'Hết hạn';
                              break;
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: _buildNotchedTicketCard(
                              context,
                              ticket: ticket,
                              route: '$from ➔ $to',
                              date: departureDate,
                              time: time,
                              operator: operator,
                              seats: seats,
                              status: statusText,
                              statusColor: statusColor,
                              currentStatus: currentStatus,
                              price: priceValue,
                              ticketProvider: ticketProvider,
                              bookingProvider: bookingProvider,
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.confirmation_number_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              _showActiveTab ? 'Bạn không có chuyến đi nào sắp khởi hành' : 'Lịch sử mua vé trống',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/');
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
          BottomNavigationBarItem(icon: Icon(Icons.confirmation_number), label: 'Vé của tôi'),
          BottomNavigationBarItem(icon: Icon(Icons.local_offer_outlined), label: 'Ưu đãi'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Tài khoản'),
        ],
      ),
    );
  }

  // Widget Thẻ Vé thiết kế Premium — đục lỗ Notch Ticket Coupon cực xịn
  Widget _buildNotchedTicketCard(
    BuildContext context, {
    required dynamic ticket,
    required String route,
    required String date,
    required String time,
    required String operator,
    required String seats,
    required String status,
    required Color statusColor,
    required String currentStatus,
    required double price,
    required TicketProvider ticketProvider,
    required BookingProvider bookingProvider,
  }) {
    final int ticketId = int.tryParse((ticket['id'] ?? '0').toString()) ?? 0;
    final int bookingId = int.tryParse((ticket['bookingId'] ?? ticket['id'] ?? '0').toString()) ?? 0;
    final bool isPending = currentStatus == 'PENDING' || currentStatus == 'RESERVED';
    final String from = ticket['fromLocation'] ?? '---';
    final String to = ticket['toLocation'] ?? '---';
    final String plateNumber = ticket['plateNumber'] ?? '';
    final String bookingType = ticket['bookingType'] ?? 'one_way';

    // Màu chủ đạo theo trạng thái
    Color accentColor;
    Color accentBgColor;
    IconData statusIcon;
    switch (currentStatus) {
      case 'PAID':
      case 'CASH_PAID':
        accentColor = const Color(0xff0d9f61);
        accentBgColor = const Color(0xffe6f9f0);
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'COMPLETED':
        accentColor = const Color(0xff1976d2);
        accentBgColor = const Color(0xffe3f2fd);
        statusIcon = Icons.verified_rounded;
        break;
      case 'CHECKED_IN':
        accentColor = const Color(0xff00897b);
        accentBgColor = const Color(0xffe0f2f1);
        statusIcon = Icons.airline_seat_recline_normal;
        break;
      case 'CANCELLED':
        accentColor = const Color(0xffc62828);
        accentBgColor = const Color(0xfffce4ec);
        statusIcon = Icons.cancel_rounded;
        break;
      case 'EXPIRED':
        accentColor = const Color(0xff757575);
        accentBgColor = const Color(0xfff5f5f5);
        statusIcon = Icons.timer_off_rounded;
        break;
      default: // PENDING, RESERVED
        accentColor = const Color(0xffe65100);
        accentBgColor = const Color(0xfffff3e0);
        statusIcon = Icons.schedule_rounded;
    }

    // Format giá VND
    String formatVND(double value) {
      final intVal = value.toInt();
      return intVal.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.08),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              spreadRadius: 0,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            // ═══════════════════════════════════════════════════════
            // PHẦN TRÊN: Header + Hành trình
            // ═══════════════════════════════════════════════════════
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, accentBgColor.withOpacity(0.3)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Mã vé + Loại hành trình + Trạng thái
                  Row(
                    children: [
                      // Mã vé badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xff006e1c).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xff006e1c).withOpacity(0.15)),
                        ),
                        child: Text(
                          '#$ticketId',
                          style: const TextStyle(
                            color: Color(0xff006e1c),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Loại hành trình
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          bookingType == 'round_trip' ? 'Khứ hồi' : 'Một chiều',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Badge trạng thái
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: accentBgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: accentColor.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 12, color: accentColor),
                            const SizedBox(width: 5),
                            Text(
                              status,
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Hành trình: FROM → TO (trực quan, to rõ ràng)
                  Row(
                    children: [
                      // Cột Điểm đi
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              from.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Color(0xff1a1a2e),
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Điểm đi',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Biểu tượng xe chạy giữa
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          children: [
                            Icon(Icons.directions_bus_filled_rounded, size: 20, color: accentColor),
                            const SizedBox(height: 2),
                            SizedBox(
                              width: 56,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    height: 1.5,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [accentColor.withOpacity(0.1), accentColor, accentColor.withOpacity(0.1)],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    child: Icon(Icons.arrow_forward_ios_rounded, size: 8, color: accentColor),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Cột Điểm đến
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              to.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Color(0xff1a1a2e),
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Điểm đến',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Hàng thông tin phụ: Ngày | Giờ | Ghế | Nhà xe
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Row(
                      children: [
                        _buildInfoChip(Icons.calendar_today_rounded, date, flex: 3),
                        _buildVerticalDivider(),
                        _buildInfoChip(Icons.access_time_rounded, time, flex: 2),
                        _buildVerticalDivider(),
                        _buildInfoChip(Icons.event_seat_rounded, seats, flex: 1),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Nhà xe + Biển số
                  Row(
                    children: [
                      Icon(Icons.business_rounded, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          operator,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (plateNumber.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blueGrey.shade100),
                          ),
                          child: Text(
                            plateNumber,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.blueGrey.shade700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // ═══════════════════════════════════════════════════════
            // ĐƯỜNG CẮT RĂNG CƯA (Tear Line) + Lỗ đục bán nguyệt
            // ═══════════════════════════════════════════════════════
            Stack(
              children: [
                // Đường nét đứt
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: List.generate(
                      50,
                      (index) => Expanded(
                        child: Container(
                          height: 1,
                          color: index % 2 == 0 ? Colors.transparent : Colors.grey.shade200,
                        ),
                      ),
                    ),
                  ),
                ),
                // Bán nguyệt trái
                Positioned(
                  left: -12,
                  top: -10,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xfff8f9fa),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Bán nguyệt phải
                Positioned(
                  right: -12,
                  top: -10,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xfff8f9fa),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),

            // ═══════════════════════════════════════════════════════
            // PHẦN DƯỚI: Tổng tiền + Hành động
            // ═══════════════════════════════════════════════════════
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TỔNG THANH TOÁN',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${formatVND(price)}đ',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              color: accentColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      if (!isPending)
                        ElevatedButton.icon(
                          onPressed: () {
                            ticketProvider.fetchTicketDetail(ticketId);
                            context.push('/boarding-pass');
                          },
                          icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                          label: const Text('Xem vé', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff006e1c),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                        ),
                    ],
                  ),

                  // Nếu là vé chờ thanh toán: Hiện các cổng thanh toán
                  if (isPending) ...[
                    const SizedBox(height: 14),
                    Container(
                      height: 1,
                      color: Colors.grey.shade100,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Chọn phương thức thanh toán:',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPaymentButton(
                            icon: Icons.qr_code_scanner_rounded,
                            label: 'VNPay',
                            color: const Color(0xff006e1c),
                            onTap: () => _handlePayment(
                              bookingId: bookingId,
                              method: 'vnpay',
                              bookingProvider: bookingProvider,
                              ticketProvider: ticketProvider,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPaymentButton(
                            icon: Icons.credit_card_rounded,
                            label: 'Visa/Master',
                            color: const Color(0xff1565c0),
                            onTap: () => _handlePayment(
                              bookingId: bookingId,
                              method: 'stripe',
                              bookingProvider: bookingProvider,
                              ticketProvider: ticketProvider,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPaymentButton(
                            icon: Icons.payments_rounded,
                            label: 'Tiền mặt',
                            color: const Color(0xffe65100),
                            onTap: () => _handlePayment(
                              bookingId: bookingId,
                              method: 'cash',
                              bookingProvider: bookingProvider,
                              ticketProvider: ticketProvider,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPaymentButton(
                            icon: Icons.cancel_outlined,
                            label: 'Hủy giữ chỗ',
                            color: const Color(0xffc62828),
                            onTap: () => _confirmCancelTicket(context, ticketId, ticketProvider),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Nhóm trạng thái đánh giá theo 4 case (đủ điều kiện / chưa hoàn thành / hết hạn / đã đánh giá)
                  ..._buildReviewSection(
                    context: context,
                    ticket: ticket,
                    currentStatus: currentStatus,
                    ticketProvider: ticketProvider,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Trả về widget(s) hiển thị nhóm trạng thái Review.
  /// Logic theo spec:
  /// - Status ∈ {PAID, CHECKED_IN, CASH_PAID} && chưa COMPLETED → "Chưa hoàn thành" (disabled)
  /// - COMPLETED && đã review → badge "Đã đánh giá"
  /// - COMPLETED && chưa review:
  ///     - now > departureDate + 7 ngày → "Hết hạn ĐG" (disabled)
  ///     - else → nút "Đánh giá" (vàng)
  List<Widget> _buildReviewSection({
    required BuildContext context,
    required dynamic ticket,
    required String currentStatus,
    required TicketProvider ticketProvider,
  }) {
    final bool reviewed =
        ticket['isReviewed'] == true || ticket['hasRating'] == true;

    // 1. COMPLETED + đã review → badge xanh
    if (currentStatus == 'COMPLETED' && reviewed) {
      return [
        const SizedBox(height: 12),
        _buildReviewBadge(
          icon: Icons.check_circle_rounded,
          color: const Color(0xff0d9f61),
          bgColor: const Color(0xffe6f9f0),
          label: 'Đã gửi đánh giá',
        ),
      ];
    }

    // 2. COMPLETED + chưa review → kiểm tra hết hạn 7 ngày
    if (currentStatus == 'COMPLETED' && !reviewed) {
      final DateTime? depDate =
          DateTime.tryParse(ticket['departureDate']?.toString() ?? '');
      if (depDate != null) {
        final expiry = depDate.add(const Duration(days: 7));
        if (DateTime.now().isAfter(expiry)) {
          return [
            const SizedBox(height: 12),
            _buildReviewBadge(
              icon: Icons.timer_off_outlined,
              color: Colors.grey.shade600,
              bgColor: Colors.grey.shade100,
              label: 'Hết hạn đánh giá (quá 7 ngày)',
            ),
          ];
        }
      }
      // Đủ điều kiện → nút Đánh giá vàng
      return [
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () =>
                _openRatingBottomSheet(context, ticket, ticketProvider),
            icon: const Icon(Icons.star_rounded, size: 18),
            label: const Text('Đánh giá chuyến đi',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffffc107),
              foregroundColor: const Color(0xff1a1a2e),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ];
    }

    // 3. PAID/CHECKED_IN/CASH_PAID nhưng chưa COMPLETED → "Chưa hoàn thành"
    if (currentStatus == 'PAID' ||
        currentStatus == 'CHECKED_IN' ||
        currentStatus == 'CASH_PAID') {
      return [
        const SizedBox(height: 12),
        _buildReviewBadge(
          icon: Icons.hourglass_bottom_rounded,
          color: Colors.blueGrey.shade600,
          bgColor: Colors.blueGrey.shade50,
          label: 'Chưa hoàn thành chuyến đi',
        ),
      ];
    }

    // Còn lại (PENDING, CANCELLED, EXPIRED…) → không hiển thị review
    return const [];
  }

  Widget _buildReviewBadge({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String label,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12),
          ),
        ],
      ),
    );
  }

  // Helper: Chip thông tin nhỏ (ngày, giờ, ghế)
  Widget _buildInfoChip(IconData icon, String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade500),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Helper: Thanh dọc phân cách
  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.grey.shade200,
    );
  }

  // Helper: Nút thanh toán nhỏ gọn sang trọng
  Widget _buildPaymentButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

