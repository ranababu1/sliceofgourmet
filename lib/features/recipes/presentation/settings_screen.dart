import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/data_sync/sync_controller.dart';
import '../../../core/privacy.dart';
import '../../../core/profile/name_controller.dart';
import '../../../core/theme.dart';
import '../../profile/name_sheet.dart';
import 'home_screen.dart' show refreshAndReport;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _clearName(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear your name?'),
        content: const Text(
            'We\'ll stop greeting you by name. Your saved recipes stay on this device.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear name')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(nameControllerProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncControllerProvider);
    final last = sync.lastSyncedAt;
    final name = ref.watch(nameControllerProvider);
    final first = name.firstName;
    final cs = Theme.of(context).colorScheme;

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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Material(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Brand.herbSoft,
                      foregroundColor: Brand.herb,
                      child: Text(
                        first == null ? '?' : first[0],
                        style: display(22, color: Brand.herb),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            first == null ? 'Hi there' : 'Hi, $first',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            first == null
                                ? 'Add a name so we can greet you'
                                : 'Your name stays on this device',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (first == null)
            ListTile(
              key: const Key('addNameTile'),
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Add your name'),
              onTap: () =>
                  maybeAskName(context, ref, reason: NamePromptReason.edit),
            )
          else ...[
            ListTile(
              key: const Key('editNameTile'),
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit name'),
              subtitle: Text(name.raw.trim()),
              onTap: () =>
                  maybeAskName(context, ref, reason: NamePromptReason.edit),
            ),
            ListTile(
              key: const Key('clearNameTile'),
              leading: const Icon(Icons.person_off_outlined),
              title: const Text('Clear name'),
              onTap: () => _clearName(context, ref),
            ),
          ],
          const Divider(),
          const _SectionHeader('Privacy'),
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
