import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:papercraft/papercraft.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthService();
  await auth.init();
  runApp(
    ChangeNotifierProvider.value(
      value: auth,
      child: const PapercraftApp(),
    ),
  );
}

class PapercraftApp extends StatelessWidget {
  const PapercraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    final router = GoRouter(
      initialLocation: '/',
      redirect: (ctx, state) {
        if (auth.loading) return null;
        final isAuth = auth.isAuthenticated;
        final isAuthRoute = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register';

        if (!isAuth && !isAuthRoute) return '/login';
        if (isAuth && isAuthRoute) return '/';
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (ctx, __) => DashboardScreen(
            ownerId: auth.user?.id ?? '',
            onOpen: (id) => ctx.go('/editor/$id'),
            onExit: () => auth.logout(),
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (_, __) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/editor/:id',
          builder: (routerCtx, state) => EditorScreen(
            templateId: state.pathParameters['id']!,
            onBack: () => routerCtx.go('/'),
          ),
        ),
      ],
    );

    if (auth.loading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp.router(
      title: 'Papercraft',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
