import 'package:get_storage/get_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_repository.dart';

/// Real backend implementation of [AppRepository] (#19).
///
/// Reads/writes Supabase (`init.sql` schema) and maps the snake_case DB columns
/// into the EXACT camelCase + `_id` map shapes the UI already consumes (the same
/// shapes [MockData] produces) — so no screen or model changes are needed.
///
/// Conventions honoured:
///  • session dates stay UTC-midnight (`YYYY-MM-DDT00:00:00.000Z`) — never
///    `.toLocal()` (see core/utils/session_time.dart).
///  • writes stamp identity from the auth session so RLS passes
///    (athletes.parent_id / bookings.searcher_id = current user id).
///  • every method is wrapped: on failure it returns empty/clean data so the UI
///    renders its existing empty states instead of crashing.
///
/// A few list-replace writes inherited from the mock surface (chat persistence,
/// favourites, notification prefs, the legacy auth flags) have no dedicated
/// table; those are kept local (GetStorage) or safe no-ops and are noted inline.
class SupabaseRepository implements AppRepository {
  SupabaseRepository();

  SupabaseClient get _db => Supabase.instance.client;
  final GetStorage _local = GetStorage();

  String? get _uid => _db.auth.currentUser?.id;

  static final RegExp _uuidRe = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
  bool _isUuid(Object? v) => v is String && _uuidRe.hasMatch(v);

  /// A DB `date`/`timestamp` → the app's UTC-midnight ISO string.
  String? _utcMidnight(dynamic d) {
    if (d == null) return null;
    final s = d.toString();
    if (s.isEmpty) return null;
    // start_date comes back as 'YYYY-MM-DD'; keep the calendar day, pin to UTC.
    final dayOnly = s.length >= 10 ? s.substring(0, 10) : s;
    return '${dayOnly}T00:00:00.000Z';
  }

