import '../../core/network/api_client.dart';
import '../../domain/models/user_model.dart';

class UserRepository {
  UserRepository(this._api);

  final ApiClient _api;

  Future<UserProfile> profile() async {
    final data = await _api.get('/user/profile');
    return UserProfile.fromJson(data);
  }

  Future<WalletModel> wallet() async {
    final data = await _api.get('/user/wallet');
    return WalletModel.fromJson(data);
  }

  Future<DailyClaimResult> claimDaily() async {
    final data = await _api.post('/user/daily-claim');
    return DailyClaimResult.fromJson(data);
  }
}
