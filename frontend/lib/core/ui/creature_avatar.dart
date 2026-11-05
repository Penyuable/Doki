import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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

/// Jam animasi bersama untuk semua kreatur: satu [Ticker], dibatasi ~30 fps,
/// hanya berjalan selama ada kreatur yang tampil. Kreatur cukup repaint
/// (tanpa rebuild widget), jadi grid berisi banyak kartu tetap ringan.
class CreatureClock extends ChangeNotifier {
  CreatureClock._();

  static final CreatureClock instance = CreatureClock._();

  static const Duration _frame = Duration(milliseconds: 33);

  Ticker? _ticker;
  Duration _elapsed = Duration.zero;
  Duration _lastNotified = Duration.zero;
  Duration _offset = Duration.zero;
  int _listeners = 0;

  /// Ticker sedang berjalan (ada kreatur hidup di layar).
  bool get isRunning => _ticker?.isActive ?? false;

  /// Waktu berjalan dalam detik.
  double get seconds => (_offset + _elapsed).inMicroseconds / 1e6;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _listeners += 1;
    if (_listeners == 1) {
      _ticker ??= Ticker(_tick, debugLabel: 'CreatureClock');
      if (!_ticker!.isActive) _ticker!.start();
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _listeners -= 1;
    if (_listeners <= 0) {
      _listeners = 0;
      if (_ticker?.isActive ?? false) {
        _offset += _elapsed;
        _elapsed = Duration.zero;
        _lastNotified = Duration.zero;
        _ticker!.stop();
      }
    }
  }

  void _tick(Duration elapsed) {
    _elapsed = elapsed;
    if (elapsed - _lastNotified < _frame) return;
    _lastNotified = elapsed;
    notifyListeners();
  }
}

/// Karakter chibi lucu bergaya ilustrasi anime (cel-shading + garis luar),
/// digambar prosedural dari `card.id`. Animasi idle: melompat kecil dengan
/// squash & stretch, bergoyang, melirik, berkedip, dan sesekali tersenyum.
class CreatureAvatar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final live = animate && !reduce;
    Widget paint = CustomPaint(
      painter: CreaturePainter(
        card: card,
        clock: live ? CreatureClock.instance : null,
      ),
      size: Size.infinite,
    );
    if (mirrored) paint = Transform.flip(flipX: true, child: paint);
    return RepaintBoundary(child: paint);
  }
}

