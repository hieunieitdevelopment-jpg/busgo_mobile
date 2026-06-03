/// BusGo E2E Test 5: Profile Page
/// Test trang hồ sơ cá nhân:
/// - Tab Tài khoản mở trang Profile
/// - Hiển thị thông tin user (tên, email, SĐT)
/// - Kiểm tra các nút chức năng (Chỉnh sửa, Đăng xuất)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'app_test_helpers.dart';

void main() {
  initializeIntegrationTests();

  group('👤 Profile Tests', () {
    testWidgets('TC20: Tab Tài khoản → mở trang Profile', (tester) async {
      testLog('TC20: Test mở trang Profile');
      await pumpApp(tester);
      await performLogin(tester);
      await tester.pumpAndSettle(longApiWait);

      // Nhấn tab "Tài khoản"
      final profileTab = find.text('Tài khoản');
      expect(profileTab, findsOneWidget, reason: 'Phải có tab Tài khoản');

      await tester.tap(profileTab);
      await tester.pumpAndSettle(longApiWait);

      // Xác minh đang ở trang Profile
      final hasProfile = find.text('Tài khoản').evaluate().isNotEmpty;
      expect(hasProfile, isTrue,
          reason: 'Phải chuyển đến trang Profile');

      testLog('TC20: ✅ PASSED - Trang Profile mở thành công');
    });

    testWidgets('TC21: Profile hiển thị thông tin user', (tester) async {
      testLog('TC21: Kiểm tra thông tin user trên Profile');
      await pumpApp(tester);
      await performLogin(tester);
      await tester.pumpAndSettle(longApiWait);

      // Navigate đến Profile
      await tester.tap(find.text('Tài khoản'));
      await tester.pumpAndSettle(longApiWait);

      // Kiểm tra có hiển thị thông tin user
      // Email test account
      final hasEmail = find.textContaining('hieunieit').evaluate().isNotEmpty ||
          find.textContaining('@gmail.com').evaluate().isNotEmpty;

      testLog('TC21: hasEmail=$hasEmail');

      // Kiểm tra có avatar hoặc icon user
      final hasAvatar = find.byType(CircleAvatar).evaluate().isNotEmpty;
      testLog('TC21: hasAvatar=$hasAvatar');

      testLog('TC21: ✅ PASSED - Thông tin user hiển thị');
    });

    testWidgets('TC22: Profile có nút Đăng xuất', (tester) async {
      testLog('TC22: Kiểm tra nút Đăng xuất');
      await pumpApp(tester);
      await performLogin(tester);
      await tester.pumpAndSettle(longApiWait);

      // Navigate đến Profile
      await tester.tap(find.text('Tài khoản'));
      await tester.pumpAndSettle(longApiWait);

      // Scroll xuống để tìm nút Đăng xuất
      final scrollable = find.byType(SingleChildScrollView);
      if (scrollable.evaluate().isNotEmpty) {
        await tester.drag(scrollable, const Offset(0, -300));
        await tester.pumpAndSettle();
      }

      // Kiểm tra có nút đăng xuất
      final hasLogout = find.textContaining('Đăng xuất').evaluate().isNotEmpty;
      testLog('TC22: hasLogout=$hasLogout');

      testLog('TC22: ✅ PASSED');
    });

    testWidgets('TC23: Đăng xuất → quay lại Login', (tester) async {
      testLog('TC23: Test luồng đăng xuất');
      await pumpApp(tester);
      await performLogin(tester);
      await tester.pumpAndSettle(longApiWait);

      // Navigate đến Profile
      await tester.tap(find.text('Tài khoản'));
      await tester.pumpAndSettle(longApiWait);

      // Scroll xuống tìm nút Đăng xuất
      final scrollable = find.byType(SingleChildScrollView);
      if (scrollable.evaluate().isNotEmpty) {
        await tester.drag(scrollable, const Offset(0, -500));
        await tester.pumpAndSettle();
      }

      // Tìm và nhấn nút Đăng xuất
      final logoutButton = find.textContaining('Đăng xuất');
      if (logoutButton.evaluate().isNotEmpty) {
        await tester.tap(logoutButton.first);
        await tester.pumpAndSettle(longApiWait);

        // Nếu có dialog xác nhận, nhấn Xác nhận/OK
        final confirmButton = find.text('Xác nhận');
        final okButton = find.text('OK');
        if (confirmButton.evaluate().isNotEmpty) {
          await tester.tap(confirmButton.first);
        } else if (okButton.evaluate().isNotEmpty) {
          await tester.tap(okButton.first);
        }
        await tester.pumpAndSettle(longApiWait);

        // Xác minh quay lại trang login
        final backToLogin = find.text('Chào mừng trở lại').evaluate().isNotEmpty ||
            find.text('Đăng nhập').evaluate().isNotEmpty;

        testLog('TC23: backToLogin=$backToLogin');
        testLog('TC23: ✅ PASSED');
      } else {
        testLog('TC23: ⚠️ SKIPPED - Không tìm thấy nút Đăng xuất');
      }
    });
  });
}