  double _toD(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
  List<dynamic> _toList(dynamic v) => v is List ? v : const [];

  String? _extractId(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    if (v is Map) return (v['_id'] ?? v['id'])?.toString();
    return null;
  }

  // ── Mappers: DB row (snake_case) → UI map (camelCase + _id) ───────────────

  Map<String, dynamic> _mapProgram(Map row) {
    final prov = row['providers'];
    return {
      '_id': row['id'],
      'coverImage': row['cover_image'],
      'title': row['title'],
      'description': row['description'],
      'sportType': row['sport_type'],
      'skillLevel': row['skill_level'],
      'ageGroup': row['age_group'],
      'language': row['language'],
      'price': _toD(row['price']),
      'currency': row['currency'],
      'pricingModel': row['pricing_model'],
      'maxCapacity': row['max_capacity'],
      'enrolledCount': row['enrolled_count'],
      'gallery': _toList(row['gallery']),
      'whatsIncluded': _toList(row['whats_included']),
      'location': {
        'type': 'Point',
        'coordinates': [row['longitude'], row['latitude']],
      },
      'address': {
        'line1': row['address_line1'],
        'city': row['city'],
        'state': row['state'],
        'zip': row['zip'],
        'country': row['country'],
      },
      'cancellationPolicy': row['cancellation_policy'],
      'minimumAge': row['minimum_age'],
      'maximumAge': row['maximum_age'],
      'isFeatured': row['is_featured'] ?? false,
      'status': row['status'],
      'averageRating': _toD(row['average_rating']),
      'totalReviews': row['total_reviews'] ?? 0,
      'providerId': prov is Map
          ? {
              'businessName': prov['business_name'],
              'verificationStatus': prov['verification_status'],
            }
          : null,
    };
  }

  Map<String, dynamic> _mapSession(Map row) {
    final iso = _utcMidnight(row['start_date']);
    return {
      '_id': row['id'],
      'programId': row['program_id'],
      'title': row['title'],
      'startDate': iso,
      'endDate': _utcMidnight(row['end_date']),
      'date': iso,
      'startTime': row['start_time'],
      'endTime': row['end_time'],
      'timezone': row['timezone'],
      'address': row['address'],
    };
  }

  Map<String, dynamic> _mapBooking(Map row) {
    final sess = row['sessions'];
    final prog = sess is Map ? sess['programs'] : null;
    final ath = row['athletes'];
    return {
      '_id': row['id'],
      'searcherId': row['searcher_id'],
      'athleteId': ath is Map
          ? {
              '_id': row['athlete_id'],
              'fullName':
                  '${ath['first_name'] ?? ''} ${ath['last_name'] ?? ''}'.trim(),
              'profileImage': ath['profile_image'],
            }
          : {
              '_id': row['athlete_id'],
              'fullName': row['athlete_first_name'] ?? '',
            },
      'programId': prog is Map
          ? {'_id': prog['id'], 'title': prog['title']}
          : row['program_id'],
      'sessionId': sess is Map
          ? {
              '_id': sess['id'],
              'title': sess['title'],
              'date': _utcMidnight(sess['start_date']),
              'startDate': _utcMidnight(sess['start_date']),
              'startTime': sess['start_time'],
              'programId': sess['program_id'],
            }
          : null,
      'selectedTier': row['selected_tier'],
      'originalPrice': _toD(row['original_price']),
      'finalPrice': _toD(row['final_price']),
      'currency': row['currency'],
      'status': row['status'],
      'paymentStatus': row['payment_status'],
      'createdAt': row['created_at'],
    };
  }

  Map<String, dynamic> _mapAthlete(Map row) => {
        '_id': row['id'],
        'firstName': row['first_name'],
        'lastName': row['last_name'],
        'fullName':
            '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'.trim(),
        'dateOfBirth': _utcMidnight(row['date_of_birth']),
        'gender': row['gender'],
        'preferredSports': _toList(row['preferred_sports']),
        'medicalConditions': row['medical_conditions'],
        'emergencyContact': row['emergency_contact'],
        'profileImage': row['profile_image'],
      };

  Map<String, dynamic> _mapUserProfile(Map row) => {
        '_id': row['id'],
        'firstName': row['first_name'],
        'lastName': row['last_name'],
        'email': row['email'],
        'role': row['role'],
        'phoneNumber': row['phone_number'],
        'preferredSports': _toList(row['preferred_sports']),
        'profileImage': row['profile_image'],
      };

  Map<String, dynamic> _mapProviderProfile(Map row) => {
        '_id': row['id'],
        'userId': row['owner_id'],
        'businessName': row['business_name'],
        'bio': row['bio'],
        'sports': _toList(row['sports']),
        'location': row['location'],
        'status': row['status'],
        'onboardingCompleted': row['onboarding_completed'] ?? false,
        'verificationStatus': row['verification_status'],
        'stripeAccountId': row['stripe_account_id'],
      };

  // ── Programs & sessions ───────────────────────────────────────────────────
  @override
  Future<List<dynamic>> getPrograms() async {
    try {
      final rows = await _db
          .from('programs')
          .select('*, providers(business_name, verification_status)');
      return (rows as List).map((r) => _mapProgram(r as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<dynamic>> getSessions() async {
    try {
      final rows = await _db.from('sessions').select();
      return (rows as List).map((r) => _mapSession(r as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Best-effort upsert of a provider's programs (read-modify-write of the whole
  /// list, mock-style). New rows get the caller's provider_id so RLS passes.
  @override
  Future<void> savePrograms(List<dynamic> programs) async {
    try {
      final providerId = await _currentProviderId();
      if (providerId == null) return;
      for (final p in programs) {
        if (p is! Map) continue;
        final row = _programToRow(p, providerId);
        await _db.from('programs').upsert(row);
      }
    } catch (_) {/* never crash the UI */}
  }

  @override
  Future<void> saveSessions(List<dynamic> sessions) async {
    try {
      for (final s in sessions) {
        if (s is! Map) continue;
        final row = _sessionToRow(s);
        if (row['program_id'] == null) continue; // can't satisfy the FK
        await _db.from('sessions').upsert(row);
      }
    } catch (_) {/* never crash the UI */}
  }

  // ── Bookings ──────────────────────────────────────────────────────────────
  @override
  Future<List<dynamic>> getBookings() async {
    try {
      final rows = await _db.from('bookings').select(
          '*, sessions(*, programs(*)), athletes(first_name,last_name,profile_image)');
      return (rows as List).map((r) => _mapBooking(r as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveBookings(List<dynamic> bookings) async {
    // No wholesale replace against a shared table; individual creation goes
    // through addBooking. Intentionally a no-op (status changes are #20).
  }

  @override
  Future<void> addBooking(Map<String, dynamic> booking) async {
    try {
      final uid = _uid;
      if (uid == null) return;
      final programId = _extractId(booking['programId']);
      var sessionId = _extractId(booking['sessionId']);
      // The demo flow invents a synthetic session id; resolve a REAL session for
      // the program so the FK + RLS pass.
      if (!_isUuid(sessionId) && programId != null) {
        final rows = await _db
            .from('sessions')
            .select('id, start_date')
            .eq('program_id', programId)
            .order('start_date')
            .limit(1);
        if (rows is List && rows.isNotEmpty) {
          sessionId = (rows.first as Map)['id']?.toString();
        }
      }
      if (!_isUuid(sessionId)) return; // nothing valid to attach to
      await _db.from('bookings').insert({
        'searcher_id': uid,
        'session_id': sessionId,
        if (_isUuid(programId)) 'program_id': programId,
        'selected_tier': booking['selectedTier'],
        'original_price': booking['originalPrice'] ?? 0,
        'final_price': booking['finalPrice'] ?? 0,
        'currency': booking['currency'] ?? 'USD',
        'status': booking['status'] ?? 'pending',
        'payment_status': booking['paymentStatus'] ?? 'unpaid',
      });
    } catch (_) {/* never crash the booking UI */}
  }

  // ── Profiles ──────────────────────────────────────────────────────────────
  @override
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final uid = _uid;
      if (uid == null) return {};
      final row =
          await _db.from('profiles').select().eq('id', uid).maybeSingle();
      return row == null ? {} : _mapUserProfile(row);
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    try {
      final uid = _uid;
      if (uid == null) return;
      await _db.from('profiles').update({
        if (profile['firstName'] != null) 'first_name': profile['firstName'],
        if (profile['lastName'] != null) 'last_name': profile['lastName'],
        if (profile['phoneNumber'] != null)
          'phone_number': profile['phoneNumber'],
        if (profile['preferredSports'] != null)
          'preferred_sports': profile['preferredSports'],
        if (profile['profileImage'] != null)
          'profile_image': profile['profileImage'],
      }).eq('id', uid);
    } catch (_) {/* never crash the UI */}
  }

  @override
  Future<Map<String, dynamic>> getProviderProfile() async {
    try {
      final uid = _uid;
      if (uid == null) return {};
      final row = await _db
          .from('providers')
          .select()
          .eq('owner_id', uid)
          .maybeSingle();
      return row == null ? {} : _mapProviderProfile(row);
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> saveProviderProfile(Map<String, dynamic> profile) async {
    try {
      final uid = _uid;
      if (uid == null) return;
      final row = <String, dynamic>{
        'owner_id': uid,
        if (profile['businessName'] != null)
          'business_name': profile['businessName'],
        if (profile['bio'] != null) 'bio': profile['bio'],
        if (profile['sports'] != null) 'sports': profile['sports'],
        if (profile['location'] != null) 'location': profile['location'],
        if (profile['status'] != null) 'status': profile['status'],
        if (profile['onboardingCompleted'] != null)
          'onboarding_completed': profile['onboardingCompleted'],
      };
      await _db.from('providers').upsert(row, onConflict: 'owner_id');
    } catch (_) {/* never crash the UI */}
  }

  // ── Athletes ──────────────────────────────────────────────────────────────
  @override
  Future<List<dynamic>> getAthletes() async {
    try {
      final rows = await _db.from('athletes').select();
      return (rows as List).map((r) => _mapAthlete(r as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveAthletes(List<dynamic> athletes) async {
    try {
      final uid = _uid;
      if (uid == null) return;
      for (final a in athletes) {
        if (a is! Map) continue;
        final row = _athleteToRow(a, uid);
        // Existing rows (real uuid) update; new rows insert under this parent.
        if (_isUuid(a['_id'])) {
          await _db.from('athletes').upsert(row);
        } else {
          await _db.from('athletes').insert(row);
        }
      }
    } catch (_) {/* never crash the UI */}
  }

  // ── Conversations & messages ──────────────────────────────────────────────
  // Real chat needs conversation rows keyed by searcher/provider profile ids,
  // which the current mock chat shape doesn't carry. Reads are wired; writes are
  // safe no-ops for now (ChatProvider keeps its in-session copy). Full chat
  // persistence is a follow-up, not part of #19's data flip.
  @override
  Future<List<dynamic>> getConversations() async {
    try {
      final rows = await _db
          .from('conversations')
          .select()
          .order('last_message_at', ascending: false);
      return (rows as List)
          .map((r) => {
                '_id': (r as Map)['id'],
                'programId': r['program_id'],
                'participants': const [],
                'lastMessage': r['last_message'] == null
                    ? null
                    : {'text': r['last_message']},
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveConversations(List<dynamic> conversations) async {}

  @override
  Future<List<dynamic>> getMessages(String conversationId) async {
    try {
      if (!_isUuid(conversationId)) return [];
      final rows = await _db
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at');
      return (rows as List)
          .map((r) => {
                '_id': (r as Map)['id'],
                'conversationId': r['conversation_id'],
                'text': r['body'],
                'senderId': r['sender_id'],
                'createdAt': r['created_at'],
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveMessages(String conversationId, List<dynamic> messages) async {}

  // ── Teams ─────────────────────────────────────────────────────────────────
  @override
  Future<List<dynamic>> getTeams() async {
    try {
      final rows = await _db.from('teams').select('*, team_athletes(*)');
      return (rows as List).map((r) {
        final m = r as Map;
        final roster = _toList(m['team_athletes']).map((ta) {
          final t = ta as Map;
          return {
            '_id': t['athlete_id'],
            'fullName': '',
            'jerseyNumber': t['jersey_number'],
            'isAvailable': t['is_available'] ?? true,
            'isPaid': t['is_paid'] ?? false,
          };
        }).toList();
        return {
          '_id': m['id'],
          'name': m['name'],
          'sport': m['sport'],
          'roster': roster,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveTeams(List<dynamic> teams) async {}

  // ── Notifications ─────────────────────────────────────────────────────────
  @override
  Future<Map<String, dynamic>> getNotificationPrefs() async {
    final data = _local.read('notification_prefs');
    return data == null ? {} : Map<String, dynamic>.from(data);
  }

  @override
  Future<void> saveNotificationPrefs(Map<String, dynamic> prefs) async =>
      _local.write('notification_prefs', prefs);

  @override
  Future<List<dynamic>> getNotifications() async {
    try {
      final rows = await _db
          .from('notifications')
          .select()
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => {
                '_id': (r as Map)['id'],
                'title': r['title'],
                'message': r['message'],
                'isRead': r['read'] ?? false,
                'createdAt': r['created_at'],
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveNotifications(List<dynamic> notifications) async {}

  // ── Auth/session legacy flags (no DB table; kept local) ───────────────────
  @override
  Future<bool> isLoggedIn() async => _db.auth.currentSession != null;
  @override
  Future<void> setLoggedIn(bool value) async {}
  @override
  Future<String> getActiveRole() async =>
      (_db.auth.currentUser?.userMetadata?['role'] as String?) ?? 'searcher';
  @override
  Future<void> setActiveRole(String role) async {}
  @override
  Future<List<String>> getFavorites() async {
    final favs = _local.read('favorites');
    return favs == null ? <String>[] : List<String>.from(favs);
  }

  @override
  Future<void> saveFavorites(List<String> favorites) async =>
      _local.write('favorites', favorites);

  // ── Reverse mappers: UI map (camelCase) → DB row (snake_case) ─────────────
  Future<String?> _currentProviderId() async {
    try {
      final uid = _uid;
      if (uid == null) return null;
      final row = await _db
          .from('providers')
          .select('id')
          .eq('owner_id', uid)
          .maybeSingle();
      return (row as Map?)?['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _programToRow(Map p, String providerId) {
    final addr = p['address'];
    final loc = p['location'];
    final coords = (loc is Map && loc['coordinates'] is List)
        ? loc['coordinates'] as List
        : const [];
    return {
      if (_isUuid(p['_id'])) 'id': p['_id'],
      'provider_id': providerId,
      'title': p['title'] ?? 'Untitled',
      'description': p['description'],
      'sport_type': p['sportType'] ?? 'Soccer',
      'skill_level': p['skillLevel'],
      'age_group': p['ageGroup'],
      if (p['language'] != null) 'language': p['language'],
      'cover_image': p['coverImage'],
      if (p['gallery'] != null) 'gallery': p['gallery'],
      if (p['whatsIncluded'] != null) 'whats_included': p['whatsIncluded'],
      'price': p['price'] ?? 0,
      if (p['currency'] != null) 'currency': p['currency'],
      if (p['pricingModel'] != null) 'pricing_model': p['pricingModel'],
      'max_capacity': p['maxCapacity'] ?? 0,
      'enrolled_count': p['enrolledCount'] ?? 0,
      if (coords.length == 2) 'longitude': coords[0],
      if (coords.length == 2) 'latitude': coords[1],
      if (addr is Map) 'address_line1': addr['line1'],
      if (addr is Map) 'city': addr['city'],
      if (addr is Map) 'state': addr['state'],
      if (addr is Map) 'zip': addr['zip'],
      if (addr is Map) 'country': addr['country'],
      if (p['cancellationPolicy'] != null)
        'cancellation_policy': p['cancellationPolicy'],
      'minimum_age': p['minimumAge'],
      'maximum_age': p['maximumAge'],
      'is_featured': p['isFeatured'] ?? false,
      'status': p['status'] ?? 'draft',
    };
  }

  Map<String, dynamic> _sessionToRow(Map s) {
    String? dateOnly(dynamic v) =>
        v == null ? null : v.toString().substring(0, 10);
    return {
      if (_isUuid(s['_id'])) 'id': s['_id'],
      'program_id': _extractId(s['programId']),
      'title': s['title'],
      'start_date': dateOnly(s['startDate'] ?? s['date']),
      'end_date': dateOnly(s['endDate']),
      'start_time': s['startTime'],
      'end_time': s['endTime'],
      'timezone': s['timezone'],
      'address': s['address'],
    };
  }

  Map<String, dynamic> _athleteToRow(Map a, String parentId) {
    const validGenders = {'male', 'female', 'other', 'prefer_not_to_say'};
    String? dob = a['dateOfBirth']?.toString();
    if (dob != null && dob.length >= 10) dob = dob.substring(0, 10);
    final gender = a['gender']?.toString();
    return {
      if (_isUuid(a['_id'])) 'id': a['_id'],
      'parent_id': parentId,
      'first_name': a['firstName'] ?? 'Athlete',
      'last_name': a['lastName'],
      'date_of_birth': dob,
      if (gender != null && validGenders.contains(gender)) 'gender': gender,
      if (a['preferredSports'] != null) 'preferred_sports': a['preferredSports'],
      'medical_conditions': a['medicalConditions'],
      if (a['emergencyContact'] != null)
        'emergency_contact': a['emergencyContact'],
      'profile_image': a['profileImage'],
    };
  }
}
