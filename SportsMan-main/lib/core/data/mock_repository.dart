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
  Future<void> savePrograms(List<dynamic> programs) async => MockData.programs = programs;
  @override
  Future<List<dynamic>> getSessions() => Future.value(MockData.sessions);
  @override
  Future<void> saveSessions(List<dynamic> sessions) async => MockData.sessions = sessions;

  // ── Bookings ─────────────────────────────────────────────────────────────
  @override
  Future<List<dynamic>> getBookings() => Future.value(MockData.bookings);
  @override
  Future<void> saveBookings(List<dynamic> bookings) async => MockData.bookings = bookings;
  @override
  Future<String?> addBooking(Map<String, dynamic> booking) async {
    MockData.addBooking(booking);
    return booking['_id']?.toString();
  }

  // ── Session notes + parent updates (demo: echo back, no AI/network) ─────────
  @override
  Future<String?> createSessionNote(Map<String, dynamic> note) async =>
      'mock-note-${DateTime.now().millisecondsSinceEpoch}';

  @override
  Future<Map<String, dynamic>> summarizeSessionNote(
          Map<String, dynamic> payload) async =>
      {
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
  Future<Map<String, dynamic>> sendParentUpdate(String id) async =>
      {'ok': true, 'status': 'sent', 'delivery_channel': 'inbox'};

  @override
  Future<List<Map<String, dynamic>>> getParentUpdatesForChild(
          String childId) async =>
      const [];

  // ── Profiles ─────────────────────────────────────────────────────────────
  @override
  Future<Map<String, dynamic>> getUserProfile() => Future.value(MockData.userProfile);
  @override
  Future<void> saveUserProfile(Map<String, dynamic> profile) async => MockData.userProfile = profile;
  @override
  Future<Map<String, dynamic>> getProviderProfile() => Future.value(MockData.providerProfile);
  @override
  Future<void> saveProviderProfile(Map<String, dynamic> profile) async => MockData.providerProfile = profile;

  // ── Athletes ─────────────────────────────────────────────────────────────
  @override
  Future<List<dynamic>> getAthletes() => Future.value(MockData.athletes);
  @override
  Future<void> saveAthletes(List<dynamic> athletes) async => MockData.athletes = athletes;

  // ── Conversations & messages ─────────────────────────────────────────────
  @override
  Future<List<dynamic>> getConversations() => Future.value(MockData.conversations);
  @override
  Future<void> saveConversations(List<dynamic> conversations) async => MockData.conversations = conversations;
  @override
  Future<List<dynamic>> getMessages(String conversationId) => Future.value(MockData.getMessages(conversationId));
  @override
  Future<void> saveMessages(String conversationId, List<dynamic> messages) async =>
      MockData.saveMessages(conversationId, messages);

  // ── Teams ────────────────────────────────────────────────────────────────
  @override
  Future<List<dynamic>> getTeams() => Future.value(MockData.teams);
  @override
  Future<void> saveTeams(List<dynamic> teams) async => MockData.teams = teams;

  // ── Notifications ────────────────────────────────────────────────────────
  @override
  Future<Map<String, dynamic>> getNotificationPrefs() => Future.value(MockData.notificationPrefs);
  @override
  Future<void> saveNotificationPrefs(Map<String, dynamic> prefs) async => MockData.notificationPrefs = prefs;
  @override
  Future<List<dynamic>> getNotifications() => Future.value(MockData.notifications);
  @override
  Future<void> saveNotifications(List<dynamic> notifications) async => MockData.notifications = notifications;

  // ── Auth/session (defined now; Supabase auth swap is #18) ────────────────
  @override
  Future<bool> isLoggedIn() => Future.value(MockData.isLoggedIn);
  @override
  Future<void> setLoggedIn(bool value) async => MockData.isLoggedIn = value;
  @override
  Future<String> getActiveRole() => Future.value(MockData.activeRole);
  @override
  Future<void> setActiveRole(String role) async => MockData.activeRole = role;
  @override
  Future<List<String>> getFavorites() => Future.value(MockData.favorites);
  @override
  Future<void> saveFavorites(List<String> favorites) async => MockData.favorites = favorites;
}
