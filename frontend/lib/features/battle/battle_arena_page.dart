import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_scope.dart';
import '../../core/config/game_config.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../domain/models/battle_api_models.dart';
import '../../domain/models/card_model.dart';
import '../auth/auth_cubit.dart';
import 'battle_cubit.dart';
import 'battle_setup_page.dart';
import 'domain/battle_models.dart';

class BattleArenaPage extends StatelessWidget {
  const BattleArenaPage({super.key, required this.start});

  final BattleStartData start;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final auth = context.read<AuthCubit>();

    return BlocProvider<BattleCubit>(
      create: (_) => BattleCubit(
        start: start,
        repository: scope.repositories.battle,
        auth: auth,
      ),
      child: _ArenaView(start: start),
    );
  }
}

class _ArenaView extends StatelessWidget {
  const _ArenaView({required this.start});

  final BattleStartData start;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return BlocBuilder<BattleCubit, BattleSessionState>(
      builder: (context, state) {
        final battle = state.battle;
        final isPlayerTurn = battle.activeSide == BattleSide.player;
        final interactive =
            isPlayerTurn && !state.busy && !battle.isTerminal;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: <Widget>[
                Text(strings.t('battle.arena')),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    strings.t('battle.difficulty.${start.difficulty}'),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFC4B5FD),
                    ),
                  ),
                ),
              ],
            ),
            leading: IconButton(
              tooltip: strings.t('battle.concede'),
              onPressed: () => _confirmConcede(context, state),
              icon: const Icon(Icons.close_rounded),
            ),
            actions: <Widget>[
              IconButton(
                tooltip: strings.t('battle.log'),
                onPressed: () => _showLog(context, battle, strings),
                icon: const Icon(Icons.receipt_long_rounded),
              ),
              IconButton(
                tooltip: strings.t('battle.concede'),
                onPressed: battle.isTerminal
                    ? null
                    : () => _confirmConcede(context, state),
                icon: const Icon(Icons.flag_outlined),
              ),
            ],
          ),
          body: AppBackground(
            child: SafeArea(
              top: false,
              child: Stack(
                children: <Widget>[
                  Column(
                    children: <Widget>[
                      _SideHeader(
                        side: BattleSide.bot,
                        state: battle.bot,
                        difficulty: start.difficulty,
                        strings: strings,
                      ),
                      Expanded(
                        flex: 3,
                        child: _BoardView(
                          units: battle.bot.board,
                          battle: battle,
                          isPlayer: false,
                          interactive: false,
                          showSlots: true,
                          onTap: null,
                          strings: strings,
                        ),
                      ),
                      _TurnStrip(
                        battle: battle,
                        busy: state.busy,
                        strings: strings,
                      ),
                      Expanded(
                        flex: 3,
                        child: _BoardView(
                          units: battle.player.board,
                          battle: battle,
                          isPlayer: true,
                          interactive: interactive,
                          showSlots: true,
                          onTap: interactive
                              ? (unit) => _openUnitActions(
                                  context,
                                  context.read<BattleCubit>(),
                                  unit,
                                )
                              : null,
                          strings: strings,
                        ),
                      ),
                      _SideHeader(
                        side: BattleSide.player,
                        state: battle.player,
                        strings: strings,
                      ),
                      _HandView(
                        battle: battle,
                        interactive: interactive,
                        strings: strings,
                        onCardTap: (index) => _playHandCard(
                          context,
                          context.read<BattleCubit>(),
                          index,
                        ),
                      ),
                      _BottomBar(
                        battle: battle,
                        busy: state.busy,
                        strings: strings,
                        onEndTurn: interactive
                            ? () => _endTurn(
                                context,
                                context.read<BattleCubit>(),
                              )
                            : null,
                        onConcede: battle.isTerminal
                            ? null
                            : () => _confirmConcede(context, state),
                      ),
                    ],
                  ),
                  if (battle.isTerminal)
                    Positioned.fill(
                      child: _ResultOverlay(
                        state: state,
                        start: start,
                        strings: strings,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _endTurn(BuildContext context, BattleCubit cubit) async {
    final error = cubit.endTurn();
    _reportError(context, error);
  }

  Future<void> _playHandCard(
    BuildContext context,
    BattleCubit cubit,
    int handIndex,
  ) async {
    final options = cubit.playOptionsForHand(handIndex);
    if (options.isEmpty) {
      _reportError(context, AppStrings.of(context).t('battle.noActions'));
      return;
    }

    var action = options.first;
    if (options.length > 1) {
      final battle = cubit.battle;
      final picked = await _chooseTarget(
        context: context,
        battle: battle,
        targetIds: options.map((option) => option.targetId).toList(),
      );
      if (!context.mounted || picked == null) return;
      action = options.firstWhere(
        (option) => option.targetId == picked.id,
        orElse: () => options.first,
      );
    }

    _reportError(context, cubit.perform(action));
  }

  Future<void> _openUnitActions(
    BuildContext context,
    BattleCubit cubit,
    BattleUnit unit,
  ) async {
    final attackOptions = cubit.attackOptionsFor(unit.instanceId);
    final abilityOptions = cubit.abilityOptionsFor(unit.instanceId);
    final guard = cubit.guardActionFor(unit.instanceId);

    if (attackOptions.isEmpty && abilityOptions.isEmpty && guard == null) {
      return;
    }

    final strings = AppStrings.of(context);
    final choice = await showModalBottomSheet<_UnitAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                unit.card.name,
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (attackOptions.isNotEmpty)
              ListTile(
                leading: const Icon(
                  Icons.flash_on_rounded,
                  color: Color(0xFFF97316),
                ),
                title: Text(
                  strings.t('battle.attackWith', <String, String>{
                    'name': unit.card.name,
                  }),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_UnitAction.attack),
              ),
            if (abilityOptions.isNotEmpty && unit.card.ability != null)
              ListTile(
                leading: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppTheme.accent,
                ),
                title: Text(unit.card.ability!.name),
                subtitle: Text(
                  strings.t('card.abilityCost', <String, String>{
                    'cost': unit.card.ability!.cost.toString(),
                  }),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_UnitAction.ability),
              ),
            if (guard != null)
              ListTile(
                leading: const Icon(
                  Icons.shield_rounded,
                  color: Color(0xFF60A5FA),
                ),
                title: Text(
                  strings.t('battle.guardWith', <String, String>{
                    'name': unit.card.name,
                  }),
                ),
                onTap: () => Navigator.of(sheetContext).pop(_UnitAction.guard),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;

    switch (choice) {
      case _UnitAction.attack:
        await _performAttack(context, cubit, unit, attackOptions);
        break;
      case _UnitAction.ability:
        await _performAbility(context, cubit, unit, abilityOptions);
        break;
      case _UnitAction.guard:
        final guardNow = cubit.guardActionFor(unit.instanceId);
        if (guardNow != null) {
          _reportError(context, cubit.perform(guardNow));
        }
        break;
    }
  }

  Future<void> _performAttack(
    BuildContext context,
    BattleCubit cubit,
    BattleUnit unit,
    List<AttackAction> options,
  ) async {
    if (options.isEmpty) return;
    var action = options.first;
    if (options.length > 1) {
      final picked = await _chooseTarget(
        context: context,
        battle: cubit.battle,
        targetIds: options.map((option) => option.targetId).toList(),
      );
      if (!context.mounted || picked == null) return;
      action = options.firstWhere(
        (option) => option.targetId == picked.id,
        orElse: () => options.first,
      );
    }
    _reportError(context, cubit.perform(action));
  }

  Future<void> _performAbility(
    BuildContext context,
    BattleCubit cubit,
    BattleUnit unit,
    List<UseAbilityAction> options,
  ) async {
    if (options.isEmpty) return;
    var action = options.first;
    if (options.length > 1) {
      final picked = await _chooseTarget(
        context: context,
        battle: cubit.battle,
        targetIds: options.map((option) => option.targetId).toList(),
      );
      if (!context.mounted || picked == null) return;
      action = options.firstWhere(
        (option) => option.targetId == picked.id,
        orElse: () => options.first,
      );
    }
    _reportError(context, cubit.perform(action));
  }

  Future<_TargetPick?> _chooseTarget({
    required BuildContext context,
    required BattleState battle,
    required List<String?> targetIds,
  }) async {
    final strings = AppStrings.of(context);
    final unique = <String?>[];
    for (final id in targetIds) {
      if (!unique.contains(id)) unique.add(id);
    }

    return showModalBottomSheet<_TargetPick>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                strings.t('battle.targetTitle'),
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            for (final id in unique)
              ListTile(
                leading: Icon(
                  id == null
                      ? Icons.person_rounded
                      : Icons.gps_fixed_rounded,
                  color: id == null
                      ? const Color(0xFFF87171)
                      : AppTheme.accent,
                ),
                title: Text(_describeTarget(id, battle, strings)),
                onTap: () => Navigator.of(sheetContext).pop(_TargetPick(id)),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _describeTarget(String? id, BattleState battle, AppStrings strings) {
    if (id == null) return strings.t('battle.faceTarget');
    for (final unit in <BattleUnit>[
      ...battle.bot.board,
      ...battle.player.board,
    ]) {
      if (unit.instanceId == id) {
        return '${unit.card.name} · ${unit.attack}/${unit.hp}';
      }
    }
    return id;
  }

  void _reportError(BuildContext context, String? error) {
    if (error == null || !context.mounted) return;
    final strings = AppStrings.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            strings.t('battle.illegal', <String, String>{'reason': error}),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _confirmConcede(
    BuildContext context,
    BattleSessionState state,
  ) async {
    if (state.battle.isTerminal) {
      return;
    }
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.t('battle.confirmConcedeTitle')),
        content: Text(strings.t('battle.concedeConfirm')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.t('battle.concede')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    context.read<BattleCubit>().concede();
  }

  void _showLog(BuildContext context, BattleState battle, AppStrings strings) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  strings.t('battle.log'),
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: battle.log.isEmpty
                    ? Center(child: Text(strings.t('battle.logEmpty')))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: battle.log.length,
                        itemBuilder: (context, index) {
                          final event =
                              battle.log[battle.log.length - 1 - index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  width: 26,
                                  height: 26,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceHigh,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    event.turn.toString(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    event.message,
                                    style: const TextStyle(fontSize: 12.5),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _UnitAction { attack, ability, guard }

class _TargetPick {
  const _TargetPick(this.id);

  final String? id;
}

class _SideHeader extends StatelessWidget {
  const _SideHeader({
    required this.side,
    required this.state,
    required this.strings,
    this.difficulty,
  });

  final BattleSide side;
  final BattlePlayerState state;
  final AppStrings strings;
  final String? difficulty;

  bool get _isBot => side == BattleSide.bot;

  @override
  Widget build(BuildContext context) {
    final color = _isBot
        ? const Color(0xFFF87171)
        : const Color(0xFF34D399);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.16),
                ),
                child: Icon(
                  _isBot
                      ? Icons.smart_toy_rounded
                      : Icons.person_rounded,
                  size: 17,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        _isBot
                            ? strings.t('battle.opponent')
                            : strings.t('battle.you'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (_isBot && difficulty != null) ...<Widget>[
                      const SizedBox(width: 6),
                      Text(
                        strings.t('battle.difficulty.$difficulty'),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF9AA3B2),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _Pill(
                icon: Icons.bolt_rounded,
                label: '${state.energy}/${state.maxEnergy}',
                color: AppTheme.accent,
              ),
              const SizedBox(width: 6),
              _Pill(
                icon: _isBot
                    ? Icons.style_rounded
                    : Icons.style_outlined,
                label: _isBot
                    ? '${state.hand.length}'
                    : strings.t('battle.hand', <String, String>{
                        'count': state.hand.length.toString(),
                      }),
                color: const Color(0xFF9AA3B2),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: HpBar(
                  current: state.hp,
                  max: state.maxHp,
                  color: color,
                  height: 9,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                strings.t('battle.hpValue', <String, String>{
                  'current': math.max(0, state.hp).toString(),
                  'max': state.maxHp.toString(),
                }),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardView extends StatelessWidget {
  const _BoardView({
    required this.units,
    required this.battle,
    required this.isPlayer,
    required this.interactive,
    required this.showSlots,
    required this.onTap,
    required this.strings,
  });

  final List<BattleUnit> units;
  final BattleState battle;
  final bool isPlayer;
  final bool interactive;
  final bool showSlots;
  final ValueChanged<BattleUnit>? onTap;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final slotCount = battle.config.boardSlots;
        final horizontal = (slotCount - 1) * 8.0 + 16;
        final widthFromHeight = constraints.maxHeight * (2 / 3);
        final widthFromWidth = (constraints.maxWidth - horizontal) / slotCount;
        final slotWidth = math.min(widthFromHeight, widthFromWidth);
        final slotHeight = slotWidth * 1.5;

        return Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (var index = 0; index < slotCount; index++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SizedBox(
                    width: slotWidth,
                    height: slotHeight,
                    child: index < units.length
                        ? _UnitTile(
                            unit: units[index],
                            battle: battle,
                            interactive: interactive,
                            onTap: onTap,
                            strings: strings,
                          )
                        : (showSlots
                              ? _EmptySlot(isPlayer: isPlayer)
                              : const SizedBox.shrink()),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _UnitTile extends StatelessWidget {
  const _UnitTile({
    required this.unit,
    required this.battle,
    required this.interactive,
    required this.onTap,
    required this.strings,
  });

  final BattleUnit unit;
  final BattleState battle;
  final bool interactive;
  final ValueChanged<BattleUnit>? onTap;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final rarity = AppTheme.rarityColor(unit.card.rarity);
    final stanceLabel = switch (unit.stance) {
      Stance.ready => null,
      Stance.tapped => strings.t('battle.tapped'),
      Stance.guarding => strings.t('battle.guarding'),
    };

    return Semantics(
      button: interactive,
      label: '${unit.card.name} ${unit.attack}/${unit.hp}',
      child: GestureDetector(
        onTap: interactive && onTap != null ? () => onTap!(unit) : null,
        child: Opacity(
          opacity: unit.hasActed ? 0.62 : 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: unit.stance == Stance.guarding
                    ? const Color(0xFF60A5FA)
                    : rarity.withValues(alpha: 0.7),
                width: unit.stance == Stance.guarding ? 1.8 : 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: rarity.withValues(alpha: 0.16),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  CardArtwork(card: unit.card, borderRadius: 11),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Color(0x00000000),
                          Color(0x44000000),
                          Color(0xF2000000),
                        ],
                        stops: <double>[0.3, 0.6, 1],
                      ),
                    ),
                  ),
                  if (unit.isFrozen)
                    Container(
                      color: const Color(0x6638BDF8),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.ac_unit_rounded,
                        color: Color(0xFFE0F2FE),
                        size: 26,
                      ),
                    ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: _StatBadge(
                      icon: Icons.flash_on_rounded,
                      value: unit.attack,
                      color: const Color(0xFFF97316),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: _StatBadge(
                      icon: Icons.favorite_rounded,
                      value: math.max(0, unit.hp),
                      color: const Color(0xFF34D399),
                    ),
                  ),
                  Positioned(
                    left: 5,
                    right: 5,
                    bottom: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          unit.card.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 2),
                        SizedBox(
                          height: 3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: unit.maxHp <= 0
                                  ? 0
                                  : (unit.hp / unit.maxHp).clamp(0.0, 1.0),
                              minHeight: 3,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF34D399),
                              ),
                            ),
                          ),
                        ),
                        if (stanceLabel != null) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            stanceLabel,
                            style: TextStyle(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w700,
                              color: unit.stance == Stance.guarding
                                  ? const Color(0xFF93C5FD)
                                  : const Color(0xFFFBBF24),
                            ),
                          ),
                        ],
                        if (unit.statuses.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 3,
                            runSpacing: 2,
                            children: unit.statuses
                                .take(2)
                                .map(
                                  (status) => _StatusDot(status: status),
                                )
                                .toList(growable: false),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 2),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final BattleStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (status.kind) {
      BattleStatusKind.burn => (const Color(0xFFF97316), 'B'),
      BattleStatusKind.freeze => (const Color(0xFF38BDF8), 'F'),
      BattleStatusKind.shield => (const Color(0xFF60A5FA), 'S'),
      BattleStatusKind.rally => (const Color(0xFFC084FC), 'R'),
    };

    return Container(
      width: 12,
      height: 12,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.28),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 7,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.isPlayer});

  final bool isPlayer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        color: Colors.white.withValues(alpha: 0.015),
      ),
      alignment: Alignment.center,
      child: Icon(
        isPlayer ? Icons.add_rounded : Icons.remove_rounded,
        size: 18,
        color: Colors.white.withValues(alpha: 0.12),
      ),
    );
  }
}

class _TurnStrip extends StatelessWidget {
  const _TurnStrip({
    required this.battle,
    required this.busy,
    required this.strings,
  });

  final BattleState battle;
  final bool busy;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final isPlayer = battle.activeSide == BattleSide.player;
    final label = battle.isTerminal
        ? strings.t('common.done')
        : isPlayer
        ? strings.t('battle.yourTurn')
        : busy
        ? strings.t('battle.waitBot')
        : strings.t('battle.botTurn');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPlayer
                  ? AppTheme.primary.withValues(alpha: 0.2)
                  : const Color(0xFFF87171).withValues(alpha: 0.16),
            ),
            child: Icon(
              isPlayer ? Icons.bolt_rounded : Icons.smart_toy_rounded,
              size: 15,
              color: isPlayer ? AppTheme.accent : const Color(0xFFFCA5A5),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (busy) ...<Widget>[
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.8),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            strings.t('battle.turn', <String, String>{
              'turn': battle.turnNumber.toString(),
            }),
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF9AA3B2),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HandView extends StatelessWidget {
  const _HandView({
    required this.battle,
    required this.interactive,
    required this.strings,
    required this.onCardTap,
  });

  final BattleState battle;
  final bool interactive;
  final AppStrings strings;
  final ValueChanged<int> onCardTap;

  @override
  Widget build(BuildContext context) {
    final hand = battle.player.hand;

    return SizedBox(
      height: 128,
      child: hand.isEmpty
          ? Center(
              child: Text(
                strings.t('battle.noActions'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              itemCount: hand.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final card = hand[index];
                final playable =
                    interactive && card.cost <= battle.player.energy;
                return _HandCard(
                  card: card,
                  playable: playable,
                  onTap: playable ? () => onCardTap(index) : null,
                );
              },
            ),
    );
  }
}

class _HandCard extends StatelessWidget {
  const _HandCard({required this.card, required this.playable, this.onTap});

  final CardModel card;
  final bool playable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rarity = AppTheme.rarityColor(card.rarity);

    return Semantics(
      button: playable,
      label: card.name,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: playable ? 1 : 0.42,
          child: SizedBox(
            width: 82,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: rarity.withValues(alpha: 0.7),
                  width: 1.2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    CardArtwork(card: card, borderRadius: 11),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Color(0x00000000),
                            Color(0x55000000),
                            Color(0xEE000000),
                          ],
                          stops: <double>[0.3, 0.6, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 5,
                      left: 5,
                      child: Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Color(0xE611827F),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          card.cost.toString(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 5,
                      right: 5,
                      bottom: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            card.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            card.isUnit
                                ? '${card.attack ?? 0}/${card.hp ?? 0}'
                                : card.ability?.type.toUpperCase() ?? 'SPELL',
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB6C2D2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.battle,
    required this.busy,
    required this.strings,
    this.onEndTurn,
    this.onConcede,
  });

  final BattleState battle;
  final bool busy;
  final AppStrings strings;
  final VoidCallback? onEndTurn;
  final VoidCallback? onConcede;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: FilledButton.icon(
              onPressed: onEndTurn,
              icon: const Icon(Icons.skip_next_rounded, size: 18),
              label: Text(strings.t('battle.endTurn')),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            tooltip: strings.t('battle.concede'),
            onPressed: onConcede,
            icon: const Icon(Icons.flag_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({
    required this.state,
    required this.start,
    required this.strings,
  });

  final BattleSessionState state;
  final BattleStartData start;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final battle = state.battle;
    final result = state.result;
    final outcome = result?.outcome ?? battle.outcome?.name ?? 'draw';
    final title = switch (outcome) {
      'win' => strings.t('battle.victory'),
      'loss' => strings.t('battle.defeat'),
      _ => strings.t('battle.draw'),
    };
    final color = switch (outcome) {
      'win' => const Color(0xFF4ADE80),
      'loss' => const Color(0xFFF87171),
      _ => const Color(0xFFFBBF24),
    };

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.68),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Panel(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.16),
                        border: Border.all(
                          color: color.withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        outcome == 'win'
                            ? Icons.emoji_events_rounded
                            : outcome == 'loss'
                            ? Icons.sentiment_dissatisfied_rounded
                            : Icons.balance_rounded,
                        color: color,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    strings.t('battle.turn', <String, String>{
                      'turn': battle.turnNumber.toString(),
                    }),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  if (state.submitting) ...<Widget>[
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 12),
                    Text(
                      strings.t('battle.submitting'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ] else if (state.submitError != null) ...<Widget>[
                    Text(
                      strings.t('battle.resultFailed', <String, String>{
                        'message': state.submitError!,
                      }),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFFFCA5A5),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () =>
                          context.read<BattleCubit>().retrySubmit(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(strings.t('battle.retrySubmit')),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _goHome(context),
                      child: Text(strings.t('battle.home')),
                    ),
                  ] else if (result != null) ...<Widget>[
                    _RewardRow(
                      label: strings.t('battle.rewardGold', <String, String>{
                        'gold': result.rewards.gold.toString(),
                      }),
                      icon: Icons.monetization_on_rounded,
                      color: AppTheme.gold,
                    ),
                    const SizedBox(height: 8),
                    _RewardRow(
                      label: strings.t('battle.rewardXp', <String, String>{
                        'xp': result.rewards.xp.toString(),
                      }),
                      icon: Icons.trending_up_rounded,
                      color: AppTheme.accent,
                    ),
                    if (result.rewards.firstWinBonus) ...<Widget>[
                      const SizedBox(height: 8),
                      _RewardRow(
                        label: strings.t(
                          'battle.firstWin',
                          <String, String>{
                            'gold': GameConfig.firstWinBonusGold.toString(),
                          },
                        ),
                        icon: Icons.star_rounded,
                        color: const Color(0xFF4ADE80),
                      ),
                    ],
                    if (result.rewards.capped) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        strings.t('battle.capped'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFFBBF24),
                        ),
                      ),
                    ],
                    if (result.levelUp.levelsGained > 0 &&
                        result.user != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        strings.t('battle.levelUp', <String, String>{
                          'level': result.user!.level.toString(),
                        }),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFC4B5FD),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () => _rematch(context),
                            icon: const Icon(
                              Icons.replay_rounded,
                              size: 18,
                            ),
                            label: Text(strings.t('battle.rematch')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _goHome(context),
                            icon: const Icon(
                              Icons.home_rounded,
                              size: 18,
                            ),
                            label: Text(strings.t('battle.home')),
                          ),
                        ),
                      ],
                    ),
                  ] else ...<Widget>[
                    const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _rematch(BuildContext context) {
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => BattleSetupPage(initialDifficulty: start.difficulty),
      ),
    );
  }

  void _goHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
