import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class NocturneTheme {
  static const background = Color(0xFF101017);
  static const surface = Color(0xFF1B1A25);
  static const border = Color(0xFF343140);
  static const accent = Color(0xFFC0AFE8);
  static const gold = Color(0xFFD6C39B);
  static const text = Color(0xFFF3EFE8);
  static const muted = Color(0xFFADA8BA);
  static const error = Color(0xFFFFB4AB);

  static const heading = TextStyle(
    fontFamily: 'CormorantGaramond',
    color: text,
    fontWeight: FontWeight.w500,
    height: 1.05,
  );
  static const eyebrow = TextStyle(
    color: muted,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.2,
  );

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      onPrimary: background,
      primaryContainer: Color(0xFF30293E),
      onPrimaryContainer: accent,
      secondary: gold,
      onSecondary: background,
      secondaryContainer: Color(0xFF30293E),
      onSecondaryContainer: accent,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: muted,
      outline: border,
      error: error,
      onError: background,
    ),
    textTheme: ThemeData.dark().textTheme.apply(
      fontFamily: 'Inter',
      bodyColor: text,
      displayColor: text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: text,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: border),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: accent,
        foregroundColor: background,
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: text,
        side: const BorderSide(color: border),
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent,
        minimumSize: const Size(48, 48),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: const TextStyle(color: muted, fontSize: 14),
      contentPadding: const EdgeInsets.all(18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: accent),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? accent : muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          color: states.contains(WidgetState.selected) ? accent : muted,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surface,
      contentTextStyle: const TextStyle(fontFamily: 'Inter', color: text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: accent,
      foregroundColor: background,
      elevation: 2,
    ),
    dividerColor: border,
  );
}

class NightBackdrop extends StatelessWidget {
  final Widget child;
  const NightBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(0.8, -0.8),
        radius: 1.3,
        colors: [Color(0xFF242032), NocturneTheme.background],
      ),
    ),
    child: CustomPaint(painter: ConstellationPainter(), child: child),
  );
}

class ConstellationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(12);
    final paint = Paint()..color = NocturneTheme.accent.withValues(alpha: 0.16);
    for (var i = 0; i < 35; i++) {
      final point = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      canvas.drawCircle(point, i % 5 == 0 ? 1.3 : 0.65, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BrandMark extends StatelessWidget {
  final bool showName;
  const BrandMark({super.key, this.showName = true});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: NocturneTheme.accent.withValues(alpha: 0.08),
          border: Border.all(
            color: NocturneTheme.accent.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(
          Icons.auto_awesome_outlined,
          color: NocturneTheme.accent,
          size: 22,
        ),
      ),
      if (showName) ...[
        const SizedBox(width: 12),
        const Flexible(
          child: Text(
            'Just Paste',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ],
  );
}

/// Vector artwork stays crisp at every screen size and needs no network assets.
class OrbitArtwork extends StatelessWidget {
  final double height;
  const OrbitArtwork({super.key, this.height = 210});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _OrbitPainter()),
    ),
  );
}

class _OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final unit = min(size.width / 330, size.height / 210);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(unit);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = NocturneTheme.accent.withValues(alpha: 0.18);
    canvas.drawCircle(Offset.zero, 96, line);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 310, height: 122),
      line,
    );
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          NocturneTheme.accent.withValues(alpha: 0.11),
          NocturneTheme.accent.withValues(alpha: 0),
        ],
      ).createShader(const Rect.fromLTWH(-130, -110, 260, 220));
    canvas.drawCircle(Offset.zero, 110, glow);

    for (var i = 2; i >= 0; i--) {
      canvas.save();
      canvas.translate((i - 1) * 12, (i - 1) * 2);
      canvas.rotate((i - 1) * 0.17);
      final card = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-53, -72, 106, 144),
        const Radius.circular(13),
      );
      canvas.drawRRect(
        card,
        Paint()
          ..color = i == 0 ? const Color(0xFF292435) : NocturneTheme.surface,
      );
      canvas.drawRRect(
        card,
        line
          ..color = NocturneTheme.accent.withValues(alpha: i == 0 ? 0.5 : 0.24),
      );
      if (i == 0) {
        final star = Path()
          ..moveTo(0, -39)
          ..quadraticBezierTo(5, -12, 25, -7)
          ..quadraticBezierTo(5, -2, 0, 25)
          ..quadraticBezierTo(-5, -2, -25, -7)
          ..quadraticBezierTo(-5, -12, 0, -39);
        canvas.drawPath(star, Paint()..color = NocturneTheme.accent);
        final rule = Paint()
          ..color = NocturneTheme.accent.withValues(alpha: 0.32)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(-22, 43), const Offset(22, 43), rule);
        canvas.drawLine(const Offset(-13, 51), const Offset(13, 51), rule);
      }
      canvas.restore();
    }
    for (final point in [const Offset(-127, -35), const Offset(112, 43)]) {
      canvas.drawCircle(point, 3, Paint()..color = NocturneTheme.gold);
      canvas.drawCircle(
        point,
        7,
        line..color = NocturneTheme.gold.withValues(alpha: 0.2),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
