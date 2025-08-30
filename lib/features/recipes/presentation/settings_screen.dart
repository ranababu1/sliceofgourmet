import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About'),
          subtitle: const Text('Slice Of Gourmet mobile app'),
          onTap: () {},
        ),
        SwitchListTile(
          secondary: const Icon(Icons.dark_mode_outlined),
          title: const Text('Use system theme'),
          subtitle: const Text('App follows device theme by default'),
          value: true,
          onChanged: (v) {},
        ),
      ],
    );
  }
}
