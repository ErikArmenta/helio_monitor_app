import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reading.dart';

class SupabaseService {
  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isAvailable => _client != null;

  Future<List<Reading>> fetchAllReadings() async {
    if (!isAvailable) return [];
    final response = await _client!
        .from('v_readings_full')
        .select()
        .order('marca_temporal', ascending: false);
    return (response as List).map((r) => Reading.fromSupabase(r)).toList();
  }

  Future<List<Reading>> fetchReadingsSince(DateTime since) async {
    if (!isAvailable) return [];
    final response = await _client!
        .from('v_readings_full')
        .select()
        .gte('marca_temporal', since.toIso8601String())
        .order('marca_temporal', ascending: false);
    return (response as List).map((r) => Reading.fromSupabase(r)).toList();
  }

  Future<String?> insertReading(Reading reading) async {
    if (!isAvailable) return null;
    final response = await _client!
        .from('readings')
        .insert(reading.toSupabaseMap())
        .select('id')
        .single();
    return response['id'] as String;
  }

  Future<void> upsertReading(Reading reading) async {
    if (!isAvailable) return;
    await _client!
        .from('readings')
        .upsert(reading.toSupabaseMap(), onConflict: 'local_id');
  }

  Future<List<Map<String, dynamic>>> fetchAlerts({bool unacknowledgedOnly = true}) async {
    if (!isAvailable) return [];
    var query = _client!.from('alerts').select();
    if (unacknowledgedOnly) {
      query = query.eq('acknowledged', false);
    }
    final response = await query.order('sent_at', ascending: false).limit(50);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> acknowledgeAlert(String alertId, String acknowledgedBy) async {
    if (!isAvailable) return;
    await _client!.from('alerts').update({
      'acknowledged': true,
      'acknowledged_by': acknowledgedBy,
      'acknowledged_at': DateTime.now().toIso8601String(),
    }).eq('id', alertId);
  }

  Future<List<Map<String, dynamic>>> fetchTechnicians() async {
    if (!isAvailable) return [];
    final response = await _client!
        .from('technicians')
        .select()
        .eq('active', true)
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  RealtimeChannel? subscribeToReadings(
      void Function(Map<String, dynamic>) onInsert) {
    if (!isAvailable) return null;
    return _client!
        .channel('readings_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'readings',
          callback: (payload) => onInsert(payload.newRecord),
        )
        .subscribe();
  }

  Future<void> saveChatMessage(
      String role, String content, String sessionId) async {
    if (!isAvailable) return;
    await _client!.from('chat_history').insert({
      'role': role,
      'content': content,
      'session_id': sessionId,
    });
  }
}
