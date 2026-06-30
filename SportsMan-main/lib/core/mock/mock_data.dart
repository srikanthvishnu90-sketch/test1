import 'package:get_storage/get_storage.dart';

class MockData {
  static final GetStorage _box = GetStorage();

  static void init() {
    if (_box.read('mock_initialized') == null) {
      _box.write('mock_initialized', true);

      _box.write('mock_user_profile', {
        "_id": "user_123",
        "firstName": "Alex",
        "lastName": "Mercer",
        "email": "alex.mercer@gmail.com",
        "role": "searcher",
        "phoneNumber": "+1 (555) 019-2834",
        "preferredSports": ["Soccer", "Tennis"],
        "profileImage": "https://picsum.photos/seed/athlete-alex/150/150",
      });

      _box.write('mock_provider_profile', {
        "_id": "provider_123",
        "userId": "user_123",
        "businessName": "Apex Performance Club",
        "bio":
            "Dedicated sports academy providing elite training clinics for junior athletes.",
        "sports": ["Soccer", "Tennis", "Basketball"],
        "location": "Miami, FL",
        "status": "approved",
        "onboardingCompleted": true,
        "stripeAccountId": "acct_mockstripe123",
      });

      _box.write('mock_athletes', [
        {
          "_id": "athlete_1",
          "firstName": "Julian",
          "lastName": "Mercer",
          "dateOfBirth": "2013-04-12T00:00:00.000Z",
          "gender": "male",
          "preferredSports": ["Soccer"],
          "medicalConditions": "None",
          "emergencyContact": {
            "name": "Alex Mercer",
            "phone": "+1 (555) 019-2834",
            "relation": "Father",
          },
          "profileImage": "https://picsum.photos/seed/coach-jordan/150/150",
        },
      ]);

      _box.write('mock_programs', [
        {
          "_id": "prog_1",
          "coverImage": "https://picsum.photos/seed/court-basketball/600/400",
          "title": "Elite Soccer Academy - U12 Training",
          "description":
              "High-intensity technical training focusing on dribbling, passing, and match awareness.",
          "sportType": "Soccer",
          "skillLevel": "Intermediate",
          "ageGroup": "Youth (Under 12)",
          "language": "English",
          "price": 45.0,
          "currency": "USD",
          "pricingModel": "single_session",
          "maxCapacity": 15,
          "enrolledCount": 8,
          "gallery": [
            "https://picsum.photos/seed/court-basketball/600/400",
            "https://picsum.photos/seed/court-tennis/600/400",
          ],
          "whatsIncluded": [
            "Training Bibs",
            "Water Bottles",
            "Professional Coaching",
          ],
          "location": {
            "type": "Point",
            "coordinates": [-80.1918, 25.7617],
          },
          "address": {
            "line1": "123 Coral Way",
            "city": "Miami",
            "state": "FL",
            "zip": "33145",
            "country": "USA",
          },
          "cancellationPolicy": "moderate",
          "minimumAge": 9,
          "maximumAge": 12,
          "isFeatured": true,
          "status": "published",
          "averageRating": 4.8,
          "totalReviews": 12,
          "providerId": {
            "businessName": "Apex Performance Club",
            "verificationStatus": "verified",
          },
        },
        {
          "_id": "prog_2",
          "coverImage": "https://picsum.photos/seed/court-soccer/600/400",
          "title": "Junior Tennis Clinic - All Levels",
          "description":
              "Learn basic and advanced tennis strokes, service, and court strategies from certified instructors.",
          "sportType": "Tennis",
          "skillLevel": "All Levels",
          "ageGroup": "Juniors (Under 16)",
          "language": "English",
          "price": 120.0,
          "currency": "USD",
          "pricingModel": "monthly",
          "maxCapacity": 8,
          "enrolledCount": 5,
          "gallery": ["https://picsum.photos/seed/court-soccer/600/400"],
          "whatsIncluded": ["Tennis Balls", "Racquet rentals"],
          "location": {
            "type": "Point",
            "coordinates": [-80.2000, 25.7700],
          },
          "address": {
            "line1": "450 Tennis Center Dr",
            "city": "Miami",
            "state": "FL",
            "zip": "33149",
            "country": "USA",
          },
          "cancellationPolicy": "strict",
          "minimumAge": 10,
          "maximumAge": 16,
          "isFeatured": false,
          "status": "published",
          "averageRating": 4.5,
          "totalReviews": 8,
          "providerId": {
            "businessName": "Apex Performance Club",
            "verificationStatus": "verified",
          },
        },
      ]);

      _box.write('mock_sessions', [
        {
          "_id": "sess_1",
          "programId": "prog_1",
          "title": "Soccer Skill Session 1",
          "startDate": "2026-05-04T00:00:00.000Z",
          "endDate": "2026-05-04T00:00:00.000Z",
          "date": "2026-05-04T00:00:00.000Z",
          "startTime": "05:00 PM",
          "endTime": "06:30 PM",
          "timezone": "EST",
          "address": "123 Coral Way, Miami, FL",
        },
        {
          "_id": "sess_2",
          "programId": "prog_1",
          "title": "Soccer Skill Session 2",
          "startDate": "2026-05-06T00:00:00.000Z",
          "endDate": "2026-05-06T00:00:00.000Z",
          "date": "2026-05-06T00:00:00.000Z",
          "startTime": "05:00 PM",
          "endTime": "06:30 PM",
          "timezone": "EST",
          "address": "123 Coral Way, Miami, FL",
        },
        {
          "_id": "sess_3",
          "programId": "prog_2",
          "title": "Weekly Tennis Practice",
          "startDate": "2026-05-05T00:00:00.000Z",
          "endDate": "2026-05-05T00:00:00.000Z",
          "date": "2026-05-05T00:00:00.000Z",
          "startTime": "04:00 PM",
          "endTime": "05:30 PM",
          "timezone": "EST",
          "address": "450 Tennis Center Dr, Miami, FL",
        },
      ]);

      _box.write('mock_bookings', [
        {
          "_id": "book_1",
          "searcherId": "user_123",
          "athleteId": {
            "_id": "athlete_1",
            "fullName": "Julian Mercer",
            "profileImage": "https://picsum.photos/seed/coach-jordan/150/150",
          },
          "providerId": "provider_123",
          "programId": {
            "_id": "prog_1",
            "title": "Elite Soccer Academy - U12 Training",
          },
          "sessionId": {
            "_id": "sess_1",
            "title": "Soccer Skill Session 1",
            "date": "2026-05-04T00:00:00.000Z",
            "startTime": "05:00 PM",
            "programId": "prog_1",
          },
          "selectedTier": "Standard",
          "originalPrice": 45.0,
          "finalPrice": 45.0,
          "currency": "USD",
          "status": "confirmed",
          "paymentStatus": "paid",
          "createdAt": "2026-05-01T10:00:00.000Z",
        },
      ]);

      _box.write('mock_conversations', [
        {
          "_id": "conv_1",
          "participants": [
            {
              "_id": "user_123",
              "firstName": "Alex",
              "lastName": "Mercer",
              "role": "searcher",
            },
            {
              "_id": "provider_user_123",
              "firstName": "Apex Performance",
              "lastName": "Club",
              "role": "provider",
            },
          ],
          "programId": "prog_1",
          "lastMessage": {
            "_id": "msg_initial",
            "conversationId": "conv_1",
            "text": "Hello, thank you for booking! See you on Monday.",
            "senderId": "provider_user_123",
            "createdAt": "2026-05-01T10:05:00.000Z",
          },
        },
      ]);

      _box.write('mock_messages_conv_1', [
        {
          "_id": "msg_1",
          "conversationId": "conv_1",
          "text":
              "Hi, I just booked the soccer session for Julian. Does he need to bring his own ball?",
          "senderId": "user_123",
          "createdAt": "2026-05-01T10:02:00.000Z",
        },
        {
          "_id": "msg_initial",
          "conversationId": "conv_1",
          "text":
              "Hello, thank you for booking! See you on Monday. We will provide training bibs and soccer balls, but he is welcome to bring his own.",
          "senderId": "provider_user_123",
          "createdAt": "2026-05-01T10:05:00.000Z",
        },
      ]);

      _box.write('mock_notifications', [
        {
          "_id": "notif_1",
          "title": "Booking Confirmed",
          "message":
              "Your booking for Soccer Skill Session 1 has been confirmed.",
          "isRead": false,
          "createdAt": "2026-05-01T10:00:00.000Z",
        },
      ]);

      _box.write('mock_teams', [
        {
          "_id": "team_1",
          "name": "Miami Elite Soccer U12",
          "sport": "Soccer",
          "roster": [
            {
              "_id": "athlete_1",
              "fullName": "Julian Mercer",
              "email": "alex.mercer@gmail.com",
              "jerseyNumber": "10",
              "avatar": "https://picsum.photos/seed/coach-jordan/150/150",
              "isAvailable": true,
              "isPaid": true,
            },
          ],
        },
      ]);

      _box.write('mock_favorites', <String>[]);
    }
  }

