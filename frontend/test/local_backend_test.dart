import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:dokimon/core/config/game_config.dart';
import 'package:dokimon/data/local/local_backend.dart';
import 'package:dokimon/data/local/local_http_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

List<Map<String, dynamic>> _catalog() {
  final raw = File('assets/cards/cards.seed.json').readAsStringSync();
  return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
}

void main() {
  late Directory dir;
  late LocalBackend backend;
  var boxIndex = 0;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('dokimon_offline_test');
    Hive.init(dir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  setUp(() async {
    final box = await Hive.openBox<dynamic>('offline_${boxIndex++}');
    backend = await LocalBackend.create(
      catalog: _catalog(),
      box: box,
      random: math.Random(42),
    );
  });

  Future<Map<String, dynamic>> call(
    String method,
    String path, [
    Map<String, dynamic> body = const <String, dynamic>{},
    Map<String, dynamic> query = const <String, dynamic>{},
  ]) =>
      backend.handle(method, path, body, query);

  Future<LocalApiError> fails(
    String method,
    String path, [
    Map<String, dynamic> body = const <String, dynamic>{},
  ]) async {
    try {
      await call(method, path, body);
    } on LocalApiError catch (error) {
      return error;
    }
    fail('$method $path seharusnya gagal');
  }

  test('pemain baru otomatis (tanpa login): saldo awal + starter deck',
      () async {
    final session = await call('POST', '/auth/guest');
    expect(session['accessToken'], isNotEmpty);

    final me = await call('GET', '/auth/me');
    final user = me['user'] as Map<String, dynamic>;
    expect(user['gold'], LocalBackend.startingGold);
    expect(user['gems'], LocalBackend.startingGems);

    final decks = (await call('GET', '/decks'))['decks'] as List<dynamic>;
    final starter = decks.single as Map<String, dynamic>;
    expect(starter['isValid'], isTrue);
    expect(starter['cardCount'], GameConfig.deckSize);
    expect(me['activeDeckId'], starter['id']);
  });

  test('state tersimpan: guest kedua memakai pemain yang sama', () async {
    final first = await call('POST', '/auth/guest');
    final second = await call('POST', '/auth/guest');
    expect(
      (second['user'] as Map<String, dynamic>)['id'],
      (first['user'] as Map<String, dynamic>)['id'],
    );
  });

  test('pull 10x: potong harga, 10 kartu, minimal 1 Rare+, masuk inventory',
      () async {
    final result = await call('POST', '/gacha/pull', <String, dynamic>{
      'count': 10,
      'currency': 'gold',
    });
    final results = result['results'] as List<dynamic>;
    expect(results, hasLength(10));
    final rarePlus = results.where((r) {
      final rarity = (r as Map<String, dynamic>)['rarity'] as String;
      return GameConfig.rarities.indexOf(rarity) >=
          GameConfig.rarities.indexOf('Rare');
    });
    expect(rarePlus, isNotEmpty);
    expect(
      (result['balance'] as Map<String, dynamic>)['gold'],
      LocalBackend.startingGold - GameConfig.gachaGoldPrice[10]!,
    );

    final inventory = await call('GET', '/inventory');
    final total = (inventory['items'] as List<dynamic>).fold<int>(
      0,
      (sum, item) => sum + ((item as Map<String, dynamic>)['quantity'] as int),
    );
    expect(total, 20 + 10);
  });

  test('saldo kurang → INSUFFICIENT_FUNDS dan saldo tidak berubah', () async {
    // 50 gem awal cukup untuk 5x 10-pull (9 gem), ke-6 harus gagal.
    for (var i = 0; i < 5; i++) {
      await call('POST', '/gacha/pull', <String, dynamic>{
        'count': 10,
        'currency': 'gem',
      });
    }
    final error = await fails('POST', '/gacha/pull', <String, dynamic>{
      'count': 10,
      'currency': 'gem',
    });
    expect(error.code, 'INSUFFICIENT_FUNDS');
    expect(error.status, 402);
    final wallet = await call('GET', '/user/wallet');
    expect(wallet['gems'], 5);
  });

  test('pity: pull ke-50 (counter 49) dijamin Epic+ lalu reset ke 0', () async {
    await call('POST', '/auth/guest');
    // Simulasikan 49 pull tanpa Epic+ dengan mengatur state tersimpan.
    final box = Hive.box<dynamic>('offline_${boxIndex - 1}');
    final state =
        jsonDecode(box.get('state') as String) as Map<String, dynamic>;
    (state['user'] as Map<String, dynamic>)['pityCounter'] =
        GameConfig.pityThreshold - 1;
    await box.put('state', jsonEncode(state));

    final res = await call('POST', '/gacha/pull', <String, dynamic>{
      'count': 1,
      'currency': 'gold',
    });
    final pulled = (res['results'] as List<dynamic>).single as Map;
    expect(pulled['wasPity'], isTrue);
    expect(<String>['Epic', 'Legendary', 'Master'], contains(pulled['rarity']));
    expect((res['pity'] as Map<String, dynamic>)['counter'], 0);
  });

  test('idempotencyKey yang sama mengembalikan hasil yang sama', () async {
    final body = <String, dynamic>{
      'count': 1,
      'currency': 'gold',
      'idempotencyKey': 'key-1',
    };
    final first = await call('POST', '/gacha/pull', body);
    final second = await call('POST', '/gacha/pull', body);
    expect(second['replayed'], isTrue);
    expect(second['batchId'], first['batchId']);
    expect(
      (second['balance'] as Map<String, dynamic>)['gold'],
      (first['balance'] as Map<String, dynamic>)['gold'],
    );
  });

  test('deck ilegal ditolak (I-03)', () async {
    final error = await fails('POST', '/decks', <String, dynamic>{
      'name': 'Curang',
      'cards': <Map<String, dynamic>>[
        <String, dynamic>{'cardId': 'card_001', 'quantity': 4},
      ],
    });
    expect(error.code, 'DECK_INVALID');
    final codes = ((error.details! as Map<String, dynamic>)['violations']
            as List<dynamic>)
        .map((v) => (v as Map<String, dynamic>)['code'])
        .toSet();
    expect(codes, containsAll(<String>['COPY_LIMIT_EXCEEDED', 'DECK_SIZE']));
  });

  test('battle: start 20 vs 20, menang memberi reward + bonus sekali',
      () async {
    final start = await call('POST', '/battles/start', <String, dynamic>{
      'difficulty': 'easy',
    });
    expect(
      ((start['playerDeck'] as Map<String, dynamic>)['cards'] as List).length,
      GameConfig.deckSize,
    );
    expect(
      ((start['botDeck'] as Map<String, dynamic>)['cards'] as List).length,
      GameConfig.deckSize,
    );

    final matchId = start['matchId'] as String;
    final body = <String, dynamic>{
      'outcome': 'win',
      'turns': 8,
      'durationMs': 60000,
    };
    final result = await call('POST', '/battles/$matchId/result', body);
    final rewards = result['rewards'] as Map<String, dynamic>;
    expect(
      rewards['gold'],
      GameConfig.battleRewards['easy']!.gold + GameConfig.firstWinBonusGold,
    );
    expect(rewards['firstWinBonus'], isTrue);
    expect((result['stats'] as Map<String, dynamic>)['wins'], 1);

    final again = await call('POST', '/battles/$matchId/result', body);
    expect(again['alreadyReported'], isTrue);
    expect((again['stats'] as Map<String, dynamic>)['wins'], 1);
  });

  test('daily claim hanya sekali per hari', () async {
    final claim = await call('POST', '/user/daily-claim');
    expect(claim['day'], 1);
    expect(
      (claim['balance'] as Map<String, dynamic>)['gold'],
      LocalBackend.startingGold + GameConfig.dailyRewardGold.first,
    );
    final error = await fails('POST', '/user/daily-claim');
    expect(error.code, 'ALREADY_CLAIMED');
  });

  test('adapter Dio: envelope {data} dan {error} seperti server', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://offline.local/api/v1'))
      ..httpClientAdapter = LocalHttpAdapter(backend);

    final ok = await dio.get<dynamic>('/user/wallet');
    expect((ok.data as Map)['data'], containsPair('gold', 1000));

    try {
      await dio.get<dynamic>('/tidak-ada');
      fail('harus 404');
    } on DioException catch (error) {
      expect(error.response?.statusCode, 404);
      expect(
        ((error.response!.data as Map)['error'] as Map)['code'],
        'NOT_FOUND',
      );
    }
  });
}
