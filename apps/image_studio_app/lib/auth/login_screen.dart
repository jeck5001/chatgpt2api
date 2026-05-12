import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    required this.baseUrl,
    required this.onLogin,
    this.loading = false,
    this.errorMessage,
  });

  final Uri baseUrl;
  final Future<void> Function(String bearerKey) onLogin;
  final bool loading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
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
                  'API Key Mode',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(baseUrl.toString()),
                const SizedBox(height: 24),
                TextField(
                  controller: controller,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Bearer key',
                    errorText: errorMessage,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: loading
                      ? null
                      : () => onLogin(controller.text.trim()),
                  child: Text(loading ? 'Connecting...' : 'Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
