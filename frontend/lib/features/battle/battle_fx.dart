import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/clay.dart';
import '../../domain/models/card_model.dart';
import 'domain/battle_models.dart';

// ---------------------------------------------------------------------------
// Cue: terjemahan murni BattleEvent → efek visual. UI tidak menghitung damage
// sendiri (I-05); angka selalu berasal dari `event.data`.
// ---------------------------------------------------------------------------

enum FxCueKind { strike, bolt, hit, heal, faint, summon }

class FxCue {
  const FxCue({
    required this.kind,
    required this.side,
    this.sourceUnitId,
    this.sourceFace,
    this.sourceCardId,
    this.targetUnitId,
    this.targetFace,
    this.amount = 0,
  });

  final FxCueKind kind;

  /// Sisi yang memicu event.
  final BattleSide? side;
  final String? sourceUnitId;
  final BattleSide? sourceFace;
  final String? sourceCardId;
  final String? targetUnitId;
  final BattleSide? targetFace;
  final int amount;
}

String? _str(Map<String, dynamic> data, String key) {
  final value = data[key];
  return value is String && value.isNotEmpty ? value : null;
}

int _int(Map<String, dynamic> data, String key) {
  final value = data[key];
  return value is int ? value : (value is num ? value.toInt() : 0);
}

/// Memetakan potongan log baru menjadi daftar cue berurutan.
List<FxCue> fxCuesFor(List<BattleEvent> events) {
  // Ability/spell di-log setelah damage-nya, jadi sumber dicari lebih dulu.
  String? abilityUnit;
  String? spellCard;
  BattleSide? spellSide;
  for (final event in events) {
    if (event.type == 'ability') abilityUnit = _str(event.data, 'unitId');
    if (event.type == 'spell') {
      spellCard = _str(event.data, 'cardId');
      spellSide = event.side;
    }
  }

  final cues = <FxCue>[];
  String? lastAttacker;
  for (final event in events) {
    final side = event.side;
    final data = event.data;
    switch (event.type) {
      case 'attack':
        lastAttacker = _str(data, 'attackerId');
        cues.add(
          FxCue(
            kind: FxCueKind.strike,
            side: side,
            sourceUnitId: lastAttacker,
            targetUnitId: _str(data, 'targetId'),
            amount: _int(data, 'damage'),
          ),
        );
      case 'face_attack':
        cues.add(
          FxCue(
            kind: FxCueKind.strike,
            side: side,
            sourceUnitId: _str(data, 'unitId'),
            targetFace: side?.opponent,
            amount: _int(data, 'damage'),
          ),
        );
      case 'counter':
        cues.add(
          FxCue(
            kind: FxCueKind.strike,
            side: side,
            sourceUnitId: _str(data, 'unitId'),
            targetUnitId: lastAttacker,
            amount: _int(data, 'damage'),
          ),
        );
      case 'pierce':
        cues.add(
          FxCue(
            kind: FxCueKind.hit,
            side: side,
            targetFace: side?.opponent,
            amount: _int(data, 'damage'),
          ),
        );
      case 'ability_damage':
        final targetId = _str(data, 'targetId');
        cues.add(
          FxCue(
            kind: FxCueKind.bolt,
            side: side,
            sourceUnitId: abilityUnit,
            sourceFace: abilityUnit == null ? (spellSide ?? side) : null,
            sourceCardId: spellCard,
            targetUnitId: targetId,
            targetFace: targetId == null ? side?.opponent : null,
            amount: _int(data, 'damage'),
          ),
        );
      case 'heal':
        cues.add(
          FxCue(
            kind: FxCueKind.heal,
            side: side,
            targetUnitId: _str(data, 'targetId'),
            amount: _int(data, 'amount'),
          ),
        );
      case 'burn':
        cues.add(
          FxCue(
            kind: FxCueKind.hit,
            side: side,
            targetUnitId: _str(data, 'unitId'),
            amount: _int(data, 'damage'),
          ),
        );
      case 'unit_died':
        cues.add(
          FxCue(
            kind: FxCueKind.faint,
            side: side,
            targetUnitId: _str(data, 'unitId'),
          ),
        );
      case 'summon':
        cues.add(
          FxCue(
            kind: FxCueKind.summon,
            side: side,
            targetUnitId: _str(data, 'instanceId'),
            sourceCardId: _str(data, 'cardId'),
          ),
        );
    }
  }
  return cues;
}

