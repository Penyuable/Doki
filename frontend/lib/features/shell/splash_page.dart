import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';

/// Lama minimum splash agar tidak sekadar berkedip saat sesi pulih seketika.
const Duration kMinSplashDuration = Duration(milliseconds: 1600);

/// Aset yang dimuat ke memori selama splash agar kartu langsung tampil.
List<String> defaultSplashAssets() => <String>{
      ...CreatureModels.byCardId.values,
      ...CreatureModels.bySpecies.values,
    }.map(CreatureModels.imageAsset).toList(growable: false);

/// Splash dengan loading sungguhan: memuat ilustrasi monster sambil
/// menampilkan progres bertahap, lalu memanggil [onLoaded].
class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    this.onLoaded,
    this.minDuration = kMinSplashDuration,
    this.assets,
  });

  /// Dipanggil sekali setelah semua aset termuat dan durasi minimum lewat.
  final VoidCallback? onLoaded;
  final Duration minDuration;

  /// Aset untuk dimuat (null = [defaultSplashAssets]).
  final List<String>? assets;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  /// Waktu berjalan 0→1 selama durasi minimum (agar bilah terisi mulus).
  late final AnimationController _time = AnimationController(
    vsync: this,
    duration: widget.minDuration,
  );

  static const List<String> _mascots = <String>['birb', 'dino', 'pig'];
  static const int _tipCount = 3;

  late final List<String> _assets = widget.assets ?? defaultSplashAssets();
  int _loaded = 0;
  bool _started = false;
  bool _notified = false;
  int _tip = 0;
  Timer? _tipTimer;

  double get _loadProgress => _assets.isEmpty ? 1 : _loaded / _assets.length;

  @override
  void initState() {
    super.initState();
    _intro.forward();
    // Status listener: status `completed` baru di-set setelah listener nilai
    // terakhir dipanggil, jadi pengecekan selesai harus di sini.
    _time
      ..addStatusListener((_) => _checkDone())
      ..forward();
    _tipTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (mounted) setState(() => _tip = (_tip + 1) % _tipCount);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _preload();
  }

  Future<void> _preload() async {
    for (final path in _assets) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(path), context);
      } on Object catch (error, stack) {
        // Gambar gagal dimuat tidak boleh menahan pemain di splash;
        // kartu tetap punya karakter cadangan.
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'dokimon splash',
            context: ErrorDescription('memuat $path'),
          ),
        );
      }
      if (!mounted) return;
      setState(() => _loaded += 1);
      _checkDone();
    }
    _checkDone();
  }

  void _checkDone() {
    if (_notified || !mounted) return;
    if (_loaded >= _assets.length && _time.isCompleted) {
      _notified = true;
      widget.onLoaded?.call();
    }
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    _intro.dispose();
    _time.dispose();
    super.dispose();
  }

  Animation<double> _interval(double begin, double end) => CurvedAnimation(
        parent: _intro,
        curve: Interval(begin, end, curve: Curves.easeOutBack),
      );

  String _stepLabel(AppStrings strings, double progress) {
    if (progress >= 1) return strings.t('splash.ready');
    if (progress < 0.35) return strings.t('splash.step.cards');
    if (progress < 0.75) return strings.t('splash.step.monsters');
    return strings.t('splash.step.table');
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final logo = _interval(0, 0.55);
    final title = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.35, 0.8, curve: Curves.easeOut),
    );

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: <Widget>[
                const Spacer(flex: 3),
                ScaleTransition(
                  scale: logo,
                  child: const AppLogo(size: 112),
                ),
                const SizedBox(height: 22),
                FadeTransition(
                  opacity: title,
                  child: Column(
                    children: <Widget>[
                      Text(
                        strings.t('app.name'),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: AppTheme.ink,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        strings.t('app.tagline'),
                        style: Theme.of(
                          context,
                        )
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppTheme.inkSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  height: 116,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      for (final (index, key) in _mascots.indexed)
                        ScaleTransition(
                          scale: _interval(
                            0.3 + index * 0.12,
                            0.75 + index * 0.08,
                          ),
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(
                            width: index == 1 ? 116 : 88,
                            height: index == 1 ? 116 : 88,
                            child: ModelCreature(
                              modelKey: key,
                              seed: index * 811,
                              mirrored: index == 2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                AnimatedBuilder(
                  animation: _time,
                  builder: (context, _) {
                    // Bilah mengikuti yang paling lambat: waktu atau muatan.
                    final progress = math.min(_loadProgress, _time.value);
                    return _LoadingBar(
                      progress: progress,
                      label: _stepLabel(strings, progress),
                    );
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 40,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      strings.t('splash.tip.$_tip'),
                      key: ValueKey<int>(_tip),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.inkSoft,
                            height: 1.35,
                          ),
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bilah progres clay dengan label tahap & persentase.
class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.progress, required this.label});

  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();
    return Semantics(
      label: label,
      value: '$percent%',
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Clay(
            height: 16,
            radius: 999,
            pressed: true,
            depth: 0.5,
            color: AppTheme.surfaceHigh,
            padding: const EdgeInsets.all(3),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress.clamp(0.04, 1.0),
                heightFactor: 1,
                child: const Clay(
                  radius: 999,
                  depth: 0.3,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
