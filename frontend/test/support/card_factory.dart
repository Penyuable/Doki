import 'package:dokimon/domain/models/card_model.dart';

/// Factory kartu untuk unit test domain (tanpa I/O).
CardModel testUnit(
  String id, {
  String? name,
  CardElement element = CardElement.fire,
  Rarity rarity = Rarity.common,
  int cost = 1,
  int attack = 5,
  int hp = 5,
  int defense = 0,
  Set<String> keywords = const <String>{},
  CardAbility? ability,
}) {
  return CardModel(
    id: id,
    name: name ?? id,
    element: element,
    rarity: rarity,
    type: CardType.unit,
    cost: cost,
    hp: hp,
    attack: attack,
    defense: defense,
    keywords: keywords,
    ability: ability,
    flavorText: '',
    imageUrl: '',
    thumbnailUrl: null,
    model3dUrl: null,
    obtainable: true,
    retired: false,
    version: 1,
  );
}

CardModel testSpell(
  String id, {
  String? name,
  CardElement element = CardElement.fire,
  Rarity rarity = Rarity.common,
  int cost = 1,
  CardAbility? ability,
}) {
  return CardModel(
    id: id,
    name: name ?? id,
    element: element,
    rarity: rarity,
    type: CardType.spell,
    cost: cost,
    hp: null,
    attack: null,
    defense: null,
    keywords: const <String>{},
    ability: ability,
    flavorText: '',
    imageUrl: '',
    thumbnailUrl: null,
    model3dUrl: null,
    obtainable: true,
    retired: false,
    version: 1,
  );
}

CardAbility testAbility({
  String name = 'Test Ability',
  String type = 'attack',
  int cost = 1,
  String target = 'enemy_unit',
  int power = 3,
  CardAbilityStatus? status,
}) {
  return CardAbility(
    name: name,
    type: type,
    cost: cost,
    target: target,
    power: power,
    text: name,
    status: status,
  );
}

/// Deck 20 kartu dengan id unik agar start() selalu valid.
List<CardModel> testDeck({
  int count = 20,
  CardElement element = CardElement.fire,
  int cost = 1,
  int attack = 2,
  int hp = 6,
  Set<String> keywords = const <String>{},
  CardAbility? ability,
}) {
  return <CardModel>[
    for (var i = 0; i < count; i++)
      testUnit(
        'deck_$i',
        element: element,
        cost: cost,
        attack: attack,
        hp: hp,
        keywords: keywords,
        ability: ability,
      ),
  ];
}
