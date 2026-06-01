import 'package:flutter_test/flutter_test.dart';
import 'package:busgo_mobile/core/api/rating_service.dart';

/// Helper local: tính avg rating từ list comments — phản chiếu logic trong RatingService.
double _avg(List<RatingComment> list) {
  if (list.isEmpty) return 0;
  final sum = list.fold<int>(0, (acc, c) => acc + c.rating);
  return double.parse((sum / list.length).toStringAsFixed(1));
}

/// Helper local: validate review form theo spec
/// - rating ∈ [1..5]
/// - comment.trim() rỗng HOẶC độ dài >= 10
String? validateReview({required int rating, String? comment}) {
  if (rating < 1 || rating > 5) {
    return 'Vui lòng chọn số sao từ 1 đến 5.';
  }
  final trimmed = (comment ?? '').trim();
  if (trimmed.isNotEmpty && trimmed.length < 10) {
    return 'Nhận xét phải để trống hoặc dài tối thiểu 10 ký tự.';
  }
  return null;
}

void main() {
  group('RatingComment.fromJson', () {
    test('Parse đầy đủ các field chuẩn', () {
      final c = RatingComment.fromJson({
        'id': 1,
        'rating': 5,
        'comment': 'Xe sạch, tài xế nhiệt tình',
        'reviewerName': 'Nguyễn A',
        'createdAt': '2026-05-20T10:00:00Z',
      });
      expect(c.id, 1);
      expect(c.rating, 5);
      expect(c.comment, 'Xe sạch, tài xế nhiệt tình');
      expect(c.reviewerName, 'Nguyễn A');
      expect(c.createdAt, isNotNull);
      expect(c.createdAt!.year, 2026);
    });

    test('Hỗ trợ fallback nhiều tên trường', () {
      final c = RatingComment.fromJson({
        'id': '7',
        'stars': 4,
        'content': 'OK',
        'fullName': 'Trần B',
        'created_at': '2026-05-22T08:00:00Z',
      });
      expect(c.id, 7);
      expect(c.rating, 4);
      expect(c.comment, 'OK');
      expect(c.reviewerName, 'Trần B');
      expect(c.createdAt, isNotNull);
    });

    test('Default về 0 và "Khách hàng" khi thiếu dữ liệu', () {
      final c = RatingComment.fromJson({});
      expect(c.id, 0);
      expect(c.rating, 0);
      expect(c.comment, '');
      expect(c.reviewerName, 'Khách hàng');
      expect(c.createdAt, isNull);
    });

    test('Clamp rating vào [0, 5] khi server trả số bất thường', () {
      final c = RatingComment.fromJson({'id': 1, 'rating': 99});
      expect(c.rating, 5);
    });
  });

  group('Validate review form', () {
    test('Sao hợp lệ + comment rỗng → pass', () {
      expect(validateReview(rating: 5, comment: ''), isNull);
      expect(validateReview(rating: 1, comment: '   '), isNull);
    });

    test('Sao ngoài 1..5 → fail', () {
      expect(validateReview(rating: 0), isNotNull);
      expect(validateReview(rating: 6), isNotNull);
      expect(validateReview(rating: -1), isNotNull);
    });

    test('Comment 1..9 ký tự → fail', () {
      expect(validateReview(rating: 5, comment: 'Xe sạch'), isNotNull);
      expect(validateReview(rating: 5, comment: '123456789'), isNotNull);
    });

    test('Comment đúng 10 ký tự → pass', () {
      expect(validateReview(rating: 5, comment: '1234567890'), isNull);
    });

    test('Comment > 10 ký tự → pass', () {
      expect(
        validateReview(
            rating: 4, comment: 'Chuyến đi rất tuyệt, tài xế nhiệt tình.'),
        isNull,
      );
    });

    test('Comment chỉ chứa khoảng trắng vẫn coi là rỗng → pass', () {
      expect(validateReview(rating: 5, comment: '       '), isNull);
    });
  });

  group('Average rating mapping', () {
    test('List rỗng → 0', () {
      expect(_avg([]), 0);
    });

    test('Trung bình đúng 1 chữ số thập phân', () {
      final list = [
        RatingComment(id: 1, rating: 5, comment: '', reviewerName: 'a'),
        RatingComment(id: 2, rating: 4, comment: '', reviewerName: 'b'),
        RatingComment(id: 3, rating: 5, comment: '', reviewerName: 'c'),
      ];
      expect(_avg(list), 4.7);
    });

    test('Tất cả 5 sao → 5.0', () {
      final list = List.generate(
        5,
        (i) => RatingComment(id: i, rating: 5, comment: '', reviewerName: 'a'),
      );
      expect(_avg(list), 5.0);
    });

    test('Tất cả 1 sao → 1.0', () {
      final list = [
        RatingComment(id: 1, rating: 1, comment: '', reviewerName: 'a'),
        RatingComment(id: 2, rating: 1, comment: '', reviewerName: 'b'),
      ];
      expect(_avg(list), 1.0);
    });
  });
}
