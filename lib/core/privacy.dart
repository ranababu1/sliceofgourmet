import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'constants.dart';

Future<void> openPrivacyPolicy(BuildContext context) async {
  final ok = await launchUrl(Uri.parse(kPrivacyPolicyUrl),
          mode: LaunchMode.externalApplication)
      .catchError((_) => false);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open privacy policy')));
  }
}
