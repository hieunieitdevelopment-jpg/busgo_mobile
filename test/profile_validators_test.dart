import 'package:flutter_test/flutter_test.dart';
import 'package:busgo_mobile/features/profile/presentation/utils/profile_validators.dart';

void main() {
  group('ProfileValidators.isValidEmail', () {
    test('Email hợp lệ', () {
      expect(ProfileValidators.isValidEmail('a@b.co'), isTrue);
      expect(ProfileValidators.isValidEmail('user.name+tag@domain.io'), isTrue);
    });
    test('Email không hợp lệ', () {
      expect(ProfileValidators.isValidEmail(''), isFalse);
      expect(ProfileValidators.isValidEmail('abc'), isFalse);
      expect(ProfileValidators.isValidEmail('a@b'), isFalse);
      expect(ProfileValidators.isValidEmail('a @b.com'), isFalse);
    });
  });

  group('ProfileValidators.isValidPhone', () {
    test('Số bắt đầu 0 + 9 chữ số', () {
      expect(ProfileValidators.isValidPhone('0901234567'), isTrue);
      expect(ProfileValidators.isValidPhone('0961637041'), isTrue);
    });
    test('Số bắt đầu +84 + 9 chữ số', () {
      expect(ProfileValidators.isValidPhone('+84901234567'), isTrue);
    });
    test('Số sai định dạng', () {
      expect(ProfileValidators.isValidPhone('090123'), isFalse);
      expect(ProfileValidators.isValidPhone('1234567890'), isFalse);
      expect(ProfileValidators.isValidPhone('+8190123456'), isFalse);
      expect(ProfileValidators.isValidPhone(''), isFalse);
    });
  });

  group('ProfileValidators.isValidOtp', () {
    test('OTP 4-8 chữ số', () {
      expect(ProfileValidators.isValidOtp('1234'), isTrue);
      expect(ProfileValidators.isValidOtp('123456'), isTrue);
      expect(ProfileValidators.isValidOtp('12345678'), isTrue);
    });
    test('OTP sai', () {
      expect(ProfileValidators.isValidOtp('123'), isFalse);
      expect(ProfileValidators.isValidOtp('123456789'), isFalse);
      expect(ProfileValidators.isValidOtp('12ab56'), isFalse);
      expect(ProfileValidators.isValidOtp(''), isFalse);
    });
  });

  group('resolveCooldownDeadline', () {
    test('Số ms (>1e12) cộng 12 giờ', () {
      const ms = 1717000000000;
      final d = resolveCooldownDeadline(ms);
      expect(d, isNotNull);
      expect(
        d!.millisecondsSinceEpoch,
        equals(ms + 12 * 3600 * 1000),
      );
    });
    test('Số seconds (<1e12) tự nhân 1000', () {
      const sec = 1717000000;
      final d = resolveCooldownDeadline(sec);
      expect(d, isNotNull);
      expect(
        d!.millisecondsSinceEpoch,
        equals(sec * 1000 + 12 * 3600 * 1000),
      );
    });
    test('Chuỗi ISO date', () {
      final d = resolveCooldownDeadline('2026-01-01T00:00:00Z');
      expect(d, isNotNull);
      expect(d!.year, 2026);
    });
    test('Null hoặc rỗng → null', () {
      expect(resolveCooldownDeadline(null), isNull);
      expect(resolveCooldownDeadline(''), isNull);
      expect(resolveCooldownDeadline('not-a-date'), isNull);
    });
  });

  group('cooldownDeadlineForField', () {
    test('Đọc field email từ lastChangeEmail (camelCase)', () {
      final user = {'lastChangeEmail': 1717000000000};
      final d = cooldownDeadlineForField(user: user, field: 'email');
      expect(d, isNotNull);
    });
    test('Fallback về lastChangeContact', () {
      final user = {'lastChangeContact': 1717000000000};
      final dEmail = cooldownDeadlineForField(user: user, field: 'email');
      final dPhone = cooldownDeadlineForField(user: user, field: 'phone');
      expect(dEmail, isNotNull);
      expect(dPhone, isNotNull);
    });
    test('User null → null', () {
      expect(cooldownDeadlineForField(user: null, field: 'email'), isNull);
    });
    test('Không field nào → null', () {
      expect(cooldownDeadlineForField(user: {}, field: 'email'), isNull);
    });
  });

  group('formatRemaining', () {
    test('Cả giờ và phút', () {
      expect(formatRemaining(const Duration(hours: 5, minutes: 30)),
          '5 giờ 30 phút');
    });
    test('Chỉ giờ', () {
      expect(formatRemaining(const Duration(hours: 3)), '3 giờ');
    });
    test('Chỉ phút', () {
      expect(formatRemaining(const Duration(minutes: 45)), '45 phút');
    });
    test('Dưới 1 phút', () {
      expect(formatRemaining(const Duration(seconds: 30)), 'dưới 1 phút');
    });
    test('Đã hết hoặc âm', () {
      expect(formatRemaining(Duration.zero), '');
      expect(formatRemaining(const Duration(seconds: -1)), '');
    });
  });
}
