/// Repository abstraction (#16) — the single swap point between the mock demo
/// data and a future Supabase backend (#19).
///
/// CORE RULE: every method returns a `Future`, even though [MockRepository]
/// resolves instantly via `Future.value(...)`. Supabase calls are async/network,
/// so async-now means the backend can drop in later by changing ONE line in
/// `lib/main.dart` (`MockRepository()` → `SupabaseRepository()`) without touching
/// a single call site.
///
/// Interfaces are grouped per domain; [AppRepository] is the facade that
/// aggregates them so controllers can be injected with one object.
library;

/// Programs & their sessions (provider listings + scheduled sessions).
abstract class ProgramRepository {
  Future<List<dynamic>> getPrograms();
  Future<void> savePrograms(List<dynamic> programs);
  Future<List<dynamic>> getSessions();
  Future<void> saveSessions(List<dynamic> sessions);
}

/// Athlete/family bookings.
abstract class BookingRepository {
  Future<List<dynamic>> getBookings();
  Future<void> saveBookings(List<dynamic> bookings);

  /// Persists a booking and returns its new id (null if it couldn't be created).
  Future<String?> addBooking(Map<String, dynamic> booking);
}

/// User + provider profiles.
abstract class ProfileRepository {
  Future<Map<String, dynamic>> getUserProfile();
  Future<void> saveUserProfile(Map<String, dynamic> profile);
  Future<Map<String, dynamic>> getProviderProfile();
  Future<void> saveProviderProfile(Map<String, dynamic> profile);
}

/// Athlete records (provider roster / family athletes).
abstract class AthleteRepository {
  Future<List<dynamic>> getAthletes();
  Future<void> saveAthletes(List<dynamic> athletes);
}

/// Conversations + their messages.
abstract class ConversationRepository {
  Future<List<dynamic>> getConversations();
  Future<void> saveConversations(List<dynamic> conversations);
  Future<List<dynamic>> getMessages(String conversationId);
  Future<void> saveMessages(String conversationId, List<dynamic> messages);
}

/// Coach teams / roster groups.
abstract class TeamRepository {
  Future<List<dynamic>> getTeams();
  Future<void> saveTeams(List<dynamic> teams);
}

/// Notification preferences + feed.
abstract class NotificationRepository {
  Future<Map<String, dynamic>> getNotificationPrefs();
  Future<void> saveNotificationPrefs(Map<String, dynamic> prefs);
  Future<List<dynamic>> getNotifications();
  Future<void> saveNotifications(List<dynamic> notifications);
}

/// Auth/session state. Defined now; the Supabase auth swap itself is #18.
abstract class AuthRepository {
  Future<bool> isLoggedIn();
  Future<void> setLoggedIn(bool value);
  Future<String> getActiveRole();
  Future<void> setActiveRole(String role);
  Future<List<String>> getFavorites();
  Future<void> saveFavorites(List<String> favorites);
}

/// Facade aggregating every domain repository. Controllers depend on this one
/// type; `lib/main.dart` injects a single concrete instance.
abstract class AppRepository
    implements
        ProgramRepository,
        BookingRepository,
        ProfileRepository,
        AthleteRepository,
        ConversationRepository,
        TeamRepository,
        NotificationRepository,
        AuthRepository {}
