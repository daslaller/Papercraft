// Dev entry point — skips login, auto-logs in as "dev@local.dev".
// Run with:  flutter run -t lib/main_dev.dart
//
// Seeds placeholder templates on first launch so you land straight
// on a populated dashboard without having to register or log in.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:papercraft/papercraft.dart';
import 'services/auth_service.dart';

const _kDevUserId = 'dev-user-local';
const _kDevEmail = 'dev@local.dev';
const _kDevName = 'Dev User';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure the dev user exists and is logged in
  final prefs = await SharedPreferences.getInstance();
  final usersJson = prefs.getString('users') ?? '[]';
  final users = (jsonDecode(usersJson) as List).cast<Map<String, dynamic>>();
  if (!users.any((u) => u['id'] == _kDevUserId)) {
    users.add({
      'id': _kDevUserId,
      'email': _kDevEmail,
      'password': 'dev',
      'fullName': _kDevName,
    });
    await prefs.setString('users', jsonEncode(users));
  }
  await prefs.setString('current_user', jsonEncode({
    'id': _kDevUserId,
    'email': _kDevEmail,
    'fullName': _kDevName,
  }));

  // Seed placeholder templates if none exist yet
  await StorageRegistry.active.seedDefaults(_kDevUserId);

  final auth = AuthService();
  await auth.init();

  runApp(
    ChangeNotifierProvider.value(
      value: auth,
      child: const _DevApp(),
    ),
  );
}

class _DevApp extends StatelessWidget {
  const _DevApp();

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (ctx, __) => DashboardScreen(
            ownerId: _kDevUserId,
            onOpen: (id) => ctx.go('/editor/$id'),
          ),
        ),
        GoRoute(
          path: '/editor/:id',
          builder: (ctx, state) => EditorScreen(
            templateId: state.pathParameters['id']!,
            onBack: () => ctx.go('/'),
          ),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Papercraft [DEV]',
      debugShowCheckedModeBanner: true,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
