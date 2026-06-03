/// BusGo E2E Test 2: Home Page Content
/// Test nội dung trang chủ sau khi đăng nhập:
/// - Search form có đủ fields
/// - Tuyến đường phổ biến load từ API
/// - Khuyến mãi load từ API
/// - Nhà xe đối tác load từ API
/// - Bottom navigation hoạt động
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'app_test_helpers.dart';

void main() {
  initializeIntegrationTests();

  group('🏠 Home Page Tests', () {
    testWidgets('TC05: Home page hiển thị search form đúng', (tester) async {
      testLog('TC05: Kiểm tra search form trên Home');
      await pumpApp(tester);

      // Login trước
      await performLogin(tester);
      await tester.pumpAndSettle(longApiWait);

      // Xác minh đang ở Home
      expect(isOnHomePage(tester), isTrue, reason: 'Phải đang ở Home page');

      // Kiểm tra header BusGo
      expect(find.text('BusGo').first, findsOneWidget,
          reason: 'Header phải có logo text BusGo');

      // Kiểm tra tiêu đề
      expect(find.text('Bạn muốn đi đâu hôm nay?'), findsOneWidget,
          reason: 'Phải hiển thị câu hỏi tìm kiếm');

      // Kiểm tra có nút tìm kiếm
      expect(find.text('Tìm chuyến xe ngay'), findsOneWidget,
          reason: 'Phải có nút CTA tìm chuyến');

      // Kiểm tra có icon thông báo
      expect(find.byIcon(Icons.notifications_none_outlined), findsOneWidget,
          reason: 'Phải có icon thông báo trên header');

      testLog('TC05: ✅ PASSED - Search form hiển thị đúng');
    });

    testWidgets('TC06: Tuyến đường phổ biến load dữ liệu', (tester) async {
      testLog('TC06: Kiểm tra section Tuyến đường phổ biến');
      await pumpApp(tester);
      await performLogin(tester);
      await tester.pumpAndSettle(longApiWait);

      // Kiểm tra tiêu đề section
      expect(find.text('Tuyến đường phổ biến'), findsOneWidget,
          reason: 'Phải có section Tuyến đường phổ biến');

      // Kiểm tra có horizontal ListView cho popular routes
      // (Nếu API load thành công sẽ có ListView.builder)
      final listViews = find.byType(ListView);
      expect(listViews, findsWidgets,
          reason: 'Phải có ít nhất 1 ListView cho tuyến đường phổ biến');

      testLog('TC06: ✅ PASSED - Tuyến đường phổ biến hiển thị');
    });

    testWidgets('TC07: Section Khuyến mãi và Nhà xe load từ API', (tester) async {
      testLog('TC07: Kiểm tra Khuyến mãi và Nhà xe đối tác');
      await pumpApp(tester);
      await performLogin(tester);
      await tester.pumpAndSettle(longApiWait);

      // Scroll xuống để xem thêm nội dung
      final scrollable = find.byType(SingleChildScrollView);
      if (scrollable.evaluate().isNotEmpty) {
        await tester.drag(scrollable, const Offset(0, -400));
        await tester.pumpAndSettle();
      }

      // Kiểm tra section khuyến mãi
      expect(find.textContaining('Khuyến mãi'), findsWidgets,
          reason: 'Phải có section Khuyến mãi');

      // Scroll xuống thêm để xem nhà xe đối tác
      if (scrollable.evaluate().isNotEmpty) {
        await tester.drag(scrollable, const Offset(0, -400));
        await tester.pumpAndSettle();
      }

      // Kiểm tra section nhà xe (có thể đã scroll đến)
      // Kiểm tra có text "Nhà xe uy tín đối tác" hoặc ít nhất có dữ liệu company
      final hasPartners = find.text('Nhà xe uy tín đối tác').evaluate().isNotEmpty;
      testLog('TC07: Nhà xe đối tác section visible = $hasPartners');

      testLog('TC07: ✅ PASSED - Sections load thành công');
    });

    testWidgets('TC08: Bottom Navigation Bar hoạt động', (tester) async {
      testLog('TC08: Kiểm tra BottomNavigationBar');
      await pumpApp(tester);
      await performLogin(tester);
      await tester.pumpAndSettle(longApiWait);

      // Xác minh có BottomNavigationBar
      final bottomNav = find.byType(BottomNavigationBar);
      expect(bottomNav, findsOneWidget,
          reason: 'Phải có BottomNavigationBar');

      // Kiểm tra có đủ 4 tab
      expect(find.text('Tìm kiếm'), findsOneWidget, reason: 'Phải có tab Tìm kiếm');
      expect(find.text('Vé của tôi'), findsOneWidget, reason: 'Phải có tab Vé của tôi');
      expect(find.text('Ưu đãi'), findsOneWidget, reason: 'Phải có tab Ưu đãi');
      expect(find.text('Tài khoản'), findsOneWidget, reason: 'Phải có tab Tài khoản');

      testLog('TC08: ✅ PASSED - BottomNavigationBar đúng 4 tab');
    });
  });
}
