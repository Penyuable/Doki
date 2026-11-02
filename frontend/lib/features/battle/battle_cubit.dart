import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_exception.dart';
import '../../data/repositories/battle_repository.dart';
import '../../domain/models/battle_api_models.dart';
import '../auth/auth_cubit.dart';
import 'domain/battle_engine.dart';
import 'domain/battle_models.dart';
import 'domain/bot_ai.dart';

class BattleSessionState {
  const BattleSessionState({
    required this.battle,
    this.busy = false,
    this.submitting = false,
    this.result,
    this.submitError,
  });

  final BattleState battle;
  final bool busy;
  final bool submitting;
  final BattleResultData? result;
  final String? submitError;

  BattleSessionState copyWith({
    BattleState? battle,
    bool? busy,
    bool? submitting,
    BattleResultData? result,
    String? submitError,
    bool clearSubmitError = false,
  }) {
    return BattleSessionState(
      battle: battle ?? this.battle,
      busy: busy ?? this.busy,
      submitting: submitting ?? this.submitting,
      result: result ?? this.result,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }
}

class BattleCubit extends Cubit<BattleSessionState> {
  BattleCubit({
    required BattleStartData start,
    required BattleRepository repository,
    AuthCubit? auth,
    BattleEngine engine = const BattleEngine(),
  }) : _engine = engine,
       _repository = repository,
       _auth = auth,
       _matchId = start.matchId,
       _bot = BotAI.forDifficulty(
         BotDifficulty.fromApi(start.difficulty),
         engine: engine,
         seed: start.seed ^ 0x9E3779B9,
       ),
       super(
         BattleSessionState(
           battle: const BattleEngine().start(
             playerDeck: start.playerDeck.cards,
             botDeck: start.botDeck.cards,
             seed: start.seed,
           ),
         ),
       ) {
    _stopwatch.start();
    if (state.battle.activeSide == BattleSide.bot) {
      unawaited(_runBotLoop());
    }
  }

  static const int _botDelayMs = 430;
  static const int _maxActionsPerTurn = 80;

  final BattleEngine _engine;
  final BattleRepository _repository;
  final AuthCubit? _auth;
  final String _matchId;
  final BotAI _bot;
  final Stopwatch _stopwatch = Stopwatch();

  bool _botRunning = false;
  bool _stopRequested = false;
  bool _submitted = false;

  BattleState get battle => state.battle;

  List<PlayCardAction> playOptionsForHand(int handIndex) {
    if (state.busy || state.battle.isTerminal) return const <PlayCardAction>[];
    return _engine
        .legalActions(state.battle, BattleSide.player)
        .whereType<PlayCardAction>()
        .where((action) => action.handIndex == handIndex)
        .toList(growable: false);
  }

  List<AttackAction> attackOptionsFor(String unitId) {
    if (state.busy || state.battle.isTerminal) return const <AttackAction>[];
    return _engine
        .legalActions(state.battle, BattleSide.player)
        .whereType<AttackAction>()
        .where((action) => action.attackerId == unitId)
        .toList(growable: false);
  }

  List<UseAbilityAction> abilityOptionsFor(String unitId) {
    if (state.busy || state.battle.isTerminal) {
      return const <UseAbilityAction>[];
    }
    return _engine
        .legalActions(state.battle, BattleSide.player)
        .whereType<UseAbilityAction>()
        .where((action) => action.unitId == unitId)
        .toList(growable: false);
  }

  SetGuardAction? guardActionFor(String unitId) {
    if (state.busy || state.battle.isTerminal) return null;
    final guards = _engine
        .legalActions(state.battle, BattleSide.player)
        .whereType<SetGuardAction>()
        .where((action) => action.unitId == unitId)
        .toList(growable: false);
    return guards.isEmpty ? null : guards.first;
  }

