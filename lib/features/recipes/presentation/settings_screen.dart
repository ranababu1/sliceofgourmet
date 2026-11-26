import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/analytics/consent.dart';
import '../../../core/auth/auth_providers.dart';
import 'package:intl/intl.dart';
import '../../../core/data_sync/sync_controller.dart';
import 'home_screen.dart' show refreshAndReport;
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
    final sync = ref.watch(syncControllerProvider);
    final last = sync.lastSyncedAt;
    final user = ref.watch(authControllerProvider);
    final consent = ref.watch(analyticsConsentProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Text('Profile',
                style: Theme.of(context).textTheme.headlineMedium),
          ),
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
          if (ref.watch(signInAvailableProvider))
            SwitchListTile(
              secondary: const Icon(Icons.analytics_outlined),
              title: const Text('Share signup info'),
              subtitle: const Text(
                  'Send my name, email and device model to Slice of Gourmet when I sign up'),
              value: consent,
              onChanged: (v) =>
                  ref.read(analyticsConsentProvider.notifier).set(v),
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
            title: const Text('Refresh recipes'),
            subtitle: Text(last == null
                ? 'Not synced yet'
                : 'Last synced ${DateFormat('d MMM, h:mm a').format(last.toLocal())}'),
            trailing: sync.syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: sync.syncing ? null : () => refreshAndReport(context, ref),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('About'),
            subtitle: Text('Slice of Gourmet recipes, from sliceofgourmet.com'),
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
