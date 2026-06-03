/// BusGo E2E Integration Test Helpers
/// Các hàm hỗ trợ dùng chung cho tất cả integration tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:busgo_mobile/main.dart';
import 'package:busgo_mobile/features/auth/presentation/providers/auth_provider.dart';

/// Thông tin tài khoản test
const String testEmail = 'hieunieitdevelopment@gmail.com';
const String testPassword = 'Abcd12345#';

/// Thời gian chờ API response (ms)
const Duration apiWait = Duration(seconds: 5);
const Duration longApiWait = Duration(seconds: 10);

/// Khởi tạo app cho integration tests
void initializeIntegrationTests() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
}

/// Pump app và đợi ổn định
Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const BusGoApp());
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

/// Đợi cho animation và API load xong
Future<void> waitForLoad(WidgetTester tester, {Duration? duration}) async {
  await tester.pumpAndSettle(duration ?? apiWait);
}

/// Thực hiện login với email và password
/// Xử lý scroll để đảm bảo nút đăng nhập nằm trong viewport
Future<bool> performLogin(WidgetTester tester) async {
  // Đợi trang login load
  await tester.pumpAndSettle(const Duration(seconds: 2));

  // Tìm tất cả TextFormField trên trang
  final textFields = find.byType(TextFormField);
  if (textFields.evaluate().isEmpty) {
    testLog('❌ Không tìm thấy TextFormField nào trên trang');
    return false;
  }

  // Nhập email (field đầu tiên)
  await tester.enterText(textFields.first, testEmail);
  await tester.pump(const Duration(milliseconds: 300));

  // Nhập password (field thứ 2)
  if (textFields.evaluate().length >= 2) {
    await tester.enterText(textFields.at(1), testPassword);
    await tester.pump(const Duration(milliseconds: 300));
  }

  // Scroll xuống để nút Đăng nhập hiển thị trong viewport
  // Tìm SingleChildScrollView và scroll
  final scrollFinder = find.byType(SingleChildScrollView);
  if (scrollFinder.evaluate().isNotEmpty) {
    await tester.drag(scrollFinder.first, const Offset(0, -200));
    await tester.pumpAndSettle();
  }

  // Tìm nút đăng nhập - nó là ElevatedButton chứa Row > Text('Đăng nhập')
  final loginButtonFinder = find.byType(ElevatedButton);
  if (loginButtonFinder.evaluate().isEmpty) {
    testLog('❌ Không tìm thấy ElevatedButton nào');
    return false;
  }

  // Tap nút ElevatedButton đầu tiên (nút đăng nhập)
  await tester.tap(loginButtonFinder.first, warnIfMissed: false);
  await tester.pumpAndSettle(longApiWait);
  
  // Đợi thêm cho API callback và navigation
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle(const Duration(seconds: 2));

  return true;
}

/// Kiểm tra xem đã ở trang Home chưa (có text đặc trưng)
bool isOnHomePage(WidgetTester tester) {
  return find.text('Bạn muốn đi đâu hôm nay?').evaluate().isNotEmpty ||
      find.text('Tìm chuyến xe ngay').evaluate().isNotEmpty ||
      find.text('BusGo').evaluate().isNotEmpty;
}

/// Kiểm tra có SnackBar với nội dung cụ thể
bool hasSnackBar(WidgetTester tester, String text) {
  return find.widgetWithText(SnackBar, text).evaluate().isNotEmpty;
}

/// Nhấn vào tab BottomNavigationBar theo label text
Future<void> tapBottomNavByLabel(WidgetTester tester, String label) async {
  final tabFinder = find.text(label);
  if (tabFinder.evaluate().isNotEmpty) {
    await tester.tap(tabFinder.last, warnIfMissed: false);
    await tester.pumpAndSettle(apiWait);
  } else {
    testLog('⚠️ Không tìm thấy tab: $label');
  }
}

/// Đếm số lượng widget con trong một finder
int countWidgets(Finder finder) {
  return finder.evaluate().length;
}

/// Print log cho test
void testLog(String message) {
  // ignore: avoid_print
  print('🧪 [BusGo E2E] $message');
}
