import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'data/settings_repository.dart';
import 'features/home/home_page.dart';
import 'state/providers.dart';

const appName = 'Tính điểm xì dách';
const appVersion = '1.0.0';

class XiDachApp extends ConsumerStatefulWidget {
  const XiDachApp({super.key});

  @override
  ConsumerState<XiDachApp> createState() => _XiDachAppState();
}

class _XiDachAppState extends ConsumerState<XiDachApp> {
  @override
  void initState() {
    super.initState();
    _applyOrientation(ref.read(prefsProvider).orientation);
  }

  static void _applyOrientation(OrientationPref o) {
    SystemChrome.setPreferredOrientations(switch (o) {
      OrientationPref.auto => const [],
      OrientationPref.portrait => const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ],
      OrientationPref.landscape => const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      prefsProvider.select((p) => p.orientation),
      (_, next) => _applyOrientation(next),
    );
    final themeMode = ref.watch(prefsProvider.select((p) => p.themeMode));
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const HomePage(),
    );
  }
}
