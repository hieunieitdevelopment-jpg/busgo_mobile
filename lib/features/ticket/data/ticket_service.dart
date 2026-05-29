import 'package:dio/dio.dart';
import 'package:busgo_mobile/core/api/api_client.dart';

class TicketService {
  final ApiClient _apiClient = ApiClient();

  // Lấy danh sách vé đặt của khách hàng (Khớp với GET /customer/ticket)
  Future<Response> getTickets({
    int limit = 10,
    int? next,
    String? type,
    String? status,
  }) async {
    final Map<String, dynamic> params = {
      'limit': limit,
    };
    if (next != null) params['next'] = next;
    if (type != null) params['type'] = type;
    if (status != null) params['status'] = status;

    return await _apiClient.dio.get(
      '/customer/ticket',
      queryParameters: params,
    );
  }

  // Xem chi tiết một vé cụ thể (Khớp với GET /customer/ticket/{id})
  Future<Response> getTicketDetail(int id) async {
    return await _apiClient.dio.get('/customer/ticket/$id');
  }

  // Hủy vé đặt (Khớp với DELETE /customer/ticket/{id})
  Future<Response> cancelTicket(int id) async {
    return await _apiClient.dio.delete('/customer/ticket/$id');
  }

  // Gửi đánh giá chấm điểm chuyến đi (Khớp với POST /customer/ticket/rating)
  Future<Response> rateTicket({
    required int tripId,
    required int rating, // 1 -> 5 stars
    required String comment,
  }) async {
    return await _apiClient.dio.post(
      '/customer/ticket/rating',
      data: {
        'tripId': tripId,
        'rating': rating,
        'comment': comment,
      },
    );
  }

  // Lấy các bình luận đánh giá của lịch trình nhà xe (Khớp với GET /customer/trip-schedule/rating)
  Future<Response> getTripRatings({
    required int companyId,
    int limit = 10,
    int? star,
    int? next,
  }) async {
    final Map<String, dynamic> params = {
      'companyId': companyId,
      'limit': limit,
    };
    if (star != null) params['star'] = star;
    if (next != null) params['next'] = next;

    return await _apiClient.dio.get(
      '/customer/trip-schedule/rating',
      queryParameters: params,
    );
  }
}
