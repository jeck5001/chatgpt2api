import 'package:flutter/material.dart';

import 'create_screen.dart';
import 'studio_controller.dart';

class StudioSessionScreen extends StatefulWidget {
  const StudioSessionScreen({super.key, required this.controller});

  final StudioController controller;

  @override
  State<StudioSessionScreen> createState() => _StudioSessionScreenState();
}

class _StudioSessionScreenState extends State<StudioSessionScreen> {
  late final Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _loadFuture = widget.controller.loadWorkspace();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load studio workspace: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return CreateScreen(controller: widget.controller);
      },
    );
  }
}
