import '../core/config/game_config.dart';
import '../domain/models/card_model.dart';

class DeckRuleViolation {
  const DeckRuleViolation({
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
}

class DeckValidationResult {
  const DeckValidationResult({
    required this.valid,
    required this.cardCount,
    required this.violations,
    required this.curve,
  });

  final bool valid;
  final int cardCount;
  final List<DeckRuleViolation> violations;
  final Map<int, int> curve;

  bool get needsMoreCards => cardCount < GameConfig.deckSize;
}

abstract final class DeckRules {
  static DeckValidationResult validate({
    required Map<String, int> entries,
    required Map<String, int> owned,
    required Map<String, CardModel> catalog,
  }) {
    final violations = <DeckRuleViolation>[];
    final curve = <int, int>{};
    var cardCount = 0;

    for (final entry in entries.entries) {
      final quantity = entry.value;
      if (quantity <= 0) continue;

      if (quantity > GameConfig.maxCopiesPerCard) {
        violations.add(
          DeckRuleViolation(
            code: 'COPY_LIMIT_EXCEEDED',
            cardId: entry.key,
            message: 'Maksimal ${GameConfig.maxCopiesPerCard} copy per kartu',
            actual: quantity,
            limit: GameConfig.maxCopiesPerCard,
          ),
        );
      }

      final card = catalog[entry.key];
      if (card == null) {
        violations.add(
          DeckRuleViolation(
            code: 'CARD_NOT_FOUND',
            cardId: entry.key,
            message: 'Kartu tidak ada di katalog',
          ),
        );
        continue;
      }

      if (card.type != CardType.unit && card.type != CardType.spell) {
        violations.add(
          DeckRuleViolation(
            code: 'CARD_NOT_PLAYABLE',
            cardId: entry.key,
            message: 'Kartu tidak bisa dimainkan',
          ),
        );
      }

      final ownedCount = owned[entry.key] ?? 0;
      if (ownedCount < quantity) {
        violations.add(
          DeckRuleViolation(
            code: 'CARD_NOT_OWNED',
            cardId: entry.key,
            message: 'Jumlah kartu melebihi yang dimiliki',
            actual: quantity,
            limit: ownedCount,
          ),
        );
      }

      cardCount += quantity;
      curve[card.cost] = (curve[card.cost] ?? 0) + quantity;
    }

    if (cardCount != GameConfig.deckSize) {
      violations.add(
        DeckRuleViolation(
          code: 'DECK_SIZE',
          message: 'Deck harus tepat ${GameConfig.deckSize} kartu',
          actual: cardCount,
          limit: GameConfig.deckSize,
        ),
      );
    }

    return DeckValidationResult(
      valid: violations.isEmpty,
      cardCount: cardCount,
      violations: violations,
      curve: curve,
    );
  }

  /// Apakah satu copy lagi boleh ditambahkan? Dipakai UI untuk disable tombol.
  static bool canAdd({
    required Map<String, int> entries,
    required String cardId,
    required int ownedCount,
  }) {
    final current = entries[cardId] ?? 0;
    if (current >= GameConfig.maxCopiesPerCard) return false;
    if (current >= ownedCount) return false;
    final total = entries.values.fold<int>(0, (sum, value) => sum + value);
    return total < GameConfig.deckSize;
  }
}
