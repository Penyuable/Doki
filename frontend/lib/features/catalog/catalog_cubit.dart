import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_exception.dart';
import '../../data/repositories/catalog_repository.dart';

sealed class CatalogState {
  const CatalogState();
}

class CatalogLoading extends CatalogState {
  const CatalogLoading();
}

class CatalogReady extends CatalogState {
  const CatalogReady(this.snapshot);

  final CatalogSnapshot snapshot;
}

class CatalogError extends CatalogState {
  const CatalogError(this.message);

  final String message;
}

class CatalogCubit extends Cubit<CatalogState> {
  CatalogCubit(this._repository) : super(const CatalogLoading());

  final CatalogRepository _repository;

  Future<void> load() async {
    emit(const CatalogLoading());
    try {
      final snapshot = await _repository.load();
      emit(CatalogReady(snapshot));
    } on ApiException catch (error) {
      emit(CatalogError(error.message));
    } catch (_) {
      emit(const CatalogError('Katalog gagal dimuat.'));
    }
  }

  CatalogSnapshot? get snapshot {
    final current = state;
    return current is CatalogReady ? current.snapshot : null;
  }
}
