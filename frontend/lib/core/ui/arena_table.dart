import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'clay.dart';

/// Tema meja arena yang bisa dipilih pemain.
enum TableTheme {
  wood,
  forest,
  ocean,
  cosmic;

  String get i18nKey => 'table.$name';

  static TableTheme fromName(String? name) => TableTheme.values.firstWhere(
    (t) => t.name == name,
    orElse: () => TableTheme.wood,
  );

  /// Bingkai meja.
  Color get rim => switch (this) {
    TableTheme.wood => const Color(0xFFB9825A),
    TableTheme.forest => const Color(0xFF5E8C4A),
    TableTheme.ocean => const Color(0xFF3F7FC2),
    TableTheme.cosmic => const Color(0xFF5B4BB8),
  };

  /// Alas (playmat) di dalam bingkai.
  Color get felt => switch (this) {
    TableTheme.wood => const Color(0xFFF1D9B5),
    TableTheme.forest => const Color(0xFFCDE8B8),
    TableTheme.ocean => const Color(0xFFC6E3F7),
    TableTheme.cosmic => const Color(0xFF2E2766),
  };

  /// Warna motif & garis di alas.
  Color get ink => switch (this) {
    TableTheme.wood => const Color(0xFFC99A6B),
    TableTheme.forest => const Color(0xFF7DB45C),
    TableTheme.ocean => const Color(0xFF6FAEE0),
    TableTheme.cosmic => const Color(0xFF9D92F7),
  };

  bool get dark => this == TableTheme.cosmic;
}

/// Meja arena: bingkai clay + alas bermotif, sedikit dimiringkan ke belakang
/// agar terlihat seperti kartu diletakkan di atas meja.
class ArenaTable extends StatelessWidget {
  const ArenaTable({
    super.key,
    required this.theme,
    required this.child,
    this.tilt = true,
  });

  final TableTheme theme;
  final Widget child;
  final bool tilt;

  @override
  Widget build(BuildContext context) {
    final table = Clay(
      color: theme.rim,
      radius: 30,
      depth: 0.9,
      padding: const EdgeInsets.all(9),
      child: Clay(
        color: theme.felt,
        radius: 23,
        pressed: true,
        depth: 0.7,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(23),
          child: CustomPaint(
            painter: _FeltPainter(theme),
            child: child,
          ),
        ),
      ),
    );
    if (!tilt) return table;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0009)
        ..rotateX(0.16),
      child: table,
    );
  }
}

class _FeltPainter extends CustomPainter {
  const _FeltPainter(this.theme);

  final TableTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()..color = theme.ink.withValues(alpha: 0.35);
    switch (theme) {
      case TableTheme.wood:
        // Serat kayu bergelombang.
        final grain = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = theme.ink.withValues(alpha: 0.35);
        for (var y = 14.0; y < size.height; y += 22) {
          final path = Path()..moveTo(0, y);
          for (var x = 0.0; x <= size.width; x += 24) {
            path.lineTo(x, y + math.sin((x + y) / 37) * 4);
          }
          canvas.drawPath(path, grain);
        }
      case TableTheme.forest:
        // Daun-daun kecil tersebar.
        final rnd = math.Random(3);
        for (var i = 0; i < 36; i++) {
          final c = Offset(
            rnd.nextDouble() * size.width,
            rnd.nextDouble() * size.height,
          );
          canvas.save();
          canvas.translate(c.dx, c.dy);
          canvas.rotate(rnd.nextDouble() * math.pi);
          canvas.drawOval(
            Rect.fromCenter(center: Offset.zero, width: 14, height: 7),
            ink,
          );
          canvas.restore();
        }
      case TableTheme.ocean:
        // Gelombang.
        final wave = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..color = theme.ink.withValues(alpha: 0.4);
        for (var y = 18.0; y < size.height; y += 30) {
          for (var x = (y ~/ 30).isEven ? 0.0 : 20.0; x < size.width; x += 44) {
            canvas.drawArc(
              Rect.fromCenter(center: Offset(x, y), width: 22, height: 12),
              math.pi,
              math.pi,
              false,
              wave,
            );
          }
        }
      case TableTheme.cosmic:
        // Bintang.
        final rnd = math.Random(9);
        for (var i = 0; i < 60; i++) {
          canvas.drawCircle(
            Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
            rnd.nextDouble() * 1.8 + 0.6,
            Paint()
              ..color = Colors.white.withValues(
                alpha: 0.35 + rnd.nextDouble() * 0.5,
              ),
          );
        }
    }

    // Garis tengah + lambang di tengah meja.
    final mid = size.height / 2;
    final line = Paint()
      ..color = theme.ink.withValues(alpha: 0.7)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(24, mid), Offset(size.width / 2 - 34, mid), line);
    canvas.drawLine(
      Offset(size.width / 2 + 34, mid),
      Offset(size.width - 24, mid),
      line,
    );
    canvas.drawCircle(
      Offset(size.width / 2, mid),
      26,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = theme.ink.withValues(alpha: 0.7),
    );
    canvas.drawCircle(
      Offset(size.width / 2, mid),
      9,
      Paint()..color = theme.ink.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(covariant _FeltPainter oldDelegate) =>
      oldDelegate.theme != theme;
}

/// Contoh kecil meja untuk pemilih tema.
class TableSwatch extends StatelessWidget {
  const TableSwatch({
    super.key,
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final TableTheme theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
              ),
              child: SizedBox(
                width: 72,
                height: 56,
                child: ArenaTable(
                  theme: theme,
                  tilt: false,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                color: selected ? AppTheme.ink : AppTheme.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
