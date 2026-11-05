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
import '../onboarding/how_to_play.dart';
import '../settings/settings_cubit.dart';
import 'battle_cubit.dart';
import 'battle_fx.dart';
import 'battle_moves.dart';
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
    final reduceMotion = context.select<SettingsCubit, bool>(
      (cubit) => cubit.state.reduceMotion,
    );
    final tableTheme = context.select<SettingsCubit, TableTheme>(
      (cubit) => cubit.state.tableTheme,
    );

    return BlocBuilder<BattleCubit, BattleSessionState>(
      builder: (context, state) {
        final battle = state.battle;
        final isPlayerTurn = battle.activeSide == BattleSide.player;
        final interactive = isPlayerTurn && !state.busy && !battle.isTerminal;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: <Widget>[
                Text(strings.t('battle.arena')),
                const SizedBox(width: 8),
                ClayPill(
                  label: strings.t('battle.difficulty.${start.difficulty}'),
                  color: AppTheme.primary,
                  fontSize: 10,
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
                tooltip: strings.t('help.title'),
                onPressed: () => showHowToPlay(context),
                icon: const Icon(Icons.help_outline_rounded),
              ),
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
                  BattleFxHost(
                    enabled: !reduceMotion,
                    child: _BattleFxBridge(
                      child: Column(
                        children: <Widget>[
                          _SideHeader(
                            side: BattleSide.bot,
                            state: battle.bot,
                            difficulty: start.difficulty,
                            strings: strings,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
                              child: ArenaTable(
                                theme: tableTheme,
                                child: Column(
                                  children: <Widget>[
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
                                      hint: _nextStepHint(
                                        context.read<BattleCubit>(),
                                        state,
                                        strings,
                                      ),
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
                                  ],
                                ),
                              ),
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
                    ),
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
      _showInfo(context, _cantPlayReason(context, cubit, handIndex));
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context).t('move.notReady')),
            duration: const Duration(seconds: 2),
          ),
        );
      return;
    }

    final strings = AppStrings.of(context);
    final moves = movesFor(unit.card, strings, attackOverride: unit.attack);
    bool enabledFor(MoveKind kind) => switch (kind) {
          MoveKind.strike => attackOptions.isNotEmpty,
          MoveKind.ability => abilityOptions.isNotEmpty,
          MoveKind.guard => guard != null,
        };
    final choice = await showModalBottomSheet<_UnitAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Clay(
                    width: 66,
                    height: 66,
                    radius: 22,
                    pressed: true,
                    color: AppTheme.elementPastel(unit.card.element),
                    child: CardArtwork(card: unit.card, borderRadius: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          unit.card.name,
                          style: Theme.of(sheetContext)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          strings.t('move.title'),
                          style: Theme.of(sheetContext).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        HpBar(
                          current: math.max(0, unit.hp),
                          max: unit.maxHp,
                          height: 8,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 14,
                children: <Widget>[
                  for (final move in moves)
                    SkillOrb(
                      move: move,
                      enabled: enabledFor(move.kind),
                      onTap: () => Navigator.of(
                        sheetContext,
                      ).pop(_actionOf(move.kind)),
                    ),
                ],
              ),
            ],
          ),
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
                  id == null ? Icons.person_rounded : Icons.gps_fixed_rounded,
                  color: id == null ? AppTheme.danger : AppTheme.accent,
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

  /// Langkah berikutnya yang disarankan, dari aksi legal engine saat ini.
  String? _nextStepHint(
    BattleCubit cubit,
    BattleSessionState state,
    AppStrings strings,
  ) {
    final battle = state.battle;
    if (battle.isTerminal) return null;
    if (battle.activeSide != BattleSide.player || state.busy) {
      return strings.t('battle.hint.botTurn');
    }
    for (var i = 0; i < battle.player.hand.length; i++) {
      if (cubit.playOptionsForHand(i).isNotEmpty) {
        return strings.t('battle.hint.play');
      }
    }
    for (final unit in battle.player.board) {
      if (cubit.attackOptionsFor(unit.instanceId).isNotEmpty ||
          cubit.abilityOptionsFor(unit.instanceId).isNotEmpty) {
        return strings.t('battle.hint.act');
      }
    }
    return strings.t('battle.hint.endTurn');
  }

  /// Penjelasan kenapa kartu di tangan tidak bisa dimainkan.
  String _cantPlayReason(
    BuildContext context,
    BattleCubit cubit,
    int handIndex,
  ) {
    final strings = AppStrings.of(context);
    final battle = cubit.battle;
    if (battle.activeSide != BattleSide.player) {
      return strings.t('battle.cantPlay.turn');
    }
    final me = battle.player;
    if (handIndex < 0 || handIndex >= me.hand.length) {
      return strings.t('battle.noActions');
    }
    final card = me.hand[handIndex];
    if (card.cost > me.energy) {
      return strings.t('battle.cantPlay.energy', <String, String>{
        'cost': '${card.cost}',
        'energy': '${me.energy}',
      });
    }
    if (card.isUnit && me.board.length >= battle.config.boardSlots) {
      return strings.t('battle.cantPlay.board', <String, String>{
        'slots': '${battle.config.boardSlots}',
      });
    }
    return strings.t('battle.cantPlay.target');
  }

  void _showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
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
                  )
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
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

_UnitAction _actionOf(MoveKind kind) => switch (kind) {
      MoveKind.strike => _UnitAction.attack,
      MoveKind.ability => _UnitAction.ability,
      MoveKind.guard => _UnitAction.guard,
    };

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
    final color = _isBot ? AppTheme.danger : AppTheme.success;

    return FxAnchor(
      id: faceAnchorId(side),
      borderRadius: 18,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
        child: Clay(
          radius: 22,
          depth: 0.6,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Clay(
                    width: 32,
                    height: 32,
                    shape: BoxShape.circle,
                    color: color,
                    depth: 0.5,
                    child: Icon(
                      _isBot ? Icons.smart_toy_rounded : Icons.person_rounded,
                      size: 17,
                      color: Colors.white,
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
                              color: AppTheme.inkSoft,
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
                    icon: _isBot ? Icons.style_rounded : Icons.style_outlined,
                    label: _isBot
                        ? '${state.hand.length}'
                        : strings.t('battle.hand', <String, String>{
                            'count': state.hand.length.toString(),
                          }),
                    color: AppTheme.inkSoft,
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
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClayPill(label: label, icon: icon, color: color, fontSize: 10);
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
                        ? FxAnchor(
                            key: ValueKey<String>(units[index].instanceId),
                            id: units[index].instanceId,
                            child: _UnitTile(
                              unit: units[index],
                              battle: battle,
                              isPlayer: isPlayer,
                              interactive: interactive,
                              onTap: onTap,
                              strings: strings,
                            ),
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
    required this.isPlayer,
    required this.interactive,
    required this.onTap,
    required this.strings,
  });

  final BattleUnit unit;
  final BattleState battle;
  final bool isPlayer;
  final bool interactive;
  final ValueChanged<BattleUnit>? onTap;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final canAct = interactive && !unit.hasActed && !unit.isFrozen;
    final body = AppTheme.elementPastel(unit.card.element);
    final ring = unit.stance == Stance.guarding
        ? AppTheme.info
        : canAct
            ? AppTheme.primary
            : null;
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
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: unit.hasActed ? 0.6 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: EdgeInsets.all(ring == null ? 0 : 2.5),
            decoration: BoxDecoration(
              color: ring ?? Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Clay(
              color: body,
              radius: 16,
              depth: 0.55,
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        Clay(
                          color: Clay.shadeOf(body, 0.04),
                          radius: 12,
                          pressed: true,
                          depth: 0.4,
                          child: CardArtwork(
                            card: unit.card,
                            borderRadius: 12,
                            mirrored: !isPlayer,
                          ),
                        ),
                        if (unit.isFrozen)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppTheme.info.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.ac_unit_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ),
                        Positioned(
                          top: 2,
                          left: 2,
                          child: _StatBadge(
                            icon: Icons.flash_on_rounded,
                            value: unit.attack,
                            color: AppTheme.attack,
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: _StatBadge(
                            icon: Icons.favorite_rounded,
                            value: math.max(0, unit.hp),
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    unit.card.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  HpBar(
                    current: math.max(0, unit.hp),
                    max: unit.maxHp,
                    height: 5,
                  ),
                  if (stanceLabel != null ||
                      unit.statuses.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 3),
                    Row(
                      children: <Widget>[
                        if (stanceLabel != null)
                          Flexible(
                            child: Text(
                              stanceLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 7.5,
                                fontWeight: FontWeight.w800,
                                color: unit.stance == Stance.guarding
                                    ? AppTheme.info
                                    : AppTheme.warning,
                              ),
                            ),
                          ),
                        for (final status in unit.statuses.take(2))
                          Padding(
                            padding: const EdgeInsets.only(left: 3),
                            child: _StatusDot(status: status),
                          ),
                      ],
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
    return ClayPill(label: '$value', icon: icon, color: color, fontSize: 8.5);
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final BattleStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (status.kind) {
      BattleStatusKind.burn => (AppTheme.attack, 'B'),
      BattleStatusKind.freeze => (AppTheme.info, 'F'),
      BattleStatusKind.shield => (AppTheme.accent, 'S'),
      BattleStatusKind.rally => (AppTheme.primary, 'R'),
    };

    return Container(
      width: 13,
      height: 13,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 7,
          fontWeight: FontWeight.w900,
          color: Colors.white,
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
    // Tembus pandang agar motif meja tetap terlihat di bawah slot.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.55),
          width: 2,
        ),
      ),
      child: Center(
        child: Icon(
          isPlayer ? Icons.add_rounded : Icons.remove_rounded,
          size: 22,
          color: Colors.white.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

class _TurnStrip extends StatelessWidget {
  const _TurnStrip({
    required this.battle,
    required this.busy,
    required this.strings,
    this.hint,
  });

  final BattleState battle;
  final bool busy;
  final AppStrings strings;

  /// Petunjuk langkah berikutnya untuk pemain (null = pakai label giliran).
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final isPlayer = battle.activeSide == BattleSide.player;
    final label = hint ??
        (battle.isTerminal
            ? strings.t('common.done')
            : isPlayer
                ? strings.t('battle.yourTurn')
                : busy
                    ? strings.t('battle.waitBot')
                    : strings.t('battle.botTurn'));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Clay(
        radius: 999,
        depth: 0.5,
        padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
        child: Row(
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPlayer ? AppTheme.primary : AppTheme.danger,
              ),
              child: Icon(
                isPlayer ? Icons.bolt_rounded : Icons.smart_toy_rounded,
                size: 15,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  label,
                  key: ValueKey<String>(label),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
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
                color: AppTheme.inkSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu di tangan disusun seperti kipas: miring, saling menumpuk, dan
/// kartu yang bisa dimainkan sedikit terangkat.
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

  static const double _cardWidth = 84;
  static const double _height = 150;

  @override
  Widget build(BuildContext context) {
    final hand = battle.player.hand;
    if (hand.isEmpty) {
      return SizedBox(
        height: _height * 0.6,
        child: Center(
          child: Text(
            strings.t('battle.noActions'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    return SizedBox(
      height: _height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final n = hand.length;
          final width = constraints.maxWidth;
          final spread = n == 1
              ? 0.0
              : math.min(64.0, (width - _cardWidth - 28) / (n - 1));
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              for (var i = 0; i < n; i++)
                _fanned(
                  index: i,
                  count: n,
                  spread: spread,
                  width: width,
                  card: hand[i],
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _fanned({
    required int index,
    required int count,
    required double spread,
    required double width,
    required CardModel card,
  }) {
    final t = index - (count - 1) / 2;
    final playable = interactive && card.cost <= battle.player.energy;
    final angle = (t * 0.085).clamp(-0.35, 0.35);
    final lift = playable ? 12.0 : 0.0;
    return AnimatedPositioned(
      key: ValueKey<int>(index),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      left: width / 2 + t * spread - _cardWidth / 2,
      top: 18 + t * t * 3.2 - lift,
      width: _cardWidth,
      child: AnimatedRotation(
        duration: const Duration(milliseconds: 260),
        turns: angle / (2 * math.pi),
        alignment: Alignment.bottomCenter,
        child: _HandCard(
          card: card,
          playable: playable,
          onTap: interactive ? () => onCardTap(index) : null,
        ),
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
    final card = CardTile(card: this.card, onTap: onTap, animate: playable);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: playable ? 1 : 0.55,
      child: playable
          ? DecoratedBox(
              // Cahaya di sekeliling kartu yang bisa dimainkan.
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppTheme.warning.withValues(alpha: 0.75),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: card,
            )
          : card,
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
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Row(
        children: <Widget>[
          Expanded(
            child: ClayButton(
              label: strings.t('battle.endTurn'),
              icon: Icons.skip_next_rounded,
              onPressed: onEndTurn,
              expand: true,
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: strings.t('battle.concede'),
            child: Opacity(
              opacity: onConcede == null ? 0.5 : 1,
              child: Clay(
                width: 52,
                height: 52,
                shape: BoxShape.circle,
                depth: 0.7,
                onTap: onConcede,
                child: const Icon(
                  Icons.flag_rounded,
                  size: 20,
                  color: AppTheme.danger,
                ),
              ),
            ),
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
      'win' => AppTheme.success,
      'loss' => AppTheme.danger,
      _ => AppTheme.warning,
    };

    return ColoredBox(
      color: AppTheme.ink.withValues(alpha: 0.45),
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
                    child: Clay(
                      width: 72,
                      height: 72,
                      shape: BoxShape.circle,
                      color: color,
                      child: Icon(
                        outcome == 'win'
                            ? Icons.emoji_events_rounded
                            : outcome == 'loss'
                                ? Icons.sentiment_dissatisfied_rounded
                                : Icons.balance_rounded,
                        color: Colors.white,
                        size: 34,
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
                        color: AppTheme.danger,
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
                        color: AppTheme.success,
                      ),
                    ],
                    if (result.rewards.capped) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        strings.t('battle.capped'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.warning,
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
                          color: AppTheme.primary,
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
    return Clay(
      radius: 18,
      depth: 0.5,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: <Widget>[
          Clay(
            width: 30,
            height: 30,
            shape: BoxShape.circle,
            color: color,
            depth: 0.4,
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
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
        ],
      ),
    );
  }
}

/// Meneruskan event baru dari [BattleCubit] ke [BattleFxHost]. Listener
/// berjalan sebelum frame berikut, sehingga posisi unit yang gugur masih
/// tersedia untuk efeknya.
class _BattleFxBridge extends StatefulWidget {
  const _BattleFxBridge({required this.child});

  final Widget child;

  @override
  State<_BattleFxBridge> createState() => _BattleFxBridgeState();
}

class _BattleFxBridgeState extends State<_BattleFxBridge> {
  late BattleState _last = context.read<BattleCubit>().state.battle;

  void _onState(BuildContext context, BattleSessionState state) {
    final previous = _last;
    final next = state.battle;
    _last = next;
    if (identical(previous, next)) return;
    final seen = previous.log.length;
    if (next.log.length <= seen) return;

    final cardsByUnit = <String, CardModel>{};
    final cardsById = <String, CardModel>{};
    for (final battle in <BattleState>[previous, next]) {
      for (final side in <BattlePlayerState>[battle.player, battle.bot]) {
        for (final unit in side.board) {
          cardsByUnit[unit.instanceId] = unit.card;
          cardsById[unit.card.id] = unit.card;
        }
        for (final card in side.discard) {
          cardsById[card.id] = card;
        }
      }
    }

    final strings = AppStrings.of(context);
    BattleFxHost.read(context)?.play(
      next.log.sublist(seen),
      cardsByUnit: cardsByUnit,
      cardsById: cardsById,
      labelFor: (cue) {
        final unitCard =
            cue.sourceUnitId == null ? null : cardsByUnit[cue.sourceUnitId];
        return switch (cue.kind) {
          FxCueKind.strike when unitCard != null => strikeNameOf(
              unitCard,
              strings,
            ),
          FxCueKind.bolt when unitCard != null => unitCard.ability?.name,
          FxCueKind.bolt => cardsById[cue.sourceCardId]?.name,
          _ => null,
        };
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BattleCubit, BattleSessionState>(
      listener: _onState,
      child: widget.child,
    );
  }
}
