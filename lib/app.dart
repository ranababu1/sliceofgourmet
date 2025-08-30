import 'package:flutter/material.dart';
import 'core/router.dart';
import 'core/theme.dart';

class SliceOfGourmetApp extends StatelessWidget {
  const SliceOfGourmetApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = createRouter();
    return MaterialApp.router(
      title: 'Slice Of Gourmet',
      themeMode: ThemeMode.system,
      theme: lightTheme,
      darkTheme: darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