  /// Mengembalikan pesan error (null = aksi diterapkan).
  String? perform(BattleAction action) {
    if (isClosed) return 'Sesi pertandingan sudah berakhir.';
    if (state.battle.isTerminal) return 'Pertandingan sudah selesai.';
    if (state.busy) return 'Tunggu bot menyelesaikan gilirannya.';

    try {
      final next = _engine.apply(state.battle, action);
      emit(state.copyWith(battle: next, clearSubmitError: true));
      if (next.isTerminal) {
        unawaited(_submit());
      } else if (next.activeSide == BattleSide.bot) {
        unawaited(_runBotLoop());
      }
      return null;
    } on IllegalActionException catch (error) {
      return error.reason;
    } catch (_) {
      return 'Aksi gagal diterapkan.';
    }
  }

  /// Mengembalikan pesan error (null = giliran berhasil diakhiri).
  String? endTurn() => perform(const EndTurnAction());

  void concede() {
    if (isClosed || state.battle.isTerminal) return;
    _stopRequested = true;
    try {
      final next = _engine.apply(state.battle, const ConcedeAction());
      emit(state.copyWith(battle: next, busy: false));
      unawaited(_submit());
    } on IllegalActionException catch (error) {
      emit(state.copyWith(submitError: error.reason));
    }
  }

  Future<void> retrySubmit() async {
    _submitted = false;
    await _submit();
  }

  Future<void> _runBotLoop() async {
    if (_botRunning || isClosed) return;
    _botRunning = true;
    emit(state.copyWith(busy: true));
    var actions = 0;

    while (!isClosed && !_stopRequested) {
      final current = state.battle;
      if (current.isTerminal || current.activeSide != BattleSide.bot) break;
      if (actions >= _maxActionsPerTurn) break;

      await Future<void>.delayed(const Duration(milliseconds: _botDelayMs));
      if (isClosed || _stopRequested) break;

      final live = state.battle;
      if (live.isTerminal || live.activeSide != BattleSide.bot) break;

      final action = _bot.decide(live, BattleSide.bot);
      BattleState next;
      try {
        next = _engine.apply(live, action);
      } on IllegalActionException {
        try {
          next = _engine.apply(live, const EndTurnAction());
        } catch (_) {
          break;
        }
      }

      actions += 1;
      emit(
        state.copyWith(
          battle: next,
          busy: !next.isTerminal && next.activeSide == BattleSide.bot,
        ),
      );
      if (next.isTerminal) break;
    }

    _botRunning = false;
    if (isClosed) return;
    if (state.battle.isTerminal) {
      emit(state.copyWith(busy: false));
      await _submit();
      return;
    }
    emit(state.copyWith(busy: false));
  }

  Future<void> _submit() async {
    if (isClosed || _submitted || state.submitting) return;
    final current = state.battle;
    final outcome = current.outcome;
    if (outcome == null) return;

    _submitted = true;
    _stopwatch.stop();
    final turns = math.max(1, math.min(50, current.turnNumber));
    final minimumDuration = turns * 500;
    final elapsed = _stopwatch.elapsedMilliseconds;
    final durationMs = math.max(elapsed, minimumDuration);

    emit(state.copyWith(submitting: true, clearSubmitError: true));
    try {
      final result = await _repository.submitResult(
        matchId: _matchId,
        outcome: outcome.name,
        turns: turns,
        durationMs: durationMs,
        logHash: current.logHash,
      );
      if (isClosed) return;
      final user = result.user;
      if (user != null) {
        _auth?.applyUser(user);
      } else {
        _auth?.applyWallet(result.balance);
      }
      emit(
        state.copyWith(
          submitting: false,
          result: result,
        ),
      );
    } on ApiException catch (error) {
      _submitted = false;
      if (isClosed) return;
      emit(
        state.copyWith(
          submitting: false,
          submitError: error.message,
        ),
      );
    } catch (_) {
      _submitted = false;
      if (isClosed) return;
      emit(
        state.copyWith(
          submitting: false,
          submitError: 'Hasil pertandingan gagal dikirim.',
        ),
      );
    }
  }
}