  // Getters & Setters
  static Map<String, dynamic> get userProfile {
    init();
    final data = _box.read('mock_user_profile');
    if (data == null) return {};
    return Map<String, dynamic>.from(data);
  }

  static set userProfile(Map<String, dynamic> val) {
    init();
    _box.write('mock_user_profile', val);
  }

  static Map<String, dynamic> get providerProfile {
    init();
    final data = _box.read('mock_provider_profile');
    if (data == null) return {};
    return Map<String, dynamic>.from(data);
  }

  static set providerProfile(Map<String, dynamic> val) {
    init();
    _box.write('mock_provider_profile', val);
  }

  static List<dynamic> get athletes {
    init();
    return _box.read<List<dynamic>>('mock_athletes') ?? [];
  }

  static set athletes(List<dynamic> val) {
    init();
    _box.write('mock_athletes', val);
  }

  static List<dynamic> get programs {
    init();
    return _box.read<List<dynamic>>('mock_programs') ?? [];
  }

  static set programs(List<dynamic> val) {
    init();
    _box.write('mock_programs', val);
  }

  static List<dynamic> get sessions {
    init();
    return _box.read<List<dynamic>>('mock_sessions') ?? [];
  }

  static set sessions(List<dynamic> val) {
    init();
    _box.write('mock_sessions', val);
  }

