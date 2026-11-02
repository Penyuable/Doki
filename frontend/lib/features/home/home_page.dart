import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/game_config.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../auth/auth_cubit.dart';
import '../battle/battle_setup_page.dart';
import '../profile/profile_cubit.dart';
import '../shell/home_shell.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, profileState) {
        if (profileState is ProfileLoading) {
          return LoadingView(message: strings.t('common.loading'));
        }
        if (profileState is ProfileError) {
          return ErrorView(
            message: profileState.message,
            retryLabel: strings.t('common.retry'),
            onRetry: () => context.read<ProfileCubit>().load(),
          );
        }
        if (profileState is! ProfileReady) {
          return const SizedBox.shrink();
        }

        final profile = profileState.profile;
        final user = profile.user;
        final stats = profile.stats;
        final xpNext = GameConfig.xpToNext(user.level);
        final winRate = stats.winRate;
        final winRateText = winRate == null
            ? '—'
            : '${(winRate * 100).toStringAsFixed(1)}%';

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[AppTheme.primary, AppTheme.accent],
                    ),
                  ),
                  child: Text(
                    user.username.isEmpty
                        ? '?'
                        : user.username.characters.first.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        strings.t('home.greeting', <String, String>{
                          'name': user.username,
                        }),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        strings.t('profile.level', <String, String>{
                          'level': user.level.toString(),
                        }),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                WalletChips(gold: user.gold, gems: user.gems),
              ],
            ),
            const SizedBox(height: 18),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        strings.t('profile.level', <String, String>{
                          'level': user.level.toString(),
                        }),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        strings.t('profile.xp', <String, String>{
                          'current': user.xp.toString(),
                          'next': xpNext.toString(),
                        }),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  HpBar(
                    current: user.xp,
                    max: xpNext,
                    color: AppTheme.primary,
                    height: 9,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _QuickAction(
                    icon: Icons.sports_martial_arts_rounded,
                    label: strings.t('home.battleCta'),
                    color: const Color(0xFFF97316),
                    onTap: () => _openBattle(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.auto_awesome_rounded,
                    label: strings.t('home.gachaCta'),
                    color: AppTheme.accent,
                    onTap: () => ShellNavigator.of(context).select(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.style_rounded,
                    label: strings.t('home.deckCta'),
                    color: AppTheme.primary,
                    onTap: () => ShellNavigator.of(context).select(2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SectionHeader(title: strings.t('home.activeDeck')),
            Panel(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          profile.activeDeck?.name ?? strings.t('home.noDeck'),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (profile.activeDeck != null) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            '${profile.activeDeck!.cardCount}/${GameConfig.deckSize} ${strings.t('deck.cards').toLowerCase()}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () => ShellNavigator.of(context).select(2),
                    child: Text(strings.t('home.buildDeck')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionHeader(title: strings.t('home.daily')),
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
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          profile.daily.canClaim
                              ? _dailyRewardLabel(profile.daily.streak, strings)
                              : strings.t('home.dailyClaimed'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed:
                        profile.daily.canClaim &&
                            !profileState.claimingDaily
                        ? () => _claimDaily(context)
                        : null,
                    child: profileState.claimingDaily
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(strings.t('profile.claim')),
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
                    color: const Color(0xFF4ADE80),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatBox(
                    label: strings.t('outcome.loss'),
                    value: stats.losses.toString(),
                    icon: Icons.close_rounded,
                    color: const Color(0xFFF87171),
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
            ),
            const SizedBox(height: 18),
            SectionHeader(title: strings.t('home.tipTitle')),
            Panel(
              child: Text(
                strings.t('home.tip'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
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

  Future<void> _claimDaily(BuildContext context) async {
    final strings = AppStrings.of(context);
    final message = await context.read<ProfileCubit>().claimDaily();
    if (!context.mounted) return;

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
  }

  Future<void> _openBattle(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const BattleSetupPage(),
      ),
    );
    if (!context.mounted) return;
    await context.read<ProfileCubit>().refresh();
    if (!context.mounted) return;
    await context.read<AuthCubit>().refreshProfile();
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
