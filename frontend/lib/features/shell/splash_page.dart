import 'package:flutter/material.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../domain/models/card_model.dart';

/// Lama minimum splash agar tidak sekadar berkedip saat sesi pulih seketika.
const Duration kMinSplashDuration = Duration(milliseconds: 1600);

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  // Kreatur maskot (id starter) — hanya visual, bukan data inventory.
  static final List<CardModel> _mascots = <CardModel>[
    mascotCard('card_002', CardElement.water),
    mascotCard('card_001', CardElement.fire),
    mascotCard('card_003', CardElement.earth),
  ];

  @override
  void initState() {
    super.initState();
    _intro.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Animation<double> _interval(double begin, double end) => CurvedAnimation(
        parent: _intro,
        curve: Interval(begin, end, curve: Curves.easeOutBack),
      );

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
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.inkSoft,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 110,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      for (final (index, card) in _mascots.indexed)
                        ScaleTransition(
                          scale: _interval(
                            0.3 + index * 0.12,
                            0.75 + index * 0.08,
                          ),
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(
                            width: index == 1 ? 110 : 84,
                            height: index == 1 ? 110 : 84,
                            child: CreatureAvatar(card: card),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 160,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: const LinearProgressIndicator(minHeight: 4),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  strings.t('common.loading'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.inkSoft,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