  static List<dynamic> get bookings {
    init();
    return _box.read<List<dynamic>>('mock_bookings') ?? [];
  }

  static set bookings(List<dynamic> val) {
    init();
    _box.write('mock_bookings', val);
  }

  /// Persist a new booking (newest first) so it survives navigation and shows
  /// up on Home "Coming Up" and the Schedule calendar.
  static void addBooking(Map<String, dynamic> booking) {
    final current = List<dynamic>.from(bookings);
    current.insert(0, booking);
    bookings = current;
  }

  static Map<String, dynamic> get notificationPrefs {
    init();
    final data = _box.read('mock_notification_prefs');
    return data != null ? Map<String, dynamic>.from(data) : {};
  }

  static set notificationPrefs(Map<String, dynamic> val) {
    init();
    _box.write('mock_notification_prefs', val);
  }

  static List<dynamic> get conversations {
    init();
    return _box.read<List<dynamic>>('mock_conversations') ?? [];
  }

  static set conversations(List<dynamic> val) {
    init();
    _box.write('mock_conversations', val);
  }

  static List<dynamic> getMessages(String convId) {
    init();
    return _box.read<List<dynamic>>('mock_messages_$convId') ?? [];
  }

  static void saveMessages(String convId, List<dynamic> msgs) {
    init();
    _box.write('mock_messages_$convId', msgs);
  }

  static List<dynamic> get notifications {
    init();
    return _box.read<List<dynamic>>('mock_notifications') ?? [];
  }

  static set notifications(List<dynamic> val) {
    init();
    _box.write('mock_notifications', val);
  }

  static List<dynamic> get teams {
    init();
    return _box.read<List<dynamic>>('mock_teams') ?? [];
  }

  static set teams(List<dynamic> val) {
    init();
    _box.write('mock_teams', val);
  }

  static List<String> get favorites {
    init();
    final favs = _box.read('mock_favorites');
    if (favs == null) return [];
    return List<String>.from(favs);
  }

  static set favorites(List<String> val) {
    init();
    _box.write('mock_favorites', val);
  }
}
