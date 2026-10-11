// Chụp màn hình các màn chính bằng font thật để kiểm tra giao diện / làm ảnh store.
// Chạy: flutter test test/screenshots --update-goldens --dart-define=SCREENSHOTS=true
// Ảnh nằm ở build/screenshots/. Mặc định bị bỏ qua khi chạy `flutter test`.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xidach/app.dart';
import 'package:xidach/core/db/app_database.dart';
import 'package:xidach/data/session_repository.dart';
import 'package:xidach/data/settings_repository.dart';
import 'package:xidach/domain/models/enums.dart';
import 'package:xidach/domain/models/player.dart';
import 'package:xidach/domain/models/round.dart';
import 'package:xidach/domain/models/rule_set.dart';
import 'package:xidach/domain/models/session.dart';
import 'package:xidach/state/providers.dart';

const enabled = bool.fromEnvironment('SCREENSHOTS');

Future<void> _loadFonts() async {
  Future<ByteData> file(String p) async =>
      ByteData.sublistView(await File(p).readAsBytes());
  const sys = '/System/Library/Fonts/Supplemental';
  await (FontLoader('Roboto')
        ..addFont(file('$sys/Arial.ttf'))
        ..addFont(file('$sys/Arial Bold.ttf')))
      .load();
  for (final (family, asset) in [
    ('FontAwesomeSolid', 'Font-Awesome-7-Free-Solid-900.otf'),
    ('FontAwesomeRegular', 'Font-Awesome-7-Free-Regular-400.otf'),
  ]) {
    await (FontLoader('packages/font_awesome_flutter/$family')..addFont(
          rootBundle.load('packages/font_awesome_flutter/lib/fonts/$asset'),
        ))
        .load();
  }
}

