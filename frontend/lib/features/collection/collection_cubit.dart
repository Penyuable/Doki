import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_exception.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../domain/models/card_model.dart';
import '../../domain/models/inventory_model.dart';

enum CollectionSort {
  rarity,
  name,
  newest,
  attack,
  hp;

  String get i18nKey => 'collection.sort.$name';
}

class CollectionFilter {
  const CollectionFilter({
    this.element,
    this.rarity,
    this.type,
    this.ownedOnly,
    this.query = '',
    this.sort = CollectionSort.rarity,
  });

  final CardElement? element;
  final Rarity? rarity;
  final CardType? type;

  /// null = semua, true = hanya dimiliki, false = hanya belum dimiliki.
  final bool? ownedOnly;
  final String query;
  final CollectionSort sort;

  bool get isDefault =>
      element == null &&
      rarity == null &&
      type == null &&
      ownedOnly == null &&
      query.trim().isEmpty &&
      sort == CollectionSort.rarity;

  CollectionFilter copyWith({
    CardElement? element,
    Rarity? rarity,
    CardType? type,
    bool? ownedOnly,
    String? query,
    CollectionSort? sort,
    bool clearElement = false,
    bool clearRarity = false,
    bool clearType = false,
    bool clearOwnedOnly = false,
  }) {
    return CollectionFilter(
      element: clearElement ? null : (element ?? this.element),
      rarity: clearRarity ? null : (rarity ?? this.rarity),
      type: clearType ? null : (type ?? this.type),
      ownedOnly: clearOwnedOnly ? null : (ownedOnly ?? this.ownedOnly),
      query: query ?? this.query,
      sort: sort ?? this.sort,
    );
  }
}

sealed class CollectionState {
  const CollectionState();
}

class CollectionLoading extends CollectionState {
  const CollectionLoading();
}

class CollectionReady extends CollectionState {
  const CollectionReady({
    required this.items,
    required this.offline,
    this.filter = const CollectionFilter(),
  });

  final List<InventoryItem> items;
  final bool offline;
  final CollectionFilter filter;

  Map<String, int> get owned => <String, int>{
    for (final item in items) item.cardId: item.quantity,
  };

  Map<String, DateTime?> get firstSeen => <String, DateTime?>{
    for (final item in items) item.cardId: item.firstSeenAt,
  };

  CollectionReady copyWith({
    List<InventoryItem>? items,
    bool? offline,
    CollectionFilter? filter,
  }) {
    return CollectionReady(
      items: items ?? this.items,
      offline: offline ?? this.offline,
      filter: filter ?? this.filter,
    );
  }
}

class CollectionError extends CollectionState {
  const CollectionError(this.message);

  final String message;
}

class CollectionCubit extends Cubit<CollectionState> {
  CollectionCubit(this._repository) : super(const CollectionLoading());

  final InventoryRepository _repository;

  Future<void> load() async {
    emit(const CollectionLoading());
    await _fetch();
  }

  Future<void> refresh() => _fetch();

  Future<void> _fetch() async {
    final previous = state;
    final filter = previous is CollectionReady
        ? previous.filter
        : const CollectionFilter();
    try {
      final snapshot = await _repository.load(sort: 'rarity');
      emit(
        CollectionReady(
          items: snapshot.page.items,
          offline: snapshot.offline,
          filter: filter,
        ),
      );
    } on ApiException catch (error) {
      emit(CollectionError(error.message));
    } catch (_) {
      emit(const CollectionError('Koleksi gagal dimuat.'));
    }
  }

  CollectionFilter get _filter {
    final current = state;
    return current is CollectionReady
        ? current.filter
        : const CollectionFilter();
  }

  void _updateFilter(CollectionFilter filter) {
    final current = state;
    if (current is CollectionReady) {
      emit(current.copyWith(filter: filter));
    }
  }

  void setElement(CardElement? value) {
    _updateFilter(
      value == null
          ? _filter.copyWith(clearElement: true)
          : _filter.copyWith(element: value),
    );
  }

  void setRarity(Rarity? value) {
    _updateFilter(
      value == null
          ? _filter.copyWith(clearRarity: true)
          : _filter.copyWith(rarity: value),
    );
  }

  void setType(CardType? value) {
    _updateFilter(
      value == null
          ? _filter.copyWith(clearType: true)
          : _filter.copyWith(type: value),
    );
  }

  void setOwnedOnly(bool? value) {
    _updateFilter(
      value == null
          ? _filter.copyWith(clearOwnedOnly: true)
          : _filter.copyWith(ownedOnly: value),
    );
  }

  void setQuery(String value) => _updateFilter(_filter.copyWith(query: value));

  void setSort(CollectionSort value) =>
      _updateFilter(_filter.copyWith(sort: value));

  void resetFilter() {
    _updateFilter(CollectionFilter(sort: _filter.sort));
  }

  List<CardModel> applyFilter(
    List<CardModel> cards, {
    required Map<String, int> owned,
  }) {
    final filter = _filter;
    final query = filter.query.trim().toLowerCase();

    final result = cards.where((card) {
      if (card.retired) return false;
      final quantity = owned[card.id] ?? 0;
      if (filter.ownedOnly == true && quantity <= 0) return false;
      if (filter.ownedOnly == false && quantity > 0) return false;
      if (filter.element != null && card.element != filter.element) {
        return false;
      }
      if (filter.rarity != null && card.rarity != filter.rarity) return false;
      if (filter.type != null && card.type != filter.type) return false;
      if (query.isNotEmpty &&
          !card.name.toLowerCase().contains(query) &&
          !card.id.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList(growable: false);

    final dated = state is CollectionReady
        ? (state as CollectionReady).firstSeen
        : const <String, DateTime?>{};

    return List<CardModel>.from(result)
      ..sort((a, b) {
        switch (filter.sort) {
          case CollectionSort.rarity:
            final byRarity = b.rarity.index.compareTo(a.rarity.index);
            return byRarity != 0 ? byRarity : a.name.compareTo(b.name);
          case CollectionSort.name:
            return a.name.compareTo(b.name);
          case CollectionSort.newest:
            final aDate = dated[a.id];
            final bDate = dated[b.id];
            if (aDate == null && bDate == null) {
              return a.name.compareTo(b.name);
            }
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          case CollectionSort.attack:
            final byAttack = (b.attack ?? 0).compareTo(a.attack ?? 0);
            return byAttack != 0 ? byAttack : a.name.compareTo(b.name);
          case CollectionSort.hp:
            final byHp = (b.hp ?? 0).compareTo(a.hp ?? 0);
            return byHp != 0 ? byHp : a.name.compareTo(b.name);
        }
      });
  }
}
