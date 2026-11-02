import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/network/api_client.dart';
import '../../core/storage/app_storage.dart';
import '../../core/utils/json_utils.dart';
import '../../domain/models/card_model.dart';

enum CatalogSource { network, cache, bundled }

class CatalogSnapshot {
  CatalogSnapshot({
    required this.version,
    required this.cards,
    required this.source,
    this.fetchedAt,
  }) : byId = <String, CardModel>{for (final card in cards) card.id: card};

  final String version;
  final List<CardModel> cards;
  final CatalogSource source;
  final DateTime? fetchedAt;
  final Map<String, CardModel> byId;

  bool get isOffline => source != CatalogSource.network;

  List<CardModel> get playable =>
      cards.where((card) => !card.retired).toList(growable: false);
}

class CatalogRepository {
  CatalogRepository({required ApiClient api, required AppStorage storage})
    : _api = api,
      _storage = storage;

  static const String assetPath = 'assets/cards/cards.seed.json';

  final ApiClient _api;
  final AppStorage _storage;

  Future<CatalogSnapshot> load() async {
    try {
      final data = await _api.get('/catalog/cards', auth: false);
      final cards = CardModel.listFromJson(data['cards']);
      if (cards.isEmpty) {
        throw StateError('Katalog kosong');
      }
      final version = data.str('version', 'unknown');
      await _storage.writeCache(
        AppStorage.kCatalogPayload,
        jsonEncode(<String, dynamic>{
          'version': version,
          'cards': data['cards'],
        }),
      );
      await _storage.setValue(AppStorage.kCatalogVersion, version);
      return CatalogSnapshot(
        version: version,
        cards: cards,
        source: CatalogSource.network,
        fetchedAt: DateTime.now(),
      );
    } catch (_) {
      final cached = _readCache();
      if (cached != null) return cached;
      final bundled = await _readBundled();
      if (bundled != null) return bundled;
      rethrow;
    }
  }

  CatalogSnapshot? _readCache() {
    final raw = _storage.cacheString(AppStorage.kCatalogPayload);
    if (raw == null) return null;
    try {
      final json = asJsonMap(jsonDecode(raw));
      final cards = CardModel.listFromJson(json['cards']);
      if (cards.isEmpty) return null;
      return CatalogSnapshot(
        version: json.str('version', 'cache'),
        cards: cards,
        source: CatalogSource.cache,
      );
    } catch (_) {
      return null;
    }
  }

  Future<CatalogSnapshot?> _readBundled() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final cards = CardModel.listFromJson(jsonDecode(raw));
      if (cards.isEmpty) return null;
      return CatalogSnapshot(
        version: 'bundled',
        cards: cards,
        source: CatalogSource.bundled,
      );
    } catch (_) {
      return null;
    }
  }
}
