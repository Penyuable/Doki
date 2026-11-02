import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../../domain/models/deck_model.dart';

class DeckRepository {
  DeckRepository(this._api);

  final ApiClient _api;

  Future<List<DeckModel>> list() async {
    final data = await _api.get('/decks');
    return data
        .listOf('decks')
        .map((value) => DeckModel.fromJson(asJsonMap(value)))
        .toList(growable: false);
  }

  Future<DeckModel> get(String id) async {
    final data = await _api.get('/decks/$id');
    return DeckModel.fromJson(data.objectOf('deck'));
  }

  Future<DeckModel> create({
    required String name,
    required Map<String, int> cards,
  }) async {
    final data = await _api.post(
      '/decks',
      body: <String, dynamic>{'name': name, 'cards': _cardsPayload(cards)},
    );
    return DeckModel.fromJson(data.objectOf('deck'));
  }

  Future<DeckModel> update({
    required String id,
    required String name,
    required Map<String, int> cards,
  }) async {
    final data = await _api.patch(
      '/decks/$id',
      body: <String, dynamic>{'name': name, 'cards': _cardsPayload(cards)},
    );
    return DeckModel.fromJson(data.objectOf('deck'));
  }

  Future<DeckModel> activate(String id) async {
    final data = await _api.put('/decks/$id/activate');
    return DeckModel.fromJson(data.objectOf('deck'));
  }

  Future<void> delete(String id) => _api.delete('/decks/$id');

  List<Map<String, dynamic>> _cardsPayload(Map<String, int> cards) {
    final entries = cards.entries
        .where((entry) => entry.value > 0)
        .map(
          (entry) => <String, dynamic>{
            'cardId': entry.key,
            'quantity': entry.value,
          },
        )
        .toList(growable: false);
    return entries;
  }
}
