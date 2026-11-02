/// Angka permainan yang mengikat (PRD §6–§9).
/// Semua layer membaca dari sini; UI tidak boleh hardcode angka.
abstract final class GameConfig {
  static const int playerHp = 200;
  static const int maxEnergy = 10;
  static const int startingEnergy = 1;
  static const int boardSlots = 3;
  static const int startingHand = 4;
  static const int handLimit = 8;
  static const int maxTurns = 50;

  static const int deckSize = 20;
  static const int maxCopiesPerCard = 3;
  static const int maxDecks = 10;

  static const int pityThreshold = 50;

  /// Harga gacha: gold & gem, untuk 1x dan 10x.
  static const Map<int, int> gachaGoldPrice = {1: 100, 10: 900};
  static const Map<int, int> gachaGemPrice = {1: 1, 10: 9};

  /// Reward kemenangan per difficulty: gold, xp.
  static const Map<String, ({int gold, int xp})> battleRewards = {
    'easy': (gold: 40, xp: 30),
    'medium': (gold: 80, xp: 60),
    'master': (gold: 150, xp: 120),
  };

  static const int lossXp = 10;
  static const int drawXp = 15;
  static const int firstWinBonusGold = 200;

  static const List<int> dailyRewardGold = [100, 150, 200, 250, 300, 400, 400];
  static const List<int> dailyRewardGems = [0, 0, 0, 0, 0, 0, 1];

  static const List<String> difficulties = ['easy', 'medium', 'master'];
  static const List<String> elements = ['Fire', 'Water', 'Earth', 'Air', 'Void'];
  static const List<String> rarities = [
    'Common',
    'Uncommon',
    'Rare',
    'Epic',
    'Legendary',
    'Master',
  ];

  static int xpToNext(int level) => 100 + 50 * (level - 1);
}
