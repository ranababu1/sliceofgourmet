import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_providers.dart';

class LoginSheet extends ConsumerStatefulWidget {
  const LoginSheet({super.key});

  @override
  ConsumerState<LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends ConsumerState<LoginSheet> {
  bool _loading = false;

  Future<void> _doGoogle() async {
    setState(() => _loading = true);
    await ref.read(authControllerProvider.notifier).signInGoogle();
    if (mounted) {
      setState(() => _loading = false);
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                height: 4,
                width: 44,
                decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Sign in',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Sign in to access bookmarks, categories and settings',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _doGoogle,
                icon: const Icon(Icons.account_circle_rounded),
                label:
                    Text(_loading ? 'Signing in...' : 'Continue with Google'),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Not now')),
          ],
        ),
      ),
    );
  }
}
