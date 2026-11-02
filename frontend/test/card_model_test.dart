import 'package:dokimon/domain/models/card_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CardModel.fromJson', () {
    test('parsing unit lengkap termasuk ability dan keyword', () {
      final card = CardModel.fromJson(<String, dynamic>{
        'id': 'card_001',
        'name': 'Ember Drake',
        'element': 'Fire',
        'rarity': 'Epic',
        'type': 'unit',
        'cost': 3,
        'hp': 12,
        'attack': 7,
        'defense': 2,
        'keywords': <String>['Charge', 'PIERCE'],
        'ability': <String, dynamic>{
          'name': 'Flame Burst',
          'type': 'attack',
          'cost': 2,
          'target': 'enemy_unit',
          'power': 5,
          'text': 'Deal 5 damage.',
          'status': <String, dynamic>{
            'kind': 'burn',
            'value': 2,
            'turns': 2,
          },
        },
        'flavorText': 'Born in ash.',
        'imageUrl': 'https://example.com/card.webp',
        'thumbnailUrl': 'https://example.com/thumb.webp',
        'model3dUrl': 'https://example.com/card.glb',
        'obtainable': true,
        'retired': false,
        'version': 3,
      });

      expect(card.id, 'card_001');
      expect(card.element, CardElement.fire);
      expect(card.rarity, Rarity.epic);
      expect(card.type, CardType.unit);
      expect(card.isUnit, isTrue);
      expect(card.hasCharge, isTrue);
      expect(card.hasPierce, isTrue);
      expect(card.hasLifesteal, isFalse);
      expect(card.displayImageUrl, 'https://example.com/thumb.webp');
      expect(card.ability?.status?.kind, 'burn');
      expect(card.keywords, <String>{'charge', 'pierce'});
    });

    test('spell tanpa field unit dan fallback nama dari id', () {
      final card = CardModel.fromJson(<String, dynamic>{
        'id': 'spell_01',
        'element': 'Void',
        'rarity': 'Rare',
        'type': 'spell',
        'cost': 2,
        'ability': <String, dynamic>{
          'name': 'Void Rift',
          'type': 'control',
          'cost': 2,
          'target': 'enemy_unit',
          'power': 0,
          'text': 'Freeze.',
        },
      });

      expect(card.name, 'spell_01');
      expect(card.element, CardElement.voidElement);
      expect(card.element.api, 'Void');
      expect(card.element.i18nKey, 'element.void');
      expect(card.type, CardType.spell);
      expect(card.isUnit, isFalse);
      expect(card.hp, isNull);
      expect(card.ability, isNotNull);
      expect(card.obtainable, isTrue);
      expect(card.retired, isFalse);
    });

    test('field asing / rusak tidak membuat crash', () {
      final card = CardModel.fromJson(<String, dynamic>{
        'id': 'x',
        'element': 'Unknown',
        'rarity': 'Mythic',
        'type': 'artifact',
        'cost': '3',
        'keywords': 'charge',
      });

      expect(card.element, CardElement.voidElement);
      expect(card.rarity, Rarity.common);
      expect(card.type, CardType.unit);
      expect(card.cost, 3);
      expect(card.keywords, isEmpty);
    });
  });

  group('Helper enum', () {
    test('rarity rare ke atas dianggap Rare+', () {
      expect(Rarity.common.isRarePlus, isFalse);
      expect(Rarity.uncommon.isRarePlus, isFalse);
      expect(Rarity.rare.isRarePlus, isTrue);
      expect(Rarity.epic.isRarePlus, isTrue);
      expect(Rarity.legendary.isRarePlus, isTrue);
      expect(Rarity.master.isRarePlus, isTrue);
    });

    test('CardModel.tryParse menolak nilai non-map dan id kosong', () {
      expect(CardModel.tryParse(null), isNull);
      expect(CardModel.tryParse('card'), isNull);
      expect(CardModel.tryParse(<String, dynamic>{}), isNull);
    });

    test('listFromJson melewati item rusak', () {
      final cards = CardModel.listFromJson(<dynamic>[
        <String, dynamic>{
          'id': 'ok',
          'element': 'Water',
          'rarity': 'Common',
          'type': 'unit',
          'cost': 1,
          'hp': 4,
          'attack': 2,
        },
        'broken',
        <String, dynamic>{},
      ]);

      expect(cards, hasLength(1));
      expect(cards.single.id, 'ok');
    });
  });
}
