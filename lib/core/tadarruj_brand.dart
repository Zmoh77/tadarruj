import '../app/locale_provider.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app/premium_provider.dart';
import '../app/theme_provider.dart';

class TadarrujColors {
  // Palette naturelle et apaisante : Ivoire, Vert profond, Vert sauge, Beige doux, Doré mat
  static const Color parchment = Color(0xFFFAF7F0);
  static const Color beigeSoft = Color(0xFFF2ECE0);
  static const Color cardBorder = Color(0xFFE4DCC8);
  static const Color emeraldDeep = Color(0xFF164235);
  static const Color emeraldPrimary = Color(0xFF235949);
  static const Color emeraldLight = Color(0xFF4E7A65);
  static const Color sageGreen = Color(0xFF4E7A65);
  static const Color sageSoft = Color(0xFFDCE8E1);
  static const Color sageMedium = Color(0xFF9BBCA9);
  static const Color goldAccent = Color(0xFFB89644);
  static const Color goldSoft = Color(0xFFD9C07A);
  static const Color inkPrimary = Color(0xFF131D19);
  static const Color warmGrey = Color(0xFF4A5751);
}

class TadarrujAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final List<Widget>? extraActions;

  const TadarrujAppBar({
    super.key,
    required this.title,
    this.actions,
    this.extraActions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(localeProvider).languageCode;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return AppBar(
      titleSpacing: 16,
      title: Row(
        children: [
          const TadarrujLogo(size: 30, showTitle: false),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              currentLang == 'ar' ? 'تَدَرُّج' : 'Tadarruj',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.elMessiri(
                fontWeight: FontWeight.w700,
                fontSize: 21,
                color: TadarrujColors.goldSoft,
                letterSpacing: currentLang == 'ar' ? 0 : 0.4,
              ),
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: TadarrujColors.goldSoft,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => GoRouter.of(context).push('/premium'),
            icon: const Icon(Icons.workspace_premium_rounded, size: 17, color: TadarrujColors.goldSoft),
            label: const Text(
              'Tadarruj+',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Réglages',
          icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
          onPressed: () => GoRouter.of(context).push('/settings'),
        ),
        if (actions != null) ...actions!,
        if (extraActions != null) ...extraActions!,
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: ['fr', 'en', 'ar'].contains(currentLang) ? currentLang : 'fr',
            dropdownColor: TadarrujColors.emeraldDeep,
            icon: const Icon(Icons.language_rounded, size: 18, color: TadarrujColors.goldSoft),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
            items: const [
              DropdownMenuItem(value: 'fr', child: Text('FR')),
              DropdownMenuItem(value: 'en', child: Text('EN')),
              DropdownMenuItem(value: 'ar', child: Text('عربي')),
            ],
            onChanged: (val) {
              if (val != null) {
                ref.read(localeProvider.notifier).state = Locale(val);
              }
            },
          ),
        ),
        IconButton(
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            size: 20,
            color: TadarrujColors.goldSoft,
          ),
          onPressed: () {
            ref.read(themeModeProvider.notifier).state =
                isDark ? ThemeMode.light : ThemeMode.dark;
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class TadarrujLogo extends StatelessWidget {
  final double size;
  final bool showTitle;
  final Color? titleColor;

  const TadarrujLogo({
    super.key,
    this.size = 56,
    this.showTitle = true,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.28),
            color: TadarrujColors.emeraldDeep,
            border: Border.all(
              color: TadarrujColors.goldAccent.withValues(alpha: 0.55),
              width: 1.2,
            ),
          ),
          child: CustomPaint(
            painter: _TadarrujStaircasePainter(),
          ),
        ),
        if (showTitle) ...[
          const SizedBox(height: 10),
          Text(
            'تَدَرُّج',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: titleColor ?? TadarrujColors.goldAccent,
              height: 1.2,
            ),
          ),
          Text(
            'TADARRUJ',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
              color: titleColor ?? TadarrujColors.emeraldDeep,
            ),
          ),
        ],
      ],
    );
  }
}

class _TadarrujStaircasePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stepPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;

    final goldPaint = Paint()
      ..color = TadarrujColors.goldSoft
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    final barWidth = w * 0.13;
    final gap = w * 0.045;
    final startX = w * 0.18;
    final baseY = h * 0.80;

    final heights = [0.20, 0.34, 0.48, 0.62];
    for (int i = 0; i < 4; i++) {
      final left = startX + i * (barWidth + gap);
      final barHeight = h * heights[i];
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, baseY - barHeight, barWidth, barHeight),
        Radius.circular(barWidth * 0.3),
      );
      canvas.drawRRect(
        rect,
        i == 3 ? goldPaint : stepPaint,
      );
    }

    final starCenter = Offset(w * 0.72, h * 0.24);
    final outerR = w * 0.10;
    final innerR = w * 0.045;
    final starPath = Path();
    for (int i = 0; i < 16; i++) {
      final r = i.isEven ? outerR : innerR;
      final angle = (i * math.pi / 8) - math.pi / 2;
      final pt = Offset(
        starCenter.dx + r * math.cos(angle),
        starCenter.dy + r * math.sin(angle),
      );
      if (i == 0) {
        starPath.moveTo(pt.dx, pt.dy);
      } else {
        starPath.lineTo(pt.dx, pt.dy);
      }
    }
    starPath.close();
    canvas.drawPath(starPath, goldPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class IslamicPatternOverlay extends StatelessWidget {
  final Color color;
  final double opacity;

  const IslamicPatternOverlay({
    super.key,
    this.color = TadarrujColors.goldAccent,
    this.opacity = 0.025,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _IslamicStarTilePainter(
          color: color.withValues(alpha: opacity),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _IslamicStarTilePainter extends CustomPainter {
  final Color color;
  _IslamicStarTilePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const step = 72.0;
    for (double y = 0; y < size.height + step; y += step) {
      for (double x = 0; x < size.width + step; x += step) {
        final center = Offset(x, y);
        const r = 16.0;
        canvas.drawRect(
          Rect.fromCenter(center: center, width: r * 1.4, height: r * 1.4),
          paint,
        );
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(math.pi / 4);
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: r * 1.4, height: r * 1.4),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IslamicStarTilePainter oldDelegate) =>
      oldDelegate.color != color;
}
