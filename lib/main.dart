import 'package:flutter/material.dart';

import 'services/scout.dart';
import 'ui/home.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final scout = await Scout.create();
  runApp(ScoutApp(scout: scout));
}

class ScoutApp extends StatelessWidget {
  final Scout scout;
  const ScoutApp({super.key, required this.scout});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'D. Scout Lab',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: HomePage(scout: scout),
      );
}
