import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/analytics/consent.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/data_sync/hydrator.dart';
import '../../../core/privacy.dart';
import '../../../core/widgets/network_image.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(authControllerProvider.notifier).signOut();
    messenger.showSnackBar(const SnackBar(content: Text('Signed out')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastHydrated = ref.watch(lastHydratedProvider);
    final user = ref.watch(authControllerProvider);
    final consent = ref.watch(analyticsConsentProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          const SizedBox(height: 12),
          if (user != null) ...[
            const _SectionHeader('Account'),
            ListTile(
              leading: (user.photoUrl ?? '').isNotEmpty
                  ? ClipOval(
                      child: SizedBox(
                          width: 40,
                          height: 40,
                          child: AppNetworkImage(url: user.photoUrl!)))
                  : CircleAvatar(
                      child: Text(user.firstName.isNotEmpty
                          ? user.firstName[0].toUpperCase()
                          : '?')),
              title: Text(user.displayName),
              subtitle: Text(user.email),
            ),
            ListTile(
              key: const Key('signOutTile'),
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Sign out'),
              onTap: () => _signOut(context, ref),
            ),
            const Divider(),
          ],
          const _SectionHeader('Privacy'),
          SwitchListTile(
            secondary: const Icon(Icons.analytics_outlined),
            title: const Text('Share signup info'),
            subtitle: const Text(
                'Send my name, email and device model to Slice Of Gourmet when I sign up'),
            value: consent,
            onChanged: (v) => ref.read(analyticsConsentProvider.notifier).set(v),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy policy'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => openPrivacyPolicy(context),
          ),
          const Divider(),
          const _SectionHeader('App'),
          ListTile(
            leading: const Icon(Icons.sync_rounded),
            title: const Text('Manual refresh'),
            subtitle: Text(
              lastHydrated == null
                  ? 'Never synced'
                  : 'Last synced: ${lastHydrated.toLocal()}',
            ),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final ok = await ref.read(hydratorProvider).hydrate();
              messenger.showSnackBar(SnackBar(
                content: Text(ok
                    ? 'Refreshed successfully'
                    : 'Refresh failed, cached data kept'),
              ));
            },
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('About'),
            subtitle: Text('Slice Of Gourmet mobile app'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700)),
    );
  }
}