void main() {
  late AppDatabase db;

  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('vi');
    if (enabled) await _loadFonts();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<void> seed() async {
    final repo = SessionRepository(db);
    const names = ['Hùng', 'Lan', 'Minh', 'Tuấn', 'Vy', 'Khoa'];
    final id = await repo.createSession(
      GameSession(
        name: 'Tối thứ Bảy',
        createdAt: DateTime(2026, 10, 10, 20),
        updatedAt: DateTime(2026, 10, 10, 20),
        mode: ScoringMode.variableMoney,
        fixedBet: 10000,
        rules: const RuleSet(),
        players: [
          for (var i = 0; i < names.length; i++)
            Player(id: i + 1, name: names[i], colorIdx: i),
        ],
        dealerId: 1,
      ),
    );
    final plan = <(int, List<RoundEntry>)>[
      (
        1,
        const [
          RoundEntry(
            playerId: 2,
            outcome: Outcome.win,
            mul: 2,
            tag: HandTag.xiDach,
            bet: 10000,
          ),
          RoundEntry(playerId: 3, outcome: Outcome.lose, bet: 10000),
          RoundEntry(
            playerId: 4,
            outcome: Outcome.lose,
            tag: HandTag.bust,
            bet: 20000,
          ),
          RoundEntry(playerId: 5, outcome: Outcome.draw, bet: 10000),
          RoundEntry(playerId: 6, outcome: Outcome.win, bet: 5000),
        ],
      ),
      (
        1,
        const [
          RoundEntry(playerId: 2, outcome: Outcome.lose, bet: 10000),
          RoundEntry(playerId: 3, outcome: Outcome.lose, bet: 10000),
          RoundEntry(
            playerId: 4,
            outcome: Outcome.win,
            mul: 2,
            tag: HandTag.nguLinh,
            bet: 20000,
          ),
          RoundEntry(playerId: 5, outcome: Outcome.lose, bet: 10000),
          RoundEntry(playerId: 6, outcome: Outcome.lose, bet: 5000),
        ],
      ),
      (
        4,
        const [
          RoundEntry(playerId: 1, outcome: Outcome.win, bet: 10000),
          RoundEntry(
            playerId: 2,
            outcome: Outcome.win,
            mul: 3,
            tag: HandTag.xiBang,
            bet: 10000,
          ),
          RoundEntry(
            playerId: 3,
            outcome: Outcome.lose,
            tag: HandTag.non,
            bet: 10000,
          ),
          RoundEntry(playerId: 5, outcome: Outcome.draw, bet: 10000),
          RoundEntry(playerId: 6, outcome: Outcome.lose, bet: 5000),
        ],
      ),
    ];
    var minute = 0;
    for (final (dealer, entries) in plan) {
      await repo.addRound(
        GameRound(
          sessionId: id,
          idx: 0,
          dealerId: dealer,
          createdAt: DateTime(2026, 10, 10, 20, minute += 7),
          entries: entries,
        ),
      );
    }
    await repo.createSession(
      GameSession(
        name: 'Tết 2026 — nhà nội',
        createdAt: DateTime(2026, 2, 17),
        updatedAt: DateTime(2026, 2, 17, 23),
        mode: ScoringMode.points,
        rules: const RuleSet(),
        players: const [
          Player(id: 1, name: 'Ba', colorIdx: 7),
          Player(id: 2, name: 'Chú Tư', colorIdx: 3),
          Player(id: 3, name: 'Cô Út', colorIdx: 5),
        ],
        dealerId: 1,
        roundCount: 0,
      ),
    );
  }

  Future<void> boot(
    WidgetTester tester,
    Size size, {
    ThemeMode theme = ThemeMode.light,
  }) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = size * 2.625;
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.runAsync(() async {
      db = await AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      );
      await seed();
      await SettingsRepository(db, prefs).savePrefs(AppPrefs(themeMode: theme));
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

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../build/screenshots/$name.png'),
    );
  }

  const phone = Size(412, 915);

  testWidgets('phone portrait', (tester) async {
    await boot(tester, phone);
    await shot(tester, '01_home');
    await tester.tap(find.text('Tối thứ Bảy'));
    await shot(tester, '02_session');
    await tester.tap(find.text('Ván mới'));
    await settle(tester);
    await tester.tap(find.byTooltip('Cái quắc'));
    await tester.pump();
    final xd = find.descendant(
      of: find.byKey(const ValueKey(3)),
      matching: find.text('Xì dách'),
    );
    await tester.ensureVisible(xd);
    await tester.pumpAndSettle();
    await tester.tap(xd);
    await tester.drag(find.byType(ListView).last, const Offset(0, 2000));
    await shot(tester, '03_round_editor');
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await settle(tester);
    await tester.tap(find.byTooltip('Tổng kết'));
    await shot(tester, '04_summary');
    debugDefaultTargetPlatformOverride = null;
  }, skip: !enabled);

  testWidgets('new session + settings', (tester) async {
    await boot(tester, phone);
    await tester.tap(find.text('Lần chơi mới'));
    await settle(tester);
    for (final n in ['Hùng', 'Lan', 'Minh', 'Tuấn']) {
      await tester.enterText(find.byKey(const Key('add-player')), n);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(tester, '05_new_session');
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await settle(tester);
    await tester.tap(find.byTooltip('Cài đặt'));
    await shot(tester, '06_settings');
    debugDefaultTargetPlatformOverride = null;
  }, skip: !enabled);

  testWidgets('landscape + dark', (tester) async {
    await boot(tester, const Size(915, 412), theme: ThemeMode.dark);
    await tester.tap(find.text('Tối thứ Bảy'));
    await shot(tester, '07_landscape_dark');
    debugDefaultTargetPlatformOverride = null;
  }, skip: !enabled);

  testWidgets('tablet two-pane', (tester) async {
    await boot(tester, const Size(1280, 800));
    await tester.tap(find.text('Tối thứ Bảy'));
    await settle(tester);
    await tester.tap(find.text('Ván mới'));
    await settle(tester);
    await tester.tap(find.byTooltip('Cái quắc'));
    await shot(tester, '08_tablet');
    debugDefaultTargetPlatformOverride = null;
  }, skip: !enabled);
}
