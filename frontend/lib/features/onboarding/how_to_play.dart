import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/config/game_config.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/storage/app_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';

class _Step {
  const _Step({
    required this.key,
    required this.color,
    required this.icon,
    this.model,
  });

  final String key;
  final Color color;
  final IconData icon;

  /// Kunci model 3D untuk ilustrasi (opsional).
  final String? model;
}

const List<_Step> _steps = <_Step>[
  _Step(
    key: 'collect',
    color: AppTheme.accent,
    icon: Icons.auto_awesome_rounded,
    model: 'dino',
  ),
  _Step(
    key: 'deck',
    color: AppTheme.primary,
    icon: Icons.style_rounded,
    model: 'shiba',
  ),
  _Step(
    key: 'summon',
    color: AppTheme.warning,
    icon: Icons.bolt_rounded,
    model: 'pig',
  ),
  _Step(
    key: 'moves',
    color: AppTheme.attack,
    icon: Icons.sports_martial_arts_rounded,
    model: 'dragon_evolved',
  ),
  _Step(
    key: 'win',
    color: AppTheme.success,
    icon: Icons.emoji_events_rounded,
    model: 'alpaking',
  ),
];

/// Tampilkan panduan otomatis sekali saja (pemain baru).
Future<void> maybeShowHowToPlay(BuildContext context) async {
  final storage = AppScope.of(context).storage;
  if (storage.getBool(AppStorage.kOnboarded)) return;
  await showHowToPlay(context);
  await storage.setValue(AppStorage.kOnboarded, true);
}

/// Panduan "Cara Bermain" 5 langkah bergambar.
Future<void> showHowToPlay(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _HowToPlaySheet(),
  );
}

/// Tombol bantuan bulat (dipakai di Beranda & Arena).
class HelpButton extends StatelessWidget {
  const HelpButton({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Tooltip(
      message: strings.t('help.title'),
      child: Clay(
        width: 40,
        height: 40,
        shape: BoxShape.circle,
        depth: 0.5,
        onTap: () => showHowToPlay(context),
        child: const Icon(
          Icons.question_mark_rounded,
          size: 20,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}

class _HowToPlaySheet extends StatefulWidget {
  const _HowToPlaySheet();

  @override
  State<_HowToPlaySheet> createState() => _HowToPlaySheetState();
}

class _HowToPlaySheetState extends State<_HowToPlaySheet> {
  final PageController _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _steps.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    _pages.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final last = _index == _steps.length - 1;
    final args = <String, String>{
      'deck': '${GameConfig.deckSize}',
      'copies': '${GameConfig.maxCopiesPerCard}',
      'slots': '${GameConfig.boardSlots}',
      'hp': '${GameConfig.playerHp}',
      'pity': '${GameConfig.pityThreshold}',
    };

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 12, 0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      strings.t('help.title'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(strings.t('common.skip')),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final step = _steps[i];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                    child: Column(
                      children: <Widget>[
                        Expanded(
                          child: Clay(
                            color: Color.lerp(step.color, Colors.white, 0.78)!,
                            radius: 32,
                            child: Stack(
                              children: <Widget>[
                                if (step.model != null)
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.all(18),
                                      child: ModelCreature(
                                        modelKey: step.model!,
                                        seed: i * 977,
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: 14,
                                  left: 14,
                                  child: Clay(
                                    width: 52,
                                    height: 52,
                                    shape: BoxShape.circle,
                                    color: step.color,
                                    depth: 0.6,
                                    child: Icon(
                                      step.icon,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 18,
                                  right: 18,
                                  child: ClayPill(
                                    label: '${i + 1}/${_steps.length}',
                                    color: AppTheme.ink,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          strings.t('help.${step.key}.title'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.t('help.${step.key}.body', args),
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppTheme.inkSoft, height: 1.4),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 16),
              child: Row(
                children: <Widget>[
                  for (var i = 0; i < _steps.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _index ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color:
                            i == _index ? AppTheme.primary : AppTheme.inkFaint,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  const Spacer(),
                  ClayButton(
                    label: strings.t(last ? 'help.start' : 'help.next'),
                    icon: last
                        ? Icons.play_arrow_rounded
                        : Icons.arrow_forward_rounded,
                    onPressed: _next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
