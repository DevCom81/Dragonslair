import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import 'game_access.dart';

abstract interface class EntitlementRepository {
  Future<UserEntitlement> fetchCurrent(String userId);
  Future<DemoSession?> fetchDemoSession(String userId);
  Future<DemoPlayResult> ensureDemoPlay(String roomId);
}

final entitlementRepositoryProvider = Provider<EntitlementRepository>((ref) {
  return SupabaseEntitlementRepository(ref.watch(supabaseClientProvider));
});

class SupabaseEntitlementRepository implements EntitlementRepository {
  const SupabaseEntitlementRepository(this._client);

  final SupabaseClient? _client;

  @override
  Future<UserEntitlement> fetchCurrent(String userId) async {
    final client = _client;
    if (client == null) {
      return UserEntitlement.demoFor(userId);
    }
    try {
      final rows = await client
          .from('user_entitlements')
          .select()
          .eq('user_id', userId)
          .limit(1);
      if (rows.isEmpty) {
        return UserEntitlement.demoFor(userId);
      }
      return UserEntitlement.fromJson(rows.first);
    } on PostgrestException {
      return UserEntitlement.demoFor(userId);
    }
  }

  @override
  Future<DemoSession?> fetchDemoSession(String userId) async {
    final client = _client;
    if (client == null) {
      return null;
    }
    try {
      final rows = await client
          .from('demo_sessions')
          .select()
          .eq('user_id', userId)
          .limit(1);
      if (rows.isEmpty) {
        return null;
      }
      return DemoSession.fromJson(rows.first);
    } on PostgrestException {
      return null;
    }
  }

  @override
  Future<DemoPlayResult> ensureDemoPlay(String roomId) async {
    final client = _client;
    if (client == null) {
      return DemoPlayResult.ok;
    }
    try {
      final raw = await client.rpc(
        'ensure_demo_play',
        params: {'target_room_id': roomId},
      );
      return DemoPlayResult.fromJson(raw);
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST202' ||
          error.message.contains('ensure_demo_play')) {
        return DemoPlayResult.ok;
      }
      throw GameException(error.message, cause: error);
    }
  }
}
