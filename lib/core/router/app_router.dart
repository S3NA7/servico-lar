import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/user_role.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/profile/presentation/profile_screen.dart';
import 'app_shell.dart';
import 'placeholder_screen.dart';
import 'splash_screen.dart';

/// Notifica o router quando sessão ou perfil mudam, e decide redirecionamentos.
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, _) => notifyListeners());
    _ref.listen(currentProfileProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;

  static const _authRoutes = {'/login', '/register'};

  String? redirect(BuildContext context, GoRouterState state) {
    final location = state.matchedLocation;
    final onAuthRoute = _authRoutes.contains(location);
    final session = _ref.read(authRepositoryProvider).currentSession;

    if (session == null) return onAuthRoute ? null : '/login';

    final profile = _ref.read(currentProfileProvider);
    final loaded = profile.hasValue && !profile.isLoading;
    if (!loaded || profile.value == null) {
      return location == '/splash' ? null : '/splash';
    }

    final isPro = profile.value!.role == UserRole.professional;
    final home = isPro ? '/pro' : '/client';
    final otherArea = isPro ? '/client' : '/pro';
    if (onAuthRoute ||
        location == '/splash' ||
        location == '/' ||
        location == otherArea ||
        location.startsWith('$otherArea/')) {
      return home;
    }
    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),

      // Área do cliente
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            AppShell(navigationShell: shell, destinations: clientDestinations),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/client',
              builder: (_, _) =>
                  const PlaceholderScreen(title: 'Buscar serviços'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/client/requests',
              builder: (_, _) =>
                  const PlaceholderScreen(title: 'Minhas solicitações'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/client/profile',
              builder: (_, _) => const ProfileScreen(),
            ),
          ]),
        ],
      ),

      // Área do profissional
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            AppShell(navigationShell: shell, destinations: proDestinations),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/pro',
              builder: (_, _) => const PlaceholderScreen(title: 'Painel'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/pro/services',
              builder: (_, _) =>
                  const PlaceholderScreen(title: 'Meus serviços'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/pro/availability',
              builder: (_, _) =>
                  const PlaceholderScreen(title: 'Minha agenda'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/pro/profile',
              builder: (_, _) => const ProfileScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});
