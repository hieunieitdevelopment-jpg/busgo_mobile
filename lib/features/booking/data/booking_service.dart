import 'package:dio/dio.dart';
import 'package:busgo_mobile/core/api/api_client.dart';

class BookingService {
  final ApiClient _apiClient = ApiClient();

  // Tìm lịch trình chuyến xe (Khớp với GET /customer/trip-schedule)
  Future<Response> getTripSchedules({
    String? from,
    String? to,
    String? date,
    int limit = 10,
    int? next,
    String orderBy = 'asc',
    String? companyId,
  }) async {
    final Map<String, dynamic> params = {
      'limit': limit,
      'orderBy': orderBy,
    };
    if (from != null && from.isNotEmpty) {
      params['from'] = from;
    }
    if (to != null && to.isNotEmpty) {
      params['to'] = to;
    }
    if (date != null && date.isNotEmpty) {
      params['date'] = date;
    }
    if (next != null) {
      params['next'] = next;
    }
    if (companyId != null && companyId.isNotEmpty) {
      params['companyId'] = companyId;
    }

    return await _apiClient.dio.get(
      '/customer/trip-schedule',
      queryParameters: params,
    );
  }

  // Lấy danh sách điểm đón (Khớp với GET /customer/trip-schedule/{id}/pickup)
  Future<Response> getPickupPoints(int tripScheduleId) async {
    return await _apiClient.dio.get('/customer/trip-schedule/$tripScheduleId/pickup');
  }

  // Lấy danh sách điểm trả (Khớp với GET /customer/trip-schedule/{id}/dropoff)
  Future<Response> getDropoffPoints({
    required int tripScheduleId,
    required int fromStationId,
    required int stopOrder,
  }) async {
    return await _apiClient.dio.get(
      '/customer/trip-schedule/$tripScheduleId/dropoff',
      queryParameters: {
        'fromStationId': fromStationId,
        'stopOrder': stopOrder,
      },
    );
  }

  // Lấy sơ đồ ghế theo tripId (Khớp với GET /customer/trip/{id}/seat)
  Future<Response> getTripSeats({
    required int tripId,
    required int stopOrderPickup,
    required int stopOrderDropoff,
  }) async {
    return await _apiClient.dio.get(
      '/customer/trip/$tripId/seat',
      queryParameters: {
        'stopOrderPickup': stopOrderPickup,
        'stopOrderDropoff': stopOrderDropoff,
      },
    );
  }

  // Giữ chỗ tạm thời (Khớp 100% với POST /customer/trip-schedule/prepare)
  Future<Response> prepareTrip({
    required int scheduleId,
    required int companyId,
    required String departureDate,
  }) async {
    return await _apiClient.dio.post(
      '/customer/trip-schedule/prepare',
      data: {
        'scheduleId': scheduleId,
        'companyId': companyId,
        'departureDate': departureDate,
      },
    );
  }

  // Lấy danh sách voucher áp dụng cho đơn hàng (Khớp với GET /customer/coupon)
  Future<Response> getCoupons({
    int? next,
    required double orderTotal,
  }) async {
    final Map<String, dynamic> params = {
      'orderTotal': orderTotal,
    };
    if (next != null) {
      params['next'] = next;
    }
    return await _apiClient.dio.get(
      '/customer/coupon',
      queryParameters: params,
    );
  }

  // Kiểm tra tính hợp lệ của voucher (Khớp với GET /customer/coupon/check)
  Future<Response> checkCoupon({
    required String code,
    required int couponId,
    required double orderTotal,
  }) async {
    return await _apiClient.dio.get(
      '/customer/coupon/check',
      queryParameters: {
        'code': code,
        'id': couponId,
        'orderTotal': orderTotal,
      },
    );
  }

  // Tạo đơn đặt vé chốt thanh toán (Khớp 100% với POST /customer/booking)
  Future<Response> createBooking({
    required int? couponId,
    required String type, // 'one_way' hoặc 'round_trip'
    required Map<String, dynamic> outBound,
    Map<String, dynamic>? returnBound,
  }) async {
    final Map<String, dynamic> data = {
      'type': type,
      'outBound': outBound,
    };
    if (couponId != null) {
      data['couponId'] = couponId;
    }
    if (returnBound != null) {
      data['returnBound'] = returnBound;
    }

    return await _apiClient.dio.post(
      '/customer/booking',
      data: data,
    );
  }

  // Đăng ký phương thức thanh toán cho đơn hàng (Khớp 100% với POST /payment/method?id={id}&method={method})
  Future<Response> createPaymentMethod({
    required int bookingId,
    required String method, // 'vnpay', 'stripe', 'cash'
  }) async {
    return await _apiClient.dio.post(
      '/payment/method',
      data: {}, // Gửi body rỗng để tránh lỗi 500 do body-parser trên Backend crash khi thiếu body ở POST
      queryParameters: {
        'id': bookingId,
        'method': method,
      },
    );
  }
}
