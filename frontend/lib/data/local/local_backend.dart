import 'dart:convert';
import 'dart:math' as math;

import 'package:hive_flutter/hive_flutter.dart';

import '../../core/config/game_config.dart';

/// Error dengan bentuk yang sama seperti envelope `{error}` backend.
class LocalApiError implements Exception {
  const LocalApiError(this.status, this.code, this.message, [this.details]);

  final int status;
  final String code;
  final String message;
  final Object? details;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'error': <String, dynamic>{
          'code': code,
          'message': message,
          if (details != null) 'details': details,
        },
      };
}

/// Backend lokal untuk mode offline (tanpa login, tanpa server).
///
/// Port Dart dari `backend/src/modules/*`: respons memakai bentuk JSON yang
/// sama sehingga repository & cubit tidak perlu tahu sedang offline.
/// Catatan: di mode ini gacha & saldo dihitung di perangkat, sehingga
/// invarian I-01/I-02 (server otoritatif) sengaja tidak berlaku.
class LocalBackend {
  LocalBackend._(this._box, this._catalog, this._catalogVersion, this._random);

  static const String _boxName = 'dokimon_offline';
  static const String _stateKey = 'state';

  // Angka ekonomi yang tidak ada di GameConfig (lihat backend config/economy.ts).
  static const int startingGold = 1000;
  static const int startingGems = 50;
  static const int dailyRewardedMatchLimit = 40;
  static const int levelUpGold = 200;
  static const int levelUpGems = 5;
  static const List<({String rarity, int weight})> rates = [
    (rarity: 'Common', weight: 6000),
    (rarity: 'Uncommon', weight: 2500),
    (rarity: 'Rare', weight: 1000),
    (rarity: 'Epic', weight: 400),
    (rarity: 'Legendary', weight: 90),
    (rarity: 'Master', weight: 10),
  ];
  static const List<({String rarity, int weight})> pityWeights = [
    (rarity: 'Epic', weight: 800),
    (rarity: 'Legendary', weight: 180),
    (rarity: 'Master', weight: 20),
  ];
  static const List<({String cardId, int quantity})> starterDeck = [
    (cardId: 'card_001', quantity: 3),
    (cardId: 'card_002', quantity: 3),
    (cardId: 'card_003', quantity: 3),
    (cardId: 'card_004', quantity: 3),
    (cardId: 'card_005', quantity: 3),
    (cardId: 'card_006', quantity: 3),
    (cardId: 'card_007', quantity: 2),
  ];

  final Box<dynamic> _box;
  final List<Map<String, dynamic>> _catalog;
  final String _catalogVersion;
  final math.Random _random;
  Future<void> _queue = Future<void>.value();

  late final Map<String, Map<String, dynamic>> _byId = {
    for (final card in _catalog) card['id'] as String: card,
  };

  static Future<LocalBackend> create({
    required List<Map<String, dynamic>> catalog,
    String catalogVersion = 'bundled',
    Box<dynamic>? box,
    math.Random? random,
  }) async {
    final opened = box ?? await Hive.openBox<dynamic>(_boxName);
    return LocalBackend._(
      opened,
      catalog,
      catalogVersion,
      random ?? math.Random.secure(),
    );
  }

