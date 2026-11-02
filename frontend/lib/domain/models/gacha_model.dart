import '../../core/utils/json_utils.dart';
import 'card_model.dart';
import 'user_model.dart';

class PityInfo {
  const PityInfo({
    required this.counter,
    required this.threshold,
    required this.guaranteedIn,
  });

  final int counter;
  final int threshold;
  final int guaranteedIn;

  static const empty = PityInfo(counter: 0, threshold: 50, guaranteedIn: 50);

  factory PityInfo.fromJson(Map<String, dynamic> json) {
    return PityInfo(
      counter: json.integer('counter'),
      threshold: json.integer('threshold', 50),
      guaranteedIn: json.integer('guaranteedIn', 50),
    );
  }

  double get progress => threshold <= 0
      ? 0
      : (counter / threshold).clamp(0.0, 1.0).toDouble();
}

class GachaPullResult {
  const GachaPullResult({
    required this.cardId,
    required this.rarity,
    required this.isNew,
    required this.wasPity,
    required this.guaranteedRare,
    this.card,
  });

  final String cardId;
  final Rarity rarity;
  final bool isNew;
  final bool wasPity;
  final bool guaranteedRare;
  final CardModel? card;

  factory GachaPullResult.fromJson(Map<String, dynamic> json) {
    return GachaPullResult(
      cardId: json.str('cardId'),
      rarity: Rarity.fromApi(json['rarity']),
      isNew: json.boolean('isNew'),
      wasPity: json.boolean('wasPity'),
      guaranteedRare: json.boolean('guaranteedRare'),
      card: CardModel.tryParse(json['card']),
    );
  }
}

class GachaPullResponse {
  const GachaPullResponse({
    required this.batchId,
    required this.results,
    required this.balance,
    required this.pity,
    required this.replayed,
  });

  final String batchId;
  final List<GachaPullResult> results;
  final WalletModel balance;
  final PityInfo pity;
  final bool replayed;

  factory GachaPullResponse.fromJson(Map<String, dynamic> json) {
    return GachaPullResponse(
      batchId: json.str('batchId'),
      results: json
          .listOf('results')
          .map((value) => GachaPullResult.fromJson(asJsonMap(value)))
          .toList(growable: false),
      balance: WalletModel.fromJson(json.objectOf('balance')),
      pity: PityInfo.fromJson(json.objectOf('pity')),
      replayed: json.boolean('replayed'),
    );
  }

  bool get hasRarePlus =>
      results.any((result) => result.rarity.isRarePlus);
}

class GachaRate {
  const GachaRate({
    required this.rarity,
    required this.weight,
    required this.percent,
  });

  final Rarity rarity;
  final int weight;
  final double percent;

  factory GachaRate.fromJson(Map<String, dynamic> json) {
    return GachaRate(
      rarity: Rarity.fromApi(json['rarity']),
      weight: json.integer('weight'),
      percent: json.decimal('percent'),
    );
  }
}

class GachaRatesData {
  const GachaRatesData({
    required this.rates,
    required this.pity,
    required this.guaranteedRarePlusOnTen,
  });

  final List<GachaRate> rates;
  final PityInfo pity;
  final bool guaranteedRarePlusOnTen;

  factory GachaRatesData.fromJson(Map<String, dynamic> json) {
    return GachaRatesData(
      rates: json
          .listOf('rates')
          .map((value) => GachaRate.fromJson(asJsonMap(value)))
          .toList(growable: false),
      pity: PityInfo.fromJson(json.objectOf('pity')),
      guaranteedRarePlusOnTen:
          json.boolean('guaranteedRarePlusOnTen', true),
    );
  }
}

class GachaHistoryEntry {
  const GachaHistoryEntry({
    required this.id,
    required this.cardId,
    required this.rarity,
    required this.isNew,
    required this.batchId,
    required this.card,
    this.createdAt,
  });

  final String id;
  final String cardId;
  final Rarity rarity;
  final bool isNew;
  final String batchId;
  final CardModel? card;
  final DateTime? createdAt;

  factory GachaHistoryEntry.fromJson(Map<String, dynamic> json) {
    return GachaHistoryEntry(
      id: json.str('id'),
      cardId: json.str('cardId'),
      rarity: Rarity.fromApi(json['rarity']),
      isNew: json.boolean('isNew'),
      batchId: json.str('batchId'),
      card: CardModel.tryParse(json['card']),
      createdAt: json.dateTime('createdAt'),
    );
  }
}
