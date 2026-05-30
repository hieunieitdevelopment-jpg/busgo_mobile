import 'package:dio/dio.dart';
import 'package:busgo_mobile/core/api/api_client.dart';

/// Một mục đánh giá nhà xe (chuẩn hoá từ nhiều tên trường có thể có).
class RatingComment {
  final int id;
  final int rating;
  final String comment;
  final String reviewerName;
  final DateTime? createdAt;

  RatingComment({
    required this.id,
    required this.rating,
    required this.comment,
    required this.reviewerName,
    this.createdAt,
  });

  factory RatingComment.fromJson(Map<String, dynamic> json) {
    final raw = json['rating'] ?? json['stars'] ?? json['score'] ?? 0;
    final int rating = raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;

    final dynamic created = json['createdAt'] ??
        json['created_at'] ??
        json['createdDate'] ??
        json['date'];
    DateTime? parsed;
    if (created != null) {
      parsed = DateTime.tryParse(created.toString());
    }

    return RatingComment(
      id: int.tryParse((json['id'] ?? '0').toString()) ?? 0,
      rating: rating.clamp(0, 5),
      comment: (json['comment'] ?? json['content'] ?? '').toString(),
      reviewerName: (json['reviewerName'] ??
              json['userName'] ??
              json['fullName'] ??
              json['customerName'] ??
              'Khách hàng')
          .toString(),
      createdAt: parsed,
    );
  }
}

/// Trang dữ liệu trả về từ GET /customer/trip-schedule/rating.
class RatingPage {
  final List<RatingComment> comments;
  final String? next;

  RatingPage({required this.comments, this.next});

  bool get hasMore => next != null && next!.isNotEmpty;
}

/// Tổng hợp đánh giá theo nhà xe (avg + total) — phục vụ Home/Companies/Routes.
class CompanyRatingSummary {
  final int companyId;
  final double avgRating;
  final int totalReviews;

  CompanyRatingSummary({
    required this.companyId,
    required this.avgRating,
    required this.totalReviews,
  });

  CompanyRatingSummary.empty(this.companyId)
      : avgRating = 0.0,
        totalReviews = 0;
}

class _CacheEntry {
  final RatingPage page;
  final DateTime fetchedAt;
  _CacheEntry(this.page, this.fetchedAt);
}

/// Service truy cập 2 endpoint Rating + 1 endpoint Notification (best-effort).
class RatingService {
  RatingService._internal();
  static final RatingService _instance = RatingService._internal();
  factory RatingService() => _instance;

  final ApiClient _apiClient = ApiClient();

  /// Cache theo key "$companyId|$limit|$star" để giảm gọi N+1 cho list.
  final Map<String, _CacheEntry> _cache = {};
  static const Duration _staleTime = Duration(seconds: 60);

  String _cacheKey(int companyId, int limit, int? star) =>
      '$companyId|$limit|${star ?? 0}';

  /// POST /customer/ticket/rating — Gửi đánh giá chuyến đi.
  /// [tripId] phải là tripId/tripScheduleId, KHÔNG phải ticketId.
  Future<Response> rateTicket({
    required int tripId,
    required int rating,
    String? comment,
  }) async {
    final Map<String, dynamic> payload = {
      'tripId': tripId,
      'rating': rating,
    };
    final String trimmed = (comment ?? '').trim();
    if (trimmed.isNotEmpty) {
      payload['comment'] = trimmed;
    }
    return _apiClient.dio.post('/customer/ticket/rating', data: payload);
  }

  /// GET /customer/trip-schedule/rating — Lấy danh sách đánh giá nhà xe.
  /// Có cache 60s cho lần gọi đầu tiên (next = null).
  Future<RatingPage> getTripScheduleRatings({
    required int companyId,
    int limit = 10,
    int? star,
    String? next,
  }) async {
    if (next == null) {
      final key = _cacheKey(companyId, limit, star);
      final cached = _cache[key];
      if (cached != null &&
          DateTime.now().difference(cached.fetchedAt) < _staleTime) {
        return cached.page;
      }
    }

    final Map<String, dynamic> qp = {
      'companyId': companyId,
      'limit': limit,
    };
    if (star != null && star >= 1 && star <= 5) qp['star'] = star;
    if (next != null && next.isNotEmpty) qp['next'] = next;

    final res = await _apiClient.dio.get(
      '/customer/trip-schedule/rating',
      queryParameters: qp,
    );

    final data = res.data;
    final List<dynamic> rawList = (data is Map ? data['comments'] : null) ?? [];
    final List<RatingComment> items = rawList
        .whereType<Map>()
        .map((m) => RatingComment.fromJson(m.cast<String, dynamic>()))
        .toList();
    final dynamic nextRaw = data is Map ? data['next'] : null;
    final String? nextCursor =
        (nextRaw == null || nextRaw == false) ? null : nextRaw.toString();

    final page = RatingPage(comments: items, next: nextCursor);

    if (next == null) {
      _cache[_cacheKey(companyId, limit, star)] = _CacheEntry(page, DateTime.now());
    }
    return page;
  }

  /// Tóm tắt đánh giá nhà xe (avg + total). Tính từ tối đa [scanLimit] comment đầu tiên.
  /// Chú ý: API hiện không trả `summary`, nên tính phía client.
  Future<CompanyRatingSummary> getCompanySummary({
    required int companyId,
    int scanLimit = 100,
  }) async {
    try {
      final page = await getTripScheduleRatings(
        companyId: companyId,
        limit: scanLimit,
      );
      if (page.comments.isEmpty) {
        return CompanyRatingSummary.empty(companyId);
      }
      final sum =
          page.comments.fold<int>(0, (acc, c) => acc + c.rating);
      final avg = sum / page.comments.length;
      return CompanyRatingSummary(
        companyId: companyId,
        avgRating: double.parse(avg.toStringAsFixed(1)),
        totalReviews: page.comments.length,
      );
    } catch (_) {
      return CompanyRatingSummary.empty(companyId);
    }
  }

  /// Tóm tắt nhiều nhà xe song song — tránh N+1, dùng cho list trips/companies.
  Future<Map<int, CompanyRatingSummary>> getSummariesParallel({
    required List<int> companyIds,
    int scanLimit = 100,
  }) async {
    final unique = companyIds.toSet().toList();
    if (unique.isEmpty) return {};
    final futures =
        unique.map((id) => getCompanySummary(companyId: id, scanLimit: scanLimit));
    final results = await Future.wait(futures);
    return {for (final s in results) s.companyId: s};
  }

  /// Xoá cache (gọi sau khi gửi đánh giá thành công để refresh list).
  void invalidateCompany(int companyId) {
    _cache.removeWhere((k, _) => k.startsWith('$companyId|'));
  }
}
