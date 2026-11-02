import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../../domain/models/battle_api_models.dart';

class BattleRepository {
  BattleRepository(this._api);

  final ApiClient _api;

  Future<BattleStartData> start({
    required String difficulty,
    String? deckId,
  }) async {
    final data = await _api.post(
      '/battles/start',
      body: <String, dynamic>{
        'difficulty': difficulty,
        if (deckId != null) 'deckId': deckId,
      },
    );
    return BattleStartData.fromJson(data);
  }

  Future<BattleResultData> submitResult({
    required String matchId,
    required String outcome,
    required int turns,
    required int durationMs,
    required String logHash,
  }) async {
    final data = await _api.post(
      '/battles/$matchId/result',
      body: <String, dynamic>{
        'outcome': outcome,
        'turns': turns,
        'durationMs': durationMs,
        'logHash': logHash,
        'engineVersion': '1.0.0',
      },
    );
    return BattleResultData.fromJson(data);
  }

  Future<List<BattleHistoryItem>> history({int limit = 20}) async {
    final data = await _api.get(
      '/battles/history',
      query: <String, dynamic>{'limit': limit},
    );
    return data
        .listOf('items')
        .map((value) => BattleHistoryItem.fromJson(asJsonMap(value)))
        .toList(growable: false);
  }
}
