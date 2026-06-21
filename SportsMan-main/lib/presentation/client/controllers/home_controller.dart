import 'package:flutter/material.dart';
import '../view/search_screen.dart'; // To access Opportunity model
import '../../../core/mock/mock_data.dart';

class HomeProvider with ChangeNotifier {

  // User Profile State
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? get userProfile => _userProfile;
  bool _isLoadingProfile = false;
  bool get isLoadingProfile => _isLoadingProfile;

  // Stats State (Dynamic if possible, otherwise empty for now)
  Map<String, dynamic> _stats = {
    'sessions': 0,
    'reviews': 0,
    'saved': 0,
  };
  Map<String, dynamic> get stats => _stats;

  // Programs State
  List<dynamic> _programs = [];
  List<dynamic> get programs => _programs;
  bool _isLoadingPrograms = false;
  bool get isLoadingPrograms => _isLoadingPrograms;

  // Bookings State
  List<dynamic> _bookings = [];
  List<dynamic> get bookings => _bookings;
  bool _isLoadingBookings = false;
  bool get isLoadingBookings => _isLoadingBookings;

  // Past Searches
  final List<String> _pastSearches = [];
  List<String> get pastSearches => _pastSearches;

  void addPastSearch(String query) {
    if (!_pastSearches.contains(query)) {
      _pastSearches.insert(0, query);
      if (_pastSearches.length > 5) _pastSearches.removeLast();
      notifyListeners();
    }
  }

  Future<void> fetchAllAthleteData() async {
    await Future.wait([
      fetchUserProfile(),
      fetchPrograms(),
      fetchBookings(),
    ]);
    _calculateStats();
  }

  void _calculateStats() {
    _stats = {
      'sessions': _bookings.length,
      'reviews': 0, 
      'saved': 0, 
    };
    notifyListeners();
  }

  Future<void> fetchUserProfile() async {
    _isLoadingProfile = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 200)); // Simulate UI loading state
    try {
      _userProfile = MockData.userProfile;
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    } finally {
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> fetchPrograms() async {
    _isLoadingPrograms = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      _programs = MockData.programs;
    } catch (e) {
      debugPrint('Error fetching programs: $e');
    } finally {
      _isLoadingPrograms = false;
      notifyListeners();
    }
  }

  Future<void> fetchBookings() async {
    _isLoadingBookings = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      _bookings = MockData.bookings;
    } catch (e) {
      debugPrint('Error fetching bookings: $e');
    } finally {
      _isLoadingBookings = false;
      notifyListeners();
    }
  }

  /// Persist a new booking and refresh derived state so Home + Schedule update.
  void addBooking(Map<String, dynamic> booking) {
    MockData.addBooking(booking);
    _bookings = MockData.bookings;
    _calculateStats(); // also calls notifyListeners()
  }

  String _selectedCategory = 'All';
  String get selectedCategory => _selectedCategory;

  final Set<int> _favoritedOpportunityIds = {};
  Set<int> get favoritedOpportunityIds => _favoritedOpportunityIds;

  final String _athleteTeam = 'ScoreNow Elite';
  String get athleteTeam => _athleteTeam;

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  bool isOpportunityFavorited(int id) {
    return _favoritedOpportunityIds.contains(id);
  }

  void toggleFavorite(int id) {
    if (_favoritedOpportunityIds.contains(id)) {
      _favoritedOpportunityIds.remove(id);
    } else {
      _favoritedOpportunityIds.add(id);
    }
    notifyListeners();
  }

  // Clear search history
  void clearPastSearches() {
    _pastSearches.clear();
    notifyListeners();
  }

  // Dynamic recommendation scoring algorithm
  List<Opportunity> getRecommendations(List<Opportunity> allOpportunities) {
    if (allOpportunities.isEmpty) return [];

    final Map<int, double> scores = {};

    for (var opp in allOpportunities) {
      double score = 0.0;

      // 1. Team Association Match (High Priority)
      if (opp.team.toLowerCase() == _athleteTeam.toLowerCase()) {
        score += 10.0;
      }

      // 2. Past Search Match (Keyword Match Boost)
      for (var search in _pastSearches) {
        final cleanSearch = search.toLowerCase().trim();
        if (cleanSearch.isEmpty) continue;

        if (opp.title.toLowerCase().contains(cleanSearch)) {
          score += 5.0;
        }
        if (opp.coach.toLowerCase().contains(cleanSearch)) {
          score += 3.0;
        }
        if (opp.team.toLowerCase().contains(cleanSearch)) {
          score += 2.0;
        }
      }

      scores[opp.id] = score;
    }

    // Sort opportunities descending by score
    final List<Opportunity> sorted = List.from(allOpportunities);
    sorted.sort((a, b) {
      final scoreA = scores[a.id] ?? 0.0;
      final scoreB = scores[b.id] ?? 0.0;
      return scoreB.compareTo(scoreA);
    });

    return sorted.take(3).toList();
  }
}
