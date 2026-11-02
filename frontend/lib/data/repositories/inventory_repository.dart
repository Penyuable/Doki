import 'dart:convert';

import '../../core/network/api_client.dart';
import '../../core/storage/app_storage.dart';
import '../../core/utils/json_utils.dart';
import '../../domain/models/inventory_model.dart';

class InventorySnapshot {
  const InventorySnapshot({required this.page, required this.offline});

  final InventoryPage page;
  final bool offline;
}

class InventoryRepository {
  InventoryRepository({required ApiClient api, required AppStorage storage})
    : _api = api,
      _storage = storage;

  final ApiClient _api;
  final AppStorage _storage;

  Future<InventorySnapshot> load({
    String? element,
    String? rarity,
    String? type,
    String sort = 'rarity',
  }) async {
    final query = <String, dynamic>{
      'limit': 100,
      'sort': sort,
      if (element != null) 'element': element,
      if (rarity != null) 'rarity': rarity,
      if (type != null) 'type': type,
    };

    try {
      final data = await _api.get('/inventory', query: query);
      final page = InventoryPage.fromJson(data);
      await _storage.writeCache(
        AppStorage.kInventoryPayload,
        jsonEncode(data),
      );
      return InventorySnapshot(page: page, offline: false);
    } catch (error) {
      final cached = _readCache();
      if (cached != null) {
        return InventorySnapshot(page: cached, offline: true);
      }
      rethrow;
    }
  }

  InventoryPage? _readCache() {
    final raw = _storage.cacheString(AppStorage.kInventoryPayload);
    if (raw == null) return null;
    try {
      final data = asJsonMap(jsonDecode(raw));
      final page = InventoryPage.fromJson(data);
      return page;
    } catch (_) {
      return null;
    }
  }
}
