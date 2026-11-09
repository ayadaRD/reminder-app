part of '../../main.dart';

final selectedTheme = ValueNotifier<String?>(null);

const categorySeeds = <String, Color>{
  'birthday': Color(0xff80519c),
  'water': Color(0xff246b91),
  'love': Color(0xffa5405c),
  'car': Color(0xff975327),
  'memorial': Color(0xff656179),
  'medicine': Color(0xff465ba5),
  'plant': Color(0xff3d724a),
  'custom': Color(0xff856315),
};

ThemeData reminderTheme(String? category) {
  final seed = categorySeeds[category] ?? const Color(0xff62636b);
  final pastel = kinds[category]?.$3 ?? const Color(0xfff3f3f5);
  final surface = category == null
      ? Colors.white
      : Color.lerp(Colors.white, pastel, .42)!;

  final scheme = ColorScheme.fromSeed(seedColor: seed).copyWith(
    surface: surface,
    primaryContainer: pastel,
    surfaceContainerLow: Color.lerp(Colors.white, pastel, .24),
    surfaceContainer: pastel,
    outline: Color.lerp(seed, Colors.white, .32),
  );

  OutlineInputBorder fieldBorder(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: surface,
    appBarTheme: AppBarThemeData(
      backgroundColor: surface,
      foregroundColor: scheme.primary,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: pastel,
      indicatorColor: Color.lerp(pastel, seed, .24),
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: fieldBorder(scheme.outline),
      enabledBorder: fieldBorder(scheme.outline),
      focusedBorder: fieldBorder(scheme.primary, 2),
      errorBorder: fieldBorder(scheme.error),
      focusedErrorBorder: fieldBorder(scheme.error, 2),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.outline),
      ),
    ),
  );
}
