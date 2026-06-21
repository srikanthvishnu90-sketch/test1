class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;

  bool get isOnline => true; // Always return true or implement network check if needed
}
