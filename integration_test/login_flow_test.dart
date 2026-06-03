/// BusGo E2E Test 1: Login Flow
/// Test luồng đăng nhập hoàn chỉnh:
/// - Hiển thị trang login
/// - Nhập email + password
/// - Nhấn đăng nhập
/// - Xác minh chuyển sang trang Home
/// - Xác minh dữ liệu Home page load
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'app_test_helpers.dart';

void main() {
  initializeIntegrationTests();

  group('🔐 Login Flow Tests', () {
    testWidgets('TC01: Trang Login hiển thị đúng giao diện', (tester) async {
      testLog('TC01: Kiểm tra giao diện trang Login');
      await pumpApp(tester);

      // Xác minh trang login xuất hiện
      expect(find.text('Chào mừng trở lại'), findsOneWidget,
          reason: 'Phải hiển thị tiêu đề "Chào mừng trở lại"');

      // Xác minh có tab Email / Số điện thoại
      expect(find.text('Email'), findsWidgets,
          reason: 'Phải có tab Email');
      expect(find.text('Số điện thoại'), findsOneWidget,
          reason: 'Phải có tab Số điện thoại');

      // Xác minh có các input fields
      expect(find.byType(TextFormField), findsWidgets,
          reason: 'Phải có ít nhất 2 TextFormField (email + password)');

      // Xác minh có nút Đăng nhập
      expect(find.text('Đăng nhập'), findsOneWidget,
          reason: 'Phải có nút Đăng nhập');

      // Xác minh có link Tạo tài khoản
      expect(find.text('Tạo tài khoản ngay'), findsOneWidget,
          reason: 'Phải có link đăng ký tài khoản');

      testLog('TC01: ✅ PASSED - Giao diện Login hiển thị đúng');
    });

    testWidgets('TC02: Validation - email rỗng không cho submit', (tester) async {
      testLog('TC02: Kiểm tra validation email rỗng');
      await pumpApp(tester);

      // Chỉ nhập password, để trống email
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.last, testPassword);
      await tester.pump();

      // Nhấn đăng nhập
      final loginButton = find.widgetWithText(ElevatedButton, 'Đăng nhập');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // Kiểm tra hiện thông báo lỗi validation
      expect(find.text('Vui lòng nhập Email.'), findsOneWidget,
          reason: 'Phải hiện thông báo validation khi email rỗng');

      testLog('TC02: ✅ PASSED - Validation email rỗng hoạt động');
    });

    testWidgets('TC03: Validation - password rỗng không cho submit', (tester) async {
      testLog('TC03: Kiểm tra validation password rỗng');
      await pumpApp(tester);

      // Chỉ nhập email, để trống password
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, testEmail);
      await tester.pump();

      // Nhấn đăng nhập
      final loginButton = find.widgetWithText(ElevatedButton, 'Đăng nhập');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // Kiểm tra hiện thông báo lỗi validation
      expect(find.text('Vui lòng nhập mật khẩu.'), findsOneWidget,
          reason: 'Phải hiện thông báo validation khi password rỗng');

      testLog('TC03: ✅ PASSED - Validation password rỗng hoạt động');
    });

    testWidgets('TC04: Đăng nhập thành công → chuyển đến Home', (tester) async {
      testLog('TC04: Test đăng nhập thật với API');
      await pumpApp(tester);

      // Thực hiện login
      final success = await performLogin(tester);
      expect(success, isTrue, reason: 'Hàm performLogin phải tìm và nhấn được nút');

      // Đợi API và navigation
      await tester.pumpAndSettle(longApiWait);

      // Xác minh đã chuyển sang Home page
      final onHome = isOnHomePage(tester);
      expect(onHome, isTrue,
          reason: 'Sau khi đăng nhập thành công, phải chuyển sang trang Home');

      // Xác minh có BottomNavigationBar
      expect(find.byType(BottomNavigationBar), findsOneWidget,
          reason: 'Trang Home phải có BottomNavigationBar');

      testLog('TC04: ✅ PASSED - Đăng nhập thành công, chuyển sang Home');
    });
  });
}
