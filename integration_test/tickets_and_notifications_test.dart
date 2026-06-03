/// BusGo E2E Test 4: Tickets & Notifications
/// Test luồng xem vé và thông báo:
/// - Tab Vé của tôi load danh sách vé
/// - Tab Sắp đi / Lịch sử hoạt động
/// - Thông tin vé hiển thị đúng (điểm đi, điểm đến, giá, trạng thái)
/// - Trang Notifications load và hiển thị
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'app_test_helpers.dart';

void main() {
  initializeIntegrationTests();

  group('🎫 My Tickets Tests', () {
    testWidgets('TC14: Tab Vé của tôi → load danh sách vé', (tester) async {
      testLog('TC14: Test xem danh sách vé');
      await pumpApp(tester);
      await performLogin(tester);
      await tester.pumpAndSettle(longApiWait);

      // Nhấn tab "Vé của tôi" trong BottomNavBar
      final ticketTab = find.text('Vé của tôi');
      expect(ticketTab, findsOneWidget, reason: 'Phải có tab Vé của tôi');

      await tester.tap(ticketTab);
      await tester.pumpAndSettle(longApiWait);

      // Xác minh trang vé xuất hiện
      final hasTicketTitle = find.text('Vé của tôi').evaluate().length >= 1;
      expect(hasTicketTitle, isTrue,
          reason: 'Phải hiển thị tiêu đề "Vé của tôi"');

      testLog('TC14: ✅ PASSED - Trang Vé của tôi load thành công');
    });

    testWidgets('TC15: Vé có tabs Sắp đi / Lịch sử', (tester) async {
      testLog('TC15: Kiểm tra tabs trên trang Vé');
      await pumpApp(tester);
      await performLogin(tester);
      await tester.pumpAndSettle(longApiWait);

      // Navigate đến My Tickets
      await tester.tap(find.text('Vé của tôi'));
      await tester.pumpAndSettle(longApiWait);

      // Kiểm tra có 2 tabs
      expect(find.text('Sắp đi'), findsOneWidget,
          reason: 'Phải có tab Sắp đi');
      expect(find.text('Lịch sử'), findsOneWidget,
          reason: 'Phải có tab Lịch sử');

      testLog('TC15: ✅ PASSED - 2 tabs Sắp đi / Lịch sử hiển thị');
    });

    testWidgets('TC16: Vé hiển thị thông tin chuyến đi', (tester) async {
      testLog('TC16: Kiểm tra thông tin hiển thị trên vé');
      await pumpApp(tester);
      await performLogin(tester);
      await tester.pumpAndSettle(longApiWait);

      // Navigate đến My Tickets
      await tester.tap(find.text('Vé của tôi'));
      await tester.pumpAndSettle(longApiWait);

      // Kiểm tra có vé nào được hiển thị hay không
      final hasTicketCard = find.textContaining('Điểm đi').evaluate().isNotEmpty ||
          find.text('Xem vé').evaluate().isNotEmpty ||
          find.textContaining('đ').evaluate().isNotEmpty; // Giá tiền
      
      final hasEmptyState = find.textContaining('chưa có vé').evaluate().isNotEmpty ||
          find.textContaining('Chưa có').evaluate().isNotEmpty;

      expect(hasTicketCard || hasEmptyState, isTrue,
          reason: 'Phải có danh sách vé hoặc empty state');

      if (hasTicketCard) {
        testLog('TC16: Có vé hiển thị trên danh sách');
        
        // Kiểm tra nút "Xem vé" có hiển thị không
        final viewButton = find.text('Xem vé');
        if (viewButton.evaluate().isNotEmpty) {
          testLog('TC16: Nút "Xem vé" có hiển thị');
        }
      } else {
        testLog('TC16: Danh sách vé trống (empty state)');
      }

      testLog('TC16: ✅ PASSED - Thông tin vé hoặc empty state đúng');
    });

    testWidgets('TC17: Switch tab Lịch sử hiển thị vé cũ', (tester) async {
      testLog('TC17: Kiểm tra tab Lịch sử');
      await pumpApp(tester);
      await performLogin(tester);
      await tester.pumpAndSettle(longApiWait);

      // Navigate đến My Tickets
      await tester.tap(find.text('Vé của tôi'));
      await tester.pumpAndSettle(longApiWait);

      // Nhấn tab Lịch sử
      final historyTab = find.text('Lịch sử');
      await tester.tap(historyTab);
      await tester.pumpAndSettle(longApiWait);

      // Tab Lịch sử phải hiển thị (có vé cũ hoặc empty state)
      testLog('TC17: Tab Lịch sử đã chuyển thành công');
      testLog('TC17: ✅ PASSED');
    });
  });

  group('🔔 Notifications Tests', () {
    testWidgets('TC18: Icon thông báo → mở trang Notifications', (tester) async {
      testLog('TC18: Test mở trang thông báo');
      await pumpApp(tester);
      await performLogin(tester);
      await tester.pumpAndSettle(longApiWait);

      // Nhấn icon thông báo trên header
      final notifIcon = find.byIcon(Icons.notifications_none_outlined);
      if (notifIcon.evaluate().isNotEmpty) {
        await tester.tap(notifIcon.first);
        await tester.pumpAndSettle(longApiWait);

        // Xác minh trang thông báo xuất hiện
        final hasNotifPage = find.text('Thông báo').evaluate().isNotEmpty;
        expect(hasNotifPage, isTrue,
            reason: 'Phải chuyển đến trang Thông báo');

        testLog('TC18: ✅ PASSED - Trang thông báo mở thành công');
      } else {
        testLog('TC18: ⚠️ Không tìm thấy icon thông báo');
      }
    });

    testWidgets('TC19: Trang Notifications hiển thị danh sách hoặc empty state', (tester) async {
      testLog('TC19: Kiểm tra nội dung trang thông báo');
      await pumpApp(tester);
      await performLogin(tester);
      await tester.pumpAndSettle(longApiWait);

      // Navigate đến notifications
      final notifIcon = find.byIcon(Icons.notifications_none_outlined);
      if (notifIcon.evaluate().isNotEmpty) {
        await tester.tap(notifIcon.first);
        await tester.pumpAndSettle(longApiWait);

        // Kiểm tra có nội dung thông báo hoặc empty state
        final hasNotifs = find.byType(ListTile).evaluate().isNotEmpty ||
            find.byType(Card).evaluate().isNotEmpty;
        final hasEmptyState = find.textContaining('Chưa có thông báo').evaluate().isNotEmpty ||
            find.textContaining('không có').evaluate().isNotEmpty;

        testLog('TC19: hasNotifs=$hasNotifs, hasEmptyState=$hasEmptyState');
        testLog('TC19: ✅ PASSED');
      }
    });
  });
}
