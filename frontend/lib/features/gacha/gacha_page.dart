import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_scope.dart';
import '../../core/config/game_config.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../domain/models/gacha_model.dart';
import '../../domain/models/user_model.dart';
import '../auth/auth_cubit.dart';
import '../collection/collection_cubit.dart';
import '../profile/profile_cubit.dart';
import '../settings/settings_cubit.dart';
import 'gacha_cubit.dart';
import 'gacha_reveal_dialog.dart';

class GachaPage extends StatelessWidget {
  const GachaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return BlocProvider<GachaCubit>(
      create: (_) => GachaCubit(
        scope.repositories.gacha,
        context.read<AuthCubit>(),
      )..init(),
      child: const _GachaView(),
    );
  }
}

class _GachaView extends StatefulWidget {
  const _GachaView();

  @override
  State<_GachaView> createState() => _GachaViewState();
}

class _GachaViewState extends State<_GachaView> {
  String _currency = 'gold';

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return BlocBuilder<GachaCubit, GachaState>(
      builder: (context, state) {
        if (state is GachaLoading) {
          return LoadingView(message: strings.t('common.loading'));
        }
        if (state is GachaError) {
          return ErrorView(
            message: state.message,
            retryLabel: strings.t('common.retry'),
            onRetry: () => context.read<GachaCubit>().init(),
          );
        }
        if (state is! GachaReady) {
          return const SizedBox.shrink();
        }

        final authState = context.watch<AuthCubit>().state;
        final user = authState is AuthAuthenticated ? authState.user : null;
        final pulling = state.pulling;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        strings.t('gacha.title'),
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        strings.t('gacha.oddsTeaser'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: user == null ? null : _showRates,
                  icon: const Icon(Icons.percent_rounded, size: 18),
                  label: Text(strings.t('gacha.rates')),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 18,
                        color: AppTheme.accent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          strings.t('gacha.pity', <String, String>{
                            'count': state.pity.guaranteedIn.toString(),
                          }),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      Text(
                        strings.t('gacha.pityProgress', <String, String>{
                          'current': state.pity.counter.toString(),
                          'max': state.pity.threshold.toString(),
                        }),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  HpBar(
                    current: state.pity.counter,
                    max: state.pity.threshold,
                    color: AppTheme.primary,
                    height: 9,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (user != null)
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      strings.t('gacha.cost'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  WalletChips(gold: user.gold, gems: user.gems),
                ],
              ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: 'gold',
                  label: Text(strings.t('gacha.currencyGold')),
                  icon: const Icon(
                    Icons.monetization_on_rounded,
                    color: AppTheme.gold,
                  ),
                ),
                ButtonSegment<String>(
                  value: 'gem',
                  label: Text(strings.t('gacha.currencyGem')),
                  icon: const Icon(
                    Icons.diamond_rounded,
                    color: AppTheme.gem,
                  ),
                ),
              ],
              selected: <String>{_currency},
              onSelectionChanged: pulling
                  ? null
                  : (selection) => setState(() => _currency = selection.first),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _PullButton(
                    count: 1,
                    currency: _currency,
                    price: _priceFor(1),
                    user: user,
                    busy: pulling,
                    onTap: () => _attemptPull(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PullButton(
                    count: 10,
                    currency: _currency,
                    price: _priceFor(10),
                    user: user,
                    busy: pulling,
                    onTap: () => _attemptPull(10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Panel(
              color: AppTheme.surfaceHigh,
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: AppTheme.gold,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      strings.t('gacha.guarantee'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            if (pulling) ...<Widget>[
              const SizedBox(height: 18),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        );
      },
    );
  }

  int _priceFor(int count) {
    final table = _currency == 'gold'
        ? GameConfig.gachaGoldPrice
        : GameConfig.gachaGemPrice;
    return table[count] ?? 0;
  }

  String _priceLabel(int count) {
    final amount = _priceFor(count).toString();
    return _currency == 'gold'
        ? AppStrings.of(context).t('gacha.costGold', <String, String>{
            'amount': amount,
          })
        : AppStrings.of(context).t('gacha.costGem', <String, String>{
            'amount': amount,
          });
  }

  Future<void> _attemptPull(int count) async {
    final strings = AppStrings.of(context);
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) return;
    final user = authState.user;
    final price = _priceFor(count);
    final balance = _currency == 'gold' ? user.gold : user.gems;

    if (balance < price) {
      if (_currency == 'gold') {
        final gemPrice = GameConfig.gachaGemPrice[count] ?? 0;
        if (user.gems >= gemPrice) {
          final useGem = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(strings.t('gacha.notEnoughTitle')),
              content: Text(
                strings.t('gacha.insufficientBody', <String, String>{
                  'price': _priceLabel(count),
                }),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(strings.t('common.cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(strings.t('gacha.useGem')),
                ),
              ],
            ),
          );
          if (useGem == true && mounted) {
            setState(() => _currency = 'gem');
            await _attemptPull(count);
          }
          return;
        }
      }
      _showSnack(strings.t('gacha.notEnough'));
      return;
    }

    final cubit = context.read<GachaCubit>();
    final current = cubit.state;
    if (current is GachaReady && current.pulling) return;

    final result = await cubit.pull(count: count, currency: _currency);
    if (!mounted) return;
    if (result == null) {
      final failed = cubit.state;
      if (failed is GachaReady && failed.errorMessage != null) {
        _showSnack(failed.errorMessage!);
      }
      return;
    }

    final settings = context.read<SettingsCubit>().state;
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GachaRevealDialog(
        results: result.results,
        reduceMotion: settings.reduceMotion,
        haptics: settings.haptics,
      ),
    );
    cubit.clearResult();
    if (!mounted) return;

    await context.read<CollectionCubit>().refresh();
    if (!mounted) return;
    await context.read<ProfileCubit>().refresh();
    if (!mounted) return;

    if (again == true) {
      await _attemptPull(count);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showRates() async {
    final strings = AppStrings.of(context);
    final cubit = context.read<GachaCubit>();
    final current = cubit.state;
    var rates = current is GachaReady ? current.rates : null;
    rates ??= await cubit.loadRates();
    if (!mounted) return;
    if (rates == null) {
      _showSnack(strings.t('gacha.ratesError'));
      return;
    }
    final pity = current is GachaReady ? current.pity : PityInfo.empty;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _RatesSheet(rates: rates!, pity: pity),
    );
  }
}

class _PullButton extends StatelessWidget {
  const _PullButton({
    required this.count,
    required this.currency,
    required this.price,
    required this.user,
    required this.busy,
    required this.onTap,
  });

  final int count;
  final String currency;
  final int price;
  final UserModel? user;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final isGold = currency == 'gold';
    final color = isGold ? AppTheme.gold : AppTheme.gem;
    final balance = user == null
        ? 0
        : isGold
            ? user!.gold
            : user!.gems;
    final affordable = balance >= price;

    return Clay(
      onTap: busy ? null : onTap,
      color: Color.lerp(color, Colors.white, 0.72)!,
      radius: 26,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: Column(
        children: <Widget>[
          Clay(
            width: 44,
            height: 44,
            shape: BoxShape.circle,
            color: color,
            depth: 0.6,
            child: Icon(
              isGold ? Icons.monetization_on_rounded : Icons.diamond_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            strings.t(count == 1 ? 'gacha.pull1' : 'gacha.pull10'),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.t(
              isGold ? 'gacha.costGold' : 'gacha.costGem',
              <String, String>{'amount': price.toString()},
            ),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: affordable ? color : AppTheme.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatesSheet extends StatelessWidget {
  const _RatesSheet({required this.rates, required this.pity});

  final GachaRatesData rates;
  final PityInfo pity;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              strings.t('gacha.ratesTitle'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            for (final rate in rates.rates)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.rarityColor(rate.rarity),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        strings.t(rate.rarity.i18nKey),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      '${rate.percent.toStringAsFixed(2)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 22),
            Text(
              strings.t('gacha.pityNote', <String, String>{
                'count': (pity.threshold - 1).toString(),
              }),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              strings.t('gacha.guarantee'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(strings.t('common.close')),
            ),
          ],
        ),
      ),
    );
  }
}
