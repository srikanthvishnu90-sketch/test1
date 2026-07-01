import '../mock/mock_data.dart';
import 'app_repository.dart';

/// Demo implementation of [AppRepository] — a thin WRAPPER over [MockData].
///
/// Every method resolves on the same microtask (`Future.value(...)`), so the
/// demo looks identical to direct synchronous access while exposing the
/// async-ready surface that #19's Supabase implementation will satisfy. No data
/// logic lives here: same data, same shapes as MockData.
class MockRepository implements AppRepository {
  const MockRepository();

  // ── Programs & sessions ──────────────────────────────────────────────────
  @override
  Future<List<dynamic>> getPrograms() => Future.value(MockData.programs);
  @override
  Future<List<dynamic>> getProgramsOrThrow() => Future.value(MockData.programs);
  @override
  Future<void> savePrograms(List<dynamic> programs) async =>
      MockData.programs = programs;
  @override
  Future<String?> createProgram(Map<String, dynamic> program) async {
    final id = 'prog_${DateTime.now().millisecondsSinceEpoch}';
    final p = Map<String, dynamic>.from(program)..['_id'] = id;
    MockData.programs = [p, ...MockData.programs];
    final now = DateTime.now();
    final sessions = [
      for (var d = 1; d <= 90; d++)
        {
          '_id': 'sess_${id}_$d',
          'programId': id,
          'title': 'Session',
          'startDate': now.add(Duration(days: d)).toIso8601String(),
          'date': now.add(Duration(days: d)).toIso8601String(),
          'startTime': '05:00 PM',
          'endTime': '06:00 PM',
        },
    ];
    MockData.sessions = [...MockData.sessions, ...sessions];
    return id;
  }

  @override
  Future<List<dynamic>> getSessions() => Future.value(MockData.sessions);
  @override
  Future<void> saveSessions(List<dynamic> sessions) async =>
      MockData.sessions = sessions;

  // ── Bookings ─────────────────────────────────────────────────────────────
  @override
  Future<List<dynamic>> getBookings() => Future.value(MockData.bookings);
  @override
  Future<List<dynamic>> getBookingsOrThrow() => Future.value(MockData.bookings);
  @override
  Future<void> saveBookings(List<dynamic> bookings) async =>
      MockData.bookings = bookings;
  @override
  Future<String?> addBooking(Map<String, dynamic> booking) async {
    MockData.addBooking(booking);
    return booking['_id']?.toString();
  }

  @override
  Future<bool> updateBookingStatus(String bookingId, String status) async {
    final list = List<dynamic>.from(MockData.bookings);
    final i = list.indexWhere((b) => (b['_id'] ?? b['id']) == bookingId);
    if (i != -1) {
      list[i]['status'] = status;
      MockData.bookings = list;
    }
    return true;
  }

  // ── Session notes + parent updates (demo: echo back, no AI/network) ─────────
  @override
  Future<String?> createSessionNote(Map<String, dynamic> note) async =>
      'mock-note-${DateTime.now().millisecondsSinceEpoch}';

  @override
  Future<Map<String, dynamic>> summarizeSessionNote(
    Map<String, dynamic> payload,
  ) async => {
    'result': {
      'type': 'draft',
      'summary_body':
          '${payload['childFirstName'] ?? 'Your athlete'} had a focused ${payload['sport'] ?? ''} session.',
      'skills_worked': const <String>[],
      'progress_signal': 'building consistency',
      'practice_suggestions': const <String>[],
      'encouragement': 'Keep it up!',
    },
    'removed': const <String>[],
  };

