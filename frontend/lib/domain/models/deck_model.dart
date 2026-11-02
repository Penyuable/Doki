import '../../core/utils/json_utils.dart';
import 'card_model.dart';

class DeckViolation {
  const DeckViolation({
    required this.code,
    required this.message,
    this.cardId,
    this.actual,
    this.limit,
  });

  final String code;
  final String message;
  final String? cardId;
  final int? actual;
  final int? limit;

  factory DeckViolation.fromJson(Map<String, dynamic> json) {
    return DeckViolation(
      code: json.str('code'),
      message: json.str('message'),
      cardId: json.strOrNull('cardId'),
      actual: json.integerOrNull('actual'),
      limit: json.integerOrNull('limit'),
    );
  }
}

class DeckCardEntry {
  const DeckCardEntry({
    required this.cardId,
    required this.quantity,
    this.card,
  });

  final String cardId;
  final int quantity;
  final CardModel? card;

  factory DeckCardEntry.fromJson(Map<String, dynamic> json) {
    return DeckCardEntry(
      cardId: json.str('cardId'),
      quantity: json.integer('quantity'),
      card: CardModel.tryParse(json['card']),
    );
  }
}

class DeckModel {
  const DeckModel({
    required this.id,
    required this.name,
    required this.isActive,
    required this.cardCount,
    required this.isValid,
    required this.violations,
    required this.curve,
    required this.cards,
    this.updatedAt,
  });

  final String id;
  final String name;
  final bool isActive;
  final int cardCount;
  final bool isValid;
  final List<DeckViolation> violations;
  final Map<int, int> curve;
  final List<DeckCardEntry> cards;
  final DateTime? updatedAt;

  factory DeckModel.fromJson(Map<String, dynamic> json) {
    final curveJson = json.objectOf('curve');
    return DeckModel(
      id: json.str('id'),
      name: json.str('name'),
      isActive: json.boolean('isActive'),
      cardCount: json.integer('cardCount'),
      isValid: json.boolean('isValid'),
      violations: json
          .listOf('violations')
          .map((value) => DeckViolation.fromJson(asJsonMap(value)))
          .toList(growable: false),
      curve: <int, int>{
        for (final entry in curveJson.entries)
          if (int.tryParse(entry.key) != null)
            int.parse(entry.key): asInt(entry.value),
      },
      cards: json
          .listOf('cards')
          .map((value) => DeckCardEntry.fromJson(asJsonMap(value)))
          .toList(growable: false),
      updatedAt: json.dateTime('updatedAt'),
    );
  }

  Map<String, int> get entries => <String, int>{
    for (final entry in cards) entry.cardId: entry.quantity,
  };

  int quantityOf(String cardId) {
    for (final entry in cards) {
      if (entry.cardId == cardId) return entry.quantity;
    }
    return 0;
  }
}
