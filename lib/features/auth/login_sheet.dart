import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/analytics/consent.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/privacy.dart';

class LoginSheet extends ConsumerStatefulWidget {
  const LoginSheet({super.key});

  @override
  ConsumerState<LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends ConsumerState<LoginSheet> {
  bool _loading = false;
  String? _error;

  Future<void> _doGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final user =
          await ref.read(authControllerProvider.notifier).signInGoogle();
      if (user != null && mounted) {
        Navigator.of(context).maybePop();
        messenger.showSnackBar(
            SnackBar(content: Text('Signed in as ${user.email}')));
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      const msg = 'Sign-in failed. Please try again.';
      if (mounted) setState(() => _error = msg);
      messenger.showSnackBar(const SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final consent = ref.watch(analyticsConsentProvider);

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
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const Key('consentCheckbox'),
              value: consent,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: _loading
                  ? null
                  : (v) => ref
                      .read(analyticsConsentProvider.notifier)
                      .set(v ?? false),
              title: const Text(
                  'Share my name, email and device model with Slice Of Gourmet when I sign up (optional)'),
              subtitle: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => openPrivacyPolicy(context),
                  child: const Text('Privacy policy'),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: TextStyle(color: cs.error)),
              ),
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
                onPressed: _loading ? null : () => Navigator.pop(context),
                child: const Text('Not now')),
          ],
        ),
      ),
    );
  }
}
