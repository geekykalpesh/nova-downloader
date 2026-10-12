import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider _instance = ThemeProvider._internal();
  factory ThemeProvider() => _instance;
  ThemeProvider._internal() {
    _loadPreference();
  }

  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('is_dark_mode')) {
        _isDarkMode = prefs.getBool('is_dark_mode') ?? true;
        notifyListeners();
      }
    } catch (_) {}
  }

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_dark_mode', _isDarkMode);
    } catch (_) {}
  }

  // --- Design Tokens ---

  // Canvas / Background
  Color get bg => _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

  // Sidebar / Header / Fixed panels
  Color get panel => _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);

  // Cards / Table items / Dialog surfaces
  Color get surface => _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);

  // Subtle hover & highlighted background
  Color get surfaceLight => _isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

  // Borders & Dividers
  Color get border => _isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

  // Typography
  Color get text => _isDarkMode ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  Color get subtext => _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  // Brand Accent (Modern Indigo / Violet)
  Color get accent => _isDarkMode ? const Color(0xFF6366F1) : const Color(0xFF4F46E5);
  Color get accentHover => _isDarkMode ? const Color(0xFF818CF8) : const Color(0xFF4338CA);
  Color get accentLight => _isDarkMode ? const Color(0x266366F1) : const Color(0x1A4F46E5);

  // Functional Colors
  Color get danger => const Color(0xFFF43F5E);
  Color get warning => const Color(0xFFF59E0B);
  Color get success => const Color(0xFF10B981);

  // Full Material 3 ThemeData
  ThemeData get themeData {
    final brightness = _isDarkMode ? Brightness.dark : Brightness.light;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Segoe UI',
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      cardColor: surface,
      dividerColor: border,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        onPrimary: Colors.white,
        secondary: accentHover,
        onSecondary: Colors.white,
        error: danger,
        onError: Colors.white,
        surface: surface,
        onSurface: text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: subtext.withOpacity(0.5)),
        checkColor: WidgetStateProperty.all(Colors.white),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent;
          }
          return Colors.transparent;
        }),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
