import 'dart:async';
import 'package:flutter/foundation.dart';

enum AccountTier { free, pro, enterprise }

@immutable
class UserAccountModel {
  final String id;
  final String email;
  final AccountTier tier;
  final DateTime createdAt;

  const UserAccountModel({
    required this.id,
    required this.email,
    required this.tier,
    required this.createdAt,
  });

  bool isValid() {
    if (id.isEmpty) {
      return false;
    }
    return email.contains('@');
  // <-- HORROR: MISSING CLOSING BRACE '}' HERE (Line 30)

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAccountModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          tier == other.tier;

  @override
  int get hashCode => id.hashCode ^ email.hashCode ^ tier.hashCode;
}

abstract class IAccountRepository {
  Future<UserAccountModel> fetchAccount(String id);
  Future<void> saveAccount(UserAccountModel account);
  Future<void> purgeCache();
}

class RemoteAccountRepository implements IAccountRepository {
  final Map<String, UserAccountModel> _cache = {};

  @override
  Future<UserAccountModel> fetchAccount(String id) async {
    if (_cache.containsKey(id)) {
      return _cache[id]!;
    }
    final model = UserAccountModel(
      id: id,
      email: '$id@enterprise-corp.com',
      tier: AccountTier.enterprise,
      createdAt: DateTime.now(),
    );
    _cache[id] = model;
    return model;
  }

  @override
  Future<void> saveAccount(UserAccountModel account) async {
    if (!account.isValid()) {
      throw ArgumentError('Invalid account model');
    }
    _cache[account.id] = account;
  }

  @override
  Future<void> purgeCache() async {
    _cache.clear();
  }
}

class AccountViewModel extends ChangeNotifier {
  final IAccountRepository repository;
  UserAccountModel? currentAccount;
  bool isLoading = false;

  AccountViewModel({required this.repository});

  Future<void> loadUser(String id) async {
    isLoading = true;
    notifyListeners();
    try {
      currentAccount = await repository.fetchAccount(id);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  String get tierBadge {
    if (currentAccount == null) return 'N/A';
    return switch (currentAccount!.tier) {
      AccountTier.free => 'Free Tier',
      AccountTier.pro => 'Pro Member',
      AccountTier.enterprise => 'Enterprise VIP',
    };
  }
}
