import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers.dart';
import '../../../core/widgets/state_views.dart';

/// Opens a shared sliceofgourmet.com link: looks up the post by slug and
/// replaces itself with the recipe screen.
class OpenLinkScreen extends ConsumerWidget {
  const OpenLinkScreen({super.key, required this.url});
  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(linkResolverProvider(url));
    final id = async.valueOrNull;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.replace('/recipe/$id');
      });
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Recipe')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => MessageView(
          message: kOfflineMessage,
          icon: Icons.cloud_off_rounded,
          onRetry: () => ref.invalidate(linkResolverProvider(url)),
        ),
        data: (id) => id != null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const MessageView(
                    message: 'We could not find that recipe in the app.',
                    icon: Icons.search_off_rounded,
                  ),
                  if (Uri.tryParse(url) case final uri?)
                    TextButton.icon(
                      onPressed: () =>
                          launchUrl(uri, mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open in browser'),
                    ),
                ],
              ),
      ),
    );
  }
}
