import 'package:flutter/material.dart';

import 'core/game.dart';
import 'core/palette.dart';
import 'screens/common.dart';
import 'screens/home_screen.dart';

class LoomApp extends StatefulWidget {
  const LoomApp({super.key, required this.game});
  final Game game;

  @override
  State<LoomApp> createState() => _LoomAppState();
}

class _LoomAppState extends State<LoomApp> {
  late final Future<void> _ready = widget.game.init();

  @override
  Widget build(BuildContext context) => GameScope(
    game: widget.game,
    child: MaterialApp(
      title: 'Loom',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Cloth.wood,
          surface: Cloth.backdrop,
        ),
        scaffoldBackgroundColor: Cloth.backdrop,
        useMaterial3: true,
      ),
      home: FutureBuilder<void>(
        future: _ready,
        builder: (context, snap) {
          if (snap.hasError) {
            return Scaffold(
              body: Center(child: Text('Loom could not start: ${snap.error}')),
            );
          }
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(body: Linen(child: SizedBox.expand()));
          }
          return const HomeScreen();
        },
      ),
    ),
  );
}
