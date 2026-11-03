import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_scope.dart';
import '../../core/config/game_config.dart';
import '../../core/config/env.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../domain/models/battle_api_models.dart';
import '../auth/auth_cubit.dart';
import '../settings/settings_page.dart';
import 'profile_cubit.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<List<BattleHistoryItem>> _history =
      Future<List<BattleHistoryItem>>.value(const <BattleHistoryItem>[]);
  bool _dependenciesReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) return;
    _dependenciesReady = true;
    _reloadHistory();
  }

  void _reloadHistory() {
    _history = AppScope.of(context).repositories.battle.history(limit: 12);
  }

  Future<void> _refresh() async {
    await context.read<ProfileCubit>().refresh();
    if (!mounted) return;
    setState(_reloadHistory);
    try {
      await _history;
    } catch (_) {
      // Kegagalan riwayat tidak boleh menggagalkan refresh profil.
    }
  }

  Future<void> _claimDaily() async {
    final strings = AppStrings.of(context);
    final message = await context.read<ProfileCubit>().claimDaily();
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (message != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            strings.t('home.dailyClaimFailed', <String, String>{
              'message': message,
            }),
          ),
        ),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(strings.t('home.dailyClaimedToast'))),
    );
    if (!mounted) return;
    setState(_reloadHistory);
  }

  Future<void> _logout() async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.t('auth.logout')),
        content: Text(strings.t('auth.logoutConfirm')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.t('auth.logout')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await context.read<AuthCubit>().logout();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _openSettings() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        if (state is ProfileLoading) {
          return LoadingView(message: strings.t('common.loading'));
        }
        if (state is ProfileError) {
          return ErrorView(
            message: state.message,
            retryLabel: strings.t('common.retry'),
            onRetry: () => context.read<ProfileCubit>().load(),
          );
        }
        if (state is! ProfileReady) {
          return const SizedBox.shrink();
        }

        final profile = state.profile;
        final user = profile.user;
        final stats = profile.stats;
        final winRate = stats.winRate;
        final winRateText =
            winRate == null ? '—' : '${(winRate * 100).toStringAsFixed(1)}%';

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Clay(
                    width: 58,
                    height: 58,
                    shape: BoxShape.circle,
                    color: AppTheme.primary,
                    depth: 0.7,
                    alignment: Alignment.center,
                    child: Text(
                      user.username.isEmpty
                          ? '?'
                          : user.username.characters.first.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          user.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          strings.t('profile.level', <String, String>{
                            'level': user.level.toString(),
                          }),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: strings.t('profile.settings'),
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          strings.t('profile.xp', <String, String>{
                            'current': user.xp.toString(),
                            'next': GameConfig.xpToNext(user.level).toString(),
                          }),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        WalletChips(gold: user.gold, gems: user.gems),
                      ],
                    ),
                    const SizedBox(height: 8),
                    HpBar(
                      current: user.xp,
                      max: GameConfig.xpToNext(user.level),
                      color: AppTheme.primary,
                      height: 9,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SectionHeader(title: strings.t('profile.stats')),
              Row(
                children: <Widget>[
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
                      label: strings.t('outcome.loss'),
                      value: stats.losses.toString(),
                      icon: Icons.close_rounded,
                      color: AppTheme.danger,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatBox(
                      label: strings.t('outcome.draw'),
                      value: stats.draws.toString(),
                      icon: Icons.balance_rounded,
                      color: AppTheme.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: StatBox(
                      label: strings.t('home.winRate'),
                      value: winRateText,
                      icon: Icons.percent_rounded,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatBox(
                      label: strings.t('home.collection'),
                      value:
                          '${profile.collection.owned}/${profile.collection.total}',
                      icon: Icons.grid_view_rounded,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SectionHeader(title: strings.t('profile.daily')),
              Panel(
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppTheme.gold.withValues(alpha: 0.14),
                      ),
                      child: const Icon(
                        Icons.card_giftcard_rounded,
                        color: AppTheme.gold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            strings.t('home.dailyStreak', <String, String>{
                              'streak': profile.daily.streak.toString(),
                            }),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            profile.daily.canClaim
                                ? _dailyRewardLabel(
                                    profile.daily.streak, strings)
                                : strings.t('home.dailyClaimed'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: profile.daily.canClaim && !state.claimingDaily
                          ? _claimDaily
                          : null,
                      child: state.claimingDaily
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              profile.daily.canClaim
                                  ? strings.t('profile.claim')
                                  : strings.t('profile.claimed'),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SectionHeader(title: strings.t('profile.account')),
              Panel(
                child: Column(
                  children: <Widget>[
                    _InfoRow(
                      icon: Icons.alternate_email_rounded,
                      label: strings.t('profile.email'),
                      value: user.email,
                    ),
                    const Divider(height: 18),
                    _InfoRow(
                      icon: Icons.calendar_month_rounded,
                      label: strings.t('profile.memberSince', <String, String>{
                        'date': _formatDate(user.createdAt),
                      }),
                      value: strings.t('profile.version', <String, String>{
                        'version': Env.appVersion,
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SectionHeader(title: strings.t('profile.history')),
              _HistoryList(
                future: _history,
                strings: strings,
                onRetry: () => setState(_reloadHistory),
              ),
              if (!Env.offlineMode) const SizedBox(height: 18),
              if (!Env.offlineMode)
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: Text(strings.t('profile.logout')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: BorderSide(
                      color: AppTheme.danger.withValues(alpha: 0.4),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _dailyRewardLabel(int streak, AppStrings strings) {
    final index = streak.clamp(0, 6);
    final gold = GameConfig.dailyRewardGold[index];
    final gems = GameConfig.dailyRewardGems[index];
    final goldLabel = strings.t('gacha.costGold', <String, String>{
      'amount': gold.toString(),
    });
    if (gems <= 0) return '+$goldLabel';
    final gemLabel = strings.t('gacha.costGem', <String, String>{
      'amount': gems.toString(),
    });
    return '+$goldLabel +$gemLabel';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: AppTheme.inkSoft),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.future,
    required this.strings,
    required this.onRetry,
  });

  final Future<List<BattleHistoryItem>> future;
  final AppStrings strings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BattleHistoryItem>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Panel(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Panel(
            child: Column(
              children: <Widget>[
                Text(
                  strings.t('error.network'),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                FilledButton.tonal(
                  onPressed: onRetry,
                  child: Text(strings.t('common.retry')),
                ),
              ],
            ),
          );
        }

        final items = snapshot.data ?? const <BattleHistoryItem>[];
        if (items.isEmpty) {
          return Panel(
            child: Text(
              strings.t('profile.noHistory'),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          );
        }

        return Column(
          children: <Widget>[
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _HistoryTile(item: item, strings: strings),
              ),
          ],
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item, required this.strings});

  final BattleHistoryItem item;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final isWin = item.outcome == 'win';
    final isLoss = item.outcome == 'loss';
    final color = isWin
        ? AppTheme.success
        : isLoss
            ? AppTheme.danger
            : AppTheme.warning;
    final outcomeLabel = isWin
        ? strings.t('outcome.win')
        : isLoss
            ? strings.t('outcome.loss')
            : strings.t('outcome.draw');

    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: color.withValues(alpha: 0.14),
            ),
            child: Icon(
              isWin
                  ? Icons.emoji_events_rounded
                  : isLoss
                      ? Icons.close_rounded
                      : Icons.balance_rounded,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      outcomeLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        strings.t('profile.historyMeta', <String, String>{
                          'difficulty': strings.t(
                            'battle.difficulty.${item.difficulty}',
                          ),
                          'turns': item.turns.toString(),
                        }),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  strings.t('profile.historyReward', <String, String>{
                    'gold': item.goldAwarded.toString(),
                    'xp': item.xpAwarded.toString(),
                  }),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _timeAgo(item.reportedAt, strings),
            style: const TextStyle(fontSize: 10, color: AppTheme.inkFaint),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime? date, AppStrings strings) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date.toLocal());
    if (diff.inMinutes < 1) return strings.t('time.justNow');
    if (diff.inHours < 1) {
      return strings.t('time.minutesAgo', <String, String>{
        'count': diff.inMinutes.toString(),
      });
    }
    if (diff.inDays < 1) {
      return strings.t('time.hoursAgo', <String, String>{
        'count': diff.inHours.toString(),
      });
    }
    return strings.t('time.daysAgo', <String, String>{
      'count': diff.inDays.toString(),
    });
  }
}
