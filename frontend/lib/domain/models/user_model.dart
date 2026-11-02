import '../../core/utils/json_utils.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.gold,
    required this.gems,
    required this.level,
    required this.xp,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.pityCounter,
    this.createdAt,
  });

  final String id;
  final String email;
  final String username;
  final int gold;
  final int gems;
  final int level;
  final int xp;
  final int wins;
  final int losses;
  final int draws;
  final int pityCounter;
  final DateTime? createdAt;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json.str('id'),
      email: json.str('email'),
      username: json.str('username'),
      gold: json.integer('gold'),
      gems: json.integer('gems'),
      level: json.integer('level', 1),
      xp: json.integer('xp'),
      wins: json.integer('wins'),
      losses: json.integer('losses'),
      draws: json.integer('draws'),
      pityCounter: json.integer('pityCounter'),
      createdAt: json.dateTime('createdAt'),
    );
  }

  UserModel copyWith({
    int? gold,
    int? gems,
    int? level,
    int? xp,
    int? wins,
    int? losses,
    int? draws,
    int? pityCounter,
  }) {
    return UserModel(
      id: id,
      email: email,
      username: username,
      gold: gold ?? this.gold,
      gems: gems ?? this.gems,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      pityCounter: pityCounter ?? this.pityCounter,
      createdAt: createdAt,
    );
  }
}

class UserStats {
  const UserStats({
    required this.wins,
    required this.losses,
    required this.draws,
    required this.total,
    required this.winRate,
  });

  final int wins;
  final int losses;
  final int draws;
  final int total;
  final double? winRate;

  static const empty = UserStats(
    wins: 0,
    losses: 0,
    draws: 0,
    total: 0,
    winRate: null,
  );

  factory UserStats.fromJson(Map<String, dynamic> json) {
    final rawRate = json['winRate'];
    return UserStats(
      wins: json.integer('wins'),
      losses: json.integer('losses'),
      draws: json.integer('draws'),
      total: json.integer('total'),
      winRate: rawRate == null ? null : asDouble(rawRate),
    );
  }
}

class WalletModel {
  const WalletModel({required this.gold, required this.gems});

  final int gold;
  final int gems;

  static const empty = WalletModel(gold: 0, gems: 0);

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      gold: json.integer('gold'),
      gems: json.integer('gems'),
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final UserModel user;
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      user: UserModel.fromJson(json.objectOf('user')),
      accessToken: json.str('accessToken'),
      refreshToken: json.str('refreshToken'),
      expiresIn: json.integer('expiresIn', 900),
    );
  }
}

class MeData {
  const MeData({
    required this.user,
    required this.stats,
    required this.activeDeckId,
  });

  final UserModel user;
  final UserStats stats;
  final String? activeDeckId;

  factory MeData.fromJson(Map<String, dynamic> json) {
    return MeData(
      user: UserModel.fromJson(json.objectOf('user')),
      stats: UserStats.fromJson(json.objectOf('stats')),
      activeDeckId: json.strOrNull('activeDeckId'),
    );
  }
}

class DailyInfo {
  const DailyInfo({
    required this.streak,
    required this.canClaim,
    this.lastClaimAt,
  });

  final int streak;
  final bool canClaim;
  final DateTime? lastClaimAt;

  factory DailyInfo.fromJson(Map<String, dynamic> json) {
    return DailyInfo(
      streak: json.integer('streak'),
      canClaim: json.boolean('canClaim'),
      lastClaimAt: json.dateTime('lastClaimAt'),
    );
  }
}

class ActiveDeckSummary {
  const ActiveDeckSummary({
    required this.id,
    required this.name,
    required this.cardCount,
  });

  final String id;
  final String name;
  final int cardCount;

  factory ActiveDeckSummary.fromJson(Map<String, dynamic> json) {
    return ActiveDeckSummary(
      id: json.str('id'),
      name: json.str('name'),
      cardCount: json.integer('cardCount'),
    );
  }
}

class CollectionSummary {
  const CollectionSummary({required this.owned, required this.total});

  final int owned;
  final int total;

  factory CollectionSummary.fromJson(Map<String, dynamic> json) {
    return CollectionSummary(
      owned: json.integer('owned'),
      total: json.integer('total'),
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.user,
    required this.stats,
    required this.collection,
    required this.daily,
    this.activeDeck,
  });

  final UserModel user;
  final UserStats stats;
  final CollectionSummary collection;
  final DailyInfo daily;
  final ActiveDeckSummary? activeDeck;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final deckJson = asJsonMap(json['activeDeck']);
    return UserProfile(
      user: UserModel.fromJson(json.objectOf('user')),
      stats: UserStats.fromJson(json.objectOf('stats')),
      collection: CollectionSummary.fromJson(json.objectOf('collection')),
      daily: DailyInfo.fromJson(json.objectOf('daily')),
      activeDeck: deckJson.isEmpty
          ? null
          : ActiveDeckSummary.fromJson(deckJson),
    );
  }
}

class DailyClaimResult {
  const DailyClaimResult({
    required this.streak,
    required this.day,
    required this.gold,
    required this.gems,
    required this.balance,
  });

  final int streak;
  final int day;
  final int gold;
  final int gems;
  final WalletModel balance;

  factory DailyClaimResult.fromJson(Map<String, dynamic> json) {
    final reward = json.objectOf('reward');
    return DailyClaimResult(
      streak: json.integer('streak'),
      day: json.integer('day', 1),
      gold: reward.integer('gold'),
      gems: reward.integer('gems'),
      balance: WalletModel.fromJson(json.objectOf('balance')),
    );
  }
}
