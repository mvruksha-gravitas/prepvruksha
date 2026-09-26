import 'package:core/core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads the user's own `profiles` row. RLS limits it to that row.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Profile?> fetchOwn() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('profiles')
        .select(
          'id, full_name, phone, preferred_language, date_of_birth, '
          'target_exam_year',
        )
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }
}
