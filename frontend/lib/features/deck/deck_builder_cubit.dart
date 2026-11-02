import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/game_config.dart';
import '../../core/network/api_exception.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../data/repositories/deck_repository.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../domain/deck_rules.dart';
import '../../domain/models/card_model.dart';
import '../../domain/models/deck_model.dart';

class DeckBuilderState {
  const DeckBuilderState({
    this.loading = true,
    this.loadError,
    this.deckId,
    this.name = '',
    this.entries = const <String, int>{},
    this.owned = const <String, int>{},
    this.catalog = const <String, CardModel>{},
    this.saving = false,
    this.saveError,
    this.saved = false,
  });

  final bool loading;
  final String? loadError;
  final String? deckId;
  final String name;
  final Map<String, int> entries;
  final Map<String, int> owned;
  final Map<String, CardModel> catalog;
  final bool saving;
  final String? saveError;
  final bool saved;

  int get totalCards =>
      entries.values.fold<int>(0, (sum, value) => sum + value);

  DeckValidationResult get validation => DeckRules.validate(
    entries: entries,
    owned: owned,
    catalog: catalog,
  );

  Map<int, int> get curve => validation.curve;

  bool get nameValid {
    final trimmed = name.trim();
    return trimmed.length >= 3 && trimmed.length <= 24;
  }

  bool get canSave =>
      !loading &&
      !saving &&
      nameValid &&
      validation.valid &&
      !saved;

  List<CardModel> get collectionCards {
    final cards = catalog.values
        .where((card) => !card.retired)
        .where((card) => (owned[card.id] ?? 0) > 0)
        .toList();
    cards.sort((a, b) {
      final byCost = a.cost.compareTo(b.cost);
      return byCost != 0 ? byCost : a.name.compareTo(b.name);
    });
    return cards;
  }

  bool canAdd(String cardId) =>
      DeckRules.canAdd(entries: entries, cardId: cardId, ownedCount: owned[cardId] ?? 0);

  DeckBuilderState copyWith({
    bool? loading,
    String? loadError,
    String? deckId,
    String? name,
    Map<String, int>? entries,
    Map<String, int>? owned,
    Map<String, CardModel>? catalog,
    bool? saving,
    String? saveError,
    bool? saved,
    bool clearLoadError = false,
    bool clearSaveError = false,
  }) {
    return DeckBuilderState(
      loading: loading ?? this.loading,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
      deckId: deckId ?? this.deckId,
      name: name ?? this.name,
      entries: entries ?? this.entries,
      owned: owned ?? this.owned,
      catalog: catalog ?? this.catalog,
      saving: saving ?? this.saving,
      saveError: clearSaveError ? null : (saveError ?? this.saveError),
      saved: saved ?? this.saved,
    );
  }
}

class DeckBuilderCubit extends Cubit<DeckBuilderState> {
  DeckBuilderCubit({
    required DeckRepository decks,
    required CatalogRepository catalog,
    required InventoryRepository inventory,
  }) : _decks = decks,
       _catalog = catalog,
       _inventory = inventory,
       super(const DeckBuilderState());

  final DeckRepository _decks;
  final CatalogRepository _catalog;
  final InventoryRepository _inventory;

  Future<void> init({String? deckId, String? initialCardId}) async {
    emit(const DeckBuilderState(loading: true));
    try {
      final catalogSnapshot = await _catalog.load();
      final inventorySnapshot = await _inventory.load();
      DeckModel? deck;
      List<DeckModel> decks = const <DeckModel>[];
      if (deckId != null) {
        deck = await _decks.get(deckId);
      } else {
        decks = await _decks.list();
      }

      final owned = <String, int>{
        for (final item in inventorySnapshot.page.items)
          item.cardId: item.quantity,
      };
      final catalog = catalogSnapshot.byId;
      final entries = <String, int>{...?deck?.entries};

      if (initialCardId != null &&
          DeckRules.canAdd(
            entries: entries,
            cardId: initialCardId,
            ownedCount: owned[initialCardId] ?? 0,
          )) {
        entries[initialCardId] = (entries[initialCardId] ?? 0) + 1;
      }

      emit(
        DeckBuilderState(
          loading: false,
          deckId: deck?.id,
          name: deck?.name ?? _defaultName(decks),
          entries: entries,
          owned: owned,
          catalog: catalog,
        ),
      );
    } on ApiException catch (error) {
      emit(
        DeckBuilderState(
          loading: false,
          loadError: error.message,
        ),
      );
    } catch (_) {
      emit(
        const DeckBuilderState(
          loading: false,
          loadError: 'Deck gagal dimuat.',
        ),
      );
    }
  }

  String _defaultName(List<DeckModel> decks) {
    final used = decks.map((deck) => deck.name.toLowerCase()).toSet();
    var index = decks.length + 1;
    var candidate = 'Deck $index';
    while (used.contains(candidate.toLowerCase())) {
      index += 1;
      candidate = 'Deck $index';
    }
    return candidate;
  }

  void setName(String value) {
    emit(
      state.copyWith(
        name: value,
        saved: false,
        clearSaveError: true,
      ),
    );
  }

  bool add(String cardId) {
    if (!state.canAdd(cardId)) return false;
    final entries = <String, int>{...state.entries};
    entries[cardId] = (entries[cardId] ?? 0) + 1;
    emit(state.copyWith(entries: entries, saved: false, clearSaveError: true));
    return true;
  }

  void remove(String cardId) {
    final current = state.entries[cardId] ?? 0;
    if (current <= 0) return;
    final entries = <String, int>{...state.entries};
    if (current == 1) {
      entries.remove(cardId);
    } else {
      entries[cardId] = current - 1;
    }
    emit(state.copyWith(entries: entries, saved: false, clearSaveError: true));
  }

  void clear() {
    emit(
      state.copyWith(
        entries: const <String, int>{},
        saved: false,
        clearSaveError: true,
      ),
    );
  }

  Future<bool> save() async {
    final current = state;
    if (!current.canSave) {
      if (!current.nameValid) {
        emit(current.copyWith(saveError: 'Nama deck 3–24 karakter'));
      }
      return false;
    }

    emit(current.copyWith(saving: true, clearSaveError: true));
    try {
      final DeckModel deck;
      if (current.deckId == null) {
        deck = await _decks.create(
          name: current.name.trim(),
          cards: current.entries,
        );
      } else {
        deck = await _decks.update(
          id: current.deckId!,
          name: current.name.trim(),
          cards: current.entries,
        );
      }
      emit(
        state.copyWith(
          saving: false,
          deckId: deck.id,
          name: deck.name,
          saved: true,
        ),
      );
      return true;
    } on ApiException catch (error) {
      emit(state.copyWith(saving: false, saveError: error.message));
      return false;
    } catch (_) {
      emit(state.copyWith(saving: false, saveError: 'Deck gagal disimpan.'));
      return false;
    }
  }

  /// Untuk menampilkan batas copy pada UI.
  int maxCopies() => GameConfig.maxCopiesPerCard;
}