/// Kartu maskot untuk logo/splash — hanya visual, bukan data inventory.
CardModel mascotCard(
  String id,
  CardElement element, {
  Rarity rarity = Rarity.rare,
  String? name,
}) {
  return CardModel(
    id: id,
    name: name ?? id,
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

/// Spesies kreatur. Menentukan anatomi; elemen menentukan warna & aksen.
enum CreatureSpecies {
  dino,
  dragon,
  bird,
  pig,
  dog,
  bear,
  bunny,
  cat,
  turtle,
  golem,
  serpent,
  sprite,
  bug,
}

/// Kata kunci nama kartu → spesies (urutan penting: yang lebih spesifik dulu).
const List<(List<String>, CreatureSpecies)> _speciesKeywords = [
  (<String>['drake', 'dragon', 'wyvern'], CreatureSpecies.dragon),
  (<String>['dino', 'saur', 'rex', 'raptor', 'titan'], CreatureSpecies.dino),
  (
    <String>['phoenix', 'griffon', 'bird', 'hawk', 'sovereign', 'wisp', 'owl'],
    CreatureSpecies.bird,
  ),
  (<String>['pig', 'boar', 'hog', 'cinder'], CreatureSpecies.pig),
  (<String>['pup', 'dog', 'hound', 'wolf'], CreatureSpecies.dog),
  (<String>['cub', 'bear'], CreatureSpecies.bear),
  (<String>['hare', 'bunny', 'rabbit', 'hop'], CreatureSpecies.bunny),
  (<String>['stalker', 'cat', 'panther', 'lynx'], CreatureSpecies.cat),
  (
    <String>['turtle', 'tortoise', 'shell', 'tidal warden'],
    CreatureSpecies.turtle
  ),
  (
    <String>['golem', 'sentinel', 'warden', 'colossus', 'giant'],
    CreatureSpecies.golem,
  ),
  (<String>['serpent', 'snake', 'wyrm', 'naga'], CreatureSpecies.serpent),
  (
    <String>['sprite', 'nymph', 'fairy', 'devil', 'pixie'],
    CreatureSpecies.sprite
  ),
  (<String>['mite', 'beetle', 'bug', 'moth'], CreatureSpecies.bug),
];

/// Spesies untuk sebuah kartu: dari nama bila cocok, selain itu dari hash id.
CreatureSpecies speciesOf(CardModel card) {
  final name = card.name.toLowerCase();
  for (final (keywords, species) in _speciesKeywords) {
    for (final keyword in keywords) {
      if (name.contains(keyword)) return species;
    }
  }
  const fallback = <CreatureSpecies>[
    CreatureSpecies.pig,
    CreatureSpecies.dino,
    CreatureSpecies.bird,
    CreatureSpecies.dog,
    CreatureSpecies.bunny,
    CreatureSpecies.cat,
    CreatureSpecies.bear,
  ];
  return fallback[creatureSeed(card.id) % fallback.length];
}

Color _darken(Color color, [double amount = 0.15]) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

class CreaturePainter extends CustomPainter {
  CreaturePainter({required this.card, this.clock, double phase = 0.15})
      : _staticPhase = phase,
        seed = creatureSeed(card.id),
        palette = CreaturePalette.of(card.element),
        super(repaint: clock);

  final CardModel card;

  /// Jam animasi; null = gambar diam pada fase [_staticPhase].
  final CreatureClock? clock;
  final double _staticPhase;
  final int seed;
  final CreaturePalette palette;

  /// Durasi satu siklus idle (berbeda tiap kreatur agar tidak serempak).
  double get _cycle => 2.4 + (seed % 900) / 1000;

  /// Posisi dalam siklus idle, 0..1.
  double get phase {
    final c = clock;
    if (c == null) return _staticPhase;
    return ((c.seconds + (seed % 1000) / 250) / _cycle) % 1;
  }

  /// Arah lirikan wajah (-0.32..0.32), lebih lambat dari lompatan.
  double get turn {
    final c = clock;
    final t = c == null ? _staticPhase : c.seconds / (_cycle * 2.3) + seed % 7;
    return math.sin(t * math.pi * 2) * 0.32;
  }

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

  CreatureSpecies get species => speciesOf(card);

  void _paintCreature(Canvas canvas, Size size) {
    final u = math.min(size.width, size.height * 0.9);
    final cx = size.width / 2;
    final groundY = size.height * 0.86;
    final kind = species;
    final hover = kind == CreatureSpecies.sprite;
    _lineW = (u * 0.013).clamp(1.0, 3.2);
    // Lompatan kecil: naik (stretch) lalu mendarat (squash).
    final s = _wave;
    final air = math.max(0.0, s);
    final land = math.max(0.0, -s);
    final heavy =
        kind == CreatureSpecies.golem || kind == CreatureSpecies.turtle;
    final bounce = kind == CreatureSpecies.serpent ? 0.0 : (heavy ? 0.45 : 1.0);

    final (rxF, ryF) = switch (kind) {
      CreatureSpecies.dino => (0.27, 0.29),
      CreatureSpecies.dragon => (0.27, 0.28),
      CreatureSpecies.bird => (0.28, 0.27),
      CreatureSpecies.pig => (0.32, 0.25),
      CreatureSpecies.dog => (0.29, 0.27),
      CreatureSpecies.bear => (0.31, 0.28),
      CreatureSpecies.bunny => (0.26, 0.25),
      CreatureSpecies.cat => (0.27, 0.27),
      CreatureSpecies.turtle => (0.33, 0.24),
      CreatureSpecies.golem => (0.31, 0.29),
      CreatureSpecies.serpent => (0.22, 0.19),
      CreatureSpecies.sprite => (0.24, 0.27),
      CreatureSpecies.bug => (0.30, 0.25),
    };
    final grow = 0.9 + 0.04 * _tier;
    final rx = u * rxF * grow * (1 + bounce * (0.07 * land - 0.03 * air));
    final ry = u * ryF * grow * (1 + bounce * (0.05 * air - 0.07 * land));
    final lift = hover
        ? u * (0.12 + 0.04 * s)
        : u * 0.07 + bounce * air * air * u * 0.07;
    final baseY = kind == CreatureSpecies.serpent
        ? groundY - u * 0.36
        : groundY - ry - lift;
    final body = Rect.fromCenter(
      center: Offset(cx, baseY),
      width: rx * 2,
      height: ry * 2,
    );

    if (card.rarity.isRarePlus) _paintAura(canvas, body, u);
    _paintShadow(
      canvas,
      Offset(cx, groundY),
      hover ? rx * 0.7 : rx * (kind == CreatureSpecies.serpent ? 1.6 : 1),
      hover ? 0.5 : air * bounce,
    );

    // Goyang kiri-kanan dari titik tumpu di tanah.
    canvas.save();
    canvas.translate(cx, groundY);
    canvas.rotate(math.sin(phase * math.pi * 2 * 0.5) * 0.05);
    canvas.translate(-cx, -groundY);

    switch (kind) {
      case CreatureSpecies.dino:
        _dino(canvas, body, u, dragon: false);
      case CreatureSpecies.dragon:
        _dino(canvas, body, u, dragon: true);
      case CreatureSpecies.bird:
        _bird(canvas, body);
      case CreatureSpecies.pig:
        _pig(canvas, body);
      case CreatureSpecies.dog:
        _dog(canvas, body);
      case CreatureSpecies.bear:
        _bear(canvas, body);
      case CreatureSpecies.bunny:
        _bunny(canvas, body);
      case CreatureSpecies.cat:
        _cat(canvas, body);
      case CreatureSpecies.turtle:
        _turtle(canvas, body);
      case CreatureSpecies.golem:
        _golem(canvas, body);
      case CreatureSpecies.serpent:
        _serpent(canvas, body, u, groundY);
      case CreatureSpecies.sprite:
        _sprite(canvas, body);
      case CreatureSpecies.bug:
        _bug(canvas, body);
    }
    _paintElementAccent(canvas, body, u, kind);
    if (_tier >= Rarity.legendary.index) _crown(canvas, body, kind);
    canvas.restore();
  }

  // ------------------------------------------------------------ helpers

  double get _faceShift => turn * 0.22;

  /// Tingkat "evolusi" = indeks rarity (0 Common … 5 Master).
  int get _tier => card.rarity.index;

  /// Mahkota kecil untuk Legendary+.
  void _crown(Canvas canvas, Rect b, CreatureSpecies kind) {
    final lift = switch (kind) {
      CreatureSpecies.bunny => b.height * 0.05,
      CreatureSpecies.bird || CreatureSpecies.dragon => b.height * 0.3,
      CreatureSpecies.serpent => b.height * 0.05,
      _ => b.height * 0.12,
    };
    final c = Offset(b.center.dx + turn * b.width * 0.15, b.top - lift);
    final w = b.width * 0.36;
    final h = b.height * 0.24;
    final bob = math.sin(phase * math.pi * 2 * 2) * b.height * 0.015;
    final crown = Path()
      ..moveTo(c.dx - w / 2, c.dy + bob)
      ..lineTo(c.dx - w / 2, c.dy - h * 0.7 + bob)
      ..lineTo(c.dx - w / 4, c.dy - h * 0.25 + bob)
      ..lineTo(c.dx, c.dy - h + bob)
      ..lineTo(c.dx + w / 4, c.dy - h * 0.25 + bob)
      ..lineTo(c.dx + w / 2, c.dy - h * 0.7 + bob)
      ..lineTo(c.dx + w / 2, c.dy + bob)
      ..close();
    canvas.drawPath(crown, Paint()..color = const Color(0xFFFFC93C));
    canvas.drawPath(crown, _stroke(b.width * 0.015, const Color(0xFFE09A1A)));
    canvas.drawCircle(
      Offset(c.dx, c.dy - h * 0.35 + bob),
      b.width * 0.035,
      Paint()..color = const Color(0xFFFF5D8F),
    );
  }

  /// Tebal & warna garis luar ala ilustrasi anime.
  double _lineW = 1.5;
  Color get _lineColor => _darken(palette.dark, 0.14);

  /// Cel-shading: isian datar + bayangan sabit kanan-bawah + garis luar.
  void _celPath(Canvas canvas, Path path, {Color? base, Color? shade}) {
    final r = path.getBounds();
    canvas.drawPath(path, Paint()..color = base ?? palette.base);
    canvas.save();
    canvas.clipPath(path);
    final crescent = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(r.inflate(r.longestSide))
      ..addOval(
        r
            .shift(Offset(-r.width * (0.1 + turn * 0.1), -r.height * 0.13))
            .inflate(r.shortestSide * 0.02),
      );
    canvas.drawPath(
      crescent,
      Paint()..color = (shade ?? palette.dark).withValues(alpha: 0.3),
    );
    canvas.restore();
    canvas.drawPath(path, _stroke(_lineW, _lineColor));
  }

  void _blob(Canvas canvas, Rect r, {Color? base, Color? dark}) {
    _celPath(canvas, Path()..addOval(r), base: base, shade: dark);
  }

  Color get _soft => Color.lerp(palette.light, Colors.white, 0.35)!;

  void _belly(Canvas canvas, Rect b, {double w = 0.56, double h = 0.5}) {
    final belly = Rect.fromCenter(
      center: b.center + Offset(turn * b.width * 0.12, b.height * 0.2),
      width: b.width * w,
      height: b.height * h,
    );
    canvas.drawOval(
      belly,
      Paint()..color = palette.light.withValues(alpha: 0.85),
    );
  }

  void _rim(Canvas canvas, Rect b) {
    canvas.drawArc(
      b.deflate(b.width * 0.02),
      -0.1 - turn,
      math.pi * 0.75,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = b.width * 0.03
        ..strokeCap = StrokeCap.round
        ..color = palette.accent.withValues(alpha: 0.4),
    );
  }

  void _specular(Canvas canvas, Rect b, {double y = -0.3}) {
    final c = b.center + Offset(-b.width * (0.22 + turn * 0.3), b.height * y);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: b.width * 0.18,
        height: b.height * 0.09,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
    canvas.restore();
  }

  bool get _blinking => phase > 0.9 && phase < 0.94;

  /// Sesekali tersenyum lebar (mata ^ ^, mulut terbuka).
  bool get _happy => ((seed >> 7) % 3 != 0) && phase > 0.52 && phase < 0.68;

  /// Sepasang mata ala chibi dengan foreshortening saat menoleh.
  void _eyes(
    Canvas canvas,
    Offset center,
    double spacing,
    double w,
    double h, {
    bool slit = false,
    Color? glow,
  }) {
    final eh = _blinking ? h * 0.12 : h;
    for (final dir in const <double>[-1, 1]) {
      final fore = 1 - (dir * turn).clamp(0.0, 1.0) * 0.35;
      final c = center + Offset(dir * spacing, 0);
      final eye = Rect.fromCenter(center: c, width: w * fore, height: eh);
      if (glow != null) {
        canvas.drawOval(
          eye.inflate(w * 0.25),
          Paint()..color = glow.withValues(alpha: 0.3),
        );
        canvas.drawOval(eye, Paint()..color = glow);
        canvas.drawOval(
          eye.deflate(w * 0.18),
          Paint()..color = Colors.white.withValues(alpha: 0.8),
        );
        continue;
      }
      if (_happy && !slit) {
        // Mata senyum ^ ^.
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - w * 0.5 * fore, c.dy + h * 0.12)
            ..quadraticBezierTo(
                c.dx, c.dy - h * 0.45, c.dx + w * 0.5 * fore, c.dy + h * 0.12),
          _stroke(w * 0.26, _ink),
        );
        continue;
      }
      canvas.drawOval(eye, Paint()..color = _ink);
      if (_blinking) continue;
      if (slit) {
        canvas.drawOval(
          Rect.fromCenter(center: c, width: w * 0.55 * fore, height: eh * 0.9),
          Paint()..color = palette.accent,
        );
        canvas.drawOval(
          Rect.fromCenter(center: c, width: w * 0.16, height: eh * 0.8),
          Paint()..color = _ink,
        );
      } else {
        canvas.drawOval(
          Rect.fromCenter(
            center: c + Offset(0, eh * 0.2),
            width: w * 0.6 * fore,
            height: eh * 0.4,
          ),
          Paint()..color = palette.dark.withValues(alpha: 0.9),
        );
      }
      canvas.drawCircle(
        c + Offset(-w * 0.18, -eh * 0.2),
        w * 0.24,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        c + Offset(w * 0.16, eh * 0.18),
        w * 0.1,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }
  }

  void _blush(Canvas canvas, Offset center, double spacing, double w) {
    final paint = Paint()
      ..color = const Color(0xFFFF7FA0).withValues(alpha: 0.5);
    for (final dir in const <double>[-1, 1]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center + Offset(dir * spacing, 0),
          width: w,
          height: w * 0.6,
        ),
        paint,
      );
    }
  }

  Paint _stroke(double width, Color color) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1, width)
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color;

  void _smile(Canvas canvas, Offset c, double w) {
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - w, c.dy)
        ..quadraticBezierTo(c.dx - w / 2, c.dy + w * 0.9, c.dx, c.dy)
        ..quadraticBezierTo(c.dx + w / 2, c.dy + w * 0.9, c.dx + w, c.dy),
      _stroke(w * 0.25, _ink),
    );
  }

  /// Mulut terbuka tertawa dengan lidah.
  void _openMouth(Canvas canvas, Offset c, double w) {
    final mouth = Path()
      ..moveTo(c.dx - w, c.dy)
      ..quadraticBezierTo(c.dx, c.dy + w * 1.7, c.dx + w, c.dy)
      ..close();
    canvas.drawPath(mouth, Paint()..color = const Color(0xFF7A1F3D));
    canvas.save();
    canvas.clipPath(mouth);
    canvas.drawCircle(
      Offset(c.dx, c.dy + w * 1.1),
      w * 0.6,
      Paint()..color = const Color(0xFFFF7FA0),
    );
    canvas.restore();
    canvas.drawPath(mouth, _stroke(w * 0.18, _ink));
  }

  /// Wajah standar: mata, pipi, mulut.
  void _face(
    Canvas canvas,
    Rect b, {
    double eyeY = -0.08,
    double eyeSpread = 0.19,
    double eyeW = 0.14,
    double eyeH = 0.27,
    bool mouth = true,
    bool slit = false,
  }) {
    final fx = b.width * _faceShift;
    final eyeC = Offset(b.center.dx + fx, b.center.dy + b.height * eyeY);
    _eyes(
      canvas,
      eyeC,
      b.width * eyeSpread,
      b.width * eyeW,
      b.height * eyeH,
      slit: slit,
    );
    _blush(
      canvas,
      eyeC + Offset(0, b.height * 0.2),
      b.width * (eyeSpread + 0.14),
      b.width * 0.13,
    );
    if (mouth) {
      final m = eyeC + Offset(0, b.height * 0.2);
      if (_happy) {
        _openMouth(canvas, m, b.width * 0.1);
      } else {
        _smile(canvas, m, b.width * 0.09);
      }
    }
  }

  void _feet(
    Canvas canvas,
    Rect b, {
    double spread = 0.24,
    double w = 0.26,
    double h = 0.16,
    Color? color,
  }) {
    final paint = Paint()..color = color ?? palette.dark;
    for (final dir in const <double>[-1, 1]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            b.center.dx + dir * b.width * spread + turn * b.width * 0.05,
            b.bottom - b.height * 0.02,
          ),
          width: b.width * w,
          height: b.height * h,
        ),
        paint,
      );
    }
  }

  void _arms(Canvas canvas, Rect b, {double size = 1, Color? color}) {
    final paint = Paint()..color = color ?? palette.base;
    for (final dir in const <double>[-1, 1]) {
      final swing = math.sin(phase * math.pi * 2 + dir) * 0.15;
      canvas.save();
      canvas.translate(
        b.center.dx + dir * b.width * 0.46,
        b.center.dy + b.height * 0.12,
      );
      canvas.rotate(dir * (0.5 + swing));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: b.width * 0.14 * size,
          height: b.height * 0.26 * size,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  Path _triangle(Offset a, Offset b, Offset c) => Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(b.dx, b.dy)
    ..lineTo(c.dx, c.dy)
    ..close();

  double get _sway => math.sin(phase * math.pi * 2 * 2);

  // ------------------------------------------------------------ species

  /// Dinosaurus chibi (atau naga bila [dragon]): duri punggung, ekor panjang,
  /// gigi kecil; naga menambah tanduk & sayap kelelawar.
  void _dino(Canvas canvas, Rect b, double u, {required bool dragon}) {
    final tailSway = _sway * 0.08;
    // Sayap naga di belakang.
    if (dragon) {
      final flap = _sway * 0.25;
      for (final dir in const <double>[-1, 1]) {
        canvas.save();
        canvas.translate(
          b.center.dx + dir * b.width * 0.3,
          b.center.dy - b.height * 0.15,
        );
        canvas.rotate(dir * (0.35 + flap));
        final w = b.width * 0.7;
        final h = b.height * 0.7;
        final wing = Path()
          ..moveTo(0, 0)
          ..lineTo(dir * w * 0.25, -h)
          ..quadraticBezierTo(dir * w * 0.6, -h * 0.75, dir * w, -h * 0.6)
          ..quadraticBezierTo(
              dir * w * 0.7, -h * 0.35, dir * w * 0.85, -h * 0.05)
          ..quadraticBezierTo(dir * w * 0.45, -h * 0.1, 0, 0)
          ..close();
        canvas.drawPath(wing, Paint()..color = palette.dark);
        canvas.drawPath(
          wing,
          Paint()..color = palette.accent.withValues(alpha: 0.35),
        );
        canvas.drawLine(
          Offset.zero,
          Offset(dir * w * 0.25, -h),
          _stroke(b.width * 0.03, palette.dark),
        );
        canvas.restore();
      }
    }
    // Ekor meruncing ke kanan-bawah.
    final tailBase =
        Offset(b.right - b.width * 0.15, b.bottom - b.height * 0.25);
    final tip = Offset(
      b.right + b.width * 0.5,
      b.bottom - b.height * (0.55 + tailSway),
    );
    final tail = Path()
      ..moveTo(tailBase.dx - b.width * 0.1, tailBase.dy - b.height * 0.22)
      ..quadraticBezierTo(
        b.right + b.width * 0.25,
        b.bottom - b.height * 0.05,
        tip.dx,
        tip.dy,
      )
      ..quadraticBezierTo(
        b.right + b.width * 0.15,
        b.bottom + b.height * 0.08,
        tailBase.dx - b.width * 0.15,
        tailBase.dy + b.height * 0.15,
      )
      ..close();
    _celPath(canvas, tail);
    if (dragon) {
      canvas.drawPath(
        _triangle(
          tip + Offset(-b.width * 0.08, -b.height * 0.05),
          tip + Offset(b.width * 0.1, -b.height * 0.12),
          tip + Offset(b.width * 0.02, b.height * 0.1),
        ),
        Paint()..color = palette.dark,
      );
    }
    // Duri punggung (dari kepala ke ekor).
    final spike = Paint()..color = dragon ? palette.dark : palette.accent;
    for (var i = 0; i < 4; i++) {
      final angle = -math.pi / 2 + 0.35 + i * 0.38 - turn * 0.3;
      final base = b.center +
          Offset(math.cos(angle) * b.width * 0.48,
              math.sin(angle) * b.height * 0.48);
      final out = Offset(math.cos(angle), math.sin(angle));
      final side = Offset(-out.dy, out.dx);
      final s = b.width * (0.13 - i * 0.015);
      canvas.drawPath(
        _triangle(
            base + side * s * 0.7, base + out * s * 1.5, base - side * s * 0.7),
        spike,
      );
    }
    _feet(canvas, b, spread: 0.22, w: 0.3, h: 0.18);
    // Cakar.
    final claw = Paint()..color = Colors.white.withValues(alpha: 0.9);
    for (final dir in const <double>[-1, 1]) {
      final fc = Offset(
        b.center.dx + dir * b.width * 0.22 + turn * b.width * 0.05,
        b.bottom + b.height * 0.04,
      );
      for (var k = -1; k <= 1; k++) {
        canvas.drawCircle(
            fc + Offset(k * b.width * 0.06, 0), b.width * 0.022, claw);
      }
    }
    _blob(canvas, b);
    _belly(canvas, b, w: 0.5, h: 0.52);
    // Garis-garis perut.
    for (var i = 0; i < 3; i++) {
      final y = b.center.dy + b.height * (0.12 + i * 0.12);
      canvas.drawLine(
        Offset(b.center.dx - b.width * 0.12 + turn * b.width * 0.1, y),
        Offset(b.center.dx + b.width * 0.12 + turn * b.width * 0.1, y),
        _stroke(b.width * 0.015, palette.base.withValues(alpha: 0.5)),
      );
    }
    if (dragon) {
      final horn = Paint()..color = palette.accent;
      for (final dir in const <double>[-1, 1]) {
        final base = Offset(
          b.center.dx + dir * b.width * 0.2 + turn * b.width * 0.1,
          b.top + b.height * 0.12,
        );
        canvas.drawPath(
          Path()
            ..moveTo(base.dx - b.width * 0.06, base.dy)
            ..quadraticBezierTo(
              base.dx + dir * b.width * 0.02,
              base.dy - b.height * 0.3,
              base.dx + dir * b.width * 0.16,
              base.dy - b.height * 0.36,
            )
            ..quadraticBezierTo(
              base.dx + dir * b.width * 0.05,
              base.dy - b.height * 0.12,
              base.dx + b.width * 0.06,
              base.dy,
            )
            ..close(),
          horn,
        );
      }
    }
    _arms(canvas, b, size: 0.8);
    _face(canvas, b, eyeY: -0.12, eyeSpread: 0.18, mouth: false);
    // Moncong + lubang hidung + gigi.
    final fx = b.width * _faceShift;
    final m = Offset(b.center.dx + fx, b.center.dy + b.height * 0.1);
    for (final dir in const <double>[-1, 1]) {
      canvas.drawCircle(
        m + Offset(dir * b.width * 0.05, -b.height * 0.03),
        b.width * 0.018,
        Paint()..color = palette.dark,
      );
    }
    final mouth = Path()
      ..moveTo(m.dx - b.width * 0.13, m.dy + b.height * 0.05)
      ..quadraticBezierTo(m.dx, m.dy + b.height * 0.13, m.dx + b.width * 0.13,
          m.dy + b.height * 0.05);
    canvas.drawPath(mouth, _stroke(b.width * 0.022, _ink));
    final tooth = Paint()..color = Colors.white;
    for (final dir in const <double>[-1, 1]) {
      final t = Offset(m.dx + dir * b.width * 0.08, m.dy + b.height * 0.075);
      canvas.drawPath(
        _triangle(
          t + Offset(-b.width * 0.022, 0),
          t + Offset(b.width * 0.022, 0),
          t + Offset(0, b.height * 0.06),
        ),
        tooth,
      );
    }
    _rim(canvas, b);
    _specular(canvas, b);
  }

  /// Burung bulat: jambul, paruh, sayap mengepak, ekor kipas, kaki ranting.
  void _bird(Canvas canvas, Rect b) {
    const beak = Color(0xFFFFB238);
    if (_tier >= Rarity.legendary.index) {
      // Pita ekor panjang berkibar.
      for (final k in const <double>[-1, 1]) {
        final start =
            Offset(b.right - b.width * 0.1, b.center.dy + b.height * 0.2);
        final wave = math.sin(phase * math.pi * 2 + k) * b.height * 0.15;
        canvas.drawPath(
          Path()
            ..moveTo(start.dx, start.dy)
            ..cubicTo(
              start.dx + b.width * 0.4,
              start.dy - b.height * 0.2 + wave,
              start.dx + b.width * 0.5,
              start.dy + b.height * 0.4 + k * b.height * 0.1,
              start.dx + b.width * 0.85,
              start.dy + b.height * 0.1 + wave,
            ),
          _stroke(
              b.width * 0.05, k < 0 ? palette.accent : const Color(0xFFFFC93C)),
        );
      }
    }
    // Ekor kipas.
    for (var i = -1; i <= 1; i++) {
      canvas.save();
      canvas.translate(b.right - b.width * 0.1, b.center.dy + b.height * 0.25);
      canvas.rotate(-0.4 + i * 0.35 + _sway * 0.06);
      canvas.drawOval(
        Rect.fromLTWH(0, -b.height * 0.1, b.width * 0.5, b.height * 0.2),
        Paint()..color = i == 0 ? palette.accent : palette.dark,
      );
      canvas.restore();
    }
    // Kaki ranting.
    final legs = _stroke(b.width * 0.035, beak);
    for (final dir in const <double>[-1, 1]) {
      final top = Offset(
          b.center.dx + dir * b.width * 0.15, b.bottom - b.height * 0.05);
      final foot = top + Offset(0, b.height * 0.16);
      canvas.drawLine(top, foot, legs);
      for (final k in const <double>[-1, 0, 1]) {
        canvas.drawLine(
            foot, foot + Offset(k * b.width * 0.07, b.height * 0.04), legs);
      }
    }
    _blob(canvas, b);
    _belly(canvas, b, w: 0.6, h: 0.55);
    // Jambul tiga bulu.
    for (var i = -1; i <= 1; i++) {
      canvas.save();
      canvas.translate(
          b.center.dx + turn * b.width * 0.15, b.top + b.height * 0.08);
      canvas.rotate(i * 0.45 + _sway * 0.05);
      final h = b.height * (i == 0 ? 0.42 : 0.32);
      canvas.drawPath(
        Path()
          ..moveTo(-b.width * 0.05, 0)
          ..quadraticBezierTo(-b.width * 0.06, -h * 0.7, 0, -h)
          ..quadraticBezierTo(b.width * 0.06, -h * 0.7, b.width * 0.05, 0)
          ..close(),
        Paint()..color = i == 0 ? palette.accent : palette.base,
      );
      canvas.restore();
    }
    // Sayap di samping.
    final flap = _sway * 0.35;
    for (final dir in const <double>[-1, 1]) {
      canvas.save();
      canvas.translate(
          b.center.dx + dir * b.width * 0.42, b.center.dy + b.height * 0.02);
      canvas.rotate(dir * (0.35 + flap));
      final wing = Rect.fromCenter(
        center: Offset(dir * b.width * 0.08, b.height * 0.1),
        width: b.width * 0.3,
        height: b.height * 0.55,
      );
      _celPath(canvas, Path()..addOval(wing),
          base: palette.base, shade: palette.dark);
      canvas.drawOval(
        wing.deflate(b.width * 0.04).shift(Offset(0, b.height * 0.08)),
        Paint()..color = palette.accent.withValues(alpha: 0.5),
      );
      canvas.restore();
    }
    if (_tier >= 2 || card.name.toLowerCase().contains('griffon')) {
      for (final dir in const <double>[-1, 1]) {
        final base = Offset(
          b.center.dx + dir * b.width * 0.3 + turn * b.width * 0.08,
          b.top + b.height * 0.18,
        );
        canvas.drawPath(
          _triangle(
            base + Offset(-b.width * 0.09, 0),
            base + Offset(dir * b.width * 0.1, -b.height * 0.32),
            base + Offset(b.width * 0.09, 0),
          ),
          Paint()..color = palette.dark,
        );
      }
    }
    _face(canvas, b, eyeY: -0.12, eyeSpread: 0.2, mouth: false);
    // Paruh dua bagian.
    final fx = b.width * _faceShift;
    final p = Offset(b.center.dx + fx, b.center.dy + b.height * 0.06);
    final open = (math.sin(phase * math.pi * 6) * 0.5 + 0.5) * b.height * 0.03;
    canvas.drawPath(
      _triangle(
        p + Offset(-b.width * 0.09, 0),
        p + Offset(b.width * 0.09, 0),
        p + Offset(0, b.height * 0.13),
      ),
      Paint()..color = _darken(beak),
    );
    canvas.drawPath(
      _triangle(
        p + Offset(-b.width * 0.1, -open),
        p + Offset(b.width * 0.1, -open),
        p + Offset(0, b.height * 0.09 - open),
      ),
      Paint()..color = beak,
    );
    _specular(canvas, b);
  }

  /// Babi gempal: telinga lipat, moncong dengan dua lubang, ekor keriting.
  void _pig(Canvas canvas, Rect b) {
    final pink = Color.lerp(palette.light, const Color(0xFFFFA3BE), 0.45)!;
    // Ekor keriting.
    final tail = Path();
    final tc = Offset(b.right + b.width * 0.02, b.center.dy + b.height * 0.05);
    for (var i = 0; i <= 20; i++) {
      final t = i / 20;
      final a = t * math.pi * 3 + phase * math.pi * 2;
      final r = b.width * 0.09 * (1 - t * 0.6);
      final pt =
          tc + Offset(t * b.width * 0.12 + math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        tail.moveTo(pt.dx, pt.dy);
      } else {
        tail.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(tail, _stroke(b.width * 0.04, palette.base));
    _feet(canvas, b, spread: 0.28, w: 0.2, h: 0.18);
    _blob(canvas, b);
    _belly(canvas, b, w: 0.62, h: 0.45);
    // Telinga segitiga terlipat ke depan.
    for (final dir in const <double>[-1, 1]) {
      final base = Offset(
        b.center.dx + dir * b.width * 0.26 + turn * b.width * 0.08,
        b.top + b.height * 0.1,
      );
      final fold = math.sin(phase * math.pi * 4 + dir) * b.height * 0.02;
      canvas.drawPath(
        _triangle(
          base + Offset(-b.width * 0.12, b.height * 0.05),
          base + Offset(dir * b.width * 0.2, -b.height * 0.18 + fold),
          base + Offset(b.width * 0.12, b.height * 0.05),
        ),
        Paint()..color = palette.dark,
      );
      canvas.drawPath(
        _triangle(
          base + Offset(-b.width * 0.06, b.height * 0.04),
          base + Offset(dir * b.width * 0.13, -b.height * 0.1 + fold),
          base + Offset(b.width * 0.06, b.height * 0.04),
        ),
        Paint()..color = pink,
      );
    }
    _face(canvas, b,
        eyeY: -0.14, eyeSpread: 0.21, eyeW: 0.12, eyeH: 0.22, mouth: false);
    final fx = b.width * _faceShift;
    final snout = Rect.fromCenter(
      center: Offset(b.center.dx + fx * 1.2, b.center.dy + b.height * 0.13),
      width: b.width * 0.34,
      height: b.height * 0.26,
    );
    _celPath(canvas, Path()..addOval(snout), base: pink, shade: _darken(pink));
    for (final dir in const <double>[-1, 1]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: snout.center + Offset(dir * snout.width * 0.2, 0),
          width: snout.width * 0.14,
          height: snout.height * 0.36,
        ),
        Paint()..color = _darken(pink, 0.35),
      );
    }
    _smile(canvas, snout.bottomCenter + Offset(0, b.height * 0.05),
        b.width * 0.06);
    _rim(canvas, b);
    _specular(canvas, b);
  }

  /// Anak anjing: telinga terkulai, moncong, hidung, ekor bergoyang.
  void _dog(Canvas canvas, Rect b) {
    canvas.save();
    canvas.translate(b.right - b.width * 0.08, b.center.dy + b.height * 0.1);
    canvas.rotate(-0.9 + _sway * 0.35);
    canvas.drawOval(
      Rect.fromLTWH(
          -b.width * 0.06, -b.height * 0.42, b.width * 0.14, b.height * 0.42),
      Paint()..color = palette.base,
    );
    canvas.restore();
    _feet(canvas, b);
    _blob(canvas, b);
    _belly(canvas, b);
    for (final dir in const <double>[-1, 1]) {
      canvas.save();
      canvas.translate(
        b.center.dx + dir * b.width * 0.36 + turn * b.width * 0.08,
        b.top + b.height * 0.18,
      );
      canvas.rotate(dir * (0.25 + math.sin(phase * math.pi * 4 + dir) * 0.08));
      canvas.drawOval(
        Rect.fromLTWH(-b.width * 0.1, 0, b.width * 0.2, b.height * 0.5),
        Paint()..color = palette.dark,
      );
      canvas.restore();
    }
    _face(canvas, b, eyeY: -0.12, mouth: false);
    _muzzle(canvas, b);
    _arms(canvas, b, size: 0.8);
    _rim(canvas, b);
    _specular(canvas, b);
  }

  void _muzzle(Canvas canvas, Rect b, {double size = 1}) {
    final fx = b.width * _faceShift;
    final m = Rect.fromCenter(
      center: Offset(b.center.dx + fx * 1.15, b.center.dy + b.height * 0.13),
      width: b.width * 0.36 * size,
      height: b.height * 0.25 * size,
    );
    canvas.drawOval(m, Paint()..color = _soft);
    final nose = Rect.fromCenter(
      center: m.center + Offset(0, -m.height * 0.2),
      width: m.width * 0.32,
      height: m.height * 0.26,
    );
    canvas.drawOval(nose, Paint()..color = _ink);
    canvas.drawCircle(
      nose.center + Offset(-nose.width * 0.2, -nose.height * 0.2),
      nose.width * 0.12,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
    _smile(canvas, m.center + Offset(0, m.height * 0.12), b.width * 0.06);
  }

  /// Beruang: telinga bulat, moncong, ekor bulat kecil.
  void _bear(Canvas canvas, Rect b) {
    canvas.drawCircle(
      Offset(b.right - b.width * 0.05, b.center.dy + b.height * 0.3),
      b.width * 0.1,
      Paint()..color = palette.base,
    );
    _feet(canvas, b, spread: 0.26, w: 0.28);
    for (final dir in const <double>[-1, 1]) {
      final c = Offset(
        b.center.dx + dir * b.width * 0.3 + turn * b.width * 0.08,
        b.top + b.height * 0.08,
      );
      _celPath(canvas,
          Path()..addOval(Rect.fromCircle(center: c, radius: b.width * 0.15)));
      canvas.drawCircle(c, b.width * 0.08, Paint()..color = _soft);
    }
    _blob(canvas, b);
    _belly(canvas, b);
    _face(canvas, b, eyeY: -0.12, eyeW: 0.12, eyeH: 0.22, mouth: false);
    _muzzle(canvas, b, size: 1.05);
    _arms(canvas, b);
    _rim(canvas, b);
    _specular(canvas, b);
  }

  /// Kelinci: telinga panjang tegak, gigi kelinci, ekor kapas.
  void _bunny(Canvas canvas, Rect b) {
    canvas.drawCircle(
      Offset(b.right, b.center.dy + b.height * 0.3),
      b.width * 0.11,
      Paint()..color = Colors.white,
    );
    _feet(canvas, b, spread: 0.22, w: 0.34, h: 0.16);
    for (final dir in const <double>[-1, 1]) {
      canvas.save();
      canvas.translate(
        b.center.dx + dir * b.width * 0.17 + turn * b.width * 0.08,
        b.top + b.height * 0.1,
      );
      canvas.rotate(dir * (0.18 + math.sin(phase * math.pi * 2 + dir) * 0.08));
      final ear = Rect.fromLTWH(
          -b.width * 0.1, -b.height * 0.85, b.width * 0.2, b.height * 0.9);
      _celPath(canvas, Path()..addOval(ear));
      canvas.drawOval(
        ear.deflate(b.width * 0.045),
        Paint()..color = const Color(0xFFFFB3C7).withValues(alpha: 0.85),
      );
      canvas.restore();
    }
    _blob(canvas, b);
    _belly(canvas, b);
    _face(canvas, b, eyeY: -0.06, mouth: false);
    final fx = b.width * _faceShift;
    final m = Offset(b.center.dx + fx, b.center.dy + b.height * 0.13);
    canvas.drawPath(
      _triangle(
        m + Offset(-b.width * 0.03, -b.height * 0.03),
        m + Offset(b.width * 0.03, -b.height * 0.03),
        m,
      ),
      Paint()..color = const Color(0xFFFF7FA0),
    );
    _smile(canvas, m + Offset(0, b.height * 0.01), b.width * 0.06);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: m + Offset(0, b.height * 0.08),
          width: b.width * 0.08,
          height: b.height * 0.08,
        ),
        Radius.circular(b.width * 0.015),
      ),
      Paint()..color = Colors.white,
    );
    _arms(canvas, b, size: 0.75);
    _rim(canvas, b);
    _specular(canvas, b);
  }

  /// Kucing: telinga runcing, kumis, pupil celah, ekor melengkung.
  void _cat(Canvas canvas, Rect b) {
    final tail = Path()
      ..moveTo(b.right - b.width * 0.1, b.bottom - b.height * 0.15)
      ..cubicTo(
        b.right + b.width * 0.4,
        b.bottom,
        b.right + b.width * 0.3,
        b.top + b.height * (0.1 + _sway * 0.08),
        b.right + b.width * 0.15,
        b.top - b.height * 0.05,
      );
    canvas.drawPath(tail, _stroke(b.width * 0.1, palette.base));
    canvas.drawPath(
        tail, _stroke(b.width * 0.05, palette.light.withValues(alpha: 0.35)));
    _feet(canvas, b, spread: 0.2, w: 0.22, h: 0.15);
    _blob(canvas, b);
    _belly(canvas, b, w: 0.5);
    for (final dir in const <double>[-1, 1]) {
      final base = Offset(
        b.center.dx + dir * b.width * 0.28 + turn * b.width * 0.08,
        b.top + b.height * 0.16,
      );
      _celPath(
          canvas,
          _triangle(
            base + Offset(-b.width * 0.12, 0),
            base + Offset(dir * b.width * 0.06, -b.height * 0.42),
            base + Offset(b.width * 0.12, 0),
          ));
      canvas.drawPath(
        _triangle(
          base + Offset(-b.width * 0.06, 0),
          base + Offset(dir * b.width * 0.04, -b.height * 0.28),
          base + Offset(b.width * 0.06, 0),
        ),
        Paint()..color = const Color(0xFFFFB3C7),
      );
    }
    _face(canvas, b,
        eyeY: -0.08, eyeW: 0.16, eyeH: 0.22, slit: true, mouth: false);
    final fx = b.width * _faceShift;
    final n = Offset(b.center.dx + fx, b.center.dy + b.height * 0.1);
    canvas.drawPath(
      _triangle(
        n + Offset(-b.width * 0.03, 0),
        n + Offset(b.width * 0.03, 0),
        n + Offset(0, b.height * 0.04),
      ),
      Paint()..color = const Color(0xFFFF7FA0),
    );
    _smile(canvas, n + Offset(0, b.height * 0.05), b.width * 0.06);
    final whisker = _stroke(b.width * 0.012, _ink.withValues(alpha: 0.6));
    for (final dir in const <double>[-1, 1]) {
      for (final k in const <double>[-1, 0, 1]) {
        canvas.drawLine(
          n + Offset(dir * b.width * 0.12, k * b.height * 0.04),
          n + Offset(dir * b.width * 0.36, k * b.height * 0.07),
          whisker,
        );
      }
    }
    _rim(canvas, b);
    _specular(canvas, b);
  }

  /// Kura-kura: tempurung kubah berpola heksagon, kepala menyembul di depan.
  void _turtle(Canvas canvas, Rect b) {
    // Kaki.
    for (final dir in const <double>[-1, 1]) {
      for (final front in const <double>[-1, 1]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(
              b.center.dx + dir * b.width * (front < 0 ? 0.35 : 0.2),
              b.bottom - b.height * 0.02,
            ),
            width: b.width * 0.18,
            height: b.height * 0.24,
          ),
          Paint()..color = palette.base,
        );
      }
    }
    final shell =
        Rect.fromLTRB(b.left, b.top, b.right, b.bottom + b.height * 0.1);
    final shellColor = _darken(palette.accent, 0.1);
    _celPath(canvas, Path()..addOval(shell),
        base: shellColor, shade: _darken(shellColor, 0.25));
    final pattern = _stroke(b.width * 0.02, _darken(shellColor, 0.2));
    final c = shell.center + Offset(turn * b.width * 0.1, -b.height * 0.05);
    final hex = Path();
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      final pt = c +
          Offset(math.cos(a) * b.width * 0.16, math.sin(a) * b.height * 0.22);
      if (i == 0) {
        hex.moveTo(pt.dx, pt.dy);
      } else {
        hex.lineTo(pt.dx, pt.dy);
      }
      canvas.drawLine(
        pt,
        c + Offset(math.cos(a) * b.width * 0.42, math.sin(a) * b.height * 0.5),
        pattern,
      );
    }
    hex.close();
    canvas.drawPath(hex, pattern);
    if (_tier >= 2) {
      final spike = Paint()..color = palette.light;
      for (var i = 0; i < 5; i++) {
        final a = math.pi + 0.35 + i * (math.pi - 0.7) / 4;
        final base = shell.center +
            Offset(math.cos(a) * shell.width * 0.47,
                math.sin(a) * shell.height * 0.47);
        final out = Offset(math.cos(a), math.sin(a));
        final side = Offset(-out.dy, out.dx);
        final sz = b.width * 0.07;
        canvas.drawPath(
          _triangle(base + side * sz, base + out * sz * 1.8, base - side * sz),
          spike,
        );
      }
    }
    // Tepi tempurung.
    canvas.drawArc(
      shell.deflate(b.width * 0.01),
      0.15,
      math.pi - 0.3,
      false,
      _stroke(b.width * 0.06, palette.light.withValues(alpha: 0.8)),
    );
    _specular(canvas, shell, y: -0.32);
    // Kepala.
    final head = Rect.fromCenter(
      center: Offset(
        b.center.dx + turn * b.width * 0.3,
        b.bottom +
            b.height * 0.02 +
            math.sin(phase * math.pi * 2) * b.height * 0.03,
      ),
      width: b.width * 0.55,
      height: b.height * 0.75,
    );
    _blob(canvas, head);
    _face(canvas, head, eyeY: -0.05, eyeSpread: 0.2, eyeW: 0.16, eyeH: 0.3);
    _specular(canvas, head);
  }

  /// Golem: tubuh balok batu, retakan, batu bahu, lengan besar, mata menyala.
  void _golem(Canvas canvas, Rect b) {
    final rock = palette.accent;
    for (final dir in const <double>[-1, 1]) {
      final arm = Rect.fromCenter(
        center: Offset(
            b.center.dx + dir * b.width * 0.58, b.center.dy + b.height * 0.15),
        width: b.width * 0.3,
        height: b.height * 0.6,
      );
      _celPath(
          canvas,
          Path()
            ..addRRect(
                RRect.fromRectAndRadius(arm, Radius.circular(arm.width * 0.4))),
          base: rock,
          shade: _darken(rock, 0.25));
    }
    _feet(canvas, b, spread: 0.25, w: 0.3, h: 0.2, color: _darken(rock, 0.2));
    final rr = RRect.fromRectAndRadius(b, Radius.circular(b.width * 0.28));
    _celPath(
      canvas,
      Path()..addRRect(rr),
      base: _tier >= 2 ? _darken(palette.base, 0.2) : null,
    );
    if (_tier >= 3) {
      // Rune bercahaya.
      final rune = _stroke(b.width * 0.02,
          palette.accent == rock ? const Color(0xFFFFE066) : palette.accent);
      final rc = b.center + Offset(turn * b.width * 0.1, b.height * 0.22);
      canvas.drawCircle(rc, b.width * 0.1, rune);
      canvas.drawLine(rc + Offset(0, -b.width * 0.16),
          rc + Offset(0, b.width * 0.16), rune);
    }
    if (_tier == 1) {
      // Topi lumut.
      canvas.save();
      canvas.clipRRect(rr);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(b.center.dx, b.top),
            width: b.width * 1.1,
            height: b.height * 0.5),
        Paint()..color = const Color(0xFF6CC644),
      );
      canvas.restore();
    }
    if (_tier >= 2) {
      // Kristal di kepala.
      final crystal = Paint()..color = const Color(0xFF8FE3FF);
      final edge = _stroke(b.width * 0.012, const Color(0xFF3FA9F0));
      for (final (dx, hh) in <(double, double)>[
        (-0.18, 0.28),
        (0.0, 0.4),
        (0.18, 0.24)
      ]) {
        final base = Offset(b.center.dx + b.width * dx + turn * b.width * 0.1,
            b.top + b.height * 0.04);
        final path = _triangle(
          base + Offset(-b.width * 0.06, 0),
          base + Offset(0, -b.height * hh),
          base + Offset(b.width * 0.06, 0),
        );
        canvas.drawPath(path, crystal);
        canvas.drawPath(path, edge);
      }
    }
    // Retakan.
    final crack = _stroke(b.width * 0.018, palette.dark.withValues(alpha: 0.6));
    canvas.drawPath(
      Path()
        ..moveTo(b.left + b.width * 0.2, b.top + b.height * 0.25)
        ..lineTo(b.left + b.width * 0.28, b.top + b.height * 0.38)
        ..lineTo(b.left + b.width * 0.22, b.top + b.height * 0.5),
      crack,
    );
    canvas.drawPath(
      Path()
        ..moveTo(b.right - b.width * 0.18, b.bottom - b.height * 0.3)
        ..lineTo(b.right - b.width * 0.28, b.bottom - b.height * 0.2)
        ..lineTo(b.right - b.width * 0.22, b.bottom - b.height * 0.1),
      crack,
    );
    // Batu bahu.
    for (final dir in const <double>[-1, 1]) {
      final c =
          Offset(b.center.dx + dir * b.width * 0.42, b.top + b.height * 0.15);
      final r = Rect.fromCircle(center: c, radius: b.width * 0.16);
      _celPath(canvas, Path()..addOval(r),
          base: rock, shade: _darken(rock, 0.3));
    }
    final fx = b.width * _faceShift;
    final eyeC = Offset(b.center.dx + fx, b.center.dy - b.height * 0.1);
    _eyes(canvas, eyeC, b.width * 0.17, b.width * 0.12, b.height * 0.13,
        glow:
            palette.accent == rock ? const Color(0xFFFFE066) : palette.accent);
    canvas.drawLine(
      eyeC + Offset(-b.width * 0.1, b.height * 0.22),
      eyeC + Offset(b.width * 0.1, b.height * 0.22),
      _stroke(b.width * 0.025, _ink),
    );
    _specular(canvas, b);
  }

  /// Ular: lilitan bertumpuk, kepala di atas, lidah bercabang.
  void _serpent(Canvas canvas, Rect head, double u, double groundY) {
    final cx = head.center.dx;
    // Lilitan dari bawah ke atas.
    for (var i = 0; i < 3; i++) {
      final w = u * (0.66 - i * 0.14);
      final h = u * (0.16 - i * 0.015);
      final r = Rect.fromCenter(
        center: Offset(
          cx + math.sin(phase * math.pi * 2 + i) * u * 0.02,
          groundY - u * 0.07 - i * u * 0.11,
        ),
        width: w,
        height: h,
      );
      _celPath(canvas, Path()..addOval(r));
      canvas.drawArc(
        r.deflate(h * 0.15),
        0.3,
        math.pi - 0.6,
        false,
        _stroke(h * 0.18, palette.light.withValues(alpha: 0.7)),
      );
    }
    // Leher.
    canvas.drawLine(
      Offset(cx, groundY - u * 0.3),
      head.center,
      _stroke(u * 0.12, palette.base),
    );
    _blob(canvas, head);
    _face(canvas, head,
        eyeY: -0.1,
        eyeSpread: 0.22,
        eyeW: 0.17,
        eyeH: 0.3,
        slit: true,
        mouth: false);
    final fx = head.width * _faceShift;
    final m = Offset(head.center.dx + fx, head.center.dy + head.height * 0.25);
    final flick = (math.sin(phase * math.pi * 8) * 0.5 + 0.5);
    if (flick > 0.4) {
      final tongue = _stroke(head.width * 0.03, const Color(0xFFFF4D6D));
      final end = m + Offset(0, head.height * 0.3 * flick);
      canvas.drawLine(m, end, tongue);
      canvas.drawLine(
          end, end + Offset(-head.width * 0.06, head.height * 0.08), tongue);
      canvas.drawLine(
          end, end + Offset(head.width * 0.06, head.height * 0.08), tongue);
    }
    _specular(canvas, head);
  }

  /// Peri tetes: tubuh tetesan melayang, sayap kupu tembus pandang, kilau.
  void _sprite(Canvas canvas, Rect b) {
    final flap = (math.sin(phase * math.pi * 2 * 3) * 0.5 + 0.5);
    for (final dir in const <double>[-1, 1]) {
      for (final upper in const <bool>[true, false]) {
        canvas.save();
        canvas.translate(
            b.center.dx + dir * b.width * 0.3, b.center.dy - b.height * 0.05);
        canvas.rotate(dir * (upper ? -0.5 : 0.4));
        canvas.scale(0.6 + 0.4 * flap, 1);
        final wing = Rect.fromLTWH(
          dir > 0 ? 0 : -b.width * 0.6,
          -b.height * (upper ? 0.35 : 0.1),
          b.width * 0.6,
          b.height * (upper ? 0.45 : 0.35),
        );
        canvas.drawOval(
            wing, Paint()..color = palette.accent.withValues(alpha: 0.45));
        canvas.drawOval(wing,
            _stroke(b.width * 0.015, Colors.white.withValues(alpha: 0.7)));
        canvas.restore();
      }
    }
    final drop = Path()
      ..moveTo(b.center.dx + turn * b.width * 0.2, b.top - b.height * 0.25)
      ..cubicTo(b.right + b.width * 0.05, b.top + b.height * 0.4, b.right,
          b.bottom, b.center.dx, b.bottom)
      ..cubicTo(
          b.left,
          b.bottom,
          b.left - b.width * 0.05,
          b.top + b.height * 0.4,
          b.center.dx + turn * b.width * 0.2,
          b.top - b.height * 0.25)
      ..close();
    _celPath(canvas, drop);
    _face(canvas, b, eyeY: 0.02, eyeSpread: 0.18, eyeW: 0.15, eyeH: 0.28);
    if (_tier >= 1) {
      const petals = <Color>[
        Color(0xFFFF8DB0),
        Color(0xFFFFD84D),
        Color(0xFFFF8DB0)
      ];
      for (var i = 0; i < 3; i++) {
        final c = Offset(
          b.center.dx + (i - 1) * b.width * 0.2 + turn * b.width * 0.15,
          b.top + b.height * (i == 1 ? 0.05 : 0.15),
        );
        for (var k = 0; k < 5; k++) {
          final a = k * math.pi * 2 / 5;
          canvas.drawCircle(
            c + Offset(math.cos(a), math.sin(a)) * b.width * 0.045,
            b.width * 0.04,
            Paint()..color = petals[i],
          );
        }
        canvas.drawCircle(c, b.width * 0.035, Paint()..color = Colors.white);
      }
    }
    _arms(canvas, b, size: 0.6);
    final sparkle = Paint()..color = Colors.white;
    for (var i = 0; i < 3; i++) {
      final a = phase * math.pi * 2 + i * 2.1;
      _star(
        canvas,
        b.center +
            Offset(math.cos(a) * b.width * 0.75, math.sin(a) * b.height * 0.7),
        b.width * 0.025 * (1 + math.sin(a * 2) * 0.4),
        sparkle,
      );
    }
    _specular(canvas, b);
  }

  /// Serangga: tubuh bergaris, antena berbola, enam kaki kecil.
  void _bug(Canvas canvas, Rect b) {
    final legs = _stroke(b.width * 0.03, palette.dark);
    for (final dir in const <double>[-1, 1]) {
      for (var i = 0; i < 3; i++) {
        final start = Offset(b.center.dx + dir * b.width * 0.35,
            b.center.dy + b.height * (0.05 + i * 0.18));
        final wiggle =
            math.sin(phase * math.pi * 6 + i + dir) * b.height * 0.04;
        canvas.drawPath(
          Path()
            ..moveTo(start.dx, start.dy)
            ..lineTo(start.dx + dir * b.width * 0.18,
                start.dy - b.height * 0.06 + wiggle)
            ..lineTo(start.dx + dir * b.width * 0.24,
                start.dy + b.height * 0.12 + wiggle),
          legs,
        );
      }
    }
    for (final dir in const <double>[-1, 1]) {
      final base = Offset(
          b.center.dx + dir * b.width * 0.12 + turn * b.width * 0.1,
          b.top + b.height * 0.1);
      final tip = base +
          Offset(dir * b.width * 0.22, -b.height * (0.45 + _sway * 0.05));
      canvas.drawPath(
        Path()
          ..moveTo(base.dx, base.dy)
          ..quadraticBezierTo(base.dx, tip.dy, tip.dx, tip.dy),
        _stroke(b.width * 0.025, palette.dark),
      );
      canvas.drawCircle(tip, b.width * 0.06, Paint()..color = palette.accent);
    }
    _blob(canvas, b);
    final stripe =
        _stroke(b.width * 0.05, palette.dark.withValues(alpha: 0.45));
    for (var i = 0; i < 3; i++) {
      final r = b
          .deflate(b.width * 0.02)
          .shift(Offset(0, b.height * (0.15 + i * 0.18)));
      canvas.save();
      canvas.clipPath(Path()..addOval(b));
      canvas.drawArc(r, 0.25, math.pi - 0.5, false, stripe);
      canvas.restore();
    }
    _face(canvas, b, eyeY: -0.14, eyeSpread: 0.2, eyeW: 0.17, eyeH: 0.3);
    _rim(canvas, b);
    _specular(canvas, b);
  }

  // ------------------------------------------------------- element accent

  void _paintElementAccent(
      Canvas canvas, Rect b, double u, CreatureSpecies kind) {
    final headFree = !const <CreatureSpecies>{
      CreatureSpecies.bird,
      CreatureSpecies.sprite,
      CreatureSpecies.dragon,
      CreatureSpecies.bunny,
      CreatureSpecies.bug,
      CreatureSpecies.serpent,
      CreatureSpecies.cat,
      CreatureSpecies.turtle,
    }.contains(kind);
    final top =
        Offset(b.center.dx + turn * b.width * 0.15, b.top + b.height * 0.06);
    switch (card.element) {
      case CardElement.fire:
        if (headFree) {
          final flicker = 1 + 0.1 * math.sin(phase * math.pi * 2 * 4 + 1);
          _flame(canvas, top, b.width * 0.3 * flicker, -0.1);
        } else {
          _embers(canvas, b);
        }
      case CardElement.water:
        _bubbles(canvas, b);
      case CardElement.earth:
        if (headFree) {
          _sprout(canvas, top, b);
        } else {
          _leaves(canvas, b);
        }
      case CardElement.air:
        _breeze(canvas, b);
      case CardElement.voidElement:
        _orbs(canvas, b, u);
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
    canvas.drawPath(path, Paint()..color = const Color(0xFFFF8A2E));
    canvas.drawPath(
      path.transform(Matrix4.diagonal3Values(0.55, 0.6, 1).storage),
      Paint()..color = const Color(0xFFFFE27A),
    );
    canvas.restore();
  }

  void _embers(Canvas canvas, Rect b) {
    for (var i = 0; i < 3; i++) {
      final t = (phase + i / 3) % 1;
      final pos = Offset(
        b.right + b.width * 0.05 - i * b.width * 0.15,
        b.bottom - t * b.height * 1.5,
      );
      canvas.drawCircle(
        pos,
        b.width * 0.03 * (1 - t),
        Paint()..color = const Color(0xFFFFA23E).withValues(alpha: 1 - t),
      );
    }
  }

  void _bubbles(Canvas canvas, Rect b) {
    for (var i = 0; i < 3; i++) {
      final t = (phase + i / 3) % 1;
      final pos = Offset(
        b.left - b.width * 0.1 + math.sin(t * math.pi * 4 + i) * b.width * 0.05,
        b.bottom - t * b.height * 1.6,
      );
      canvas.drawCircle(
        pos,
        b.width * (0.04 + 0.02 * i),
        _stroke(
            b.width * 0.02, palette.light.withValues(alpha: 0.85 * (1 - t))),
      );
    }
  }

  void _sprout(Canvas canvas, Offset top, Rect b) {
    canvas.save();
    canvas.translate(top.dx, top.dy);
    canvas.rotate(_wave * 0.15);
    final h = b.height * 0.3;
    canvas.drawLine(Offset.zero, Offset(0, -h),
        _stroke(b.width * 0.03, const Color(0xFF3F7D20)));
    for (final dir in const <double>[-1, 1]) {
      canvas.save();
      canvas.translate(0, -h);
      canvas.rotate(dir * 0.9);
      canvas.drawOval(
        Rect.fromLTWH(-h * 0.2, -h * 0.75, h * 0.4, h * 0.75),
        Paint()..color = const Color(0xFF6CC644),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  void _leaves(Canvas canvas, Rect b) {
    for (var i = 0; i < 2; i++) {
      final t = (phase + i / 2) % 1;
      final pos = Offset(
          b.left + b.width * (0.1 + i * 0.9), b.top + t * b.height * 1.2);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(t * math.pi * 2);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset.zero, width: b.width * 0.1, height: b.width * 0.05),
        Paint()..color = const Color(0xFF6CC644).withValues(alpha: 1 - t * 0.6),
      );
      canvas.restore();
    }
  }

  void _breeze(Canvas canvas, Rect b) {
    final paint =
        _stroke(b.width * 0.025, palette.accent.withValues(alpha: 0.7));
    for (var i = 0; i < 2; i++) {
      final t = (phase * 2 + i * 0.5) % 1;
      final y = b.top + b.height * (0.3 + i * 0.5);
      final x = b.left - b.width * 0.35 + t * b.width * 0.25;
      canvas.drawPath(
        Path()
          ..moveTo(x, y)
          ..quadraticBezierTo(
              x + b.width * 0.15, y - b.height * 0.08, x + b.width * 0.25, y)
          ..quadraticBezierTo(x + b.width * 0.32, y + b.height * 0.05,
              x + b.width * 0.25, y + b.height * 0.08),
        paint..color = palette.accent.withValues(alpha: 0.7 * (1 - t)),
      );
    }
  }

  void _orbs(Canvas canvas, Rect b, double u) {
    for (var i = 0; i < 2; i++) {
      final angle = phase * math.pi * 2 + i * math.pi;
      final depth = math.sin(angle);
      final pos = b.center +
          Offset(math.cos(angle) * b.width * 0.75,
              -b.height * 0.2 + depth * b.height * 0.15);
      final r = u * 0.03 * (1 + depth * 0.3);
      canvas.drawCircle(
        pos,
        r * 2,
        Paint()..color = palette.accent.withValues(alpha: 0.3),
      );
      canvas.drawCircle(pos, r, Paint()..color = palette.light);
    }
  }

  void _paintAura(Canvas canvas, Rect body, double u) {
    final color = AppTheme.rarityColor(card.rarity);
    final pulse = 0.92 + 0.08 * math.sin(phase * math.pi * 4);
    canvas.drawCircle(
      body.center,
      body.width * 0.86 * pulse,
      Paint()..color = color.withValues(alpha: 0.16),
    );
    canvas.drawCircle(
      body.center,
      body.width * 0.86 * pulse,
      _stroke(u * 0.008, color.withValues(alpha: 0.45)),
    );
    if (card.rarity.index >= Rarity.legendary.index) {
      final sparkle = Paint()..color = Colors.white.withValues(alpha: 0.9);
      for (var i = 0; i < 4; i++) {
        final angle = phase * math.pi * 2 + i * math.pi / 2;
        final pos = body.center +
            Offset(math.cos(angle), math.sin(angle) * 0.5) * body.width * 0.82;
        _star(canvas, pos, u * 0.025, sparkle);
      }
    }
  }

  void _paintShadow(Canvas canvas, Offset ground, double rx, double air) {
    // Bayangan datar ala ilustrasi; mengecil saat kreatur melompat.
    final w = rx * 1.6 * (1 - 0.25 * air);
    canvas.drawOval(
      Rect.fromCenter(
        center: ground.translate(0, -rx * 0.18),
        width: w,
        height: w * 0.22,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.13 - 0.04 * air),
    );
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
      u * 0.34,
      Paint()..color = color.withValues(alpha: 0.22),
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
      oldDelegate.card.id != card.id ||
      oldDelegate.card.rarity != card.rarity ||
      oldDelegate.clock != clock ||
      (clock == null && oldDelegate._staticPhase != _staticPhase);
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
        painter: _StagePainter(
          AppTheme.elementColor(card.element),
          aura:
              card.rarity.isRarePlus ? AppTheme.rarityColor(card.rarity) : null,
        ),
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
  const _StagePainter(this.color, {this.aura});

  final Color color;

  /// Lingkar aura rarity (Rare+).
  final Color? aura;

  @override
  void paint(Canvas canvas, Size size) {
    // Lingkaran latar besar (warna solid tipis), lalu lantai bundar.
    final center = Offset(size.width / 2, size.height * 0.45);
    if (aura != null) {
      canvas.drawCircle(
        center,
        size.shortestSide * 0.47,
        Paint()..color = aura!.withValues(alpha: 0.22),
      );
    }
    canvas.drawCircle(
      center,
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
      oldDelegate.color != color || oldDelegate.aura != aura;
}