  // ── Lifecycle automated messaging (P4/P6) — in-memory demo ────────────────
  static final Map<String, String> _lifecyclePrefs = {};
  static final List<Map<String, dynamic>> _lifecycleDrafts = [
    {
      'id': 'lc-draft-1',
      'eventType': 'post_session',
      'childId': null,
      'bookingId': null,
      'body':
          'Hi! Just checking in after today\'s session — it was a good one. Let me know if you have any questions before next time!',
      'scheduledFor': null,
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> getLifecyclePrefs() async =>
      _lifecyclePrefs.entries
          .map((e) => {'eventType': e.key, 'mode': e.value})
          .toList();

  @override
  Future<bool> setLifecyclePref(String eventType, String mode) async {
    // Mirror the DB rule: 'auto' only valid for logistics types.
    const logistics = {'booking_confirmed', 'reminder_24h'};
    if (mode == 'auto' && !logistics.contains(eventType)) return false;
    _lifecyclePrefs[eventType] = mode;
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> getLifecycleDrafts() async =>
      List<Map<String, dynamic>>.from(_lifecycleDrafts);

  @override
  Future<Map<String, dynamic>> approveLifecycleMessage(
    String id, {
    String? body,
  }) async {
    _lifecycleDrafts.removeWhere((d) => d['id'] == id);
    return {'ok': true, 'status': 'sent'};
  }

  @override
  Future<Map<String, dynamic>> draftMessage(
    Map<String, dynamic> payload,
  ) async {
    await Future.delayed(const Duration(milliseconds: 600)); // mimic round-trip
    final intent = (payload['intent'] ?? 'reply').toString();
    final reschedule = intent == 'reschedule';
    return {
      'result': {
        'type': 'drafts',
        'drafts': [
          {
            'text': reschedule
                ? 'No problem at all — happy to move the session. What day works best on your end this week? I\'ll get it set up.'
                : 'Thanks for reaching out! Happy to help with that — let me know what works best and we\'ll sort it out.',
          },
          {
            'text': reschedule
                ? 'Thanks for the heads up! I have a couple of openings later this week — just tell me what\'s easiest and I\'ll lock it in.'
                : 'Got it! I\'ll take care of this. Let me know if there\'s anything else you need in the meantime.',
          },
        ],
      },
      'removed': const <String>[],
      'note': 'Drafts only — not saved, not sent.',
    };
  }

  // ── AI discovery (demo: local heuristic parse + filter, no network/model) ───
  @override
  Future<Map<String, dynamic>> searchParse(
    String query, {
    Map<String, dynamic>? locationHint,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final q = query.toLowerCase();

    // sport: first known sport mentioned.
    const sports = [
      'soccer',
      'basketball',
      'tennis',
      'football',
      'swimming',
      'baseball',
      'volleyball',
      'golf',
      'martial arts',
    ];
    String? sport;
    for (final s in sports) {
      if (q.contains(s)) {
        sport = s;
        break;
      }
    }

    // max_price: "under $80" / "$80" / "80 dollars".
    num? maxPrice;
    final priceMatch = RegExp(r'\$?\s*(\d{2,4})').firstMatch(q);
    if (q.contains('under') || q.contains('\$') || q.contains('budget')) {
      if (priceMatch != null) maxPrice = num.tryParse(priceMatch.group(1)!);
    }

    // athlete_age: "12 year old" / "12yo".
    int? age;
    final ageMatch = RegExp(r'(\d{1,2})\s*(?:yo|year)').firstMatch(q);
    if (ageMatch != null) age = int.tryParse(ageMatch.group(1)!);

    // soft attributes: subjective hints.
    final soft = <String>[];
    if (q.contains('beginner')) soft.add('beginner-friendly');
    if (q.contains('patient')) soft.add('patient');
    if (q.contains('competitive') || q.contains('elite')) {
      soft.add('competitive');
    }

    return {
      'sport': sport,
      'athlete_age': age,
      'metro': null,
      'max_price': maxPrice,
      'radius_miles': null,
      'soft_attributes': soft,
    };
  }

  @override
  Future<Map<String, dynamic>> searchExecute(
    Map<String, dynamic> constraints, {
    Map<String, dynamic>? locationHint,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final sport = (constraints['sport'] as String?)?.toLowerCase();
    final maxPrice = constraints['max_price'] as num?;

    final matched = MockData.programs
        .where((p) {
          if (p is! Map) return false;
          if (sport != null &&
              !(p['sportType']?.toString().toLowerCase().contains(sport) ??
                  false)) {
            return false;
          }
          if (maxPrice != null &&
              (p['price'] is num) &&
              p['price'] > maxPrice) {
            return false;
          }
          return true;
        })
        .map((p) {
          // Mirror the real search_listings row shape (no image column).
          return {
            'program_id': p['_id'],
            'title': p['title'] ?? 'Program',
            'specialty': p['sportType'] ?? '',
            'price': p['price'] ?? 0,
            'rating': p['averageRating'] ?? p['rating'] ?? 0,
            'review_count': p['totalReviews'] ?? 0,
            'has_availability': true,
            'why': sport != null
                ? 'Matches ${sport[0].toUpperCase()}${sport.substring(1)} in your search.'
                : 'A strong match for what you described.',
          };
        })
        .toList();

    return {'gated': false, 'results': matched, 'relax': null};
  }

  @override
  Future<String?> upsertParentUpdateDraft(Map<String, dynamic> update) async =>
      (update['id'] as String?) ??
      'mock-update-${DateTime.now().millisecondsSinceEpoch}';

  @override
  Future<Map<String, dynamic>?> approveParentUpdate(String id) async => {
    'id': id,
    'status': 'approved',
    'approved_at': DateTime.now().toUtc().toIso8601String(),
  };

  @override
  Future<Map<String, dynamic>> sendParentUpdate(String id) async => {
    'ok': true,
    'status': 'sent',
    'delivery_channel': 'inbox',
  };

  @override
  Future<List<Map<String, dynamic>>> getParentUpdatesForChild(
    String childId,
  ) async => const [];

  // ── Profiles ─────────────────────────────────────────────────────────────
  @override
  Future<Map<String, dynamic>> getUserProfile() =>
      Future.value(MockData.userProfile);
  @override
  Future<void> saveUserProfile(Map<String, dynamic> profile) async =>
      MockData.userProfile = profile;
  @override
  Future<Map<String, dynamic>> getProviderProfile() =>
      Future.value(MockData.providerProfile);
  @override
  Future<void> saveProviderProfile(Map<String, dynamic> profile) async =>
      MockData.providerProfile = profile;

  // ── Athletes ─────────────────────────────────────────────────────────────
  @override
  Future<List<dynamic>> getAthletes() => Future.value(MockData.athletes);
  @override
  Future<String?> addAthlete(Map<String, dynamic> athlete) async {
    final id = 'athlete_${DateTime.now().millisecondsSinceEpoch}';
    final first = (athlete['firstName'] ?? '').toString();
    final last = (athlete['lastName'] ?? '').toString();
    MockData.athletes = [
      ...MockData.athletes,
      {
        '_id': id,
        'firstName': first,
        'lastName': last,
        'fullName': '$first $last'.trim(),
        if (athlete['dateOfBirth'] != null)
          'dateOfBirth': athlete['dateOfBirth'],
        if (athlete['gender'] != null) 'gender': athlete['gender'],
      },
    ];
    return id;
  }

  @override
  Future<void> saveAthletes(List<dynamic> athletes) async =>
      MockData.athletes = athletes;

  // ── Conversations & messages ─────────────────────────────────────────────
  @override
  Future<List<dynamic>> getConversations() =>
      Future.value(MockData.conversations);
  @override
  Future<List<dynamic>> getConversationsOrThrow() =>
      Future.value(MockData.conversations);
  @override
  Future<void> saveConversations(List<dynamic> conversations) async =>
      MockData.conversations = conversations;
  @override
  Future<List<dynamic>> getMessages(String conversationId) =>
      Future.value(MockData.getMessages(conversationId));
  @override
  Future<void> saveMessages(
    String conversationId,
    List<dynamic> messages,
  ) async => MockData.saveMessages(conversationId, messages);

  @override
  Future<Map<String, dynamic>?> postMessage(
    String conversationId,
    String body,
  ) async {
    final msg = {
      '_id': 'mock-${DateTime.now().millisecondsSinceEpoch}',
      'conversationId': conversationId,
      'text': body,
      'senderId': MockData.userProfile['_id'] ?? 'me',
      'createdAt': DateTime.now().toIso8601String(),
    };
    final msgs = List<dynamic>.from(MockData.getMessages(conversationId))
      ..add(msg);
    MockData.saveMessages(conversationId, msgs);
    return msg;
  }

  @override
  Future<void Function()> subscribeMessages(
    String conversationId,
    void Function(Map<String, dynamic>) onMessage,
  ) async => () {}; // no realtime in the mock

  // ── Teams ────────────────────────────────────────────────────────────────
  @override
  Future<List<dynamic>> getTeams() => Future.value(MockData.teams);
  @override
  Future<void> saveTeams(List<dynamic> teams) async => MockData.teams = teams;

  // ── Notifications ────────────────────────────────────────────────────────
  @override
  Future<Map<String, dynamic>> getNotificationPrefs() =>
      Future.value(MockData.notificationPrefs);
  @override
  Future<void> saveNotificationPrefs(Map<String, dynamic> prefs) async =>
      MockData.notificationPrefs = prefs;
  @override
  Future<List<dynamic>> getNotifications() =>
      Future.value(MockData.notifications);
  @override
  Future<void> saveNotifications(List<dynamic> notifications) async =>
      MockData.notifications = notifications;
  @override
  Future<void> savePushToken(String token, {String platform = 'web'}) async {}

  // ── Favorites ────────────────────────────────────────────────────────────
  @override
  Future<List<String>> getFavorites() => Future.value(MockData.favorites);
  @override
  Future<void> saveFavorites(List<String> favorites) async =>
      MockData.favorites = favorites;
}
