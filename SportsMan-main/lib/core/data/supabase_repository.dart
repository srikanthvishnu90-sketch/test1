import 'package:flutter/foundation.dart';
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
/// favourites, notification prefs) have no dedicated table; those are kept local
/// (GetStorage) or safe no-ops and are noted inline. Auth state is NOT here — it
/// is owned by AuthProvider/AuthService (the Supabase session); see #18.
class SupabaseRepository implements AppRepository {
  SupabaseRepository();

  SupabaseClient get _db => Supabase.instance.client;
  final GetStorage _local = GetStorage();

  String? get _uid => _db.auth.currentUser?.id;

  static final RegExp _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
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
              'firstName': ath['first_name'] ?? row['athlete_first_name'] ?? '',
              'fullName': '${ath['first_name'] ?? ''} ${ath['last_name'] ?? ''}'
                  .trim(),
              'profileImage': ath['profile_image'],
            }
          : {
              '_id': row['athlete_id'],
              'firstName': row['athlete_first_name'] ?? '',
              'fullName': row['athlete_first_name'] ?? '',
            },
      'programId': prog is Map
          ? {
              '_id': prog['id'],
              'title': prog['title'],
              'sport': prog['sport_type'],
            }
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
      'stripeCheckoutSessionId': row['stripe_checkout_session_id'],
      'createdAt': row['created_at'],
    };
  }

  Map<String, dynamic> _mapAthlete(Map row) => {
    '_id': row['id'],
    'firstName': row['first_name'],
    'lastName': row['last_name'],
    'fullName': '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'.trim(),
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
    'stripeChargesEnabled': row['stripe_charges_enabled'] ?? false,
  };

  // ── Programs & sessions ───────────────────────────────────────────────────
  Future<List<dynamic>> _fetchPrograms() async {
    final rows = await _db
        .from('programs')
        .select('*, providers(business_name, verification_status)');
    return (rows as List).map((r) => _mapProgram(r as Map)).toList();
  }

  @override
  Future<List<dynamic>> getPrograms() async {
    try {
      return await _fetchPrograms();
    } catch (e) {
      debugPrint('SupabaseRepository read failed: $e');
      return [];
    }
  }

  @override
  Future<List<dynamic>> getProgramsOrThrow() => _fetchPrograms();

  @override
  Future<List<dynamic>> getSessions() async {
    try {
      final rows = await _db.from('sessions').select();
      return (rows as List).map((r) => _mapSession(r as Map)).toList();
    } catch (e) {
      debugPrint('SupabaseRepository read failed: $e');
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
    } catch (e) {
      debugPrint('SupabaseRepository write failed: $e');
    }
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
    } catch (e) {
      debugPrint('SupabaseRepository write failed: $e');
    }
  }

  // ── Bookings ──────────────────────────────────────────────────────────────
  Future<List<dynamic>> _fetchBookings() async {
    final rows = await _db
        .from('bookings')
        .select(
          '*, sessions(*, programs(*)), athletes(first_name,last_name,profile_image)',
        );
    return (rows as List).map((r) => _mapBooking(r as Map)).toList();
  }

  @override
  Future<List<dynamic>> getBookings() async {
    try {
      return await _fetchBookings();
    } catch (e) {
      debugPrint('SupabaseRepository read failed: $e');
      return [];
    }
  }

  @override
  Future<List<dynamic>> getBookingsOrThrow() => _fetchBookings();

  @override
  Future<void> saveBookings(List<dynamic> bookings) async {
    // No wholesale replace against a shared table; individual creation goes
    // through addBooking; status changes go through updateBookingStatus.
  }

  @override
  Future<bool> updateBookingStatus(String bookingId, String status) async {
    try {
      if (!_isUuid(bookingId)) return false;
      // Provider RLS + enforce_booking_provider_update pin this to `status`.
      await _db.from('bookings').update({'status': status}).eq('id', bookingId);
      return true;
    } on PostgrestException catch (e) {
      debugPrint('updateBookingStatus failed: ${e.message}');
      return false;
    }
  }

  @override
  Future<String?> addBooking(Map<String, dynamic> booking) async {
    // RLS WITH CHECK requires searcher_id = auth.uid(); no session => no insert.
    final uid = _db.auth.currentUser?.id;
    if (uid == null) {
      debugPrint('addBooking: no authenticated user — cannot insert booking');
      return null;
    }

    final programId = _extractId(booking['programId']);
    var sessionId = _extractId(booking['sessionId']);
    // The booking flow invents a synthetic session id; resolve a REAL session
    // for the program so the session_id FK is satisfied. Only consider FUTURE
    // (today-or-later) sessions so we never book one that already happened, and
    // pick the soonest. start_date is a calendar date; compare as 'YYYY-MM-DD'
    // (UTC-midnight convention — no .toLocal()).
    if (!_isUuid(sessionId) && programId != null) {
      try {
        final now = DateTime.now();
        final todayStr =
            '${now.year.toString().padLeft(4, '0')}-'
            '${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}';
        final rows = await _db
            .from('sessions')
            .select('id, start_date')
            .eq('program_id', programId)
            .gte('start_date', todayStr)
            .order('start_date')
            .limit(1);
        if (rows.isNotEmpty) {
          sessionId = (rows.first as Map)['id']?.toString();
        }
      } catch (e) {
        debugPrint('addBooking: session lookup failed: $e');
      }
    }
    if (!_isUuid(sessionId)) {
      debugPrint(
        'addBooking: no real session to book for program=$programId '
        '(is the database seeded?) — skipping insert',
      );
      return null;
    }

    final athleteId = _extractId(booking['athleteId']);
    // Every key below is a real `bookings` column. searcher_id MUST equal
    // auth.uid() (RLS). status MUST satisfy the CHECK
    // (pending|confirmed|declined|completed) — payment lives in the separate
    // payment_status column, which we let DEFAULT to 'unpaid'.
    final athleteName = booking['athleteName']?.toString();
    final payload = <String, dynamic>{
      'searcher_id': uid,
      'session_id': sessionId,
      if (_isUuid(programId)) 'program_id': programId,
      if (_isUuid(athleteId)) 'athlete_id': athleteId,
      if (athleteName != null && athleteName.isNotEmpty)
        'athlete_first_name': athleteName.split(' ').first,
      'selected_tier': booking['selectedTier'],
      'original_price': booking['originalPrice'] ?? 0,
      'final_price': booking['finalPrice'] ?? 0,
      'currency': booking['currency'] ?? 'USD',
      'status': 'pending',
    };

    try {
      final inserted = await _db
          .from('bookings')
          .insert(payload)
          .select('id')
          .single();
      return (inserted as Map)['id']?.toString();
    } on PostgrestException catch (e) {
      // Surface the REAL database reason rather than masking it as a generic
      // "could not create booking" — the caller shows e.message to the user.
      debugPrint(
        'addBooking PostgrestException: code=${e.code} '
        'message=${e.message} details=${e.details} hint=${e.hint}',
      );
      rethrow;
    }
  }

  // ── Session notes + parent updates (AI deliverable) ─────────────────────────
  @override
  Future<String?> createSessionNote(Map<String, dynamic> note) async {
    try {
      final providerId = await _currentProviderId();
      if (providerId == null) {
        debugPrint('createSessionNote: caller is not a provider');
        return null;
      }
      final payload = <String, dynamic>{
        'provider_id': providerId,
        'raw_notes': note['rawNotes'] ?? '',
        if (_isUuid(note['bookingId'])) 'booking_id': note['bookingId'],
        if (_isUuid(note['childId'])) 'child_id': note['childId'],
      };
      final inserted = await _db
          .from('session_notes')
          .insert(payload)
          .select('id')
          .single();
      return (inserted as Map)['id']?.toString();
    } on PostgrestException catch (e) {
      debugPrint('createSessionNote failed: ${e.message}');
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>> summarizeSessionNote(
    Map<String, dynamic> payload,
  ) async {
    try {
      final res = await _db.functions.invoke(
        'session-note-summarize',
        body: payload,
      );
      return Map<String, dynamic>.from((res.data as Map?) ?? {});
    } on FunctionException catch (e) {
      debugPrint('summarizeSessionNote FunctionException: ${e.status}');
      final det = e.details;
      if (det is Map && det['error'] != null) {
        return {'error': det['error'].toString()};
      }
      return {'error': 'Could not draft the update (status ${e.status}).'};
    } catch (e) {
      debugPrint('summarizeSessionNote failed: $e');
      return {'error': 'Could not draft the update. Please try again.'};
    }
  }

  // ── Lifecycle automated messaging (P4/P6) ─────────────────────────────────
  @override
  Future<List<Map<String, dynamic>>> getLifecyclePrefs() async {
    try {
      final providerId = await _currentProviderId();
      if (providerId == null) return [];
      final rows = await _db
          .from('lifecycle_message_prefs')
          .select('event_type, mode')
          .eq('provider_id', providerId);
      return (rows as List)
          .map((r) => {'eventType': r['event_type'], 'mode': r['mode']})
          .toList();
    } on PostgrestException catch (e) {
      debugPrint('getLifecyclePrefs failed: ${e.message}');
      return [];
    }
  }

  @override
  Future<bool> setLifecyclePref(String eventType, String mode) async {
    try {
      final providerId = await _currentProviderId();
      if (providerId == null) return false;
      // Upsert on (provider_id, event_type). The DB CHECK rejects 'auto' for
      // non-logistics types (surfaces as a PostgrestException -> false).
      await _db.from('lifecycle_message_prefs').upsert({
        'provider_id': providerId,
        'event_type': eventType,
        'mode': mode,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'provider_id,event_type');
      return true;
    } on PostgrestException catch (e) {
      debugPrint('setLifecyclePref rejected/failed: ${e.message}');
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getLifecycleDrafts() async {
    try {
      final providerId = await _currentProviderId();
      if (providerId == null) return [];
      final rows = await _db
          .from('outbound_messages')
          .select(
            'id, event_type, child_id, booking_id, content, scheduled_for, created_at',
          )
          .eq('provider_id', providerId)
          .eq('status', 'drafted')
          .order('created_at', ascending: false);
      return (rows as List).map((r) {
        final content = r['content'];
        return {
          'id': r['id'],
          'eventType': r['event_type'],
          'childId': r['child_id'],
          'bookingId': r['booking_id'],
          'body': (content is Map ? content['body'] : null)?.toString() ?? '',
          'scheduledFor': r['scheduled_for'],
        };
      }).toList();
    } on PostgrestException catch (e) {
      debugPrint('getLifecycleDrafts failed: ${e.message}');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> approveLifecycleMessage(
    String id, {
    String? body,
  }) async {
    try {
      final res = await _db.functions.invoke(
        'lifecycle-approve',
        body: {'id': id, 'body': ?body},
      );
      return Map<String, dynamic>.from((res.data as Map?) ?? {});
    } on FunctionException catch (e) {
      debugPrint('approveLifecycleMessage FunctionException: ${e.status}');
      final det = e.details;
      if (det is Map && det['error'] != null) {
        return {'error': det['error'].toString()};
      }
      return {'error': 'Could not send the message (status ${e.status}).'};
    } catch (e) {
      debugPrint('approveLifecycleMessage failed: $e');
      return {'error': 'Could not send the message. Please try again.'};
    }
  }

  // ── AI discovery (search-parse / search-execute) ────────────────────────────
  @override
  Future<Map<String, dynamic>> searchParse(
    String query, {
    Map<String, dynamic>? locationHint,
  }) async {
    try {
      final res = await _db.functions.invoke(
        'search-parse',
        body: {'query': query, 'parentLocationHint': ?locationHint},
      );
      return Map<String, dynamic>.from((res.data as Map?) ?? {});
    } on FunctionException catch (e) {
      debugPrint('searchParse FunctionException: ${e.status}');
      final det = e.details;
      if (det is Map && det['error'] != null) {
        return {'error': det['error'].toString()};
      }
      return {
        'error': 'Could not understand that search (status ${e.status}).',
      };
    } catch (e) {
      debugPrint('searchParse failed: $e');
      return {'error': 'Could not run that search. Please try again.'};
    }
  }

  @override
  Future<Map<String, dynamic>> searchExecute(
    Map<String, dynamic> constraints, {
    Map<String, dynamic>? locationHint,
  }) async {
    try {
      final res = await _db.functions.invoke(
        'search-execute',
        body: {'constraints': constraints, 'parentLocationHint': ?locationHint},
      );
      return Map<String, dynamic>.from((res.data as Map?) ?? {});
    } on FunctionException catch (e) {
      debugPrint('searchExecute FunctionException: ${e.status}');
      final det = e.details;
      if (det is Map && det['error'] != null) {
        return {'error': det['error'].toString()};
      }
      return {'error': 'Could not run that search (status ${e.status}).'};
    } catch (e) {
      debugPrint('searchExecute failed: $e');
      return {'error': 'Could not run that search. Please try again.'};
    }
  }

  @override
  Future<Map<String, dynamic>> draftMessage(
    Map<String, dynamic> payload,
  ) async {
    try {
      final providerId = await _currentProviderId();
      if (providerId == null) {
        return {'error': 'Only a coach can draft replies.'};
      }
      final body = <String, dynamic>{
        'providerId': providerId,
        'threadContext': payload['threadContext'] ?? const [],
        if (payload['intent'] != null) 'intent': payload['intent'],
        if (payload['childFirstName'] != null)
          'childFirstName': payload['childFirstName'],
        if (payload['bookingContext'] != null)
          'bookingContext': payload['bookingContext'],
      };
      final res = await _db.functions.invoke('message-draft', body: body);
      return Map<String, dynamic>.from((res.data as Map?) ?? {});
    } on FunctionException catch (e) {
      debugPrint('draftMessage FunctionException: ${e.status}');
      final det = e.details;
      if (det is Map && det['error'] != null) {
        return {'error': det['error'].toString()};
      }
      return {'error': 'Could not draft a reply (status ${e.status}).'};
    } catch (e) {
      debugPrint('draftMessage failed: $e');
      return {'error': 'Could not draft a reply. Please try again.'};
    }
  }

  @override
  Future<String?> upsertParentUpdateDraft(Map<String, dynamic> update) async {
    try {
      final providerId = await _currentProviderId();
      if (providerId == null) return null;
      final fields = <String, dynamic>{
        'provider_id': providerId,
        if (_isUuid(update['sessionNoteId']))
          'session_note_id': update['sessionNoteId'],
        if (_isUuid(update['bookingId'])) 'booking_id': update['bookingId'],
        if (_isUuid(update['childId'])) 'child_id': update['childId'],
        'summary_body': update['summaryBody'] ?? '',
        'skills_worked':
            (update['skillsWorked'] as List?)?.cast<String>() ?? <String>[],
        'progress_signal': update['progressSignal'] ?? '',
        'practice_suggestions':
            (update['practiceSuggestions'] as List?)?.cast<String>() ??
            <String>[],
        'encouragement': update['encouragement'] ?? '',
      };
      final id = update['id'];
      if (_isUuid(id)) {
        // Don't touch status on update — autosave must never revert an approval.
        await _db.from('parent_updates').update(fields).eq('id', id);
        return id.toString();
      }
      final inserted = await _db
          .from('parent_updates')
          .insert({...fields, 'status': 'draft'})
          .select('id')
          .single();
      return (inserted as Map)['id']?.toString();
    } on PostgrestException catch (e) {
      debugPrint('upsertParentUpdateDraft failed: ${e.message}');
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> approveParentUpdate(String id) async {
    try {
      final updated = await _db
          .from('parent_updates')
          .update({
            'status': 'approved',
            'approved_by': _uid,
            'approved_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .select()
          .single();
      return Map<String, dynamic>.from(updated as Map);
    } on PostgrestException catch (e) {
      debugPrint('approveParentUpdate failed: ${e.message}');
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>> sendParentUpdate(String id) async {
    try {
      final res = await _db.functions.invoke(
        'parent-update-send',
        body: {'parentUpdateId': id},
      );
      return Map<String, dynamic>.from((res.data as Map?) ?? {});
    } on FunctionException catch (e) {
      debugPrint('sendParentUpdate FunctionException: ${e.status}');
      final det = e.details;
      if (det is Map && det['error'] != null) {
        return {'error': det['error'].toString()};
      }
      return {'error': 'Could not send the update (status ${e.status}).'};
    } catch (e) {
      debugPrint('sendParentUpdate failed: $e');
      return {'error': 'Could not send the update. Please try again.'};
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getParentUpdatesForChild(
    String childId,
  ) async {
    try {
      final uid = _uid;
      if (uid == null || !_isUuid(childId)) return [];
      // Defense in depth on top of RLS: confirm the caller actually guards this
      // child before querying, then constrain to that child's SENT rows only.
      final child = await _db
          .from('athletes')
          .select('id')
          .eq('id', childId)
          .eq('parent_id', uid)
          .maybeSingle();
      if (child == null) return [];
      final rows = await _db
          .from('parent_updates')
          .select(
            'id, child_id, summary_body, skills_worked, progress_signal, practice_suggestions, encouragement, status, sent_at, created_at',
          )
          .eq('child_id', childId)
          .eq('status', 'sent')
          .order('created_at', ascending: false);
      return (rows as List).map((r) => _mapParentUpdate(r as Map)).toList();
    } catch (e) {
      debugPrint('getParentUpdatesForChild failed: $e');
      return [];
    }
  }

  Map<String, dynamic> _mapParentUpdate(Map row) => {
    '_id': row['id'],
    'childId': row['child_id'],
    'summaryBody': row['summary_body'] ?? '',
    'skillsWorked': _toList(row['skills_worked']),
    'progressSignal': row['progress_signal'] ?? '',
    'practiceSuggestions': _toList(row['practice_suggestions']),
    'encouragement': row['encouragement'] ?? '',
    'status': row['status'],
    'sentAt': row['sent_at'],
    'createdAt': row['created_at'],
  };

  // ── Profiles ──────────────────────────────────────────────────────────────
  @override
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final uid = _uid;
      if (uid == null) return {};
      final row = await _db
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      return row == null ? {} : _mapUserProfile(row);
    } catch (e) {
      debugPrint('SupabaseRepository read failed: $e');
      return {};
    }
  }

  @override
  Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    try {
      final uid = _uid;
      if (uid == null) return;
      await _db
          .from('profiles')
          .update({
            if (profile['firstName'] != null)
              'first_name': profile['firstName'],
            if (profile['lastName'] != null) 'last_name': profile['lastName'],
            if (profile['email'] != null) 'email': profile['email'],
            if (profile['phoneNumber'] != null)
              'phone_number': profile['phoneNumber'],
            if (profile['preferredSports'] != null)
              'preferred_sports': profile['preferredSports'],
            if (profile['profileImage'] != null)
              'profile_image': profile['profileImage'],
          })
          .eq('id', uid);
    } catch (e) {
      debugPrint('saveUserProfile failed: $e');
      rethrow; // let the caller surface a real error
    }
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
    } catch (e) {
      debugPrint('SupabaseRepository read failed: $e');
      return {};
    }
  }

  @override
  Future<void> saveProviderProfile(Map<String, dynamic> profile) async {
    try {
      final uid = _uid;
      if (uid == null) return;
      // Only the fields the caller actually provided.
      final fields = <String, dynamic>{
        if (profile['businessName'] != null)
          'business_name': profile['businessName'],
        if (profile['bio'] != null) 'bio': profile['bio'],
        if (profile['sports'] != null) 'sports': profile['sports'],
        if (profile['location'] != null) 'location': profile['location'],
        if (profile['status'] != null) 'status': profile['status'],
        if (profile['onboardingCompleted'] != null)
          'onboarding_completed': profile['onboardingCompleted'],
      };
      // UPDATE the existing provider row (the edit case) — a partial edit must
      // NOT require business_name. Only INSERT a new row when none exists yet
      // (e.g. onboarding), where business_name is mandatory.
      final updated = await _db
          .from('providers')
          .update(fields)
          .eq('owner_id', uid)
          .select('id');
      if ((updated as List).isEmpty) {
        await _db.from('providers').insert({
          'owner_id': uid,
          'business_name': profile['businessName'] ?? 'My Academy',
          ...fields,
        });
      }
    } catch (e) {
      debugPrint('saveProviderProfile failed: $e');
      rethrow; // let the caller surface a real error
    }
  }

  // ── Athletes ──────────────────────────────────────────────────────────────
  @override
  Future<List<dynamic>> getAthletes() async {
    try {
      final rows = await _db.from('athletes').select();
      return (rows as List).map((r) => _mapAthlete(r as Map)).toList();
    } catch (e) {
      debugPrint('SupabaseRepository read failed: $e');
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
    } catch (e) {
      debugPrint('SupabaseRepository write failed: $e');
    }
  }

  // ── Conversations & messages ──────────────────────────────────────────────
  // Real chat needs conversation rows keyed by searcher/provider profile ids,
  // which the current mock chat shape doesn't carry. Reads are wired; writes are
  // safe no-ops for now (ChatProvider keeps its in-session copy). Full chat
  // persistence is a follow-up, not part of #19's data flip.
  Future<List<dynamic>> _fetchConversations() async {
    final rows = await _db
        .from('conversations')
        .select()
        .order('last_message_at', ascending: false);
    return (rows as List)
        .map(
          (r) => {
            '_id': (r as Map)['id'],
            'programId': r['program_id'],
            'participants': const [],
            'lastMessage': r['last_message'] == null
                ? null
                : {'text': r['last_message']},
          },
        )
        .toList();
  }

  @override
  Future<List<dynamic>> getConversations() async {
    try {
      return await _fetchConversations();
    } catch (e) {
      debugPrint('SupabaseRepository read failed: $e');
      return [];
    }
  }

  @override
  Future<List<dynamic>> getConversationsOrThrow() => _fetchConversations();

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
          .map(
            (r) => {
              '_id': (r as Map)['id'],
              'conversationId': r['conversation_id'],
              'text': r['body'],
              'senderId': r['sender_id'],
              'createdAt': r['created_at'],
            },
          )
          .toList();
    } catch (e) {
      debugPrint('SupabaseRepository read failed: $e');
      return [];
    }
  }

  @override
  Future<void> saveMessages(
    String conversationId,
    List<dynamic> messages,
  ) async {
    // Deprecated: chat is append-only now. Use postMessage() for new messages;
    // this wholesale-replace no-op stays only for interface compatibility.
  }

  @override
  Future<Map<String, dynamic>?> postMessage(
    String conversationId,
    String body,
  ) async {
    try {
      if (!_isUuid(conversationId) || body.trim().isEmpty) return null;
      final inserted = await _db
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': _uid,
            'body': body.trim(),
          })
          .select()
          .single();
      final m = inserted as Map;
      // Best-effort: bump the conversation's last-message preview.
      await _db
          .from('conversations')
          .update({
            'last_message': body.trim(),
            'last_message_at': m['created_at'],
          })
          .eq('id', conversationId);
      return {
        '_id': m['id'],
        'conversationId': m['conversation_id'],
        'text': m['body'],
        'senderId': m['sender_id'],
        'createdAt': m['created_at'],
      };
    } on PostgrestException catch (e) {
      debugPrint('postMessage failed: ${e.message}');
      return null;
    }
  }

  @override
  Future<void Function()> subscribeMessages(
    String conversationId,
    void Function(Map<String, dynamic>) onMessage,
  ) async {
    final channel = _db.channel('messages:$conversationId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final r = payload.newRecord;
            onMessage({
              '_id': r['id'],
              'conversationId': r['conversation_id'],
              'text': r['body'],
              'senderId': r['sender_id'],
              'createdAt': r['created_at'],
            });
          },
        )
        .subscribe();
    return () async {
      await _db.removeChannel(channel);
    };
  }

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
            // Denormalized name (see team_athlete_name migration); blank until
            // applied — never read the minors-only athletes table here.
            'fullName': t['athlete_first_name']?.toString() ?? '',
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
    } catch (e) {
      debugPrint('SupabaseRepository read failed: $e');
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
          .map(
            (r) => {
              '_id': (r as Map)['id'],
              'title': r['title'],
              'message': r['message'],
              'isRead': r['read'] ?? false,
              'createdAt': r['created_at'],
            },
          )
          .toList();
    } catch (e) {
      debugPrint('SupabaseRepository read failed: $e');
      return [];
    }
  }

  @override
  Future<void> saveNotifications(List<dynamic> notifications) async {}

  // ── Favorites (local; no dedicated table yet) ─────────────────────────────
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
    } catch (e) {
      debugPrint('SupabaseRepository read failed: $e');
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
    String? dateOnly(dynamic v) => v?.toString().substring(0, 10);
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
    // The onboarding flow stores the child's name as `fullName`; derive
    // first/last from it so the real name is persisted (not a placeholder).
    final full = (a['fullName'] ?? '').toString().trim();
    final firstFromFull = full.isEmpty
        ? null
        : full.split(RegExp(r'\s+')).first;
    final lastFromFull = full.contains(' ')
        ? full.substring(full.indexOf(' ') + 1).trim()
        : null;
    return {
      if (_isUuid(a['_id'])) 'id': a['_id'],
      'parent_id': parentId,
      // REAL entered name only (UI validates non-empty); no 'Athlete' fallback.
      'first_name': a['firstName'] ?? firstFromFull,
      'last_name': a['lastName'] ?? lastFromFull,
      'date_of_birth': dob, // required real DOB (UI-validated); never defaulted
      if (gender != null && validGenders.contains(gender)) 'gender': gender,
      if (a['preferredSports'] != null)
        'preferred_sports': a['preferredSports'],
      // Written only when the parent entered it — null otherwise (no 'None').
      'medical_conditions': a['medicalConditions'],
      if (a['emergencyContact'] != null)
        'emergency_contact': a['emergencyContact'],
      'profile_image': a['profileImage'],
      // COPPA parental consent.
      if (a['parentConsent'] != null) 'parent_consent': a['parentConsent'],
      if (a['consentAt'] != null) 'consent_at': a['consentAt'],
      if (a['consentVersion'] != null) 'consent_version': a['consentVersion'],
    };
  }
}
