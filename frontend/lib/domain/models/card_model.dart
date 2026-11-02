import 'dart:convert';

import '../../core/utils/json_utils.dart';

enum CardElement {
  fire,
  water,
  earth,
  air,
  voidElement;

  String get api => switch (this) {
    CardElement.fire => 'Fire',
    CardElement.water => 'Water',
    CardElement.earth => 'Earth',
    CardElement.air => 'Air',
    CardElement.voidElement => 'Void',
  };

  String get slug => this == CardElement.voidElement ? 'void' : name;

  String get i18nKey => 'element.$slug';

  static CardElement fromApi(Object? raw) => enumFromApi(
    raw,
    CardElement.values,
    CardElement.voidElement,
    nameOf: (value) => value.api,
  );
}

enum Rarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
  master;

  String get api => switch (this) {
    Rarity.common => 'Common',
    Rarity.uncommon => 'Uncommon',
    Rarity.rare => 'Rare',
    Rarity.epic => 'Epic',
    Rarity.legendary => 'Legendary',
    Rarity.master => 'Master',
  };

  bool get isRarePlus => index >= Rarity.rare.index;

  String get i18nKey => 'rarity.$name';

  static Rarity fromApi(Object? raw) => enumFromApi(
    raw,
    Rarity.values,
    Rarity.common,
    nameOf: (value) => value.api,
  );
}

enum CardType {
  unit,
  spell;

  String get api => name;

  String get i18nKey => 'type.$name';

  static CardType fromApi(Object? raw) => enumFromApi(
    raw,
    CardType.values,
    CardType.unit,
    nameOf: (value) => value.api,
  );
}

class CardAbilityStatus {
  const CardAbilityStatus({
    required this.kind,
    required this.value,
    required this.turns,
  });

  final String kind;
  final int value;
  final int turns;

  factory CardAbilityStatus.fromJson(Map<String, dynamic> json) {
    return CardAbilityStatus(
      kind: json.str('kind'),
      value: json.integer('value'),
      turns: json.integer('turns', 1),
    );
  }
}

class CardAbility {
  const CardAbility({
    required this.name,
    required this.type,
    required this.cost,
    required this.target,
    required this.power,
    required this.text,
    this.status,
  });

  final String name;
  final String type;
  final int cost;
  final String target;
  final int power;
  final String text;
  final CardAbilityStatus? status;

  factory CardAbility.fromJson(Map<String, dynamic> json) {
    final statusJson = asJsonMap(json['status']);
    return CardAbility(
      name: json.str('name'),
      type: json.str('type', 'attack'),
      cost: json.integer('cost'),
      target: json.str('target', 'enemy_unit'),
      power: json.integer('power'),
      text: json.str('text'),
      status: statusJson.isEmpty ? null : CardAbilityStatus.fromJson(statusJson),
    );
  }

  bool get requiresUnitTarget =>
      target == 'enemy_unit' || target == 'any_unit' || target == 'self';
}

class CardModel {
  const CardModel({
    required this.id,
    required this.name,
    required this.element,
    required this.rarity,
    required this.type,
    required this.cost,
    required this.hp,
    required this.attack,
    required this.defense,
    required this.keywords,
    required this.ability,
    required this.flavorText,
    required this.imageUrl,
    required this.thumbnailUrl,
    required this.model3dUrl,
    required this.obtainable,
    required this.retired,
    required this.version,
  });

  final String id;
  final String name;
  final CardElement element;
  final Rarity rarity;
  final CardType type;
  final int cost;
  final int? hp;
  final int? attack;
  final int? defense;
  final Set<String> keywords;
  final CardAbility? ability;
  final String flavorText;
  final String imageUrl;
  final String? thumbnailUrl;
  final String? model3dUrl;
  final bool obtainable;
  final bool retired;
  final int version;

  bool get isUnit => type == CardType.unit;
  bool get hasCharge => keywords.contains('charge');
  bool get hasPierce => keywords.contains('pierce');
  bool get hasLifesteal => keywords.contains('lifesteal');

  String get displayImageUrl =>
      (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) ? thumbnailUrl! : imageUrl;

  factory CardModel.fromJson(Map<String, dynamic> json) {
    final abilityJson = asJsonMap(json['ability']);
    return CardModel(
      id: json.str('id'),
      name: json.str('name', json.str('id')),
      element: CardElement.fromApi(json['element']),
      rarity: Rarity.fromApi(json['rarity']),
      type: CardType.fromApi(json['type']),
      cost: json.integer('cost'),
      hp: json.integerOrNull('hp'),
      attack: json.integerOrNull('attack'),
      defense: json.integerOrNull('defense'),
      keywords: json
          .listOf('keywords')
          .map((value) => asString(value).toLowerCase())
          .where((value) => value.isNotEmpty)
          .toSet(),
      ability: abilityJson.isEmpty ? null : CardAbility.fromJson(abilityJson),
      flavorText: json.str('flavorText'),
      imageUrl: json.str('imageUrl'),
      thumbnailUrl: json.strOrNull('thumbnailUrl'),
      model3dUrl: json.strOrNull('model3dUrl'),
      obtainable: json.boolean('obtainable', true),
      retired: json.boolean('retired'),
      version: json.integer('version', 1),
    );
  }

  static CardModel? tryParse(Object? raw) {
    if (raw is Map) {
      final card = CardModel.fromJson(asJsonMap(raw));
      if (card.id.isEmpty) return null;
      return card;
    }
    return null;
  }

  static List<CardModel> listFromJson(Object? raw) {
    return asJsonList(raw)
        .map(CardModel.tryParse)
        .whereType<CardModel>()
        .toList(growable: false);
  }

  /// Hanya field yang relevan untuk replay/telemetri.
  Map<String, dynamic> toSummaryJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'element': element.api,
    'rarity': rarity.api,
    'type': type.api,
    'cost': cost,
    'hp': hp,
    'attack': attack,
    'defense': defense,
    'keywords': keywords.toList()..sort(),
    'ability': ability == null
        ? null
        : <String, dynamic>{
            'name': ability!.name,
            'type': ability!.type,
            'cost': ability!.cost,
            'target': ability!.target,
            'power': ability!.power,
          },
  };

  String get debugJson => jsonEncode(toSummaryJson());
}
