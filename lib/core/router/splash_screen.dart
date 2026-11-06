import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_providers.dart';
import '../../features/profile/data/profile_repository.dart';
import '../utils/error_messages.dart';

/// Mostrado enquanto o perfil do usuário logado é carregado.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    return Scaffold(
      body: Center(
        child: profile.when(
          loading: () => const CircularProgressIndicator(),
          data: (p) => p == null
              ? _Problem(
                  message: 'Seu perfil não foi encontrado.',
                  onRetry: () => ref.invalidate(currentProfileProvider),
                  onSignOut: () => ref.read(authRepositoryProvider).signOut(),
                )
              : const CircularProgressIndicator(),
          error: (e, _) => _Problem(
            message: friendlyError(e),
            onRetry: () => ref.invalidate(currentProfileProvider),
            onSignOut: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ),
      ),
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({
    required this.message,
    required this.onRetry,
    required this.onSignOut,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Tentar novamente')),
          TextButton(onPressed: onSignOut, child: const Text('Sair')),
        ],
      ),
    );
  }
}
