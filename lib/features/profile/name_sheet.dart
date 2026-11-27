import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../core/profile/name_controller.dart';
import '../../core/theme.dart';
import '../../features/recipes/providers.dart';

enum NamePromptReason { welcome, save, edit }

/// Shows the name sheet unless the user already has a name.
///
/// [NamePromptReason.welcome] is shown once, the first time Home is ready.
/// [NamePromptReason.save] is shown when they try to save a recipe with no
/// name, even if they skipped earlier. Both are skippable.
/// [NamePromptReason.edit] is for Profile and is cancelled rather than skipped.
Future<void> maybeAskName(
  BuildContext context,
  WidgetRef ref, {
  required NamePromptReason reason,
}) async {
  final ctrl = ref.read(nameControllerProvider.notifier);
  await ctrl.ensureLoaded();
  if (!context.mounted) return;
  final state = ref.read(nameControllerProvider);
  if (state.hasName && reason != NamePromptReason.edit) return;
  if (reason == NamePromptReason.welcome && state.promptShown) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => NameSheet(reason: reason, initial: state.raw),
  );
  await ctrl.markPromptShown();
}

/// Saves or unsaves a recipe. If this is a new save and there is no name yet,
/// the name prompt is shown first (skippable); the recipe is saved either way.
Future<void> toggleSavedRecipe(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  final saved = ref.read(bookmarkIdsNotifierProvider).contains(id);
  if (!saved) {
    await maybeAskName(context, ref, reason: NamePromptReason.save);
  }
  if (!context.mounted) return;
  await ref.read(bookmarkIdsNotifierProvider.notifier).toggle(id);
}

class NameSheet extends ConsumerStatefulWidget {
  const NameSheet({super.key, required this.reason, this.initial = ''});

  final NamePromptReason reason;
  final String initial;

  @override
  ConsumerState<NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends ConsumerState<NameSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(nameControllerProvider.notifier).setName(_controller.text);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reason = widget.reason;
    final title = switch (reason) {
      NamePromptReason.welcome => 'What should we call you?',
      NamePromptReason.save => 'Want to add your name?',
      NamePromptReason.edit => 'Your name',
    };
    final body = switch (reason) {
      NamePromptReason.welcome =>
        'We\'ll greet you by name and keep your saved recipes on this device.',
      NamePromptReason.save =>
        'Saved recipes stay on this device. We\'ll also greet you when you come back.',
      NamePromptReason.edit =>
        'This stays on your device. We use it to say hi.',
    };
    final skip = reason == NamePromptReason.edit ? 'Cancel' : 'Skip for now';
    final inset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 4, 24, 12 + inset),
      child: FadeSlideIn(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: display(26, color: cs.onSurface)),
            const SizedBox(height: 8),
            Text(body, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            TextField(
              key: const Key('nameField'),
              controller: _controller,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.givenName],
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                hintText: 'Your first name',
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              key: const Key('saveNameButton'),
              onPressed: _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Save name'),
            ),
            TextButton(
              key: const Key('skipNameButton'),
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(skip),
            ),
          ],
        ),
      ),
    );
  }
}
