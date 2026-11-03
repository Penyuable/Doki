import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/card_model.dart';
import '../theme/app_theme.dart';

/// Palet volumetrik per elemen: highlight, base, shadow, aksen fitur.
class CreaturePalette {
  const CreaturePalette(this.light, this.base, this.dark, this.accent);

  final Color light;
  final Color base;
  final Color dark;
  final Color accent;

  static CreaturePalette of(CardElement element) => switch (element) {
        CardElement.fire => const CreaturePalette(
            Color(0xFFFFD39A),
            Color(0xFFFF7A3D),
            Color(0xFFB2341A),
            Color(0xFFFFE066),
          ),
        CardElement.water => const CreaturePalette(
            Color(0xFFBDEBFF),
            Color(0xFF3FA9F5),
            Color(0xFF1B559C),
            Color(0xFF7FFFE0),
          ),
        CardElement.earth => const CreaturePalette(
            Color(0xFFDDF2A6),
            Color(0xFF8BBF4A),
            Color(0xFF486B22),
            Color(0xFFA67C52),
          ),
        CardElement.air => const CreaturePalette(
            Color(0xFFFFFFFF),
            Color(0xFFDCE6F7),
            Color(0xFF8396BD),
            Color(0xFF9BE7FF),
          ),
        CardElement.voidElement => const CreaturePalette(
            Color(0xFFDCD0FF),
            Color(0xFF8E6CF0),
            Color(0xFF38227F),
            Color(0xFFFF6BD6),
          ),
      };
}

/// Karakter chibi bergaya 3D yang digambar prosedural dari `card.id`.
///
/// Tidak butuh aset: bentuk tubuh, telinga, dan mata diturunkan dari hash id
/// sehingga tiap kartu punya kreatur yang stabil. Efek 3D dihasilkan dari
/// shading radial, rim light, parallax wajah, dan rotasi perspektif idle.
class CreatureAvatar extends StatefulWidget {
  const CreatureAvatar({
    super.key,
    required this.card,
    this.animate = true,
    this.mirrored = false,
  });

  final CardModel card;
  final bool animate;

  /// Kreatur menghadap ke kiri (dipakai untuk sisi lawan di arena).
  final bool mirrored;

  @override
  State<CreatureAvatar> createState() => _CreatureAvatarState();
}

