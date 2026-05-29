import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:busgo_mobile/features/booking/data/booking_service.dart';

class BookingProvider extends ChangeNotifier {
  final BookingService _bookingService = BookingService();

  double _parsePrice(dynamic schedule) {
    if (schedule == null) return 0.0;
    
    dynamic raw = schedule['price'] ?? 
                  schedule['ticketPrice'] ?? 
                  schedule['ticket_price'] ?? 
                  schedule['fare'] ??
                  schedule['pricePerSeat'] ??
                  schedule['price_per_seat'];
                  
    if (raw == null && schedule['tripSchedule'] is Map) {
      final sMap = schedule['tripSchedule'] as Map;
      raw = sMap['price'] ?? 
            sMap['ticketPrice'] ?? 
            sMap['ticket_price'] ?? 
            sMap['fare'] ??
            sMap['pricePerSeat'] ??
            sMap['price_per_seat'];
    }
    
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();
    final String clean = raw.toString().replaceAll(RegExp('[^0-9]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  List<dynamic> _schedules = [];
  List<dynamic> _coupons = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Trạng thái tìm kiếm
  String _currentFrom = '';
  String _currentTo = '';
  String _currentDate = '';
  String _companyFilter = '';
  String _companyIdFilter = '';

  // Trạng thái vé được chọn
  dynamic _selectedSchedule;
  final Set<int> _selectedSeatIds = {};
  final Set<String> _selectedSeatNumbers = {};
  
  double _couponDiscount = 0.0;
  int? _couponId;
  String? _couponCode;

  // Trạng thái Điểm đón/trả và Sơ đồ ghế động từ API
  List<dynamic> _pickups = [];
  List<dynamic> _dropoffs = [];
  List<dynamic> _seats = [];
  dynamic _selectedPickup;
  dynamic _selectedDropoff;
  int? _tripId;
  bool _isLoadingSeats = false;
  bool _isLoadingStops = false;
  dynamic _lastCreatedBooking;
  String? _paymentUrl;
  
  List<dynamic> get schedules => _schedules;
  List<dynamic> get coupons => _coupons;
  bool get isLoading => _isLoading;
  String? get paymentUrl => _paymentUrl;
  String? get errorMessage => _errorMessage;

  String get currentFrom => _currentFrom;
  String get currentTo => _currentTo;
  String get currentDate => _currentDate;
  String get companyFilter => _companyFilter;
  String get companyIdFilter => _companyIdFilter;

  void setCompanyFilter(String filter, {String id = ''}) {
    _companyFilter = filter;
    _companyIdFilter = id;
    notifyListeners();
  }

  void clearCompanyFilter() {
    _companyFilter = '';
    _companyIdFilter = '';
    notifyListeners();
  }

  dynamic get selectedSchedule => _selectedSchedule;
  Set<int> get selectedSeatIds => _selectedSeatIds;
  Set<String> get selectedSeatNumbers => _selectedSeatNumbers;
  double get couponDiscount => _couponDiscount;
  int? get couponId => _couponId;
  String? get couponCode => _couponCode;

  List<dynamic> get pickups => _pickups;
  List<dynamic> get dropoffs => _dropoffs;
  List<dynamic> get seats => _seats;
  dynamic get selectedPickup => _selectedPickup;
  dynamic get selectedDropoff => _selectedDropoff;
  int? get tripId => _tripId;
  bool get isLoadingSeats => _isLoadingSeats;
  bool get isLoadingStops => _isLoadingStops;
  dynamic get lastCreatedBooking => _lastCreatedBooking;

  double get totalPrice {
    if (_selectedSchedule == null) return 0.0;
    // Lấy đơn giá theo điểm trả được chọn, fallback về giá mặc định của lịch trình
    final double pricePerSeat = _selectedDropoff != null
        ? double.tryParse(_selectedDropoff['price']?.toString() ?? '') ?? _parsePrice(_selectedSchedule)
        : _parsePrice(_selectedSchedule);
    final double subtotal = pricePerSeat * (_selectedSeatIds.isEmpty ? 1 : _selectedSeatIds.length);
    final double finalTotal = subtotal - _couponDiscount;
    return finalTotal < 0 ? 0.0 : finalTotal;
  }

  // Tìm kiếm lịch trình thật từ API (Có hỗ trợ lọc theo nhà xe đối tác)
  Future<bool> searchTrips({
    required String from,
    required String to,
    required String date,
    String? companyId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _schedules = [];
    _currentFrom = from;
    _currentTo = to;
    _currentDate = date;
    if (companyId != null) {
      _companyIdFilter = companyId;
    }
    notifyListeners();

    // Đồng bộ định dạng ngày YYYY-MM-DD cho API máy chủ
    String apiDate = date;
    try {
      final parts = date.split('/');
      if (parts.length == 3) {
        final day = parts[0].padLeft(2, '0');
        final month = parts[1].padLeft(2, '0');
        final year = parts[2];
        apiDate = '$year-$month-$day';
      }
    } catch (_) {}

    try {
      final response = await _bookingService.getTripSchedules(
        from: from,
        to: to,
        date: apiDate,
        limit: 100,
        companyId: companyId ?? _companyIdFilter,
      );
      
      final data = response.data;
      if (data != null) {
        _schedules = data['trip'] ?? data['data'] ?? [];
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('DioException: ', '');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Tải danh sách điểm đón (Pickups) và điểm trả mặc định (Dropoffs)
  Future<void> fetchStops() async {
    if (_selectedSchedule == null) return;
    _isLoadingStops = true;
    _errorMessage = null;
    _pickups = [];
    _dropoffs = [];
    _selectedPickup = null;
    _selectedDropoff = null;
    notifyListeners();

    try {
      final int scheduleId = int.tryParse((_selectedSchedule['id'] ?? _selectedSchedule['tripSchedule']?['id'] ?? '0').toString()) ?? 0;
      final pickupRes = await _bookingService.getPickupPoints(scheduleId);
      
      // Khớp với React client: trích xuất từ key 'tripStops' trước
      final dynamic rawPick = pickupRes.data;
      final List<dynamic> pickData = (rawPick is Map ? rawPick['tripStops'] ?? rawPick['data'] : null) ?? 
                                     (rawPick is List ? rawPick : []);

      if (pickData.isNotEmpty) {
        _pickups = pickData;
        // Chọn điểm đón đầu tiên làm mặc định
        _selectedPickup = pickData.first;

        // Tải điểm trả cho điểm đón này
        final dynamic pickupStationObj = _selectedPickup['station'];
        final int fromStationId = int.tryParse((_selectedPickup['stationId'] ?? _selectedPickup['station_id'] ?? (pickupStationObj is Map ? pickupStationObj['id'] ?? pickupStationObj['_id'] : '') ?? '0').toString()) ?? 0;
        final int stopOrder = int.tryParse((_selectedPickup['stopOrder'] ?? _selectedPickup['stop_order'] ?? '1').toString()) ?? 1;

        final dropoffRes = await _bookingService.getDropoffPoints(
          tripScheduleId: scheduleId,
          fromStationId: fromStationId,
          stopOrder: stopOrder,
        );
        
        final dynamic rawDrop = dropoffRes.data;
        final List<dynamic> dropData = (rawDrop is Map ? rawDrop['tripStops'] ?? rawDrop['data'] : null) ?? 
                                       (rawDrop is List ? rawDrop : []);

        if (dropData.isNotEmpty) {
          _dropoffs = dropData;
          // Chọn điểm trả cuối cùng làm mặc định (giống React Web Client)
          _selectedDropoff = dropData.last;

          // Sau khi có cả Điểm đón & trả -> Tải sơ đồ ghế thật ngay!
          await fetchSeats();
        }
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('DioException: ', '');
    }

    _isLoadingStops = false;
    notifyListeners();
  }

  // Chọn điểm đón mới
  Future<void> selectPickup(dynamic pickup) async {
    _selectedPickup = pickup;
    _dropoffs = [];
    _selectedDropoff = null;
    _seats = [];
    notifyListeners();

    try {
      final int scheduleId = int.tryParse((_selectedSchedule['id'] ?? _selectedSchedule['tripSchedule']?['id'] ?? '0').toString()) ?? 0;
      final dynamic pickupStationObj = pickup['station'];
      final int fromStationId = int.tryParse((pickup['stationId'] ?? pickup['station_id'] ?? (pickupStationObj is Map ? pickupStationObj['id'] ?? pickupStationObj['_id'] : '') ?? '0').toString()) ?? 0;
      final int stopOrder = int.tryParse((pickup['stopOrder'] ?? pickup['stop_order'] ?? '1').toString()) ?? 1;

      final dropoffRes = await _bookingService.getDropoffPoints(
        tripScheduleId: scheduleId,
        fromStationId: fromStationId,
        stopOrder: stopOrder,
      );
      
      final dynamic rawDrop = dropoffRes.data;
      final List<dynamic> dropData = (rawDrop is Map ? rawDrop['tripStops'] ?? rawDrop['data'] : null) ?? 
                                     (rawDrop is List ? rawDrop : []);

      if (dropData.isNotEmpty) {
        _dropoffs = dropData;
        _selectedDropoff = dropData.last;
        await fetchSeats();
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('DioException: ', '');
    }
    notifyListeners();
  }

  // Chọn điểm trả mới
  Future<void> selectDropoff(dynamic dropoff) async {
    _selectedDropoff = dropoff;
    notifyListeners();
    await fetchSeats();
  }

  // Tải sơ đồ ghế thật (GET /customer/trip/{id}/seat)
  Future<void> fetchSeats() async {
    if (_tripId == null || _selectedPickup == null || _selectedDropoff == null) return;
    _isLoadingSeats = true;
    _seats = [];
    notifyListeners();

    try {
      final int stopOrderPickup = int.tryParse((_selectedPickup['stopOrder'] ?? _selectedPickup['stop_order'] ?? '1').toString()) ?? 1;
      final int stopOrderDropoff = int.tryParse((_selectedDropoff['stopOrder'] ?? _selectedDropoff['stop_order'] ?? '2').toString()) ?? 2;

      final response = await _bookingService.getTripSeats(
        tripId: _tripId!,
        stopOrderPickup: stopOrderPickup,
        stopOrderDropoff: stopOrderDropoff,
      );
      
      final dynamic rawSeats = response.data;
      _seats = (rawSeats is Map ? rawSeats['seats'] ?? rawSeats['data'] : null) ?? 
               (rawSeats is List ? rawSeats : []);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('DioException: ', '');
    }

    _isLoadingSeats = false;
    notifyListeners();
  }

  // Lấy các mã giảm giá khả dụng của User (GET /customer/coupon)
  Future<void> fetchCoupons() async {
    if (_selectedSchedule == null) return;
    final double pricePerSeat = _selectedDropoff != null
        ? double.tryParse(_selectedDropoff['price']?.toString() ?? '') ?? _parsePrice(_selectedSchedule)
        : _parsePrice(_selectedSchedule);
    final double orderTotal = pricePerSeat * (_selectedSeatIds.isEmpty ? 1 : _selectedSeatIds.length);

    try {
      final response = await _bookingService.getCoupons(orderTotal: orderTotal);
      final data = response.data;
      if (data != null && data['coupons'] != null) {
        _coupons = data['coupons'];
        notifyListeners();
      }
    } catch (_) {}
  }

  // Chọn lịch trình chuyến xe
  void selectSchedule(dynamic schedule) {
    _selectedSchedule = schedule;
    _selectedSeatIds.clear();
    _selectedSeatNumbers.clear();
    _couponDiscount = 0.0;
    _couponId = null;
    _couponCode = null;
    
    // Clear dynamic states
    _pickups = [];
    _dropoffs = [];
    _seats = [];
    _selectedPickup = null;
    _selectedDropoff = null;
    _tripId = null;
    _lastCreatedBooking = null;

    notifyListeners();
    fetchCoupons();
  }

  // Chọn/Bỏ chọn ghế (Chỉ cho phép chọn 1 ghế duy nhất để đồng bộ React Web Client)
  void toggleSeat(int seatId, String seatNumber) {
    if (_selectedSeatIds.contains(seatId)) {
      _selectedSeatIds.clear();
      _selectedSeatNumbers.clear();
    } else {
      _selectedSeatIds.clear();
      _selectedSeatNumbers.clear();
      _selectedSeatIds.add(seatId);
      _selectedSeatNumbers.add(seatNumber);
    }
    notifyListeners();
  }

  // Kiểm tra mã giảm giá voucher thật (GET /customer/coupon/check)
  Future<bool> applyCouponCode(String code, int checkCouponId) async {
    if (_selectedSchedule == null || _selectedSeatIds.isEmpty) return false;
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final double pricePerSeat = _selectedDropoff != null
          ? double.tryParse(_selectedDropoff['price']?.toString() ?? '') ?? _parsePrice(_selectedSchedule)
          : _parsePrice(_selectedSchedule);
      final double subtotal = pricePerSeat * _selectedSeatIds.length;

      final response = await _bookingService.checkCoupon(
        code: code,
        couponId: checkCouponId,
        orderTotal: subtotal,
      );
      final data = response.data;

      if (data != null) {
        _couponDiscount = double.tryParse(data['discountAmount']?.toString() ?? '0') ?? 0.0;
        _couponId = checkCouponId;
        _couponCode = code;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('DioException: ', '');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Chuẩn bị đặt chỗ (POST /customer/trip-schedule/prepare)
  Future<bool> prepareBooking() async {
    if (_selectedSchedule == null) return false;
    _isLoading = true;
    _errorMessage = null;
    _tripId = null;
    notifyListeners();

    // Đồng bộ định dạng ngày sang YYYY-MM-DD
    String apiDate = _currentDate;
    try {
      final parts = _currentDate.split('/');
      if (parts.length == 3) {
        final day = parts[0].padLeft(2, '0');
        final month = parts[1].padLeft(2, '0');
        final year = parts[2];
        apiDate = '$year-$month-$day';
      }
    } catch (_) {}

    try {
      final int scheduleId = int.tryParse((_selectedSchedule['id'] ?? _selectedSchedule['tripSchedule']?['id'] ?? '0').toString()) ?? 0;
      final dynamic compObj = _selectedSchedule['company'] ?? (_selectedSchedule['tripSchedule'] is Map ? _selectedSchedule['tripSchedule']['company'] : null);
      final int companyId = int.tryParse((_selectedSchedule['companyId'] ?? 
                                          _selectedSchedule['company_id'] ?? 
                                          (_selectedSchedule['tripSchedule'] is Map ? _selectedSchedule['tripSchedule']['companyId'] ?? _selectedSchedule['tripSchedule']['company_id'] : null) ?? 
                                          (compObj is Map ? compObj['id'] ?? compObj['_id'] : '') ?? 
                                          '0').toString()) ?? 0;

      final response = await _bookingService.prepareTrip(
        scheduleId: scheduleId,
        companyId: companyId,
        departureDate: apiDate,
      );
      
      final data = response.data;
      if (data != null) {
        // Trích xuất tripId từ prepareTrip response
        final dynamic nestedData = data['data'];
        final int extractedTripId = int.tryParse((nestedData != null ? nestedData['id'] : data['id'] ?? '0').toString()) ?? 0;
        
        if (extractedTripId > 0) {
          _tripId = extractedTripId;
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('DioException: ', '');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Đặt vé chính thức chốt giao dịch (POST /customer/booking) và thanh toán (POST /payment/method)
  Future<bool> checkout({
    required String paymentMethod,
    required String fullName,
    required String phone,
    required String email,
  }) async {
    if (_selectedSchedule == null || _selectedSeatIds.isEmpty || _selectedPickup == null || _selectedDropoff == null || _tripId == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final dynamic compObj = _selectedSchedule['company'];
      final int companyId = int.tryParse((_selectedSchedule['companyId'] ?? _selectedSchedule['company_id'] ?? (compObj is Map ? compObj['id'] ?? compObj['_id'] : '') ?? '0').toString()) ?? 0;
      final int seatId = _selectedSeatIds.first;
      final dynamic pickupStationObj = _selectedPickup['station'];
      final int fromStationId = int.tryParse((_selectedPickup['stationId'] ?? _selectedPickup['station_id'] ?? (pickupStationObj is Map ? pickupStationObj['id'] ?? pickupStationObj['_id'] : '') ?? '0').toString()) ?? 0;
      
      final dynamic dropoffStationObj = _selectedDropoff['station'];
      final int toStationId = int.tryParse((_selectedDropoff['stationId'] ?? _selectedDropoff['station_id'] ?? (dropoffStationObj is Map ? dropoffStationObj['id'] ?? dropoffStationObj['_id'] : '') ?? '0').toString()) ?? 0;

      print('=== THÔNG TIN ĐẶT VÉ GỬI BACKEND ===');
      print('tripId (chuỗi prepareTrip): $_tripId');
      print('seatId: $seatId');
      print('fromStationId: $fromStationId');
      print('toStationId: $toStationId');
      print('companyId: $companyId');
      print('couponId: $_couponId');
      print('paymentMethod (sẽ gọi ở API 2): $paymentMethod');
      print('======================================');

      // Đồng bộ 100% với React Web: Chỉ gửi thông tin liên quan đến vé trong outBound, bỏ thông tin hành khách/paymentMethod gây lỗi 500
      final Map<String, dynamic> outBound = {
        'tripId': _tripId,
        'seatId': seatId,
        'fromStationId': fromStationId,
        'companyId': companyId,
        'toStationId': toStationId,
      };

      // 1. Tạo đặt vé (PENDING)
      final response = await _bookingService.createBooking(
        couponId: _couponId,
        type: 'one_way',
        outBound: outBound,
      );

      final rawData = response.data;
      if (rawData != null) {
        final data = rawData['data'] ?? rawData;
        _lastCreatedBooking = data;
        print('=== PHẢN HỒI TẠO ĐẶT VÉ THÀNH CÔNG ===');
        print(rawData);

        // Trích xuất bookingId/ticketId từ response giống hệt React Web client
        final rawId = data['bookingId'] ?? data['id'] ?? 
            (data['ticket'] is Map ? (data['ticket']['bookingId'] ?? data['ticket']['id']) : null);
        
        final int? bookingId = int.tryParse(rawId?.toString() ?? '');
        print('Trích xuất bookingId thành công: $bookingId');

        if (bookingId != null) {
          // 2. Gọi API xác thực/đăng ký phương thức thanh toán tương ứng (cash, stripe, vnpay)
          final String apiMethod = paymentMethod.toLowerCase();
          print('Bắt đầu gọi API đăng ký thanh toán: method=$apiMethod, bookingId=$bookingId');
          
          final paymentResponse = await _bookingService.createPaymentMethod(
            bookingId: bookingId,
            method: apiMethod,
          );

          print('=== ĐĂNG KÝ PHƯƠNG THỨC THANH TOÁN THÀNH CÔNG ===');
          print(paymentResponse.data);

          _paymentUrl = null;
          final dynamic payData = paymentResponse.data;
          if (payData != null) {
            if (payData is Map) {
              _paymentUrl = payData['paymentUrl'] ?? 
                            payData['url'] ?? 
                            (payData['data'] is Map ? payData['data']['paymentUrl'] ?? payData['data']['url'] : null);
            } else if (payData is String) {
              _paymentUrl = payData;
            }
          }
          print('Trích xuất paymentUrl thành công: $_paymentUrl');

          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          _errorMessage = 'Không tìm thấy mã đơn hàng trả về từ Backend.';
          print(_errorMessage);
        }
      }
    } catch (e) {
      if (e is DioException) {
        final resData = e.response?.data;
        _errorMessage = 'Lỗi [${e.response?.statusCode}]: ${resData is Map ? (resData['message'] ?? resData['error'] ?? resData.toString()) : (resData ?? e.message)}';
      } else {
        _errorMessage = e.toString().replaceAll('DioException: ', '');
      }
      print('=== CHECKOUT DIAL ERROR ===: $_errorMessage');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Reset luồng sau khi hoàn thành thanh toán
  void clearSelectionAfterBooking() {
    _selectedSeatIds.clear();
    _selectedSeatNumbers.clear();
    _couponDiscount = 0.0;
    _couponId = null;
    _couponCode = null;
    _selectedPickup = null;
    _selectedDropoff = null;
    _tripId = null;
    _paymentUrl = null;
    notifyListeners();
  }
}
