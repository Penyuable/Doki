import '../../core/utils/json_utils.dart';
import 'card_model.dart';
import 'user_model.dart';

class BattleDeckSnapshot {
  const BattleDeckSnapshot({
    required this.name,
    required this.cards,
    this.deckId,
  });

  final String name;
  final List<CardModel> cards;
  final String? deckId;

  factory BattleDeckSnapshot.fromJson(Map<String, dynamic> json) {
    return BattleDeckSnapshot(
      name: json.str('name'),
      deckId: json.strOrNull('deckId'),
      cards: CardModel.listFromJson(json['cards']),
    );
  }
}

class BattleStartData {
  const BattleStartData({
    required this.matchId,
    required this.seed,
    required this.difficulty,
    required this.playerDeck,
    required this.botDeck,
    required this.catalogVersion,
    required this.engineVersion,
    this.startedAt,
  });

  final String matchId;
  final int seed;
  final String difficulty;
  final BattleDeckSnapshot playerDeck;
  final BattleDeckSnapshot botDeck;
  final String catalogVersion;
  final String engineVersion;
  final DateTime? startedAt;

  factory BattleStartData.fromJson(Map<String, dynamic> json) {
    return BattleStartData(
      matchId: json.str('matchId'),
      seed: json.integer('seed'),
      difficulty: json.str('difficulty', 'easy'),
      playerDeck: BattleDeckSnapshot.fromJson(json.objectOf('playerDeck')),
      botDeck: BattleDeckSnapshot.fromJson(json.objectOf('botDeck')),
      catalogVersion: json.str('catalogVersion'),
      engineVersion: json.str('engineVersion', '1.0.0'),
      startedAt: json.dateTime('startedAt'),
    );
  }
}

class BattleRewards {
  const BattleRewards({
    required this.gold,
    required this.xp,
    required this.firstWinBonus,
    required this.capped,
  });

  final int gold;
  final int xp;
  final bool firstWinBonus;
  final bool capped;

  factory BattleRewards.fromJson(Map<String, dynamic> json) {
    return BattleRewards(
      gold: json.integer('gold'),
      xp: json.integer('xp'),
      firstWinBonus: json.boolean('firstWinBonus'),
      capped: json.boolean('capped'),
    );
  }
}

class LevelUpResult {
  const LevelUpResult({
    required this.levelsGained,
    required this.gold,
    required this.gems,
  });

  final int levelsGained;
  final int gold;
  final int gems;

  factory LevelUpResult.fromJson(Map<String, dynamic> json) {
    return LevelUpResult(
      levelsGained: json.integer('levelsGained'),
      gold: json.integer('gold'),
      gems: json.integer('gems'),
    );
  }
}

class BattleResultData {
  const BattleResultData({
    required this.matchId,
    required this.alreadyReported,
    required this.outcome,
    required this.rewards,
    required this.levelUp,
    required this.stats,
    required this.balance,
    this.user,
  });

  final String matchId;
  final bool alreadyReported;
  final String outcome;
  final BattleRewards rewards;
  final LevelUpResult levelUp;
  final UserStats stats;
  final WalletModel balance;
  final UserModel? user;

  factory BattleResultData.fromJson(Map<String, dynamic> json) {
    final userJson = asJsonMap(json['user']);
    return BattleResultData(
      matchId: json.str('matchId'),
      alreadyReported: json.boolean('alreadyReported'),
      outcome: json.str('outcome', 'draw'),
      rewards: BattleRewards.fromJson(json.objectOf('rewards')),
      levelUp: LevelUpResult.fromJson(json.objectOf('levelUp')),
      stats: UserStats.fromJson(json.objectOf('stats')),
      balance: WalletModel.fromJson(json.objectOf('balance')),
      user: userJson.isEmpty ? null : UserModel.fromJson(userJson),
    );
  }
}

class BattleHistoryItem {
  const BattleHistoryItem({
    required this.matchId,
    required this.difficulty,
    required this.outcome,
    required this.turns,
    required this.goldAwarded,
    required this.xpAwarded,
    this.reportedAt,
  });

  final String matchId;
  final String difficulty;
  final String outcome;
  final int turns;
  final int goldAwarded;
  final int xpAwarded;
  final DateTime? reportedAt;

  factory BattleHistoryItem.fromJson(Map<String, dynamic> json) {
    return BattleHistoryItem(
      matchId: json.str('matchId'),
      difficulty: json.str('difficulty'),
      outcome: json.str('outcome'),
      turns: json.integer('turns'),
      goldAwarded: json.integer('goldAwarded'),
      xpAwarded: json.integer('xpAwarded'),
      reportedAt: json.dateTime('reportedAt'),
    );
  }
}
