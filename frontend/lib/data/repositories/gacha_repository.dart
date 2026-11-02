import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../../domain/models/gacha_model.dart';

class GachaRepository {
  GachaRepository(this._api);

  final ApiClient _api;

  Future<GachaRatesData> rates() async {
    final data = await _api.get('/gacha/rates', auth: false);
    return GachaRatesData.fromJson(data);
  }

  Future<PityInfo> pity() async {
    final data = await _api.get('/gacha/pity');
    return PityInfo.fromJson(data);
  }

  Future<GachaPullResponse> pull({
    required int count,
    required String currency,
    required String idempotencyKey,
  }) async {
    final data = await _api.post(
      '/gacha/pull',
      body: <String, dynamic>{
        'count': count,
        'currency': currency,
        'idempotencyKey': idempotencyKey,
      },
    );
    return GachaPullResponse.fromJson(data);
  }

  Future<List<GachaHistoryEntry>> history({int limit = 20}) async {
    final data = await _api.get(
      '/gacha/history',
      query: <String, dynamic>{'limit': limit},
    );
    return data
        .listOf('items')
        .map((value) => GachaHistoryEntry.fromJson(asJsonMap(value)))
        .toList(growable: false);
  }
}
