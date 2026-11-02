import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_exception.dart';
import '../../data/repositories/deck_repository.dart';
import '../../domain/models/deck_model.dart';

sealed class DeckListState {
  const DeckListState();
}

class DeckListLoading extends DeckListState {
  const DeckListLoading();
}

class DeckListReady extends DeckListState {
  const DeckListReady({required this.decks, this.busyDeckId});

  final List<DeckModel> decks;
  final String? busyDeckId;

  DeckListReady copyWith({List<DeckModel>? decks, String? busyDeckId}) {
    return DeckListReady(
      decks: decks ?? this.decks,
      busyDeckId: busyDeckId,
    );
  }
}

class DeckListError extends DeckListState {
  const DeckListError(this.message);

  final String message;
}

class DeckListCubit extends Cubit<DeckListState> {
  DeckListCubit(this._repository) : super(const DeckListLoading());

  final DeckRepository _repository;

  Future<void> load() async {
    emit(const DeckListLoading());
    await _fetch();
  }

  Future<void> refresh() => _fetch();

  Future<void> _fetch() async {
    try {
      final decks = await _repository.list();
      emit(DeckListReady(decks: decks));
    } on ApiException catch (error) {
      emit(DeckListError(error.message));
    } catch (_) {
      emit(const DeckListError('Deck gagal dimuat.'));
    }
  }

  /// Mengembalikan pesan error (null = sukses).
  Future<String?> activate(String deckId) async {
    final current = state;
    if (current is! DeckListReady || current.busyDeckId != null) return null;

    emit(current.copyWith(busyDeckId: deckId));
    try {
      await _repository.activate(deckId);
      await _fetch();
      return null;
    } on ApiException catch (error) {
      emit(DeckListReady(decks: current.decks));
      return error.message;
    } catch (_) {
      emit(DeckListReady(decks: current.decks));
      return 'Deck gagal diaktifkan.';
    }
  }

  Future<String?> delete(String deckId) async {
    final current = state;
    if (current is! DeckListReady || current.busyDeckId != null) return null;

    emit(current.copyWith(busyDeckId: deckId));
    try {
      await _repository.delete(deckId);
      await _fetch();
      return null;
    } on ApiException catch (error) {
      emit(DeckListReady(decks: current.decks));
      return error.message;
    } catch (_) {
      emit(DeckListReady(decks: current.decks));
      return 'Deck gagal dihapus.';
    }
  }
}
