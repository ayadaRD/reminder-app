import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'schedule.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

part 'src/core/catalog.dart';
part 'src/core/formatting.dart';
part 'src/core/localization.dart';
part 'src/theme/reminder_theme.dart';
part 'src/theme/theme_reveal.dart';
part 'src/screens/home.dart';
part 'src/screens/settings.dart';
part 'src/widgets/reminder_form.dart';
part 'src/widgets/solar_picker.dart';

const native = MethodChannel('ir.yadavar/alarms');
final categoryPickerVisible = ValueNotifier<bool>(true);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final saved = await native.invokeMethod<String>('getLanguage');
    appLanguage.value = saved == 'en' ? 'en' : 'fa';
  } on PlatformException {
    appLanguage.value = 'fa';
  } on MissingPluginException {
    appLanguage.value = 'fa';
  }
  runApp(
  
    ThemeReveal(
      child:AnimatedBuilder(
        animation: Listenable.merge([appLanguage, selectedTheme]),
        builder: (context, child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: Locale(appLanguage.value),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: reminderTheme(selectedTheme.value),
        themeAnimationDuration: const Duration(milliseconds: 0),
        home: child,
      ),
      child: const Home(),
    ),
    ),

  );
}
