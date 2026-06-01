import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:busgo_mobile/features/booking/presentation/providers/booking_provider.dart';
import 'package:busgo_mobile/features/ticket/presentation/providers/ticket_provider.dart';
import 'package:busgo_mobile/features/ticket/data/cash_tickets_tracker.dart';
import 'package:busgo_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:busgo_mobile/features/notifications/presentation/providers/notification_provider.dart';

class BookingCheckoutPage extends StatefulWidget {
  const BookingCheckoutPage({super.key});

  @override
  State<BookingCheckoutPage> createState() => _BookingCheckoutPageState();
}

class _BookingCheckoutPageState extends State<BookingCheckoutPage> {
  // Giữ các controller ẩn với giá trị mặc định để truyền cho API mà không cần người dùng nhập
  final _nameController = TextEditingController(text: 'Khách hàng BusGo');
  final _phoneController = TextEditingController(text: '0912345678');
  final _emailController = TextEditingController(text: 'customer@busgo.vn');
  
  final _cardNumberController = TextEditingController(text: '4242 4242 4242 4242');
  final _expiryController = TextEditingController(text: '12/26');
  final _cvcController = TextEditingController(text: '123');

  final _couponCodeController = TextEditingController();

  String _selectedPaymentMethod = 'VNPay'; // 'VNPay', 'Card', 'Cash'
  int _countdownSeconds = 600; // 10 minutes (600 seconds)
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // Tự động tải danh sách mã giảm giá từ API cho hành trình & số ghế đã chọn
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BookingProvider>(context, listen: false).fetchCoupons();
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0) {
        if (mounted) {
          setState(() {
            _countdownSeconds--;
          });
        }
      } else {
        _timer?.cancel();
      }
    });
  }

  /// Resolve nhãn mã vé ĐỒNG BỘ với trang "Vé của tôi" (hiển thị dạng #<ticketId>).
  /// Trang My Tickets dùng ticket['id'], không phải bookingId, nên cần resolve để khớp.
  Future<String> _resolveTicketLabel() async {
    if (!mounted) return '';
    final bookingProvider =
        Provider.of<BookingProvider>(context, listen: false);
    final ticketProvider =
        Provider.of<TicketProvider>(context, listen: false);
    final dynamic lastBooking = bookingProvider.lastCreatedBooking;
    if (lastBooking is! Map) return '';

    // 1. Nếu response đặt vé đã chứa ticket id trực tiếp
    final dynamic directTicketId =
        lastBooking['ticket'] is Map ? lastBooking['ticket']['id'] : null;
    if (directTicketId != null && directTicketId.toString().isNotEmpty) {
      return '#$directTicketId';
    }

    // 2. Resolve qua bookingId -> tra cứu ticket thật để lấy đúng ticket id
    final dynamic rawBookingId = lastBooking['bookingId'] ?? lastBooking['id'];
    final int? bookingId = int.tryParse(rawBookingId?.toString() ?? '');
    if (bookingId == null) return '';
    try {
      final ticket = await ticketProvider.findTicketByBookingId(bookingId);
      if (ticket is Map && ticket['id'] != null) {
        return '#${ticket['id']}';
      }
    } catch (_) {
      // bỏ qua, dùng fallback bên dưới
    }
    return '#$bookingId';
  }

  /// Tạo thông báo cho người dùng (đặt vé / thanh toán). An toàn nếu chưa đăng nhập.
  Future<void> _createUserNotification({
    required String title,
    required String body,
    String? data,
  }) async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final notiProvider =
        Provider.of<NotificationProvider>(context, listen: false);
    final int? uid = authProvider.userId;
    if (uid == null) return;
    await notiProvider.pushUserNotification(
      userId: uid,
      title: title,
      body: body,
      data: data,
    );
  }

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
        String checkMessage = 'Hệ thống đang chờ xác nhận thanh toán trực tuyến của bạn từ VNPAY / Stripe.\n\nSau khi bạn hoàn tất thanh toán trên tab trình duyệt vừa mở, hãy nhấn nút "Kiểm tra giao dịch" ở dưới.';
        Timer? pollTimer;

        // Cơ cơ chế tự động truy vấn mỗi 3 giây
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
                    checkMessage = 'Thanh toán thành công! Vé của bạn đã được xác nhận. Đang chuyển hướng...';
                  });
                }

                // Thông báo: Thanh toán thành công (thanh toán trực tuyến)
                await _createUserNotification(
                  title: 'Thanh toán thành công',
                  body:
                      'Thanh toán thành công! Vé của bạn đã được xác nhận.',
                  data: 'payment-success',
                );

                await Future.delayed(const Duration(seconds: 2));
                if (context.mounted) {
                  pollTimer?.cancel();
                  Navigator.pop(dialogContext);
                  bookingProvider.clearSelectionAfterBooking();
                  context.push('/boarding-pass');
                }
              }
            } catch (e) {
              print('=== POLLING ERROR: $e ===');
            }
          });
        }

        return StatefulBuilder(
          builder: (dialogContext, setState) {
            // Kích hoạt tự động truy vấn ở lần dựng đầu tiên
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
                                  checkMessage = 'Thanh toán thành công! Vé của bạn đã được xác nhận. Đang chuyển hướng...';
                                });

                                // Thông báo: Thanh toán thành công (kiểm tra thủ công)
                                await _createUserNotification(
                                  title: 'Thanh toán thành công',
                                  body:
                                      'Thanh toán thành công! Vé của bạn đã được xác nhận.',
                                  data: 'payment-success',
                                );

                                await Future.delayed(const Duration(seconds: 2));
                                if (context.mounted) {
                                  Navigator.pop(dialogContext);
                                  bookingProvider.clearSelectionAfterBooking();
                                  context.push('/boarding-pass');
                                }
                              } else {
                                setState(() {
                                  statusState = 'fail';
                                  checkMessage = 'Giao dịch chưa hoàn tất hoặc đang được xử lý (Trạng thái: ${status ?? 'chưa xác định'}).\n\nVui lòng thử lại sau vài giây hoặc kiểm tra tab thanh toán.';
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
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Kiểm tra giao dịch', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (statusState == 'checking') const SizedBox(height: 60),
                    if (statusState != 'success' && statusState != 'checking') ...[
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          onPressed: () {
                            pollTimer?.cancel();
                            Navigator.pop(dialogContext);
                            bookingProvider.clearSelectionAfterBooking();
                            context.push('/my-tickets');
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Xem Lịch sử vé'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    _couponCodeController.dispose();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    final String minutesStr = minutes.toString().padLeft(2, '0');
    final String secondsStr = seconds.toString().padLeft(2, '0');
    return '$minutesStr:$secondsStr';
  }

  Future<void> _applyTypedCoupon(BookingProvider bookingProvider) async {
    final typedCode = _couponCodeController.text.trim();
    if (typedCode.isEmpty) return;
    
    dynamic foundCoupon;
    for (var coupon in bookingProvider.coupons) {
      if (coupon['code']?.toString().toUpperCase() == typedCode.toUpperCase()) {
        foundCoupon = coupon;
        break;
      }
    }
    
    final int couponId = foundCoupon != null 
        ? int.tryParse(foundCoupon['id']?.toString() ?? '0') ?? 0
        : 0;
        
    final bool success = await bookingProvider.applyCouponCode(typedCode, couponId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã áp dụng mã giảm giá $typedCode thành công!'),
          backgroundColor: const Color(0xff006e1c),
        ),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(bookingProvider.errorMessage ?? 'Mã giảm giá không hợp lệ.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final schedule = bookingProvider.selectedSchedule;

    if (schedule == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thanh toán')),
        body: const Center(child: Text('Vui lòng chọn chuyến xe trước.')),
      );
    }

    final compObj = schedule['company'] ?? (schedule['tripSchedule'] is Map ? schedule['tripSchedule']['company'] : null);
    final companyName = schedule['name'] ?? 
                        schedule['companyName'] ?? 
                        schedule['company_name'] ?? 
                        (schedule['tripSchedule'] is Map ? schedule['tripSchedule']['companyName'] ?? schedule['tripSchedule']['company_name'] : null) ?? 
                        (compObj is Map ? compObj['name'] ?? compObj['companyName'] ?? compObj['company_name'] : null) ?? 
                        'Futa Bus Lines';
    final fromTo = '${bookingProvider.currentFrom.isEmpty ? 'Gia Lai' : bookingProvider.currentFrom} ➔ ${bookingProvider.currentTo.isEmpty ? 'Đà Nẵng' : bookingProvider.currentTo}';

    final pickupStation = bookingProvider.selectedPickup != null
        ? (bookingProvider.selectedPickup['address'] ?? bookingProvider.selectedPickup['stationName'] ?? bookingProvider.selectedPickup['station_name'] ?? (bookingProvider.selectedPickup['station'] is Map ? bookingProvider.selectedPickup['station']['name'] : '') ?? 'Bến xe đón')
        : 'Chưa chọn';

    final dropoffStation = bookingProvider.selectedDropoff != null
        ? (bookingProvider.selectedDropoff['address'] ?? bookingProvider.selectedDropoff['stationName'] ?? bookingProvider.selectedDropoff['station_name'] ?? (bookingProvider.selectedDropoff['station'] is Map ? bookingProvider.selectedDropoff['station']['name'] : '') ?? 'Bến xe trả')
        : 'Chưa chọn';

    final formattedPrice = '${bookingProvider.totalPrice.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}đ';

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
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
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Thanh Toán An Toàn',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: bookingProvider.isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xff006e1c))),
                  SizedBox(height: 16),
                  Text('Đang xử lý giao dịch an toàn...', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Step Stepper
                  _buildProgressStepper(),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero Invoice Card with countdown
                        _buildHeroInvoiceCard(
                          bookingProvider,
                          companyName,
                          fromTo,
                          pickupStation,
                          dropoffStation,
                          formattedPrice,
                        ),
                        const SizedBox(height: 20),

                        // Coupon input box (horizontal input + button)
                        _buildVoucherInput(bookingProvider),
                        const SizedBox(height: 20),

                        // ĐỀ XUẤT VOUCHER TỪ API (Thay thế phần điền thông tin liên hệ hành khách cũ)
                        const Row(
                          children: [
                            Icon(Icons.local_offer, color: Color(0xff006e1c), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Đề xuất Voucher & Khuyến mãi',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        if (bookingProvider.coupons.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.confirmation_number_outlined, color: Colors.grey, size: 36),
                                SizedBox(height: 8),
                                Text(
                                  'Chưa có mã khuyến mãi khả dụng',
                                  style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Hệ thống chưa tìm thấy voucher phù hợp cho hành trình này.',
                                  style: TextStyle(color: Colors.black38, fontSize: 11),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: bookingProvider.coupons.length,
                            itemBuilder: (context, index) {
                              final coupon = bookingProvider.coupons[index];
                              final String code = coupon['code'] ?? 'BUSGO';
                              final String title = coupon['title'] ?? 'Khuyến mãi hấp dẫn';
                              final String desc = coupon['description'] ?? 'Áp dụng để nhận ưu đãi ngay';
                              final int couponId = int.tryParse(coupon['id']?.toString() ?? '0') ?? 0;
                              final bool isApplied = bookingProvider.couponId == couponId;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: isApplied ? const Color(0xff006e1c).withOpacity(0.04) : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isApplied ? const Color(0xff006e1c) : Colors.grey.shade200,
                                    width: isApplied ? 1.5 : 1,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _couponCodeController.text = code;
                                    });
                                    _applyTypedCoupon(bookingProvider);
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        // Left accent icon/badge
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isApplied ? const Color(0xff006e1c) : Colors.green.shade50,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.local_offer,
                                            color: isApplied ? Colors.white : const Color(0xff006e1c),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        
                                        // Middle texts
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    code,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 14,
                                                      color: isApplied ? const Color(0xff006e1c) : Colors.black87,
                                                    ),
                                                  ),
                                                  if (isApplied) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xff006e1c),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: const Text(
                                                        'Đã áp dụng',
                                                        style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                title,
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                desc,
                                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        
                                        // Right apply button
                                        ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              _couponCodeController.text = code;
                                            });
                                            _applyTypedCoupon(bookingProvider);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isApplied ? Colors.grey.shade300 : const Color(0xff006e1c),
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: Text(
                                            isApplied ? 'Hủy' : 'Áp dụng',
                                            style: TextStyle(
                                              color: isApplied ? Colors.black54 : Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 24),

                        // Payment Methods Title
                        const Text(
                          'Phương thức thanh toán',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                        ),
                        const SizedBox(height: 10),

                        // Vertical Radio Payments List
                        _buildVerticalPaymentCard(
                          value: 'VNPay',
                          icon: Icons.qr_code_scanner,
                          title: 'Cổng VNPay',
                          isSelected: _selectedPaymentMethod == 'VNPay',
                          onTap: () => setState(() => _selectedPaymentMethod = 'VNPay'),
                        ),
                        _buildVerticalPaymentCard(
                          value: 'Card',
                          icon: Icons.credit_card_outlined,
                          title: 'Thanh toán bằng thẻ',
                          isSelected: _selectedPaymentMethod == 'Card',
                          onTap: () => setState(() => _selectedPaymentMethod = 'Card'),
                        ),
                        _buildVerticalPaymentCard(
                          value: 'Cash',
                          icon: Icons.payments_outlined,
                          title: 'Thanh toán khi lên xe',
                          isSelected: _selectedPaymentMethod == 'Cash',
                          onTap: () => setState(() => _selectedPaymentMethod = 'Cash'),
                        ),
                        const SizedBox(height: 12),

                        // Card Input Fields — CHỈ hiện khi chọn "Thanh toán bằng thẻ"
                        if (_selectedPaymentMethod == 'Card') ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Cổng thanh toán bảo mật',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'SECURE SSL',
                                        style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 8),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _cardNumberController,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.credit_card_outlined, color: Colors.blue, size: 20),
                                    hintText: 'Số thẻ (Card Number)',
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Colors.blue, width: 1.2),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey.shade200),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    fillColor: Colors.grey.shade50,
                                    filled: true,
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _expiryController,
                                        decoration: InputDecoration(
                                          hintText: 'MM/YY',
                                          prefixIcon: const Icon(Icons.calendar_month_outlined, color: Colors.blue, size: 20),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Colors.blue, width: 1.2),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey.shade200),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          fillColor: Colors.grey.shade50,
                                          filled: true,
                                        ),
                                        style: const TextStyle(fontSize: 13),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: _cvcController,
                                        decoration: InputDecoration(
                                          hintText: 'CVC / CVV',
                                          prefixIcon: const Icon(Icons.lock_outline, color: Colors.blue, size: 20),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Colors.blue, width: 1.2),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey.shade200),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          fillColor: Colors.grey.shade50,
                                          filled: true,
                                        ),
                                        style: const TextStyle(fontSize: 13),
                                        keyboardType: TextInputType.number,
                                        obscureText: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Main action checkout button (Green & glowing)
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final String checkoutMethod = _selectedPaymentMethod == 'Cash'
                                  ? 'cash'
                                  : (_selectedPaymentMethod == 'Card' ? 'stripe' : 'vnpay');

                              final bool success = await bookingProvider.checkout(
                                paymentMethod: checkoutMethod,
                                fullName: _nameController.text.trim(),
                                phone: _phoneController.text.trim(),
                                email: _emailController.text.trim(),
                              );

                              if (success && mounted) {
                                // Thông báo: Đặt vé thành công (đã giữ chỗ)
                                final String ticketLabel =
                                    await _resolveTicketLabel();
                                if (!mounted) return;
                                await _createUserNotification(
                                  title: 'Đặt vé thành công',
                                  body:
                                      'Đặt vé thành công. Mã vé: $ticketLabel. Vui lòng hoàn tất thanh toán để xác nhận chuyến đi.',
                                  data: 'booking-success',
                                );

                                if (!mounted) return;
                                if (checkoutMethod == 'vnpay' || checkoutMethod == 'stripe') {
                                  final String? payUrl = bookingProvider.paymentUrl;
                                  if (payUrl != null && payUrl.isNotEmpty) {
                                    try {
                                      final Uri uri = Uri.parse(payUrl);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Đang mở cổng thanh toán trực tuyến bảo mật...'),
                                          backgroundColor: Color(0xff006e1c),
                                        ),
                                      );
                                      await launchUrl(
                                        uri,
                                        mode: LaunchMode.inAppWebView,
                                        webViewConfiguration: const WebViewConfiguration(
                                          enableJavaScript: true,
                                          enableDomStorage: true,
                                        ),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Không thể mở liên kết thanh toán: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Không tìm thấy link thanh toán từ hệ thống.'),
                                        backgroundColor: Colors.amber,
                                      ),
                                    );
                                  }

                                  // Kích hoạt Dialog trạng thái thanh toán trực tuyến chuẩn logic của Web
                                  final dynamic lastBookingData = bookingProvider.lastCreatedBooking;
                                  print('=== LAST BOOKING DATA FOR RESOLUTION: $lastBookingData ===');
                                  
                                  // Trích xuất ticketId thực tế để polling trạng thái vé (Tránh lỗi HTTP 500 khi dùng sai Booking ID)
                                  final rawTicketId = lastBookingData != null 
                                      ? ((lastBookingData['ticket'] is Map ? lastBookingData['ticket']['id'] : null) ?? 
                                         lastBookingData['id'] ?? 
                                         lastBookingData['bookingId'])
                                      : null;
                                  final int? ticketIdForPolling = int.tryParse(rawTicketId?.toString() ?? '');
                                  print('=== RESOLVED TICKET ID FOR POLLING: $ticketIdForPolling ===');

                                  if (ticketIdForPolling != null) {
                                    final ticketProvider = Provider.of<TicketProvider>(context, listen: false);
                                    _showPaymentProcessingDialog(
                                      context: context,
                                      bookingId: ticketIdForPolling,
                                      bookingProvider: bookingProvider,
                                      ticketProvider: ticketProvider,
                                    );
                                  } else {
                                    bookingProvider.clearSelectionAfterBooking();
                                    context.push('/my-tickets');
                                  }
                                } else {
                                  // Thanh toán tiền mặt: vé GIỮ CHỖ, thu tiền tại quầy/khi lên xe (vẫn ở trạng thái chờ thanh toán)
                                  // Đánh dấu phía client: vé này thanh toán tiền mặt → coi như đã thanh toán, chỉ chờ nhà xe hoàn thành chuyến.
                                  final lastBooking =
                                      bookingProvider.lastCreatedBooking;
                                  if (lastBooking is Map) {
                                    final int? bId = int.tryParse(
                                        (lastBooking['bookingId'] ??
                                                lastBooking['id'] ??
                                                '')
                                            .toString());
                                    final int? tId = int.tryParse(
                                        ((lastBooking['ticket'] is Map
                                                    ? lastBooking['ticket']
                                                        ['id']
                                                    : null) ??
                                                '')
                                            .toString());
                                    await CashTicketsTracker().markCash(
                                      ticketId: tId,
                                      bookingId: bId,
                                    );
                                  }

                                  await _createUserNotification(
                                    title: 'Đặt vé tiền mặt thành công',
                                    body:
                                        'Vé của bạn đã được giữ chỗ. Vui lòng thanh toán tiền mặt tại quầy hoặc khi lên xe để hoàn tất.',
                                    data: 'cash-reserved',
                                  );
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Đặt vé thành công!'),
                                      backgroundColor: Color(0xff006e1c),
                                    ),
                                  );
                                  context.push('/boarding-pass');
                                }
                              } else {
                                // Thông báo: Giao dịch thất bại
                                await _createUserNotification(
                                  title: 'Giao dịch thất bại',
                                  body:
                                      'Giao dịch chưa hoàn tất. Vui lòng kiểm tra lại thông tin và thử lại.',
                                  data: 'payment-failed',
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(bookingProvider.errorMessage ?? 'Giao dịch thất bại. Vui lòng kiểm tra lại thông tin.'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff006e1c),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                              shadowColor: const Color(0xff006e1c).withOpacity(0.3),
                            ),
                            icon: const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
                            label: const Text(
                              'Thanh toán ngay',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProgressStepper() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Step 1: Chọn chuyến & Ghế (Completed)
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xff006e1c),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Chọn chuyến & Ghế',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Connecting line
              Container(
                width: 40,
                height: 2,
                color: const Color(0xff006e1c).withOpacity(0.3),
              ),
              const SizedBox(width: 12),
              // Step 2: Thanh toán (Active)
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xff006e1c), width: 2),
                    ),
                    child: const Center(
                      child: Text(
                        '2',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff006e1c),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Thanh toán',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff006e1c),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroInvoiceCard(
    BookingProvider bookingProvider,
    String companyName,
    String fromTo,
    String pickupStation,
    String dropoffStation,
    String formattedPrice,
  ) {
    final countdownText = _formatDuration(_countdownSeconds);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header box: Chi tiết hóa đơn
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xff006e1c),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Chi tiết hóa đơn',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                // Countdown timer pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Giữ chỗ $countdownText',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Body content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CHIỀU ĐI: ${fromTo.toUpperCase()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Color(0xff006e1c),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'GHẾ ĐÃ CHỌN',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          bookingProvider.selectedSeatNumbers.join(', '),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.deepOrange),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'SỐ LƯỢNG',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${bookingProvider.selectedSeatIds.length} Vé',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const Divider(height: 24, thickness: 0.5),
                
                _buildInvoiceRow('Nhà xe đối tác:', companyName),
                _buildInvoiceRow('Điểm đón:', '${bookingProvider.selectedPickup?['time'] ?? ''} - $pickupStation'),
                _buildInvoiceRow('Điểm trả:', '${bookingProvider.selectedDropoff?['time'] ?? ''} - $dropoffStation'),
                _buildInvoiceRow('Giá vé cơ bản:', '${(bookingProvider.totalPrice + bookingProvider.couponDiscount).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}đ'),
                if (bookingProvider.couponDiscount > 0)
                  _buildInvoiceRow('Mã giảm giá:', '-${bookingProvider.couponDiscount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}đ', isDiscount: true),
                
                const Divider(height: 24, thickness: 0.8),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tổng thanh toán',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.black87),
                    ),
                    Text(
                      formattedPrice,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDiscount ? Colors.red : Colors.black87,
              ),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherInput(BookingProvider bookingProvider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_offer_outlined, color: Color(0xff006e1c), size: 16),
              SizedBox(width: 8),
              Text(
                'Mã giảm giá',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _couponCodeController,
                    decoration: InputDecoration(
                      hintText: 'Nhập mã ưu đãi thủ công',
                      hintStyle: const TextStyle(fontSize: 13, color: Colors.black26),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xff006e1c), width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      fillColor: Colors.grey.shade50,
                      filled: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: () => _applyTypedCoupon(bookingProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5E5E5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text(
                    'Áp dụng',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalPaymentCard({
    required String value,
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff006e1c).withOpacity(0.04) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xff006e1c) : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xff006e1c).withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xff006e1c) : Colors.grey.shade300,
                  width: isSelected ? 5.5 : 1.5,
                ),
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Icon(
              icon,
              color: isSelected ? const Color(0xff006e1c) : Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? const Color(0xff006e1c) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
