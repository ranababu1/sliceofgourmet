import 'package:flutter/material.dart';

/// Centered message with an icon in a soft circle and an optional retry.
class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    this.onRetry,
  });

  final String message;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: cs.primaryContainer, shape: BoxShape.circle),
              child: Icon(icon, size: 30, color: cs.primary),
            ),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.4)),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              FilledButton.tonal(
                  onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

const kOfflineMessage =
    'Could not load. Check your internet connection and try again.';
