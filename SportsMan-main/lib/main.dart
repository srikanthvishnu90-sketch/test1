import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

import 'package:provider/provider.dart';
import 'core/config/env.dart';
import 'core/auth/auth_service.dart';
import 'core/auth/supabase_auth_service.dart';
import 'core/data/app_repository.dart';
import 'core/data/mock_repository.dart';
import 'presentation/onboarding/controllers/onboarding_controller.dart';
import 'presentation/client/controllers/home_controller.dart';
import 'presentation/provider/controllers/provider_controller.dart';
import 'presentation/authentication/controllers/auth_provider.dart';
import 'presentation/shared/controllers/chat_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init(); // Must be called before any token read/write

  // Real Supabase auth (#18). Keys come ONLY from Env (--dart-define-from-file=
  // env.json); never hardcoded. Supabase persists the session itself.
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  // THE SWAP POINT (#16): the app's single data source. #19 changes this one
  // line to `SupabaseRepository()` — nothing else in the app changes.
  final AppRepository repo = const MockRepository();

  // AUTH SWAP POINT (#18): the app's single auth source. The UI only ever talks
  // to AuthService (via AuthProvider); the Supabase SDK never leaks past it.
  final AuthService authService = SupabaseAuthService();

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        ChangeNotifierProvider(create: (_) => OnboardingProvider(repo)),
        ChangeNotifierProvider(create: (_) => HomeProvider(repo)),
        ChangeNotifierProvider(create: (_) => ProviderController(repo)),
        ChangeNotifierProvider(create: (_) => AuthProvider(authService)),
        ChangeNotifierProvider(create: (_) => ChatProvider(repo, authService)),
      ],
      child: const MyApp(),
    ),
  );
}