String faceAnchorId(BattleSide side) => 'face:${side.name}';

// ---------------------------------------------------------------------------
// Host: menangkap posisi anchor, menjalankan partikel, lunge, shake.
// ---------------------------------------------------------------------------

class BattleFxHost extends StatefulWidget {
  const BattleFxHost({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  static BattleFxHostState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_FxScope>()?.state;

  /// Versi tanpa dependensi, aman dipanggil dari callback di luar build.
  static BattleFxHostState? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_FxScope>()?.state;

  @override
  State<BattleFxHost> createState() => BattleFxHostState();
}

class _FxScope extends InheritedWidget {
  const _FxScope({required this.state, required super.child});

  final BattleFxHostState state;

  @override
  bool updateShouldNotify(covariant _FxScope oldWidget) =>
      oldWidget.state != state;
}

/// Pose sesaat sebuah anchor (unit atau header pemain).
class FxPose {
  const FxPose({this.offset = Offset.zero, this.flash = 0, this.flashColor});

  static const FxPose rest = FxPose();

  final Offset offset;
  final double flash;
  final Color? flashColor;
}

class _PoseAnim {
  _PoseAnim({
    required this.start,
    required this.duration,
    this.lunge = Offset.zero,
    this.shake = 0,
    this.flashColor,
  });

  final double start;
  final double duration;
  final Offset lunge;
  final double shake;
  final Color? flashColor;
}

abstract class _Fx {
  _Fx(this.start, this.duration);

  final double start;
  final double duration;

  bool done(double now) => now > start + duration;

  void paint(Canvas canvas, double t);
}

class BattleFxHostState extends State<BattleFxHost>
    with SingleTickerProviderStateMixin {
  final Map<String, GlobalKey> _anchors = <String, GlobalKey>{};
  final Map<String, ValueNotifier<FxPose>> _poses =
      <String, ValueNotifier<FxPose>>{};
  final Map<String, List<_PoseAnim>> _poseAnims = <String, List<_PoseAnim>>{};
  final List<_Fx> _fx = <_Fx>[];
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  // Jam efek (ms) digerakkan Ticker: beku saat idle, lanjut saat aktif.
  double _now = 0;
  double _tickerBase = 0;
  final math.Random _random = math.Random(7);
  final GlobalKey _layerKey = GlobalKey();
  late final Ticker _ticker = createTicker(_onTick);

  double _shakeStart = -1;
  double _shakeMagnitude = 0;

  void registerAnchor(String id, GlobalKey key) => _anchors[id] = key;

  void unregisterAnchor(String id, GlobalKey key) {
    if (_anchors[id] == key) _anchors.remove(id);
  }

  ValueNotifier<FxPose> poseOf(String id) =>
      _poses.putIfAbsent(id, () => ValueNotifier<FxPose>(FxPose.rest));

  Rect? _rectOf(String id) {
    final box = _anchors[id]?.currentContext?.findRenderObject();
    final layer = _layerKey.currentContext?.findRenderObject();
    if (box is! RenderBox || layer is! RenderBox) return null;
    if (!box.attached || !box.hasSize || !layer.attached) return null;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: layer);
    return topLeft & box.size;
  }

  /// Dipanggil saat log bertambah. `units` dipakai untuk mencari elemen
  /// penyerang (termasuk unit yang sudah gugur di state baru).
  /// `labelFor` memberi nama jurus untuk callout ala Pokémon (opsional).
  void play(
    List<BattleEvent> events, {
    required Map<String, CardModel> cardsByUnit,
    required Map<String, CardModel> cardsById,
    String? Function(FxCue cue)? labelFor,
  }) {
    if (!widget.enabled || !mounted) return;
    final cues = fxCuesFor(events);
    if (cues.isEmpty) return;

    var cursor = _now;
    final pendingSummons = <FxCue>[];
    String? lastLabel;
    for (final cue in cues) {
      final label = labelFor?.call(cue);
      // AoE memicu beberapa bolt bernama sama; cukup satu callout.
      if (label != null && label != lastLabel) {
        final anchor = cue.sourceUnitId != null
            ? _rectOf(cue.sourceUnitId!)
            : (cue.sourceFace == null
                ? null
                : _rectOf(faceAnchorId(cue.sourceFace!)));
        if (anchor != null) {
          final card = cue.sourceUnitId == null
              ? cardsById[cue.sourceCardId]
              : cardsByUnit[cue.sourceUnitId];
          _fx.add(
            _CalloutFx(
              Offset(anchor.center.dx, anchor.top),
              label,
              card == null
                  ? AppTheme.primary
                  : AppTheme.elementColor(card.element),
              cursor,
            ),
          );
          cursor += 160;
        }
      }
      lastLabel = label;
      switch (cue.kind) {
        case FxCueKind.strike:
          cursor = _playStrike(cue, cursor, cardsByUnit) + 80;
        case FxCueKind.bolt:
          cursor = _playBolt(cue, cursor, cardsByUnit, cardsById);
        case FxCueKind.hit:
          final rect = _targetRect(cue);
          if (rect != null) {
            _impact(rect, const Color(0xFFF97316), cursor, cue.amount,
                small: true);
            _poseHit(_targetId(cue), cursor);
          }
          cursor += 120;
        case FxCueKind.heal:
          final rect = _targetRect(cue);
          if (rect != null) {
            _fx.add(_HealFx(rect, cursor, _random.nextInt(1 << 20)));
            _fx.add(_FloatTextFx(rect.center, '+${cue.amount}',
                const Color(0xFF4ADE80), cursor));
          }
          cursor += 120;
        case FxCueKind.faint:
          final rect = _targetRect(cue);
          final card =
              cue.targetUnitId == null ? null : cardsByUnit[cue.targetUnitId];
          if (rect != null) {
            _fx.add(
              _FaintFx(
                rect,
                card == null
                    ? Colors.white
                    : AppTheme.elementColor(card.element),
                cursor,
                _random.nextInt(1 << 20),
              ),
            );
          }
        case FxCueKind.summon:
          pendingSummons.add(cue);
      }
    }

    if (pendingSummons.isNotEmpty) {
      // Unit baru belum punya posisi; tunggu frame berikut.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final cue in pendingSummons) {
          final rect = _targetRect(cue);
          final card =
              cue.sourceCardId == null ? null : cardsById[cue.sourceCardId];
          if (rect == null) continue;
          _fx.add(
            _SummonFx(
              rect,
              card == null
                  ? AppTheme.accent
                  : AppTheme.elementColor(card.element),
              _now,
              _random.nextInt(1 << 20),
            ),
          );
        }
        _ensureTicking();
      });
    }
    _ensureTicking();
  }

  String? _targetId(FxCue cue) =>
      cue.targetUnitId ??
      (cue.targetFace == null ? null : faceAnchorId(cue.targetFace!));

  Rect? _targetRect(FxCue cue) {
    final id = _targetId(cue);
    return id == null ? null : _rectOf(id);
  }

  double _playStrike(FxCue cue, double start, Map<String, CardModel> cards) {
    final from = cue.sourceUnitId == null ? null : _rectOf(cue.sourceUnitId!);
    final to = _targetRect(cue);
    if (to == null) return start;
    final card = cue.sourceUnitId == null ? null : cards[cue.sourceUnitId];
    final color = card == null
        ? const Color(0xFFF97316)
        : AppTheme.elementColor(card.element);
    const windup = 170.0;

    if (from != null) {
      final delta = to.center - from.center;
      final dist = delta.distance;
      final lunge =
          dist == 0 ? Offset.zero : delta / dist * math.min(dist * 0.45, 46);
      _addPose(cue.sourceUnitId!,
          _PoseAnim(start: start, duration: 380, lunge: lunge));
    }
    final impactAt = start + windup;
    _fx.add(_SlashFx(to, color, impactAt));
    _impact(to, color, impactAt, cue.amount);
    _poseHit(_targetId(cue), impactAt);
    _shake(impactAt, cue.targetFace != null ? 7 : 4);
    return impactAt + 160;
  }

  double _playBolt(
    FxCue cue,
    double start,
    Map<String, CardModel> cardsByUnit,
    Map<String, CardModel> cardsById,
  ) {
    final to = _targetRect(cue);
    if (to == null) return start + 60;
    Rect? from;
    if (cue.sourceUnitId != null) from = _rectOf(cue.sourceUnitId!);
    if (from == null && cue.sourceFace != null) {
      from = _rectOf(faceAnchorId(cue.sourceFace!));
    }
    final card = cue.sourceUnitId != null
        ? cardsByUnit[cue.sourceUnitId]
        : (cue.sourceCardId == null ? null : cardsById[cue.sourceCardId]);
    final element = card?.element;
    final color =
        element == null ? AppTheme.accent : AppTheme.elementColor(element);

    const travel = 300.0;
    if (from != null) {
      _fx.add(_BoltFx(from.center, to.center, color, start, travel,
          _random.nextInt(1 << 20)));
      if (cue.sourceUnitId != null) {
        _addPose(
          cue.sourceUnitId!,
          _PoseAnim(start: start, duration: 260, shake: 2, flashColor: color),
        );
      }
    }
    final impactAt = start + (from == null ? 0 : travel);
    _impact(to, color, impactAt, cue.amount);
    _poseHit(_targetId(cue), impactAt);
    _shake(impactAt, 5);
    // Area-effect: bolt berikutnya menyusul cepat.
    return start + 70;
  }

  void _impact(Rect rect, Color color, double at, int amount,
      {bool small = false}) {
    _fx.add(_ImpactFx(rect.center, rect.shortestSide * (small ? 0.4 : 0.62),
        color, at, _random.nextInt(1 << 20)));
    if (amount > 0) {
      _fx.add(
          _FloatTextFx(rect.center, '-$amount', const Color(0xFFFF5D73), at));
    }
  }

  void _poseHit(String? id, double at) {
    if (id == null) return;
    _addPose(
      id,
      _PoseAnim(
          start: at,
          duration: 320,
          shake: 5,
          flashColor: const Color(0xFFFF4D5E)),
    );
  }

  void _shake(double at, double magnitude) {
    _shakeStart = at;
    _shakeMagnitude = magnitude;
  }

  void _addPose(String id, _PoseAnim anim) {
    poseOf(id);
    (_poseAnims[id] ??= <_PoseAnim>[]).add(anim);
  }

  void _ensureTicking() {
    if (_ticker.isActive) return;
    _tickerBase = _now;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    _now = _tickerBase + elapsed.inMicroseconds / 1000.0;
    final now = _now;
    _fx.removeWhere((fx) => fx.done(now));

    final finished = <String>[];
    _poseAnims.forEach((id, anims) {
      anims.removeWhere((a) => now > a.start + a.duration);
      var offset = Offset.zero;
      var flash = 0.0;
      Color? flashColor;
      for (final a in anims) {
        if (now < a.start) continue;
        final t = ((now - a.start) / a.duration).clamp(0.0, 1.0);
        if (a.lunge != Offset.zero) {
          // Ancang-ancang mundur sedikit, lalu terjang dan kembali.
          final k = t < 0.3
              ? -0.15 * math.sin(t / 0.3 * math.pi)
              : math.sin((t - 0.3) / 0.7 * math.pi);
          offset += a.lunge * k;
        }
        if (a.shake > 0) {
          final decay = 1 - t;
          offset += Offset(math.sin(t * 40) * a.shake * decay, 0);
        }
        if (a.flashColor != null) {
          final f = (1 - t) * (1 - t);
          if (f > flash) {
            flash = f;
            flashColor = a.flashColor;
          }
        }
      }
      poseOf(id).value =
          FxPose(offset: offset, flash: flash, flashColor: flashColor);
      if (anims.isEmpty) finished.add(id);
    });
    for (final id in finished) {
      _poseAnims.remove(id);
      _poses[id]?.value = FxPose.rest;
    }

    _frame.value++;
    final shaking = _shakeStart >= 0 && now < _shakeStart + 260;
    if (_fx.isEmpty && _poseAnims.isEmpty && !shaking) {
      _ticker.stop();
      _frame.value++;
    }
  }

  Offset _shakeOffset() {
    final now = _now;
    if (_shakeStart < 0 || now < _shakeStart || now > _shakeStart + 260) {
      return Offset.zero;
    }
    final t = (now - _shakeStart) / 260;
    final m = _shakeMagnitude * (1 - t);
    return Offset(math.sin(t * 55) * m, math.cos(t * 47) * m * 0.6);
  }

  @override
  void didUpdateWidget(covariant BattleFxHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _fx.clear();
      _poseAnims.clear();
      for (final pose in _poses.values) {
        pose.value = FxPose.rest;
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    for (final pose in _poses.values) {
      pose.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FxScope(
      state: this,
      child: Stack(
        key: _layerKey,
        fit: StackFit.expand,
        children: <Widget>[
          ValueListenableBuilder<int>(
            valueListenable: _frame,
            builder: (context, _, child) =>
                Transform.translate(offset: _shakeOffset(), child: child),
            child: widget.child,
          ),
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _FxPainter(this),
                size: Size.infinite,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FxPainter extends CustomPainter {
  _FxPainter(this.host) : super(repaint: host._frame);

  final BattleFxHostState host;

  @override
  void paint(Canvas canvas, Size size) {
    final now = host._now;
    for (final fx in host._fx) {
      if (now < fx.start) continue;
      final t = ((now - fx.start) / fx.duration).clamp(0.0, 1.0);
      fx.paint(canvas, t);
    }
  }

  @override
  bool shouldRepaint(covariant _FxPainter oldDelegate) => true;
}

/// Membungkus unit/header: mendaftarkan posisi dan menerapkan pose efek.
class FxAnchor extends StatefulWidget {
  const FxAnchor({
    super.key,
    required this.id,
    required this.child,
    this.borderRadius = 12,
  });

  final String id;
  final Widget child;
  final double borderRadius;

  @override
  State<FxAnchor> createState() => _FxAnchorState();
}

class _FxAnchorState extends State<FxAnchor> {
  final GlobalKey _key = GlobalKey();
  BattleFxHostState? _host;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final host = BattleFxHost.maybeOf(context);
    if (host != _host) {
      _host?.unregisterAnchor(widget.id, _key);
      _host = host;
    }
    _host?.registerAnchor(widget.id, _key);
  }

  @override
  void didUpdateWidget(covariant FxAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _host?.unregisterAnchor(oldWidget.id, _key);
      _host?.registerAnchor(widget.id, _key);
    }
  }

  @override
  void dispose() {
    _host?.unregisterAnchor(widget.id, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final host = _host;
    final keyed = KeyedSubtree(key: _key, child: widget.child);
    if (host == null) return keyed;
    return ValueListenableBuilder<FxPose>(
      valueListenable: host.poseOf(widget.id),
      child: widget.child,
      builder: (context, pose, child) {
        return KeyedSubtree(
          key: _key,
          child: Transform.translate(
            offset: pose.offset,
            child: Stack(
              fit: StackFit.passthrough,
              children: <Widget>[
                child!,
                if (pose.flash > 0.01 && pose.flashColor != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(widget.borderRadius),
                          color: pose.flashColor!
                              .withValues(alpha: 0.45 * pose.flash),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: pose.flashColor!
                                  .withValues(alpha: 0.6 * pose.flash),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Efek partikel.
// ---------------------------------------------------------------------------

double _easeOut(double t) => 1 - math.pow(1 - t, 3).toDouble();

class _ImpactFx extends _Fx {
  _ImpactFx(this.center, this.radius, this.color, double start, int seed)
      : _angles = List<double>.generate(10, (i) {
          final r = math.Random(seed + i);
          return i * math.pi / 5 + r.nextDouble() * 0.4;
        }),
        super(start, 480);

  final Offset center;
  final double radius;
  final Color color;
  final List<double> _angles;

  @override
  void paint(Canvas canvas, double t) {
    final e = _easeOut(t);
    final fade = 1 - t;
    // Kilat inti.
    if (t < 0.35) {
      final f = 1 - t / 0.35;
      final r = radius * (0.4 + 0.5 * (1 - f));
      canvas.drawCircle(
          center, r, Paint()..color = color.withValues(alpha: 0.6 * f));
      canvas.drawCircle(
        center,
        r * 0.55,
        Paint()..color = Colors.white.withValues(alpha: 0.95 * f),
      );
    }
    // Gelombang kejut.
    canvas.drawCircle(
      center,
      radius * (0.3 + e * 0.9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * fade + 0.5
        ..color = color.withValues(alpha: 0.85 * fade),
    );
    // Percikan radial.
    final spark = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.6 * fade + 0.4
      ..color = Color.lerp(Colors.white, color, t)!.withValues(alpha: fade);
    for (final a in _angles) {
      final dir = Offset(math.cos(a), math.sin(a));
      final p0 = center + dir * radius * (0.25 + e * 0.7);
      final p1 = center + dir * radius * (0.45 + e * 1.05);
      canvas.drawLine(p0, p1, spark);
    }
  }
}

class _SlashFx extends _Fx {
  _SlashFx(this.rect, this.color, double start) : super(start, 300);

  final Rect rect;
  final Color color;

  @override
  void paint(Canvas canvas, double t) {
    final fade = 1 - t;
    final s = rect.shortestSide * 0.55;
    for (var i = 0; i < 3; i++) {
      final local = ((t * 1.6) - i * 0.18).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final offset = Offset((i - 1) * s * 0.28, (i - 1) * s * 0.1);
      final a = rect.center + offset + Offset(-s, -s * 0.8);
      final b = rect.center + offset + Offset(s, s * 0.8);
      final end = Offset.lerp(a, b, _easeOut(local))!;
      canvas.drawLine(
        a,
        end,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 7 * fade + 1
          ..color = color.withValues(alpha: 0.5 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawLine(
        a,
        end,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.5 * fade + 0.5
          ..color = Colors.white.withValues(alpha: fade),
      );
    }
  }
}

class _BoltFx extends _Fx {
  _BoltFx(this.from, this.to, this.color, double start, double travel, int seed)
      : _random = math.Random(seed),
        super(start, travel);

  final Offset from;
  final Offset to;
  final Color color;
  final math.Random _random;

  @override
  void paint(Canvas canvas, double t) {
    final e = Curves.easeIn.transform(t);
    // Lintasan melengkung seperti lemparan.
    final mid =
        Offset.lerp(from, to, 0.5)! + Offset(0, -(to - from).distance * 0.18);
    Offset at(double k) {
      final a = Offset.lerp(from, mid, k)!;
      final b = Offset.lerp(mid, to, k)!;
      return Offset.lerp(a, b, k)!;
    }

    final head = at(e);
    // Ekor.
    for (var i = 1; i <= 8; i++) {
      final k = (e - i * 0.035).clamp(0.0, 1.0);
      final p = at(k) +
          Offset(_random.nextDouble() * 4 - 2, _random.nextDouble() * 4 - 2);
      canvas.drawCircle(
        p,
        9 * (1 - i / 9),
        Paint()..color = color.withValues(alpha: 0.5 * (1 - i / 9)),
      );
    }
    canvas.drawCircle(head, 16, Paint()..color = color.withValues(alpha: 0.35));
    canvas.drawCircle(head, 11, Paint()..color = color);
    canvas.drawCircle(head, 6.5, Paint()..color = Colors.white);
  }
}

/// Gelembung nama jurus yang muncul di atas penyerang (gaya clay solid).
class _CalloutFx extends _Fx {
  _CalloutFx(this.anchor, this.text, this.color, double start)
      : super(start, 1100);

  final Offset anchor;
  final String text;
  final Color color;

  @override
  void paint(Canvas canvas, double t) {
    final pop = t < 0.15 ? Curves.easeOutBack.transform(t / 0.15) : 1.0;
    final fade = t < 0.75 ? 1.0 : 1 - (t - 0.75) / 0.25;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Colors.white.withValues(alpha: fade),
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 220);
    final w = painter.width + 26;
    final h = painter.height + 12;
    canvas.save();
    canvas.translate(anchor.dx, anchor.dy - 10 - t * 6);
    canvas.scale(pop);
    final pill = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, -h / 2), width: w, height: h),
      Radius.circular(h / 2),
    );
    canvas.drawRRect(
      pill.shift(const Offset(2, 4)),
      Paint()
        ..color = Clay.shadeOf(color, 0.3).withValues(alpha: 0.4 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawRRect(pill, Paint()..color = color.withValues(alpha: fade));
    // Sorot clay di tepi atas.
    canvas.drawRRect(
      pill.deflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.35 * fade),
    );
    painter.paint(
      canvas,
      Offset(-painter.width / 2, -h / 2 - painter.height / 2),
    );
    canvas.restore();
  }
}

class _FloatTextFx extends _Fx {
  _FloatTextFx(this.center, this.text, this.color, double start)
      : super(start, 950);

  final Offset center;
  final String text;
  final Color color;

  @override
  void paint(Canvas canvas, double t) {
    final pop = t < 0.18 ? Curves.easeOutBack.transform(t / 0.18) : 1.0;
    final fade = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
    final rise = _easeOut(t) * 46;
    final style = TextStyle(
      fontSize: 22 * (0.6 + 0.4 * pop),
      fontWeight: FontWeight.w900,
      color: color.withValues(alpha: fade),
      shadows: <Shadow>[
        Shadow(
            color: Colors.black.withValues(alpha: 0.85 * fade), blurRadius: 6),
      ],
    );
    final stroke = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(
          color: null,
          shadows: const <Shadow>[],
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5
            ..color = Colors.black.withValues(alpha: 0.8 * fade),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final fill = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final pos = center - Offset(fill.width / 2, fill.height / 2 + rise);
    stroke.paint(canvas, pos);
    fill.paint(canvas, pos);
  }
}

class _HealFx extends _Fx {
  _HealFx(this.rect, double start, int seed)
      : _xs =
            List<double>.generate(7, (i) => math.Random(seed + i).nextDouble()),
        super(start, 800);

  final Rect rect;
  final List<double> _xs;

  @override
  void paint(Canvas canvas, double t) {
    final fade = 1 - t;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()..color = const Color(0xFF4ADE80).withValues(alpha: 0.22 * fade),
    );
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3
      ..color = const Color(0xFFB9F6CA).withValues(alpha: fade);
    for (var i = 0; i < _xs.length; i++) {
      final local = ((t - i * 0.06) / 0.8).clamp(0.0, 1.0);
      final p = Offset(
        rect.left + rect.width * (0.15 + _xs[i] * 0.7),
        rect.bottom - rect.height * 0.15 - local * rect.height * 0.8,
      );
      const s = 5.0;
      canvas.drawLine(p - const Offset(s, 0), p + const Offset(s, 0), paint);
      canvas.drawLine(p - const Offset(0, s), p + const Offset(0, s), paint);
    }
  }
}

class _FaintFx extends _Fx {
  _FaintFx(this.rect, this.color, double start, int seed)
      : _dirs = List<Offset>.generate(14, (i) {
          final r = math.Random(seed + i);
          final a = r.nextDouble() * math.pi * 2;
          return Offset(math.cos(a), math.sin(a)) *
              (0.4 + r.nextDouble() * 0.6);
        }),
        super(start + 120, 650);

  final Rect rect;
  final Color color;
  final List<Offset> _dirs;

  @override
  void paint(Canvas canvas, double t) {
    final e = _easeOut(t);
    final fade = 1 - t;
    // Siluet "ghost" yang melayang ke atas.
    final ghost = rect
        .translate(0, -e * rect.height * 0.25)
        .deflate(rect.width * 0.1 * e);
    canvas.drawRRect(
      RRect.fromRectAndRadius(ghost, const Radius.circular(12)),
      Paint()..color = Colors.white.withValues(alpha: 0.35 * fade),
    );
    for (final d in _dirs) {
      final p = rect.center + d * rect.shortestSide * (0.2 + e * 0.9);
      canvas.drawCircle(
        p,
        5 * fade + 1,
        Paint()
          ..color =
              Color.lerp(color, Colors.white, 0.4)!.withValues(alpha: fade),
      );
    }
  }
}

class _SummonFx extends _Fx {
  _SummonFx(this.rect, this.color, double start, int seed)
      : _xs =
            List<double>.generate(9, (i) => math.Random(seed + i).nextDouble()),
        super(start, 700);

  final Rect rect;
  final Color color;
  final List<double> _xs;

  @override
  void paint(Canvas canvas, double t) {
    final e = _easeOut(t);
    final fade = 1 - t;
    final base = Offset(rect.center.dx, rect.bottom - rect.height * 0.1);
    final ring = Rect.fromCenter(
      center: base,
      width: rect.width * (0.3 + e * 1.0),
      height: rect.width * (0.1 + e * 0.32),
    );
    canvas.drawOval(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * fade + 0.5
        ..color = color.withValues(alpha: fade),
    );
    // Pilar cahaya.
    final pillar = Rect.fromLTRB(
      rect.left + rect.width * 0.2,
      rect.top,
      rect.right - rect.width * 0.2,
      base.dy,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pillar, Radius.circular(pillar.width / 2)),
      Paint()..color = color.withValues(alpha: 0.28 * fade),
    );
    final dot = Paint()..color = Colors.white.withValues(alpha: fade);
    for (var i = 0; i < _xs.length; i++) {
      final p = Offset(
        rect.left + rect.width * (0.1 + _xs[i] * 0.8),
        base.dy - e * rect.height * (0.4 + _xs[(i + 3) % _xs.length] * 0.6),
      );
      canvas.drawCircle(p, 2.2, dot);
    }
  }
}
