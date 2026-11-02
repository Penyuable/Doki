import '../../core/network/api_client.dart';
import '../../core/storage/app_storage.dart';
import '../../core/telemetry/telemetry_service.dart';
import 'auth_repository.dart';
import 'battle_repository.dart';
import 'catalog_repository.dart';
import 'deck_repository.dart';
import 'gacha_repository.dart';
import 'inventory_repository.dart';
import 'user_repository.dart';

class Repositories {
  Repositories({
    required this.auth,
    required this.catalog,
    required this.inventory,
    required this.gacha,
    required this.deck,
    required this.battle,
    required this.user,
    required this.telemetry,
  });

  factory Repositories.create({
    required ApiClient api,
    required AppStorage storage,
  }) {
    return Repositories(
      auth: AuthRepository(api),
      catalog: CatalogRepository(api: api, storage: storage),
      inventory: InventoryRepository(api: api, storage: storage),
      gacha: GachaRepository(api),
      deck: DeckRepository(api),
      battle: BattleRepository(api),
      user: UserRepository(api),
      telemetry: TelemetryService(api),
    );
  }

  final AuthRepository auth;
  final CatalogRepository catalog;
  final InventoryRepository inventory;
  final GachaRepository gacha;
  final DeckRepository deck;
  final BattleRepository battle;
  final UserRepository user;
  final TelemetryService telemetry;
}
