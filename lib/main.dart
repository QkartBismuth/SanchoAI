import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:google_fonts/google_fonts.dart';
import 'presentation/screens/chat_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/providers/model_provider.dart';
import 'data/datasources/log_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LogService.instance.initialize();
  LogService.instance.info('Sancho.AI started');
  runApp(const ProviderScope(child: SanchoApp()));
}

class SanchoApp extends ConsumerWidget {
  const SanchoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(autoLoadModelProvider);
    
    final settings = ref.watch(settingsProvider);
    
    final themeMode = settings.when(
      data: (s) => s.theme == 'light' ? ThemeMode.light : 
                    s.theme == 'dark' ? ThemeMode.dark : ThemeMode.system,
      loading: () => ThemeMode.system,
      error: (_, __) => ThemeMode.system,
    );

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: 'Sancho.AI',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(lightDynamic, Brightness.light, themeMode),
          darkTheme: _buildTheme(darkDynamic, Brightness.dark, themeMode),
          themeMode: themeMode,
          home: const ChatScreen(),
          routes: {
            '/settings': (context) => const SettingsScreen(),
          },
        );
      },
    );
  }

  ThemeData _buildTheme(ColorScheme? dynamicColorScheme, Brightness brightness, ThemeMode themeMode) {
    final ColorScheme colorScheme = dynamicColorScheme ?? ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: brightness,
    );

    final textTheme = GoogleFonts.notoSansTextTheme().copyWith(
      displayLarge: GoogleFonts.notoSans(fontSize: 57, fontWeight: FontWeight.w400),
      displayMedium: GoogleFonts.notoSans(fontSize: 45, fontWeight: FontWeight.w400),
      displaySmall: GoogleFonts.notoSans(fontSize: 36, fontWeight: FontWeight.w400),
      headlineLarge: GoogleFonts.notoSans(fontSize: 32, fontWeight: FontWeight.w400),
      headlineMedium: GoogleFonts.notoSans(fontSize: 28, fontWeight: FontWeight.w400),
      headlineSmall: GoogleFonts.notoSans(fontSize: 24, fontWeight: FontWeight.w400),
      titleLarge: GoogleFonts.notoSans(fontSize: 22, fontWeight: FontWeight.w500),
      titleMedium: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w500),
      titleSmall: GoogleFonts.notoSans(fontSize: 14, fontWeight: FontWeight.w500),
      bodyLarge: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: GoogleFonts.notoSans(fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall: GoogleFonts.notoSans(fontSize: 12, fontWeight: FontWeight.w400),
      labelLarge: GoogleFonts.notoSans(fontSize: 14, fontWeight: FontWeight.w500),
      labelMedium: GoogleFonts.notoSans(fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: GoogleFonts.notoSans(fontSize: 11, fontWeight: FontWeight.w500),
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: colorScheme.surfaceContainerLowest,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 3,
        highlightElevation: 4,
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }
}
