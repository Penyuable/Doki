import 'package:dokimon/domain/deck_rules.dart';
import 'package:dokimon/domain/models/card_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/card_factory.dart';

void main() {
  Map<String, CardModel> catalogOf(List<CardModel> cards) => <String, CardModel>{
    for (final card in cards) card.id: card,
  };

  group('DeckRules.validate', () {
    test('deck 20 kartu yang dimiliki dinyatakan valid', () {
      final cards = <CardModel>[
        for (var i = 0; i < 10; i++)
          testUnit('c$i', cost: i % 4, attack: 2 + i),
      ];
      final entries = <String, int>{
        for (final card in cards) card.id: 2,
      };
      final result = DeckRules.validate(
        entries: entries,
        owned: <String, int>{for (final card in cards) card.id: 3},
        catalog: catalogOf(cards),
      );

      expect(result.valid, isTrue);
      expect(result.cardCount, 20);
      expect(result.violations, isEmpty);
      expect(result.needsMoreCards, isFalse);
      expect(result.curve.values.fold<int>(0, (sum, v) => sum + v), 20);
    });

    test('jumlah kartu bukan 20 ditolak', () {
      final card = testUnit('c1');
      final result = DeckRules.validate(
        entries: <String, int>{card.id: 3},
        owned: <String, int>{card.id: 3},
        catalog: catalogOf(<CardModel>[card]),
      );

      expect(result.valid, isFalse);
      expect(result.cardCount, 3);
      expect(result.needsMoreCards, isTrue);
      expect(
        result.violations.map((violation) => violation.code),
        contains('DECK_SIZE'),
      );
    });

    test('lebih dari 3 copy ditolak walau dimiliki', () {
      final card = testUnit('c1');
      final result = DeckRules.validate(
        entries: <String, int>{card.id: 4},
        owned: <String, int>{card.id: 4},
        catalog: catalogOf(<CardModel>[card]),
      );

      expect(
        result.violations.map((violation) => violation.code),
        contains('COPY_LIMIT_EXCEEDED'),
      );
    });

    test('kartu yang tidak dimiliki cukup ditolak', () {
      final card = testUnit('c1');
      final result = DeckRules.validate(
        entries: <String, int>{card.id: 2},
        owned: <String, int>{card.id: 1},
        catalog: catalogOf(<CardModel>[card]),
      );

      expect(
        result.violations.map((violation) => violation.code),
        contains('CARD_NOT_OWNED'),
      );
    });

    test('kartu di luar katalog ditolak', () {
      final result = DeckRules.validate(
        entries: <String, int>{'missing': 2},
        owned: <String, int>{'missing': 2},
        catalog: const <String, CardModel>{},
      );

      expect(
        result.violations.map((violation) => violation.code),
        contains('CARD_NOT_FOUND'),
      );
    });
  });

  group('DeckRules.canAdd', () {
    test('boleh menambah bila masih di bawah batas', () {
      expect(
        DeckRules.canAdd(
          entries: <String, int>{'c1': 1},
          cardId: 'c1',
          ownedCount: 3,
        ),
        isTrue,
      );
    });

    test('menolak copy ke-4', () {
      expect(
        DeckRules.canAdd(
          entries: <String, int>{'c1': 3},
          cardId: 'c1',
          ownedCount: 5,
        ),
        isFalse,
      );
    });

    test('menolak bila kepemilikan habis', () {
      expect(
        DeckRules.canAdd(
          entries: <String, int>{'c1': 2},
          cardId: 'c1',
          ownedCount: 2,
        ),
        isFalse,
      );
    });

    test('menolak bila deck sudah 20 kartu', () {
      final entries = <String, int>{for (var i = 0; i < 20; i++) 'c$i': 1};
      expect(
        DeckRules.canAdd(
          entries: entries,
          cardId: 'new',
          ownedCount: 1,
        ),
        isFalse,
      );
    });
  });
}
