import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/config/game_config.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../domain/models/user_model.dart';
import 'battle_arena_page.dart';

/// Layar pemilihan kesulitan sebelum pertandingan dimulai.
/// Deck aktif divalidasi di server; layar ini hanya menampilkan status.
class BattleSetupPage extends StatefulWidget {
  const BattleSetupPage({super.key, this.initialDifficulty});

  final String? initialDifficulty;

  @override
  State<BattleSetupPage> createState() => _BattleSetupPageState();
}

class _BattleSetupPageState extends State<BattleSetupPage> {
  late String _difficulty;
  UserProfile? _profile;
  String? _loadError;
  bool _loading = true;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _difficulty = GameConfig.difficulties.contains(widget.initialDifficulty)
        ? widget.initialDifficulty!
        : 'easy';
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final profile = await AppScope.of(context).repositories.user.profile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = AppStrings.of(context).t('error.unknown');
        _loading = false;
      });
    }
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    final scope = AppScope.of(context);
    try {
      final start = await scope.repositories.battle.start(
        difficulty: _difficulty,
      );
      if (!mounted) return;
      setState(() => _starting = false);
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => BattleArenaPage(start: start),
        ),
      );
      if (!mounted) return;
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _starting = false);
      _showError(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _starting = false);
      _showError(AppStrings.of(context).t('error.unknown'));
    }
  }

  void _showError(String message) {
    final strings = AppStrings.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            strings.t('battle.startFailed', <String, String>{
              'message': message,
            }),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final profile = _profile;
    final activeDeck = profile?.activeDeck;
    final canStart =
        !_starting && !_loading && _loadError == null && activeDeck != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t('battle.setup')),
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          top: false,
          child: _loading
              ? LoadingView(message: strings.t('common.loading'))
              : _loadError != null
              ? ErrorView(
                  message: _loadError!,
                  retryLabel: strings.t('common.retry'),
                  onRetry: _load,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  children: <Widget>[
                    Text(
                      strings.t('battle.title'),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.t('battle.setupSubtitle'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Panel(
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: AppTheme.primary.withValues(alpha: 0.16),
                            ),
                            child: const Icon(
                              Icons.style_rounded,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  activeDeck != null
                                      ? strings.t(
                                          'battle.deckActive',
                                          <String, String>{
                                            'name': activeDeck.name,
                                          },
                                        )
                                      : strings.t('battle.noDeck'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (activeDeck != null)
                                  Text(
                                    '${activeDeck.cardCount}/${GameConfig.deckSize} '
                                    '${strings.t('deck.cards').toLowerCase()}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SectionHeader(title: strings.t('battle.selectDifficulty')),
                    for (final difficulty in GameConfig.difficulties) ...<Widget>[
                      _DifficultyCard(
                        difficulty: difficulty,
                        selected: _difficulty == difficulty,
                        onTap: _starting
                            ? null
                            : () => setState(() => _difficulty = difficulty),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 8),
                    if (profile != null) _StatsRow(profile: profile),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: canStart ? _start : null,
                      icon: _starting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sports_martial_arts_rounded),
                      label: Text(
                        _starting
                            ? strings.t('battle.submittingTitle')
                            : strings.t('battle.start'),
                      ),
                    ),
                    if (!_loading && activeDeck == null) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        strings.t('battle.invalidDeck'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.warning,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  const _DifficultyCard({
    required this.difficulty,
    required this.selected,
    required this.onTap,
  });

  final String difficulty;
  final bool selected;
  final VoidCallback? onTap;

  static const Map<String, IconData> _icons = <String, IconData>{
    'easy': Icons.sentiment_satisfied_rounded,
    'medium': Icons.local_fire_department_rounded,
    'master': Icons.whatshot_rounded,
  };

  static const Map<String, Color> _colors = <String, Color>{
    'easy': AppTheme.success,
    'medium': AppTheme.warning,
    'master': AppTheme.danger,
  };

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final reward = GameConfig.battleRewards[difficulty];
    final color = _colors[difficulty] ?? AppTheme.primary;
    final accent = color;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.all(selected ? 3 : 0),
      decoration: BoxDecoration(
        color: selected ? accent : Colors.transparent,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Clay(
        onTap: onTap,
        radius: 26,
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        child: Row(
          children: <Widget>[
            Clay(
              width: 44,
              height: 44,
              shape: BoxShape.circle,
              color: accent,
              depth: 0.6,
              child: Icon(
                _icons[difficulty] ?? Icons.smart_toy_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    strings.t('battle.difficulty.$difficulty'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    strings.t('battle.difficultyHint.$difficulty'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (reward != null) ...<Widget>[
                    const SizedBox(height: 5),
                    Text(
                      strings.t('battle.rewardPreview', <String, String>{
                        'gold': reward.gold.toString(),
                        'xp': reward.xp.toString(),
                      }),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? accent : AppTheme.inkFaint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final stats = profile.stats;
    final winRate = stats.winRate;
    final winRateText = winRate == null
        ? '—'
        : '${(winRate * 100).toStringAsFixed(1)}%';

    return Row(
      children: <Widget>[
        Expanded(
          child: StatBox(
            label: strings.t('home.battles'),
            value: stats.total.toString(),
            icon: Icons.sports_esports_rounded,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatBox(
            label: strings.t('outcome.win'),
            value: stats.wins.toString(),
            icon: Icons.emoji_events_rounded,
            color: AppTheme.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatBox(
            label: strings.t('home.winRate'),
            value: winRateText,
            icon: Icons.percent_rounded,
            color: AppTheme.accent,
          ),
        ),
      ],
    );
  }
}