  /// Menjalankan request satu per satu (setara transaksi DB berurutan).
  Future<Map<String, dynamic>> handle(
    String method,
    String path,
    Map<String, dynamic> body,
    Map<String, dynamic> query,
  ) {
    final result = _queue.then((_) => _route(method, path, body, query));
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  // ------------------------------------------------------------------ state

  Map<String, dynamic>? _loadState() {
    final raw = _box.get(_stateKey);
    if (raw is! String || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> _save(Map<String, dynamic> state) =>
      _box.put(_stateKey, jsonEncode(state));

  Future<Map<String, dynamic>> _state() async {
    final existing = _loadState();
    if (existing != null) return existing;
    final now = _now();
    final deckId = 'deck_${_id()}';
    final state = <String, dynamic>{
      'user': <String, dynamic>{
        'id': 'local_${_id()}',
        'email': 'player@offline.local',
        'username': 'player',
        'gold': startingGold,
        'gems': startingGems,
        'level': 1,
        'xp': 0,
        'wins': 0,
        'losses': 0,
        'draws': 0,
        'pityCounter': 0,
        'createdAt': now,
        'dailyStreak': 0,
        'lastDailyAt': null,
        'lastFirstWinAt': null,
        'activeDeckId': deckId,
      },
      'inventory': <Map<String, dynamic>>[
        for (final entry in starterDeck)
          if (_byId.containsKey(entry.cardId))
            <String, dynamic>{
              'cardId': entry.cardId,
              'quantity': entry.quantity,
              'firstSeenAt': now,
            },
      ],
      'decks': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': deckId,
          'name': 'Starter',
          'isActive': true,
          'updatedAt': now,
          'cards': <Map<String, dynamic>>[
            for (final entry in starterDeck)
              <String, dynamic>{
                'cardId': entry.cardId,
                'quantity': entry.quantity,
              },
          ],
        },
      ],
      'pulls': <Map<String, dynamic>>[],
      'matches': <Map<String, dynamic>>[],
    };
    await _save(state);
    return state;
  }

  String _now() => DateTime.now().toUtc().toIso8601String();

  String _id() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List<String>.generate(
      12,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
  }

  // ----------------------------------------------------------------- router

  Future<Map<String, dynamic>> _route(
    String method,
    String path,
    Map<String, dynamic> body,
    Map<String, dynamic> query,
  ) async {
    final segments =
        Uri.parse(path).pathSegments.where((s) => s.isNotEmpty).toList();
    final key = '$method ${segments.isEmpty ? '' : segments.first}';
    final rest = segments.skip(1).toList();

    switch (key) {
      case 'POST auth':
        return _auth(rest.isEmpty ? '' : rest.first);
      case 'GET auth':
        if (rest.length == 1 && rest.first == 'me') return _me();
      case 'GET catalog':
        if (rest.length == 1 && rest.first == 'cards') {
          return <String, dynamic>{
            'version': _catalogVersion,
            'cards': _catalog,
          };
        }
      case 'GET user':
        if (rest.length == 1 && rest.first == 'profile') return _profile();
        if (rest.length == 1 && rest.first == 'wallet') return _wallet();
      case 'POST user':
        if (rest.length == 1 && rest.first == 'daily-claim') return _daily();
      case 'GET inventory':
        return _inventory(query);
      case 'GET gacha':
        if (rest.length == 1 && rest.first == 'rates') return _rates();
        if (rest.length == 1 && rest.first == 'pity') return _pity();
        if (rest.length == 1 && rest.first == 'history') {
          return _gachaHistory(query);
        }
      case 'POST gacha':
        if (rest.length == 1 && rest.first == 'pull') return _pull(body);
      case 'GET decks':
        if (rest.isEmpty) return _listDecks();
        return <String, dynamic>{'deck': await _getDeck(rest.first)};
      case 'POST decks':
        if (rest.isEmpty) return _createDeck(body);
      case 'PATCH decks':
        if (rest.length == 1) return _updateDeck(rest.first, body);
      case 'PUT decks':
        if (rest.length == 2 && rest[1] == 'activate') {
          return _activateDeck(rest.first);
        }
      case 'DELETE decks':
        if (rest.length == 1) return _deleteDeck(rest.first);
      case 'POST battles':
        if (rest.length == 1 && rest.first == 'start') {
          return _startBattle(body);
        }
        if (rest.length == 2 && rest[1] == 'result') {
          return _reportResult(rest.first, body);
        }
      case 'GET battles':
        if (rest.length == 1 && rest.first == 'history') {
          return _battleHistory(query);
        }
      case 'POST telemetry':
        return <String, dynamic>{'accepted': 0};
    }
    throw LocalApiError(404, 'NOT_FOUND', 'Endpoint $method $path tidak ada');
  }

  // ------------------------------------------------------------------- auth

  Future<Map<String, dynamic>> _auth(String action) async {
    final state = await _state();
    switch (action) {
      case 'guest':
      case 'login':
      case 'register':
      case 'refresh':
        return <String, dynamic>{
          'user': _publicUser(state),
          'accessToken': 'offline',
          'refreshToken': 'offline',
          'expiresIn': 0,
        };
      case 'logout':
        return <String, dynamic>{};
    }
    throw const LocalApiError(404, 'NOT_FOUND', 'Endpoint auth tidak ada');
  }

  Map<String, dynamic> _publicUser(Map<String, dynamic> state) {
    final user = state['user'] as Map<String, dynamic>;
    return <String, dynamic>{
      for (final key in const <String>[
        'id',
        'email',
        'username',
        'gold',
        'gems',
        'level',
        'xp',
        'wins',
        'losses',
        'draws',
        'pityCounter',
        'createdAt',
      ])
        key: user[key],
    };
  }

  Map<String, dynamic> _stats(Map<String, dynamic> user) {
    final wins = user['wins'] as int;
    final losses = user['losses'] as int;
    final draws = user['draws'] as int;
    final total = wins + losses + draws;
    return <String, dynamic>{
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'total': total,
      'winRate':
          total == 0 ? null : double.parse((wins / total).toStringAsFixed(3)),
    };
  }

  Future<Map<String, dynamic>> _me() async {
    final state = await _state();
    final user = state['user'] as Map<String, dynamic>;
    return <String, dynamic>{
      'user': _publicUser(state),
      'stats': _stats(user),
      'activeDeckId': user['activeDeckId'],
    };
  }

  // ------------------------------------------------------------------- user

  Future<Map<String, dynamic>> _profile() async {
    final state = await _state();
    final user = state['user'] as Map<String, dynamic>;
    final inventory = _list(state, 'inventory');
    Map<String, dynamic>? active;
    for (final deck in _list(state, 'decks')) {
      if (deck['id'] == user['activeDeckId']) active = deck;
    }
    final lastDaily = _date(user['lastDailyAt']);
    return <String, dynamic>{
      'user': _publicUser(state),
      'stats': _stats(user),
      'collection': <String, dynamic>{
        'owned': inventory.length,
        'total': _catalog.length,
      },
      'activeDeck': active == null
          ? null
          : <String, dynamic>{
              'id': active['id'],
              'name': active['name'],
              'cardCount': _deckEntries(active).fold<int>(
                0,
                (sum, e) => sum + (e['quantity'] as int),
              ),
            },
      'daily': <String, dynamic>{
        'streak': user['dailyStreak'],
        'lastClaimAt': user['lastDailyAt'],
        'canClaim': !_sameWibDay(lastDaily, DateTime.now()),
      },
    };
  }

  Future<Map<String, dynamic>> _wallet() async {
    final state = await _state();
    final user = state['user'] as Map<String, dynamic>;
    return <String, dynamic>{
      'gold': user['gold'],
      'gems': user['gems'],
      'updatedAt': _now(),
    };
  }

  Future<Map<String, dynamic>> _daily() async {
    final state = await _state();
    final user = state['user'] as Map<String, dynamic>;
    final now = DateTime.now();
    final last = _date(user['lastDailyAt']);
    final nextClaimAt = _startOfWibDay(
      now,
    ).add(const Duration(days: 1)).toIso8601String();
    if (_sameWibDay(last, now)) {
      throw LocalApiError(
        409,
        'ALREADY_CLAIMED',
        'Reward harian sudah diambil hari ini',
        <String, dynamic>{'nextClaimAt': nextClaimAt},
      );
    }
    final streak = last != null && _isYesterdayWib(last, now)
        ? (user['dailyStreak'] as int) + 1
        : 1;
    final day = ((streak - 1) % 7) + 1;
    final gold = GameConfig.dailyRewardGold[day - 1];
    final gems = GameConfig.dailyRewardGems[day - 1];
    user['gold'] = (user['gold'] as int) + gold;
    user['gems'] = (user['gems'] as int) + gems;
    user['lastDailyAt'] = now.toUtc().toIso8601String();
    user['dailyStreak'] = streak;
    await _save(state);
    return <String, dynamic>{
      'claimed': true,
      'streak': streak,
      'day': day,
      'reward': <String, dynamic>{'gold': gold, 'gems': gems},
      'balance': <String, dynamic>{'gold': user['gold'], 'gems': user['gems']},
      'nextClaimAt': nextClaimAt,
    };
  }

  // -------------------------------------------------------------- inventory

  Future<Map<String, dynamic>> _inventory(Map<String, dynamic> query) async {
    final state = await _state();
    final rows = _list(state, 'inventory');
    final element = query['element']?.toString();
    final rarity = query['rarity']?.toString();
    final type = query['type']?.toString();
    final sort = query['sort']?.toString() ?? 'rarity';
    final limit = int.tryParse('${query['limit'] ?? 50}') ?? 50;
    final cursor = int.tryParse('${query['cursor'] ?? 0}') ?? 0;

    final items = <Map<String, dynamic>>[
      for (final row in rows)
        if (_byId[row['cardId']] case final card?)
          if ((element == null || card['element'] == element) &&
              (rarity == null || card['rarity'] == rarity) &&
              (type == null || card['type'] == type))
            <String, dynamic>{
              'cardId': row['cardId'],
              'quantity': row['quantity'],
              'firstSeenAt': row['firstSeenAt'],
              'card': card,
            },
    ];

    int rarityIndex(Map<String, dynamic> item) =>
        GameConfig.rarities.indexOf(_card(item)['rarity'] as String);
    int name(Map<String, dynamic> a, Map<String, dynamic> b) =>
        (_card(a)['name'] as String).compareTo(_card(b)['name'] as String);
    int stat(Map<String, dynamic> item, String key) =>
        (_card(item)[key] as int?) ?? -1;

    items.sort((a, b) {
      switch (sort) {
        case 'name':
          return name(a, b);
        case 'recent':
          return (b['firstSeenAt'] as String).compareTo(
            a['firstSeenAt'] as String,
          );
        case 'attack':
          return stat(b, 'attack') - stat(a, 'attack');
        case 'hp':
          return stat(b, 'hp') - stat(a, 'hp');
        default:
          final diff = rarityIndex(b) - rarityIndex(a);
          return diff != 0 ? diff : name(a, b);
      }
    });

    final start = cursor.clamp(0, items.length);
    final end = (start + limit).clamp(0, items.length);
    return <String, dynamic>{
      'items': items.sublist(start, end),
      'nextCursor': end < items.length ? end : null,
      'owned': rows.length,
      'total': _catalog.where((c) => c['retired'] != true).length,
    };
  }

  Map<String, dynamic> _card(Map<String, dynamic> item) =>
      item['card'] as Map<String, dynamic>;

  // ------------------------------------------------------------------ gacha

  Map<String, dynamic> _rates() => <String, dynamic>{
        'rates': <Map<String, dynamic>>[
          for (final r in rates)
            <String, dynamic>{
              'rarity': r.rarity,
              'weight': r.weight,
              'percent': double.parse((r.weight / 100).toStringAsFixed(2)),
            },
        ],
        'pity': <String, dynamic>{
          'threshold': GameConfig.pityThreshold,
          'bonusWeights': <Map<String, dynamic>>[
            for (final w in pityWeights)
              <String, dynamic>{'rarity': w.rarity, 'weight': w.weight},
          ],
          'note':
              'Epic+ dijamin pada pull ke-${GameConfig.pityThreshold} sejak '
                  'Epic+ terakhir. 10x pull dijamin minimal 1 Rare+.',
        },
        'guaranteedRarePlusOnTen': true,
      };

  Map<String, dynamic> _pityJson(int counter) => <String, dynamic>{
        'counter': counter,
        'threshold': GameConfig.pityThreshold,
        'guaranteedIn': math.max(0, GameConfig.pityThreshold - counter),
      };

  Future<Map<String, dynamic>> _pity() async {
    final state = await _state();
    final user = state['user'] as Map<String, dynamic>;
    return _pityJson(user['pityCounter'] as int);
  }

  String _weightedPick(List<({String rarity, int weight})> items) {
    final total = items.fold<int>(0, (sum, i) => sum + i.weight);
    var roll = _random.nextInt(total);
    for (final item in items) {
      if (roll < item.weight) return item.rarity;
      roll -= item.weight;
    }
    return items.last.rarity;
  }

  String _fallbackRarity(String rarity, Set<String> available) {
    var index = GameConfig.rarities.indexOf(rarity);
    while (index >= 0) {
      final candidate = GameConfig.rarities[index];
      if (available.contains(candidate)) return candidate;
      index -= 1;
    }
    return GameConfig.rarities.first;
  }

  bool _isRarePlus(String rarity) =>
      GameConfig.rarities.indexOf(rarity) >=
      GameConfig.rarities.indexOf('Rare');

  Future<Map<String, dynamic>> _pull(Map<String, dynamic> body) async {
    final count = body['count'];
    final currency = body['currency'];
    if ((count != 1 && count != 10) ||
        (currency != 'gold' && currency != 'gem')) {
      throw const LocalApiError(
        400,
        'VALIDATION_ERROR',
        'count harus 1/10 dan currency gold/gem',
      );
    }
    final state = await _state();
    final user = state['user'] as Map<String, dynamic>;

    final idempotencyKey = body['idempotencyKey'] as String?;
    if (idempotencyKey != null) {
      final replay = _replayPull(state, idempotencyKey);
      if (replay != null) return replay;
    }

    final price = currency == 'gold'
        ? GameConfig.gachaGoldPrice[count]!
        : GameConfig.gachaGemPrice[count]!;
    final walletKey = currency == 'gold' ? 'gold' : 'gems';
    final available = user[walletKey] as int;
    if (available < price) {
      throw LocalApiError(
        402,
        'INSUFFICIENT_FUNDS',
        'Saldo tidak cukup',
        <String, dynamic>{
          'currency': currency,
          'required': price,
          'available': available,
        },
      );
    }

    final pool = _catalog
        .where((c) => c['obtainable'] == true && c['retired'] != true)
        .toList();
    if (pool.isEmpty) {
      throw const LocalApiError(
        503,
        'CATALOG_UNAVAILABLE',
        'Katalog tidak punya kartu yang bisa di-pull',
      );
    }
    final byRarity = <String, List<Map<String, dynamic>>>{};
    for (final card in pool) {
      (byRarity[card['rarity'] as String] ??= <Map<String, dynamic>>[]).add(
        card,
      );
    }
    final availableRarities = byRarity.keys.toSet();

    final inventory = _list(state, 'inventory');
    final owned = inventory.map((row) => row['cardId']).toSet();
    final usedInBatch = <Object?>{};
    var pity = user['pityCounter'] as int;
    final results = <Map<String, dynamic>>[];

    Map<String, dynamic> pick(String rarity) {
      final bucket = byRarity[rarity]!;
      return bucket[_random.nextInt(bucket.length)];
    }

    for (var i = 0; i < count; i++) {
      final wasPity = pity >= GameConfig.pityThreshold - 1;
      var rarity = _weightedPick(wasPity ? pityWeights : rates);
      rarity = _fallbackRarity(rarity, availableRarities);
      final card = pick(rarity);
      final isNew =
          !owned.contains(card['id']) && !usedInBatch.contains(card['id']);
      usedInBatch.add(card['id']);
      pity = const <String>['Epic', 'Legendary', 'Master'].contains(rarity)
          ? 0
          : pity + 1;
      results.add(<String, dynamic>{
        'cardId': card['id'],
        'rarity': rarity,
        'isNew': isNew,
        'wasPity': wasPity,
        'guaranteedRare': false,
        'card': card,
      });
    }

    if (count == 10 &&
        !results.any((r) => _isRarePlus(r['rarity'] as String))) {
      final last = results.last;
      var target =
          last['wasPity'] == true ? _weightedPick(pityWeights) : 'Rare';
      target = _fallbackRarity(target, availableRarities);
      final card = pick(target);
      results[results.length - 1] = <String, dynamic>{
        ...last,
        'cardId': card['id'],
        'rarity': target,
        'card': card,
        'isNew':
            !owned.contains(card['id']) && !usedInBatch.contains(card['id']),
        'guaranteedRare': true,
      };
    }

    final now = _now();
    final batchId = 'bat_${_id()}';
    user[walletKey] = available - price;
    user['pityCounter'] = pity;
    for (final result in results) {
      final existing = inventory
          .where((row) => row['cardId'] == result['cardId'])
          .firstOrNull;
      if (existing != null) {
        existing['quantity'] = (existing['quantity'] as int) + 1;
      } else {
        inventory.add(<String, dynamic>{
          'cardId': result['cardId'],
          'quantity': 1,
          'firstSeenAt': now,
        });
      }
    }
    final pulls = _list(state, 'pulls');
    for (final (index, result) in results.indexed) {
      pulls.add(<String, dynamic>{
        'id': 'pul_${_id()}',
        'cardId': result['cardId'],
        'rarity': result['rarity'],
        'isNew': result['isNew'],
        'wasPity': result['wasPity'],
        'batchId': batchId,
        'idempotencyKey': index == 0 ? idempotencyKey : null,
        'createdAt': now,
      });
    }
    if (pulls.length > 500) pulls.removeRange(0, pulls.length - 500);
    await _save(state);

    return <String, dynamic>{
      'batchId': batchId,
      'results': results,
      'balance': <String, dynamic>{'gold': user['gold'], 'gems': user['gems']},
      'pity': _pityJson(pity),
      'replayed': false,
    };
  }

  Map<String, dynamic>? _replayPull(
    Map<String, dynamic> state,
    String idempotencyKey,
  ) {
    final pulls = _list(state, 'pulls');
    final first =
        pulls.where((p) => p['idempotencyKey'] == idempotencyKey).firstOrNull;
    if (first == null) return null;
    final user = state['user'] as Map<String, dynamic>;
    return <String, dynamic>{
      'batchId': first['batchId'],
      'results': <Map<String, dynamic>>[
        for (final p in pulls.where((p) => p['batchId'] == first['batchId']))
          <String, dynamic>{
            'cardId': p['cardId'],
            'rarity': p['rarity'],
            'isNew': p['isNew'],
            'wasPity': p['wasPity'],
            'guaranteedRare': false,
            'card': _byId[p['cardId']],
          },
      ],
      'balance': <String, dynamic>{'gold': user['gold'], 'gems': user['gems']},
      'pity': _pityJson(user['pityCounter'] as int),
      'replayed': true,
    };
  }

  Future<Map<String, dynamic>> _gachaHistory(Map<String, dynamic> query) async {
    final state = await _state();
    final pulls = _list(state, 'pulls').reversed.toList();
    return _page(
        query,
        pulls,
        (p) => <String, dynamic>{
              'id': p['id'],
              'cardId': p['cardId'],
              'rarity': p['rarity'],
              'isNew': p['isNew'],
              'wasPity': p['wasPity'],
              'batchId': p['batchId'],
              'createdAt': p['createdAt'],
              'card': _byId[p['cardId']],
            });
  }

  Map<String, dynamic> _page(
    Map<String, dynamic> query,
    List<Map<String, dynamic>> rows,
    Map<String, dynamic> Function(Map<String, dynamic>) shape,
  ) {
    final limit = (int.tryParse('${query['limit'] ?? 20}') ?? 20).clamp(1, 50);
    final cursor = query['cursor']?.toString();
    var start = 0;
    if (cursor != null && cursor.isNotEmpty) {
      final index = rows.indexWhere((r) => r['id'] == cursor);
      start = index < 0 ? rows.length : index + 1;
    }
    final page = rows.skip(start).take(limit).toList();
    final hasMore = start + limit < rows.length;
    return <String, dynamic>{
      'items': page.map(shape).toList(),
      'nextCursor': hasMore && page.isNotEmpty ? page.last['id'] : null,
    };
  }

  // ------------------------------------------------------------------ decks

  List<Map<String, dynamic>> _deckEntries(Map<String, dynamic> deck) =>
      (deck['cards'] as List<dynamic>).cast<Map<String, dynamic>>();

  Map<String, dynamic> _validate(
    List<Map<String, dynamic>> entries,
    Map<String, int> owned,
  ) {
    final violations = <Map<String, dynamic>>[];
    final seen = <String>{};
    final totals = <String, int>{};
    final curve = <String, int>{};
    var cardCount = 0;

    for (final entry in entries) {
      final cardId = '${entry['cardId']}';
      final qty = entry['quantity'];
      if (!seen.add(cardId)) {
        violations.add(<String, dynamic>{
          'code': 'DUPLICATE_ENTRY',
          'cardId': cardId,
          'message': 'Kartu muncul lebih dari satu baris di payload',
        });
      }
      if (qty is! int || qty < 1) {
        violations.add(<String, dynamic>{
          'code': 'COPY_LIMIT_EXCEEDED',
          'cardId': cardId,
          'message': 'Quantity harus minimal 1',
          'limit': GameConfig.maxCopiesPerCard,
        });
        continue;
      }
      final card = _byId[cardId];
      if (card == null) {
        violations.add(<String, dynamic>{
          'code': 'CARD_NOT_FOUND',
          'cardId': cardId,
          'message': 'Kartu tidak ada di katalog',
        });
        continue;
      }
      if (card['type'] != 'unit' && card['type'] != 'spell') {
        violations.add(<String, dynamic>{
          'code': 'CARD_NOT_PLAYABLE',
          'cardId': cardId,
          'message': 'Kartu tidak bisa dimainkan di deck',
        });
      }
      totals[cardId] = (totals[cardId] ?? 0) + qty;
      cardCount += qty;
      final cost = '${card['cost']}';
      curve[cost] = (curve[cost] ?? 0) + qty;
    }

    totals.forEach((cardId, total) {
      if (total > GameConfig.maxCopiesPerCard) {
        violations.add(<String, dynamic>{
          'code': 'COPY_LIMIT_EXCEEDED',
          'cardId': cardId,
          'message': 'Maksimal ${GameConfig.maxCopiesPerCard} copy per kartu',
          'actual': total,
          'limit': GameConfig.maxCopiesPerCard,
        });
      }
      final ownedQty = owned[cardId] ?? 0;
      if (ownedQty < total) {
        violations.add(<String, dynamic>{
          'code': 'CARD_NOT_OWNED',
          'cardId': cardId,
          'message': 'Jumlah kartu melebihi yang dimiliki',
          'actual': total,
          'limit': ownedQty,
        });
      }
    });

    if (cardCount != GameConfig.deckSize) {
      violations.add(<String, dynamic>{
        'code': 'DECK_SIZE',
        'message': 'Deck harus tepat ${GameConfig.deckSize} kartu',
        'actual': cardCount,
        'limit': GameConfig.deckSize,
      });
    }

    return <String, dynamic>{
      'valid': violations.isEmpty,
      'cardCount': cardCount,
      'violations': violations,
      'curve': curve,
    };
  }

  Map<String, int> _owned(Map<String, dynamic> state) => <String, int>{
        for (final row in _list(state, 'inventory'))
          row['cardId'] as String: row['quantity'] as int,
      };

  Map<String, dynamic> _shapeDeck(
    Map<String, dynamic> deck,
    Map<String, dynamic> validation,
  ) =>
      <String, dynamic>{
        'id': deck['id'],
        'name': deck['name'],
        'isActive': deck['isActive'],
        'cardCount': validation['cardCount'],
        'isValid': validation['valid'],
        'violations': validation['violations'],
        'curve': validation['curve'],
        'updatedAt': deck['updatedAt'],
        'cards': <Map<String, dynamic>>[
          for (final entry in _deckEntries(deck))
            <String, dynamic>{
              'cardId': entry['cardId'],
              'quantity': entry['quantity'],
              'card': _byId[entry['cardId']],
            },
        ],
      };

  Map<String, dynamic> _findDeck(Map<String, dynamic> state, String id) {
    final deck = _list(state, 'decks').where((d) => d['id'] == id).firstOrNull;
    if (deck == null) {
      throw const LocalApiError(404, 'NOT_FOUND', 'Deck tidak ditemukan');
    }
    return deck;
  }

  List<Map<String, dynamic>> _entriesFrom(Object? raw) {
    if (raw is! List) {
      throw const LocalApiError(400, 'VALIDATION_ERROR', 'cards wajib list');
    }
    return <Map<String, dynamic>>[
      for (final item in raw)
        if (item is Map)
          <String, dynamic>{
            'cardId': item['cardId'],
            'quantity': item['quantity']
          },
    ];
  }

  String _deckName(Object? raw) {
    final name = raw is String ? raw.trim() : '';
    if (name.length < 3 || name.length > 24) {
      throw const LocalApiError(
        400,
        'VALIDATION_ERROR',
        'Nama deck 3–24 karakter',
      );
    }
    return name;
  }

  void _rejectInvalid(Map<String, dynamic> validation) {
    if (validation['valid'] != true) {
      throw LocalApiError(
        422,
        'DECK_INVALID',
        'Deck tidak valid',
        <String, dynamic>{
          'violations': validation['violations'],
          'cardCount': validation['cardCount'],
        },
      );
    }
  }

  void _assertUniqueName(
    Map<String, dynamic> state,
    String name, {
    String? exceptId,
  }) {
    final taken = _list(
      state,
      'decks',
    ).any((d) => d['name'] == name && d['id'] != exceptId);
    if (taken) {
      throw const LocalApiError(
        409,
        'DECK_NAME_TAKEN',
        'Nama deck sudah dipakai',
      );
    }
  }

  Future<Map<String, dynamic>> _listDecks() async {
    final state = await _state();
    final owned = _owned(state);
    final decks = List<Map<String, dynamic>>.from(_list(state, 'decks'))
      ..sort((a, b) {
        if (a['isActive'] != b['isActive']) {
          return a['isActive'] == true ? -1 : 1;
        }
        return (b['updatedAt'] as String).compareTo(a['updatedAt'] as String);
      });
    return <String, dynamic>{
      'decks': <Map<String, dynamic>>[
        for (final deck in decks)
          _shapeDeck(deck, _validate(_deckEntries(deck), owned)),
      ],
    };
  }

  Future<Map<String, dynamic>> _getDeck(String id) async {
    final state = await _state();
    final deck = _findDeck(state, id);
    return _shapeDeck(deck, _validate(_deckEntries(deck), _owned(state)));
  }

  Future<Map<String, dynamic>> _createDeck(Map<String, dynamic> body) async {
    final state = await _state();
    final name = _deckName(body['name']);
    final entries = _entriesFrom(body['cards']);
    final validation = _validate(entries, _owned(state));
    _rejectInvalid(validation);
    final decks = _list(state, 'decks');
    if (decks.length >= GameConfig.maxDecks) {
      throw const LocalApiError(
        422,
        'DECK_INVALID',
        'Maksimal ${GameConfig.maxDecks} deck per akun',
        <String, dynamic>{
          'violations': <Map<String, dynamic>>[
            <String, dynamic>{
              'code': 'DECK_LIMIT_REACHED',
              'message': 'Maksimal ${GameConfig.maxDecks} deck',
              'limit': GameConfig.maxDecks,
            },
          ],
        },
      );
    }
    _assertUniqueName(state, name);
    final deck = <String, dynamic>{
      'id': 'deck_${_id()}',
      'name': name,
      'isActive': decks.isEmpty,
      'updatedAt': _now(),
      'cards': entries,
    };
    decks.add(deck);
    if (deck['isActive'] == true) {
      (state['user'] as Map<String, dynamic>)['activeDeckId'] = deck['id'];
    }
    await _save(state);
    return <String, dynamic>{'deck': _shapeDeck(deck, validation)};
  }

  Future<Map<String, dynamic>> _updateDeck(
    String id,
    Map<String, dynamic> body,
  ) async {
    final state = await _state();
    final deck = _findDeck(state, id);
    if (!body.containsKey('name') && !body.containsKey('cards')) {
      throw const LocalApiError(
        400,
        'VALIDATION_ERROR',
        'Kirim minimal satu field: name atau cards',
      );
    }
    if (body.containsKey('cards')) {
      final entries = _entriesFrom(body['cards']);
      _rejectInvalid(_validate(entries, _owned(state)));
      deck['cards'] = entries;
    }
    if (body.containsKey('name')) {
      final name = _deckName(body['name']);
      _assertUniqueName(state, name, exceptId: id);
      deck['name'] = name;
    }
    deck['updatedAt'] = _now();
    await _save(state);
    return <String, dynamic>{
      'deck': _shapeDeck(deck, _validate(_deckEntries(deck), _owned(state))),
    };
  }

  Future<Map<String, dynamic>> _activateDeck(String id) async {
    final state = await _state();
    final target = _findDeck(state, id);
    for (final deck in _list(state, 'decks')) {
      deck['isActive'] = identical(deck, target);
    }
    (state['user'] as Map<String, dynamic>)['activeDeckId'] = id;
    await _save(state);
    return <String, dynamic>{
      'activeDeckId': id,
      'deck':
          _shapeDeck(target, _validate(_deckEntries(target), _owned(state))),
    };
  }

  Future<Map<String, dynamic>> _deleteDeck(String id) async {
    final state = await _state();
    final deck = _findDeck(state, id);
    _list(state, 'decks').remove(deck);
    final user = state['user'] as Map<String, dynamic>;
    if (user['activeDeckId'] == id) user['activeDeckId'] = null;
    await _save(state);
    return <String, dynamic>{};
  }

  // ----------------------------------------------------------------- battle

  static const Map<String, String> _rarityCap = <String, String>{
    'easy': 'Rare',
    'medium': 'Epic',
    'master': 'Master',
  };

  List<Map<String, dynamic>> _fillDeck(
    List<Map<String, dynamic>> pool,
    int target,
    math.Random rng, [
    List<Map<String, dynamic>> existing = const <Map<String, dynamic>>[],
  ]) {
    final out = List<Map<String, dynamic>>.from(existing);
    if (pool.isEmpty) return out;
    final counts = <Object?, int>{};
    for (final card in existing) {
      counts[card['id']] = (counts[card['id']] ?? 0) + 1;
    }
    final shuffled = List<Map<String, dynamic>>.from(pool)..shuffle(rng);
    for (var copy = 0; copy < GameConfig.maxCopiesPerCard; copy++) {
      for (final card in shuffled) {
        if (out.length >= target) return out;
        final used = counts[card['id']] ?? 0;
        if (used > copy || used >= GameConfig.maxCopiesPerCard) continue;
        counts[card['id']] = used + 1;
        out.add(card);
      }
    }
    return out;
  }

  List<Map<String, dynamic>> _botDeck(String difficulty, int seed) {
    final rng = math.Random(seed);
    final maxIndex = GameConfig.rarities.indexOf(_rarityCap[difficulty]!);
    final pool = _catalog
        .where(
          (c) =>
              c['obtainable'] == true &&
              c['retired'] != true &&
              GameConfig.rarities.indexOf(c['rarity'] as String) <= maxIndex,
        )
        .toList();
    var deck = _fillDeck(
      pool.where((c) => c['type'] == 'unit').toList(),
      15,
      rng,
    );
    deck = _fillDeck(
      pool.where((c) => c['type'] == 'spell').toList(),
      GameConfig.deckSize,
      rng,
      deck,
    );
    if (deck.length < GameConfig.deckSize) {
      deck = _fillDeck(pool, GameConfig.deckSize, rng, deck);
    }
    deck.shuffle(rng);
    return deck.take(GameConfig.deckSize).toList();
  }

  Future<Map<String, dynamic>> _startBattle(Map<String, dynamic> body) async {
    final difficulty = body['difficulty'];
    if (difficulty is! String || !_rarityCap.containsKey(difficulty)) {
      throw const LocalApiError(
        400,
        'VALIDATION_ERROR',
        'difficulty harus easy/medium/master',
      );
    }
    final state = await _state();
    final user = state['user'] as Map<String, dynamic>;
    final deckId =
        (body['deckId'] as String?) ?? user['activeDeckId'] as String?;
    if (deckId == null) {
      throw const LocalApiError(
        422,
        'DECK_INVALID',
        'Pilih deck aktif terlebih dahulu',
      );
    }
    final deck = _findDeck(state, deckId);
    final validation = _validate(_deckEntries(deck), _owned(state));
    if (validation['valid'] != true) {
      throw LocalApiError(
        422,
        'DECK_INVALID',
        'Deck aktif tidak valid',
        <String, dynamic>{'violations': validation['violations']},
      );
    }
    final cards = <Map<String, dynamic>>[
      for (final entry in _deckEntries(deck))
        for (var i = 0; i < (entry['quantity'] as int); i++)
          _byId[entry['cardId']]!,
    ];

    final seed = 1 + _random.nextInt(2147483646);
    final botCards = _botDeck(difficulty, seed);
    if (botCards.length != GameConfig.deckSize) {
      throw const LocalApiError(
        503,
        'CATALOG_UNAVAILABLE',
        'Katalog tidak cukup untuk menyusun deck bot',
      );
    }

    final now = _now();
    final matchId = 'mat_${_id()}';
    final matches = _list(state, 'matches');
    matches.add(<String, dynamic>{
      'id': matchId,
      'difficulty': difficulty,
      'seed': seed,
      'outcome': 'pending',
      'turns': 0,
      'durationMs': 0,
      'goldAwarded': 0,
      'xpAwarded': 0,
      'firstWinBonus': false,
      'reportedAt': null,
      'createdAt': now,
    });
    if (matches.length > 200) matches.removeRange(0, matches.length - 200);
    await _save(state);

    return <String, dynamic>{
      'matchId': matchId,
      'seed': seed,
      'difficulty': difficulty,
      'startedAt': now,
      'catalogVersion': _catalogVersion,
      'engineVersion': '1.0.0',
      'playerDeck': <String, dynamic>{
        'deckId': deck['id'],
        'name': deck['name'],
        'cards': cards,
      },
      'botDeck': <String, dynamic>{
        'name': 'Bot $difficulty',
        'cards': botCards
      },
      'config': <String, dynamic>{
        'playerHp': GameConfig.playerHp,
        'maxEnergy': GameConfig.maxEnergy,
        'startingEnergy': GameConfig.startingEnergy,
        'boardSlots': GameConfig.boardSlots,
        'startingHand': GameConfig.startingHand,
        'handLimit': GameConfig.handLimit,
        'maxTurns': GameConfig.maxTurns,
      },
    };
  }

  Future<Map<String, dynamic>> _reportResult(
    String matchId,
    Map<String, dynamic> body,
  ) async {
    final outcome = body['outcome'];
    final turns = body['turns'];
    final durationMs = body['durationMs'];
    if (!const <String>['win', 'loss', 'draw'].contains(outcome) ||
        turns is! int ||
        durationMs is! int) {
      throw const LocalApiError(400, 'VALIDATION_ERROR', 'Hasil tidak valid');
    }
    final state = await _state();
    final user = state['user'] as Map<String, dynamic>;
    final match = _list(
      state,
      'matches',
    ).where((m) => m['id'] == matchId).firstOrNull;
    if (match == null) {
      throw const LocalApiError(404, 'NOT_FOUND', 'Match tidak ditemukan');
    }

    var levelUp = <String, dynamic>{'levelsGained': 0, 'gold': 0, 'gems': 0};
    var capped = false;
    final alreadyReported = match['outcome'] != 'pending';

    if (!alreadyReported) {
      if (turns < 1 || turns > GameConfig.maxTurns) {
        throw const LocalApiError(400, 'VALIDATION_ERROR', 'turns harus 1..50');
      }
      final now = DateTime.now();
      final dayStart = _startOfWibDay(now);
      final rewardedToday = _list(state, 'matches').where((m) {
        final at = _date(m['reportedAt']);
        return at != null &&
            !at.isBefore(dayStart) &&
            (m['goldAwarded'] as int) > 0;
      }).length;
      capped = rewardedToday >= dailyRewardedMatchLimit;

      final difficulty = match['difficulty'] as String;
      final base = outcome == 'win'
          ? GameConfig.battleRewards[difficulty]!
          : (
              gold: 0,
              xp: outcome == 'loss' ? GameConfig.lossXp : GameConfig.drawXp
            );
      final gold = capped ? 0 : base.gold;
      final xp = capped ? 0 : base.xp;
      final bonus = !capped &&
              outcome == 'win' &&
              !_sameWibDay(_date(user['lastFirstWinAt']), now)
          ? GameConfig.firstWinBonusGold
          : 0;

      var level = user['level'] as int;
      var xpNow = (user['xp'] as int) + xp;
      var gained = 0;
      while (xpNow >= GameConfig.xpToNext(level) && gained < 100) {
        xpNow -= GameConfig.xpToNext(level);
        level += 1;
        gained += 1;
      }
      levelUp = <String, dynamic>{
        'levelsGained': gained,
        'gold': gained * levelUpGold,
        'gems': gained * levelUpGems,
      };

      match
        ..['outcome'] = outcome
        ..['turns'] = turns
        ..['durationMs'] = durationMs
        ..['goldAwarded'] = gold + bonus
        ..['xpAwarded'] = xp
        ..['firstWinBonus'] = bonus > 0
        ..['reportedAt'] = now.toUtc().toIso8601String();

      user
        ..['gold'] = (user['gold'] as int) + gold + bonus + gained * levelUpGold
        ..['gems'] = (user['gems'] as int) + gained * levelUpGems
        ..['xp'] = xpNow
        ..['level'] = level
        ..['wins'] = (user['wins'] as int) + (outcome == 'win' ? 1 : 0)
        ..['losses'] = (user['losses'] as int) + (outcome == 'loss' ? 1 : 0)
        ..['draws'] = (user['draws'] as int) + (outcome == 'draw' ? 1 : 0);
      if (bonus > 0) user['lastFirstWinAt'] = now.toUtc().toIso8601String();
      await _save(state);
    }

    return <String, dynamic>{
      'matchId': matchId,
      'alreadyReported': alreadyReported,
      'outcome': match['outcome'],
      'rewards': <String, dynamic>{
        'gold': match['goldAwarded'],
        'xp': match['xpAwarded'],
        'firstWinBonus': match['firstWinBonus'],
        'capped': capped,
      },
      'levelUp': levelUp,
      'stats': _stats(user),
      'balance': <String, dynamic>{'gold': user['gold'], 'gems': user['gems']},
      'user': _publicUser(state),
    };
  }

  Future<Map<String, dynamic>> _battleHistory(
      Map<String, dynamic> query) async {
    final state = await _state();
    final rows = _list(
      state,
      'matches',
    ).where((m) => m['outcome'] != 'pending').toList().reversed.toList();
    return _page(
        query,
        rows,
        (m) => <String, dynamic>{
              'matchId': m['id'],
              'difficulty': m['difficulty'],
              'outcome': m['outcome'],
              'turns': m['turns'],
              'durationMs': m['durationMs'],
              'goldAwarded': m['goldAwarded'],
              'xpAwarded': m['xpAwarded'],
              'firstWinBonus': m['firstWinBonus'],
              'reportedAt': m['reportedAt'],
              'createdAt': m['createdAt'],
            });
  }

  // ------------------------------------------------------------------ utils

  List<Map<String, dynamic>> _list(Map<String, dynamic> state, String key) {
    final raw = state[key];
    if (raw is List<Map<String, dynamic>>) return raw;
    final list = <Map<String, dynamic>>[
      if (raw is List)
        for (final item in raw)
          if (item is Map) Map<String, dynamic>.from(item),
    ];
    state[key] = list;
    return list;
  }

  DateTime? _date(Object? raw) => raw is String ? DateTime.tryParse(raw) : null;

  static const Duration _wibOffset = Duration(hours: 7);

  String _wibDayKey(DateTime date) =>
      date.toUtc().add(_wibOffset).toIso8601String().substring(0, 10);

  DateTime _startOfWibDay(DateTime date) {
    final wib = date.toUtc().add(_wibOffset);
    return DateTime.utc(wib.year, wib.month, wib.day).subtract(_wibOffset);
  }

  bool _sameWibDay(DateTime? a, DateTime b) =>
      a != null && _wibDayKey(a) == _wibDayKey(b);

  bool _isYesterdayWib(DateTime previous, DateTime now) =>
      _wibDayKey(previous.add(const Duration(days: 1))) == _wibDayKey(now);
}
