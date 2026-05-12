import 'package:flutter/material.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.onContinue});

  final ValueChanged<Uri> onContinue;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: 'http://localhost:8000');
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Connect Image Studio',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Enter your chatgpt2api backend URL. The app stores only '
                  'the active server and bearer key.',
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'Backend URL'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    final uri = Uri.tryParse(controller.text.trim());
                    if (uri != null && uri.hasScheme) {
                      onContinue(uri);
                    }
                  },
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
