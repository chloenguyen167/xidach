import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xidach/app.dart';
import 'package:xidach/core/db/app_database.dart';
import 'package:xidach/data/session_repository.dart';
import 'package:xidach/domain/models/enums.dart';
import 'package:xidach/domain/models/player.dart';
import 'package:xidach/domain/models/rule_set.dart';
import 'package:xidach/domain/models/session.dart';
import 'package:xidach/state/providers.dart';

void main() {
  late AppDatabase db;

  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('vi');
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(400, 860),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.runAsync(() async {
      db = await AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      );
    });
    addTearDown(() => tester.runAsync(db.close));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPrefsProvider.overrideWithValue(prefs),
        ],
        child: const XiDachApp(),
      ),
    );
    await settle(tester);
  }

  testWidgets('create session, record, edit and delete rounds', (tester) async {
    await pumpApp(tester);
    expect(find.text('Chưa có lần chơi nào'), findsOneWidget);

    await tester.tap(find.text('Lần chơi mới'));
    await settle(tester);

    // Thêm 3 người chơi.
    final input = find.byKey(const Key('add-player'));
    for (final n in ['An', 'Bình', 'Chi']) {
      await tester.enterText(input, n);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
    }
    expect(find.text('Người chơi (3/10)'), findsOneWidget);
    // Trùng tên bị chặn.
    await tester.enterText(input, 'an');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(find.text('Người chơi (3/10)'), findsOneWidget);

    await tester.tap(find.text('Bắt đầu'));
    await settle(tester);
    expect(find.text('Chưa có ván nào'), findsOneWidget);

    // Ván 1: cái An; Bình thắng xì dách (x2), Chi thua.
    await tester.tap(find.text('Ván mới'));
    await settle(tester);
    expect(find.text('Ván 1'), findsOneWidget);
    await tapIn(tester, 2, 'Xì dách');
    await tester.pump();
    await tapIn(tester, 3, 'Thua');
    await tester.pump();
    await tester.tap(find.text('Lưu ván'));
    await settle(tester);

    var s = await load(tester, db);
    expect(s.totals, {1: -1, 2: 2, 3: -1});

    // Ván 2: cái vẫn là An (giữ người làm cái ván trước) — cái ăn hết.
    await tester.tap(find.text('Ván mới'));
    await settle(tester);
    expect(find.text('Cái An'), findsOneWidget);
    await tester.tap(find.byTooltip('Cái ăn hết'));
    await tester.pump();
    await tester.tap(find.text('Lưu ván'));
    await settle(tester);
    s = await load(tester, db);
    expect(s.totals, {1: 1, 2: 1, 3: -2});
    expect(s.roundCount, 2);

    // Sửa ván 1: Chi hòa thay vì thua.
    await tester.tap(find.text('Ván 1'));
    await settle(tester);
    expect(find.text('Sửa ván 1'), findsOneWidget);
    await tapIn(tester, 3, 'Hòa');
    await tester.pump();
    await tester.tap(find.text('Cập nhật'));
    await settle(tester);
    s = await load(tester, db);
    expect(s.totals, {1: -2 + 2, 2: 2 - 1, 3: 0 - 1});

    // Xóa ván 2 bằng vuốt, rồi Hoàn tác.
    await tester.drag(find.text('Ván 2'), const Offset(-500, 0));
    await settle(tester);
    s = await load(tester, db);
    expect(s.roundCount, 1);
    expect(s.totals, {1: -2, 2: 2, 3: 0});
    await tester.tap(find.text('Hoàn tác'));
    await settle(tester);
    s = await load(tester, db);
    expect(s.roundCount, 2);
    expect(s.totals.values.reduce((a, b) => a + b), 0);
  });

  testWidgets('tablet shows round editor in a side pane', (tester) async {
    await pumpApp(tester, size: const Size(1280, 800));
    await seedAndOpen(tester, db, 10);
    expect(find.text('Chọn một ván để sửa'), findsOneWidget);
    await tester.tap(find.text('Ván mới'));
    await settle(tester);
    expect(find.text('Ván 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Cái đền hết'));
    await tester.pump();
    await tester.tap(find.text('Lưu ván'));
    await settle(tester);
    final s = await load(tester, db);
    expect(s.totals[1], -9 * 10000);
    expect(find.text('Chọn một ván để sửa'), findsOneWidget);
  });

  testWidgets('large text on a small phone does not overflow', (tester) async {
    await pumpApp(tester, size: const Size(360, 740), textScale: 1.6);
    await seedAndOpen(tester, db, 10);
    await tester.tap(find.text('Ván mới'));
    await settle(tester);
    await tester.tap(find.byTooltip('Cái quắc'));
    await tester.pump();
    expect(find.text('Lưu ván'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await settle(tester);
    await tester.tap(find.byTooltip('Tổng kết'));
    await settle(tester);
    expect(find.text('Xếp hạng'), findsOneWidget);
  });

  testWidgets('landscape shows score table', (tester) async {
    await pumpApp(tester, size: const Size(860, 400));
    await tester.runAsync(
      () => SessionRepository(db).createSession(
        GameSession(
          name: 'Ngang',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          mode: ScoringMode.points,
          rules: const RuleSet(),
          players: const [
            Player(id: 1, name: 'An', colorIdx: 0),
            Player(id: 2, name: 'Bình', colorIdx: 1),
          ],
          dealerId: 1,
        ),
      ),
    );
    // Mở lại Home để đọc danh sách mới.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    container.invalidate(sessionsProvider);
    await settle(tester);
    await tester.tap(find.text('Ngang'));
    await settle(tester);
    expect(find.text('Tổng'), findsOneWidget);
    expect(find.text('Ván mới'), findsOneWidget);
  });
}

Future<void> seedAndOpen(
  WidgetTester tester,
  AppDatabase db,
  int players,
) async {
  await tester.runAsync(
    () => SessionRepository(db).createSession(
      GameSession(
        name: 'Bàn',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        mode: ScoringMode.variableMoney,
        fixedBet: 10000,
        rules: const RuleSet(heavyBustEnabled: true),
        players: [
          for (var i = 1; i <= players; i++)
            Player(id: i, name: 'Người chơi số $i', colorIdx: i - 1),
        ],
        dealerId: 1,
      ),
    ),
  );
  ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  ).invalidate(sessionsProvider);
  await settle(tester);
  await tester.tap(find.text('Bàn'));
  await settle(tester);
}

/// Cuộn tới rồi bấm nút [label] trong thẻ của người chơi [playerId].
Future<void> tapIn(WidgetTester tester, int playerId, String label) async {
  final f = find.descendant(
    of: find.byKey(ValueKey(playerId)),
    matching: find.text(label),
  );
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
}

/// Chờ DB (chạy thật) và animation xong.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }
}

Future<GameSession> load(WidgetTester tester, AppDatabase db) async =>
    (await tester.runAsync(() => SessionRepository(db).listSessions()))!.first;
