import 'package:dio/dio.dart';
import 'package:busgo_mobile/core/api/api_client.dart';

class PublicService {
  final ApiClient _apiClient = ApiClient();

  // Lấy danh sách các nhà xe đối tác (Khớp với GET /public/company)
  Future<Response> getCompanies() async {
    return await _apiClient.dio.get('/public/company');
  }

  // Lấy danh sách các khuyến mãi mới nhất (Khớp với GET /public/promotion-new)
  Future<Response> getPromotions({int limit = 10, int page = 1}) async {
    return await _apiClient.dio.get(
      '/public/promotion-new',
      queryParameters: {
        'limit': limit,
        'page': page,
      },
    );
  }
}
