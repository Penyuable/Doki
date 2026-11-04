import '../../domain/models/card_model.dart';
import 'creature_avatar.dart';

/// Ilustrasi kartun kreatur di `assets/creatures/<key>.webp`, dirender dengan
/// gaya cel-shading dari model Quaternius (CC0) di `tool/render_creatures/`.
/// Model 3D tidak dibundel di app. Lihat `assets/creatures/CREDITS.md`.
abstract final class CreatureModels {
  /// Kartu katalog → model. Kartu yang mirip sengaja diberi model berbeda.
  static const Map<String, String> byCardId = <String, String>{
    'card_001': 'shiba',
    'card_002': 'slime',
    'card_003': 'mushnub',
    'card_004': 'bird',
    'card_005': 'spider',
    'card_006': 'pig',
    'card_007': 'frog',
    'card_008': 'bunny',
    'card_010': 'pink_slime',
    'card_011': 'ghost',
    'card_012': 'cactoro',
    'card_013': 'panda',
    'card_016': 'birb',
    'card_017': 'snake',
    'card_018': 'crab',
    'card_019': 'blue_demon',
    'card_020': 'wolf',
    'card_021': 'dragon',
    'card_022': 'dino',
    'card_023': 'mushroom_king',
    'card_024': 'alpaking',
    'card_025': 'dragon_evolved',
  };

  /// Cadangan untuk kartu baru dari CMS yang belum dipetakan.
  static const Map<CreatureSpecies, String> bySpecies =
      <CreatureSpecies, String>{
    CreatureSpecies.dino: 'dino',
    CreatureSpecies.dragon: 'dragon',
    CreatureSpecies.bird: 'birb',
    CreatureSpecies.pig: 'pig',
    CreatureSpecies.dog: 'shiba',
    CreatureSpecies.bear: 'panda',
    CreatureSpecies.bunny: 'bunny',
    CreatureSpecies.cat: 'wolf',
    CreatureSpecies.turtle: 'frog',
    CreatureSpecies.golem: 'mushroom_king',
    CreatureSpecies.serpent: 'snake',
    CreatureSpecies.sprite: 'slime',
    CreatureSpecies.bug: 'spider',
  };

  /// Kunci model untuk kartu unit, atau null untuk spell.
  static String? keyOf(CardModel card) {
    if (!card.isUnit) return null;
    return byCardId[card.id] ?? bySpecies[speciesOf(card)];
  }

  static String imageAsset(String key) => 'assets/creatures/$key.webp';

}
