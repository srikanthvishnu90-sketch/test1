import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'app.dart';

import 'package:provider/provider.dart';
import 'presentation/onboarding/controllers/onboarding_controller.dart';
import 'presentation/client/controllers/home_controller.dart';
import 'presentation/provider/controllers/provider_controller.dart';
import 'presentation/authentication/controllers/auth_provider.dart';
import 'presentation/shared/controllers/chat_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init(); // Must be called before any token read/write
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OnboardingProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => ProviderController()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: const MyApp(),
    ),
  );
}


