import 'package:dio/dio.dart';
import 'package:busgo_mobile/core/api/api_client.dart';

class NotificationService {
  final ApiClient _apiClient = ApiClient();

  // GET /auth/notification: Lấy danh sách thông báo
  Future<Response> getNotifications({
    int limit = 20,
    int? status,
    int? next,
  }) async {
    final Map<String, dynamic> queryParams = {
      'limit': limit,
    };
    if (status != null) {
      queryParams['status'] = status;
    }
    if (next != null) {
      queryParams['next'] = next;
    }

    return await _apiClient.dio.get(
      '/auth/notification',
      queryParameters: queryParams,
    );
  }

  // POST /auth/notification: Tạo thông báo mới (nếu cần gửi)
  Future<Response> createNotification({
    required int userId,
    required String title,
    required String body,
    String? data,
  }) async {
    final Map<String, dynamic> payload = {
      'userId': userId,
      'title': title,
      'body': body,
    };
    if (data != null) {
      payload['data'] = data;
    }

    return await _apiClient.dio.post(
      '/auth/notification',
      data: payload,
    );
  }

  // PUT /auth/notification/:id/read: Đánh dấu đã đọc thông báo
  Future<Response> markNotificationRead(int id) async {
    return await _apiClient.dio.put('/auth/notification/$id/read');
  }
}