class _CreatureAvatarState extends State<CreatureAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final seed = creatureSeed(widget.card.id);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2600 + seed % 900),
      value: (seed % 100) / 100,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant CreatureAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final shouldRun = widget.animate && !reduce;
    if (shouldRun && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldRun && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final phase = _controller.value;
          final turn = math.sin(phase * math.pi * 2) * 0.32;
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.0016)
            ..rotateY(widget.mirrored ? math.pi + turn : turn);
          return Transform(
            alignment: Alignment.center,
            transform: transform,
            child: CustomPaint(
              painter: CreaturePainter(
                card: widget.card,
                phase: phase,
                turn: turn,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

/// Kartu maskot untuk logo/splash — hanya visual, bukan data inventory.
CardModel mascotCard(
  String id,
  CardElement element, {
  Rarity rarity = Rarity.rare,
}) {
  return CardModel(
    id: id,
    name: id,
    element: element,
    rarity: rarity,
    type: CardType.unit,
    cost: 1,
    hp: 1,
    attack: 1,
    defense: 0,
    keywords: const <String>{},
    ability: null,
    flavorText: '',
    imageUrl: '',
    thumbnailUrl: null,
    model3dUrl: null,
    obtainable: false,
    retired: false,
    version: 1,
  );
}

/// Hash stabil (FNV-1a 32-bit) — tidak memakai `String.hashCode` yang bisa
/// berbeda antar platform.
int creatureSeed(String id) {
  var hash = 0x811C9DC5;
  for (final unit in id.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

class CreaturePainter extends CustomPainter {
  CreaturePainter({
    required this.card,
    required this.phase,
    required this.turn,
  })  : seed = creatureSeed(card.id),
        palette = CreaturePalette.of(card.element);

  final CardModel card;
  final double phase;
  final double turn;
  final int seed;
  final CreaturePalette palette;

  static const Color _ink = Color(0xFF1B1530);

  double get _wave => math.sin(phase * math.pi * 2);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (card.isUnit) {
      _paintCreature(canvas, size);
    } else {
      _paintSpellCrystal(canvas, size);
    }
  }

  // ---------------------------------------------------------------- creature

  void _paintCreature(Canvas canvas, Size size) {
    final u = math.min(size.width, size.height * 0.9);
    final cx = size.width / 2;
    final groundY = size.height * 0.86;
    final bob = _wave;

    final shape = seed % 3;
    final (rxF, ryF) = switch (shape) {
      0 => (0.30, 0.27),
      1 => (0.26, 0.31),
      _ => (0.33, 0.25),
    };
    final rx = u * rxF * (1 + 0.025 * bob);
    final ry = u * ryF * (1 - 0.025 * bob);
    final cy = groundY - ry - u * 0.07 - bob * u * 0.025;
    final body = Rect.fromCenter(
      center: Offset(cx, cy),
      width: rx * 2,
      height: ry * 2,
    );

    if (card.rarity.isRarePlus) _paintAura(canvas, body, u);
    _paintShadow(canvas, Offset(cx, groundY), rx, bob);
    _paintBackFeatures(canvas, body, u);
    _paintFeet(canvas, body);
    _paintBody(canvas, body);
    _paintEars(canvas, body);
    _paintFrontFeatures(canvas, body, u);
    _paintFace(canvas, body);
    _paintSpecular(canvas, body);
  }

  void _paintAura(Canvas canvas, Rect body, double u) {
    final color = AppTheme.rarityColor(card.rarity);
    final pulse = 0.85 + 0.15 * math.sin(phase * math.pi * 4);
    canvas.drawCircle(
      body.center,
      body.width * 0.95 * pulse,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            color.withValues(alpha: 0.42),
            color.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCircle(center: body.center, radius: body.width * pulse),
        ),
    );
    if (card.rarity.index >= Rarity.legendary.index) {
      final sparkle = Paint()..color = Colors.white.withValues(alpha: 0.85);
      for (var i = 0; i < 4; i++) {
        final angle = phase * math.pi * 2 + i * math.pi / 2;
        final pos = body.center +
            Offset(math.cos(angle), math.sin(angle) * 0.5) * body.width * 0.82;
        _star(canvas, pos, u * 0.025, sparkle);
      }
    }
  }

  void _paintShadow(Canvas canvas, Offset ground, double rx, double bob) {
    // Bayangan clay: elips solid yang dikaburkan, tepat di bawah kaki.
    final w = rx * 1.6 * (1 - 0.08 * bob);
    final rect = Rect.fromCenter(
      center: ground.translate(0, -rx * 0.18),
      width: w,
      height: w * 0.24,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18 - 0.03 * bob)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05),
    );
  }

  void _paintBody(Canvas canvas, Rect body) {
    final highlightCenter = Alignment(-0.35 - turn * 0.6, -0.5);
    canvas.drawOval(
      body,
      Paint()
        ..shader = RadialGradient(
          center: highlightCenter,
          radius: 1.05,
          colors: <Color>[palette.light, palette.base, palette.dark],
          stops: const <double>[0, 0.5, 1],
        ).createShader(body),
    );

    // Perut: oval terang yang ikut bergeser saat kreatur menoleh.
    final belly = Rect.fromCenter(
      center: body.center + Offset(turn * body.width * 0.12, body.height * 0.2),
      width: body.width * 0.56,
      height: body.height * 0.5,
    );
    canvas.drawOval(
      belly,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.4),
          colors: <Color>[
            palette.light.withValues(alpha: 0.95),
            palette.light.withValues(alpha: 0.35),
          ],
        ).createShader(belly),
    );

    // Rim light di sisi bawah-kanan memberi kesan volume.
    canvas.drawArc(
      body.deflate(body.width * 0.02),
      -0.1 - turn,
      math.pi * 0.75,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = body.width * 0.035
        ..strokeCap = StrokeCap.round
        ..color = palette.accent.withValues(alpha: 0.45),
    );
  }

  void _paintFeet(Canvas canvas, Rect body) {
    final paint = Paint()..color = palette.dark;
    for (final dir in const <double>[-1, 1]) {
      final foot = Rect.fromCenter(
        center: Offset(
          body.center.dx + dir * body.width * 0.24 + turn * body.width * 0.05,
          body.bottom - body.height * 0.02,
        ),
        width: body.width * 0.26,
        height: body.height * 0.16,
      );
      canvas.drawOval(foot, paint);
    }
    // Lengan kecil.
    final arm = Paint()..color = palette.base;
    for (final dir in const <double>[-1, 1]) {
      final swing = math.sin(phase * math.pi * 2 + dir) * 0.15;
      canvas.save();
      canvas.translate(
        body.center.dx + dir * body.width * 0.46,
        body.center.dy + body.height * 0.12,
      );
      canvas.rotate(dir * (0.5 + swing));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: body.width * 0.14,
          height: body.height * 0.26,
        ),
        arm,
      );
      canvas.restore();
    }
  }

  void _paintEars(Canvas canvas, Rect body) {
    final style = (seed >> 3) % 3;
    if (style == 2) return;
    final outer = Paint()..color = palette.base;
    final inner = Paint()..color = palette.light.withValues(alpha: 0.9);
    for (final dir in const <double>[-1, 1]) {
      final base = Offset(
        body.center.dx + dir * body.width * 0.27 + turn * body.width * 0.08,
        body.top + body.height * 0.14,
      );
      final wiggle = math.sin(phase * math.pi * 2 * 2 + dir) * 0.06;
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.rotate(dir * (0.38 + wiggle));
      if (style == 0) {
        final h = body.height * 0.48;
        final w = body.width * 0.2;
        canvas.drawPath(_earPath(w, h), outer);
        canvas.drawPath(_earPath(w * 0.55, h * 0.66), inner);
        // Ujung telinga lebih gelap, khas monster lucu.
        canvas.drawPath(
          _earPath(w * 0.4, h * 0.3).shift(Offset(0, -h * 0.7)),
          Paint()..color = palette.dark,
        );
      } else {
        final r = body.width * 0.15;
        canvas.drawCircle(Offset(0, -r * 0.7), r, outer);
        canvas.drawCircle(Offset(0, -r * 0.7), r * 0.58, inner);
      }
      canvas.restore();
    }
  }

  Path _earPath(double w, double h) {
    return Path()
      ..moveTo(-w / 2, 0)
      ..quadraticBezierTo(-w * 0.35, -h * 0.6, 0, -h)
      ..quadraticBezierTo(w * 0.35, -h * 0.6, w / 2, 0)
      ..close();
  }

  void _paintFace(Canvas canvas, Rect body) {
    final faceShift = turn * body.width * 0.22;
    final eyeY = body.center.dy - body.height * 0.08;
    final bigEyes = (seed >> 5).isEven;
    final ew = body.width * (bigEyes ? 0.15 : 0.13);
    final blink = phase > 0.9 && phase < 0.94 ? 0.12 : 1.0;
    final eh = body.height * (bigEyes ? 0.3 : 0.22) * blink;

    for (final dir in const <double>[-1, 1]) {
      // Mata sisi jauh mengecil sedikit saat menoleh (foreshortening).
      final foreshorten = 1 - (dir * turn).clamp(0.0, 1.0) * 0.35;
      final center = Offset(
        body.center.dx + dir * body.width * 0.19 + faceShift,
        eyeY,
      );
      final eye = Rect.fromCenter(
        center: center,
        width: ew * foreshorten,
        height: eh,
      );
      canvas.drawOval(eye, Paint()..color = _ink);
      if (blink < 1) continue;
      final iris = Rect.fromCenter(
        center: center + Offset(0, eh * 0.2),
        width: ew * 0.6 * foreshorten,
        height: eh * 0.4,
      );
      canvas.drawOval(
        iris,
        Paint()..color = palette.dark.withValues(alpha: 0.9),
      );
      canvas.drawCircle(
        center + Offset(-ew * 0.18, -eh * 0.2),
        ew * 0.24,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        center + Offset(ew * 0.16, eh * 0.18),
        ew * 0.1,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }

    final blush = Paint()
      ..color = const Color(0xFFFF7FA0).withValues(alpha: 0.5);
    for (final dir in const <double>[-1, 1]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            body.center.dx + dir * body.width * 0.33 + faceShift,
            eyeY + body.height * 0.2,
          ),
          width: body.width * 0.13,
          height: body.height * 0.08,
        ),
        blush,
      );
    }

    final mouthCenter = Offset(
      body.center.dx + faceShift,
      eyeY + body.height * 0.2,
    );
    final mw = body.width * 0.1;
    final mouth = Path()
      ..moveTo(mouthCenter.dx - mw, mouthCenter.dy)
      ..quadraticBezierTo(
        mouthCenter.dx - mw / 2,
        mouthCenter.dy + mw * 0.9,
        mouthCenter.dx,
        mouthCenter.dy,
      )
      ..quadraticBezierTo(
        mouthCenter.dx + mw / 2,
        mouthCenter.dy + mw * 0.9,
        mouthCenter.dx + mw,
        mouthCenter.dy,
      );
    canvas.drawPath(
      mouth,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, body.width * 0.025)
        ..strokeCap = StrokeCap.round
        ..color = _ink,
    );
  }

  void _paintSpecular(Canvas canvas, Rect body) {
    final spot = Rect.fromCenter(
      center: body.center +
          Offset(
            -body.width * (0.22 + turn * 0.3),
            -body.height * 0.3,
          ),
      width: body.width * 0.24,
      height: body.height * 0.14,
    );
    canvas.save();
    canvas.translate(spot.center.dx, spot.center.dy);
    canvas.rotate(-0.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: spot.width,
        height: spot.height,
      ),
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: 0.75),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCenter(
            center: Offset.zero,
            width: spot.width,
            height: spot.height,
          ),
        ),
    );
    canvas.restore();
  }

  // ------------------------------------------------------- element features

  void _paintBackFeatures(Canvas canvas, Rect body, double u) {
    switch (card.element) {
      case CardElement.fire:
        final flicker = 1 + 0.12 * math.sin(phase * math.pi * 2 * 3);
        _flame(
          canvas,
          Offset(
            body.right - body.width * 0.05 - turn * body.width * 0.2,
            body.center.dy + body.height * 0.2,
          ),
          body.width * 0.42 * flicker,
          0.7,
        );
      case CardElement.water:
        _fishTail(canvas, body);
      case CardElement.earth:
        _rockPlates(canvas, body);
      case CardElement.air:
        _wings(canvas, body);
      case CardElement.voidElement:
        _orbs(canvas, body, u, back: true);
    }
  }

  void _paintFrontFeatures(Canvas canvas, Rect body, double u) {
    final top = Offset(
      body.center.dx + turn * body.width * 0.15,
      body.top + body.height * 0.06,
    );
    switch (card.element) {
      case CardElement.fire:
        final flicker = 1 + 0.1 * math.sin(phase * math.pi * 2 * 4 + 1);
        _flame(canvas, top, body.width * 0.3 * flicker, -0.1);
      case CardElement.water:
        _headFin(canvas, top, body);
        _bubbles(canvas, body);
      case CardElement.earth:
        _sprout(canvas, top, body);
      case CardElement.air:
        _swirl(canvas, top, body);
      case CardElement.voidElement:
        _horns(canvas, body);
        _orbs(canvas, body, u, back: false);
    }
  }

  void _flame(Canvas canvas, Offset base, double height, double tilt) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(tilt);
    final w = height * 0.55;
    final path = Path()
      ..moveTo(0, 0)
      ..cubicTo(-w, -height * 0.15, -w * 0.4, -height * 0.7, 0, -height)
      ..cubicTo(w * 0.15, -height * 0.6, w * 0.9, -height * 0.45, w * 0.5, 0)
      ..close();
    final bounds = Rect.fromLTWH(-w, -height, w * 2, height);
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[
            Color(0xFFE2361B),
            Color(0xFFFF9A2E),
            Color(0xFFFFF27A)
          ],
        ).createShader(bounds),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x55FFB347)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6),
    );
    canvas.restore();
  }

  void _fishTail(Canvas canvas, Rect body) {
    final sway = math.sin(phase * math.pi * 2 * 2) * 0.25;
    canvas.save();
    canvas.translate(
      body.right - body.width * 0.08 - turn * body.width * 0.2,
      body.center.dy + body.height * 0.3,
    );
    canvas.rotate(-0.6 + sway);
    final w = body.width * 0.36;
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(w * 0.5, -w * 0.1, w, -w * 0.5)
      ..quadraticBezierTo(w * 0.7, 0, w, w * 0.5)
      ..quadraticBezierTo(w * 0.5, w * 0.1, 0, 0);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[palette.base, palette.accent],
        ).createShader(Rect.fromLTWH(0, -w / 2, w, w)),
    );
    canvas.restore();
  }

  void _headFin(Canvas canvas, Offset top, Rect body) {
    final h = body.height * 0.45;
    final path = Path()
      ..moveTo(top.dx - body.width * 0.12, top.dy + h * 0.2)
      ..quadraticBezierTo(top.dx - body.width * 0.05, top.dy - h,
          top.dx + body.width * 0.2, top.dy - h * 0.7)
      ..quadraticBezierTo(top.dx + body.width * 0.05, top.dy - h * 0.2,
          top.dx + body.width * 0.12, top.dy + h * 0.2)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[palette.base, palette.accent],
        ).createShader(Rect.fromLTWH(
            top.dx - body.width * 0.2, top.dy - h, body.width * 0.4, h * 1.2)),
    );
  }

  void _bubbles(Canvas canvas, Rect body) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, body.width * 0.02)
      ..color = palette.light.withValues(alpha: 0.8);
    for (var i = 0; i < 3; i++) {
      final t = (phase + i / 3) % 1;
      final pos = Offset(
        body.left -
            body.width * 0.1 +
            math.sin(t * math.pi * 4 + i) * body.width * 0.05,
        body.bottom - t * body.height * 1.6,
      );
      final r = body.width * (0.04 + 0.02 * i);
      stroke.color = palette.light.withValues(alpha: 0.8 * (1 - t));
      canvas.drawCircle(pos, r, stroke);
    }
  }

  void _rockPlates(Canvas canvas, Rect body) {
    final rock = Paint()..color = palette.accent;
    final rockLight = Paint()
      ..color = Color.lerp(palette.accent, Colors.white, 0.35)!;
    for (var i = 0; i < 3; i++) {
      final angle = -math.pi / 2 + (i - 1) * 0.55 - turn * 0.3;
      final base = body.center +
          Offset(math.cos(angle) * body.width * 0.45,
              math.sin(angle) * body.height * 0.48);
      final h = body.height * (i == 1 ? 0.42 : 0.32);
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.rotate(angle + math.pi / 2);
      final w = body.width * 0.16;
      final plate = Path()
        ..moveTo(-w, 0)
        ..lineTo(-w * 0.35, -h)
        ..lineTo(w * 0.5, -h * 0.82)
        ..lineTo(w, 0)
        ..close();
      canvas.drawPath(plate, rock);
      final facet = Path()
        ..moveTo(-w, 0)
        ..lineTo(-w * 0.35, -h)
        ..lineTo(0, 0)
        ..close();
      canvas.drawPath(facet, rockLight);
      canvas.restore();
    }
  }

  void _sprout(Canvas canvas, Offset top, Rect body) {
    final sway = math.sin(phase * math.pi * 2) * 0.15;
    canvas.save();
    canvas.translate(top.dx, top.dy);
    canvas.rotate(sway);
    final stem = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, body.width * 0.03)
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF3F7D20);
    final h = body.height * 0.3;
    canvas.drawLine(Offset.zero, Offset(0, -h), stem);
    final leaf = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[Color(0xFF5FBF3A), Color(0xFFB6F07A)],
      ).createShader(Rect.fromLTWH(-h, -h * 1.5, h * 2, h));
    for (final dir in const <double>[-1, 1]) {
      canvas.save();
      canvas.translate(0, -h);
      canvas.rotate(dir * 0.9);
      canvas.drawOval(
        Rect.fromLTWH(-h * 0.2, -h * 0.75, h * 0.4, h * 0.75),
        leaf,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  void _wings(Canvas canvas, Rect body) {
    final flap = math.sin(phase * math.pi * 2 * 2) * 0.3;
    for (final dir in const <double>[-1, 1]) {
      canvas.save();
      canvas.translate(
        body.center.dx + dir * body.width * 0.38 - turn * body.width * 0.1,
        body.center.dy - body.height * 0.1,
      );
      canvas.rotate(dir * (0.9 + flap));
      for (var f = 0; f < 3; f++) {
        final len = body.width * (0.55 - f * 0.1);
        final feather = Rect.fromLTWH(
          dir > 0 ? 0 : -len,
          -body.height * 0.09 + f * body.height * 0.08,
          len,
          body.height * 0.17,
        );
        canvas.drawOval(
          feather,
          Paint()
            ..shader = LinearGradient(
              begin: dir > 0 ? Alignment.centerLeft : Alignment.centerRight,
              end: dir > 0 ? Alignment.centerRight : Alignment.centerLeft,
              colors: <Color>[
                palette.light,
                palette.accent.withValues(alpha: 0.85)
              ],
            ).createShader(feather),
        );
      }
      canvas.restore();
    }
  }

  void _swirl(Canvas canvas, Offset top, Rect body) {
    final r = body.width * 0.14;
    final path = Path();
    for (var i = 0; i <= 24; i++) {
      final t = i / 24;
      final angle = t * math.pi * 3 + phase * math.pi * 2;
      final rr = r * (1 - t * 0.7);
      final p = Offset(
          top.dx + math.cos(angle) * rr, top.dy - r + math.sin(angle) * rr);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, body.width * 0.035)
        ..strokeCap = StrokeCap.round
        ..color = palette.accent,
    );
  }

  void _horns(Canvas canvas, Rect body) {
    for (final dir in const <double>[-1, 1]) {
      final base = Offset(
        body.center.dx + dir * body.width * 0.22 + turn * body.width * 0.1,
        body.top + body.height * 0.12,
      );
      final h = body.height * 0.42;
      final w = body.width * 0.12;
      final path = Path()
        ..moveTo(base.dx - w, base.dy)
        ..quadraticBezierTo(base.dx - w + dir * w * 0.5, base.dy - h * 0.7,
            base.dx + dir * w * 1.6, base.dy - h)
        ..quadraticBezierTo(
            base.dx + dir * w * 0.2, base.dy - h * 0.4, base.dx + w, base.dy)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: <Color>[palette.dark, palette.accent],
          ).createShader(Rect.fromLTWH(base.dx - w * 2, base.dy - h, w * 4, h)),
      );
    }
  }

  void _orbs(Canvas canvas, Rect body, double u, {required bool back}) {
    for (var i = 0; i < 2; i++) {
      final angle = phase * math.pi * 2 + i * math.pi;
      final depth = math.sin(angle);
      // Orb di belakang tubuh saat depth < 0, di depan saat depth >= 0.
      if (back != (depth < 0)) continue;
      final pos = body.center +
          Offset(math.cos(angle) * body.width * 0.75,
              -body.height * 0.2 + depth * body.height * 0.15);
      final r = u * 0.035 * (1 + depth * 0.3);
      canvas.drawCircle(
        pos,
        r * 2.4,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              palette.accent.withValues(alpha: 0.6),
              palette.accent.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: pos, radius: r * 2.4)),
      );
      canvas.drawCircle(pos, r, Paint()..color = palette.light);
    }
  }

  // ----------------------------------------------------------------- spells

  void _paintSpellCrystal(Canvas canvas, Size size) {
    final u = math.min(size.width, size.height * 0.9);
    final center = Offset(size.width / 2, size.height * 0.5 - _wave * u * 0.04);
    final color = AppTheme.elementColor(card.element);

    // Lingkaran rune dalam perspektif (ellipse) yang berputar.
    final ring = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.78),
      width: u * 0.8,
      height: u * 0.26,
    );
    canvas.drawOval(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, u * 0.012)
        ..color = color.withValues(alpha: 0.7),
    );
    canvas.drawOval(
      ring.deflate(u * 0.05),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, u * 0.006)
        ..color = palette.accent.withValues(alpha: 0.5),
    );
    final tick = Paint()..color = palette.light.withValues(alpha: 0.9);
    for (var i = 0; i < 10; i++) {
      final angle = phase * math.pi * 2 + i * math.pi / 5;
      final pos = ring.center +
          Offset(math.cos(angle) * ring.width / 2.2,
              math.sin(angle) * ring.height / 2.2);
      canvas.drawCircle(pos, u * 0.012 * (1 + math.sin(angle) * 0.4), tick);
    }

    // Glow.
    canvas.drawCircle(
      center,
      u * 0.42,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0)
          ],
        ).createShader(Rect.fromCircle(center: center, radius: u * 0.42)),
    );

    // Kristal berfaset; faset kiri/kanan bertukar terang saat berputar.
    final h = u * 0.5;
    final w = u * 0.2 * (0.75 + 0.25 * math.cos(phase * math.pi * 2).abs());
    final top = center + Offset(0, -h / 2);
    final bottom = center + Offset(0, h / 2);
    final mid = center + Offset(turn * w * 0.8, -h * 0.08);
    final left = center + Offset(-w, -h * 0.08);
    final right = center + Offset(w, -h * 0.08);
    final lit = _wave > 0;
    void facet(List<Offset> pts, Color c) {
      canvas.drawPath(Path()..addPolygon(pts, true), Paint()..color = c);
    }

    facet(<Offset>[top, left, mid], lit ? palette.light : palette.base);
    facet(<Offset>[top, mid, right], lit ? palette.base : palette.light);
    facet(<Offset>[left, bottom, mid], palette.dark);
    facet(<Offset>[mid, bottom, right],
        Color.lerp(palette.dark, palette.base, 0.5)!);
    _star(canvas, top + Offset(-w * 0.2, h * 0.18), u * 0.03,
        Paint()..color = Colors.white);
  }

  void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r * 2)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r * 2, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r * 2)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r * 2, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r * 2)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CreaturePainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.card.id != card.id ||
      oldDelegate.turn != turn;
}

/// Panggung clay + kreatur: latar pastel polos dan lantai bundar solid.
/// Dipakai sebagai artwork bila gambar kartu tidak tersedia.
class CreatureScene extends StatelessWidget {
  const CreatureScene({
    super.key,
    required this.card,
    this.animate = true,
    this.mirrored = false,
  });

  final CardModel card;
  final bool animate;
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.elementPastel(card.element),
      child: CustomPaint(
        painter: _StagePainter(AppTheme.elementColor(card.element)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: CreatureAvatar(
            card: card,
            animate: animate,
            mirrored: mirrored,
          ),
        ),
      ),
    );
  }
}

class _StagePainter extends CustomPainter {
  const _StagePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Lingkaran latar besar (warna solid tipis), lalu lantai bundar.
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.45),
      size.shortestSide * 0.42,
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
    final floor = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.88),
      width: size.width * 0.78,
      height: size.height * 0.14,
    );
    canvas.drawOval(floor, Paint()..color = color.withValues(alpha: 0.22));
    canvas.drawOval(
      floor.deflate(size.width * 0.06),
      Paint()..color = Colors.white.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(covariant _StagePainter oldDelegate) =>
      oldDelegate.color != color;
}
