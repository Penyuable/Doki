import '../../core/utils/json_utils.dart';
import 'card_model.dart';

class InventoryItem {
  const InventoryItem({
    required this.cardId,
    required this.quantity,
    required this.card,
    this.firstSeenAt,
  });

  final String cardId;
  final int quantity;
  final CardModel card;
  final DateTime? firstSeenAt;

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      cardId: json.str('cardId'),
      quantity: json.integer('quantity'),
      card: CardModel.fromJson(json.objectOf('card')),
      firstSeenAt: json.dateTime('firstSeenAt'),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'cardId': cardId,
    'quantity': quantity,
    'card': <String, dynamic>{
      'id': card.id,
      'name': card.name,
      'element': card.element.api,
      'rarity': card.rarity.api,
      'type': card.type.api,
      'cost': card.cost,
      'hp': card.hp,
      'attack': card.attack,
      'defense': card.defense,
      'keywords': card.keywords.toList(),
      'ability': card.ability == null
          ? null
          : <String, dynamic>{
              'name': card.ability!.name,
              'type': card.ability!.type,
              'cost': card.ability!.cost,
              'target': card.ability!.target,
              'power': card.ability!.power,
              'text': card.ability!.text,
              'status': card.ability!.status == null
                  ? null
                  : <String, dynamic>{
                      'kind': card.ability!.status!.kind,
                      'value': card.ability!.status!.value,
                      'turns': card.ability!.status!.turns,
                    },
            },
      'flavorText': card.flavorText,
      'imageUrl': card.imageUrl,
      'thumbnailUrl': card.thumbnailUrl,
      'model3dUrl': card.model3dUrl,
      'obtainable': card.obtainable,
      'retired': card.retired,
      'version': card.version,
    },
    if (firstSeenAt != null) 'firstSeenAt': firstSeenAt!.toIso8601String(),
  };
}

class InventoryPage {
  const InventoryPage({
    required this.items,
    required this.owned,
    required this.total,
    this.nextCursor,
  });

  final List<InventoryItem> items;
  final int owned;
  final int total;
  final int? nextCursor;

  factory InventoryPage.fromJson(Map<String, dynamic> json) {
    return InventoryPage(
      items: json
          .listOf('items')
          .map((value) => InventoryItem.fromJson(asJsonMap(value)))
          .toList(growable: false),
      owned: json.integer('owned'),
      total: json.integer('total'),
      nextCursor: json.integerOrNull('nextCursor'),
    );
  }
}
