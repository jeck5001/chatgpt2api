import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/defaults.dart';
import '../app/tokens.dart';
import '../app/typography.dart';
import '../shared/brand/kiln_logo.dart';
import '../shared/components/gradient_button.dart';

/// Step 2 of the entry flow — supply the Bearer key for the chosen server.
class LoginScreen extends StatefulWidget {
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
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _controller;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: defaultBearerKey);
    _errorMessage = widget.errorMessage;
  }

  @override
  void didUpdateWidget(LoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorMessage != oldWidget.errorMessage) {
      _errorMessage = widget.errorMessage;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await widget.onLogin(_controller.text.trim());
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = widget.loading || _submitting;
    return Scaffold(
      body: Stack(
        children: [
          const _AmberBackdrop(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: KilnSpacing.xl,
                            vertical: KilnSpacing.xxl,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: KilnSpacing.xxl),
                              const KilnLogo(size: 56),
                              const SizedBox(height: KilnSpacing.xl),
                              const KilnWordmark(
                                size: 56,
                                weight: FontWeight.w300,
                              ),
                              const SizedBox(height: KilnSpacing.sm),
                              Text(
                                '提示，迭代，\n留存。',
                                style: KilnTypography.display(
                                  size: 18,
                                  weight: FontWeight.w300,
                                  color: KilnColors.ink300,
                                  letterSpacing: 0.1,
                                  height: 1.45,
                                ).copyWith(fontStyle: FontStyle.italic),
                              ),
                              const SizedBox(height: KilnSpacing.xxxl),
                              Text(
                                '第 2 步 / 共 2 步 · 凭证'.toUpperCase(),
                                style: KilnTypography.mono(
                                  size: 10,
                                  color: KilnColors.ember400,
                                  letterSpacing: 2.5,
                                ),
                              ),
                              const SizedBox(height: KilnSpacing.sm),
                              _GlassCard(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      '录入你的密钥',
                                      style: KilnTypography.display(
                                        size: 22,
                                        weight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '只保存在设备的安全存储里，不会上传到任何地方，仅用于和你的工作室通信。',
                                      style: KilnTypography.bodyS,
                                    ),
                                    const SizedBox(height: KilnSpacing.lg),
                                    Text('Bearer 密钥', style: KilnTypography.label),
                                    const SizedBox(height: KilnSpacing.xs),
                                    TextField(
                                      controller: _controller,
                                      enabled: !loading,
                                      obscureText: true,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      style: KilnTypography.mono(
                                        size: 13,
                                        color: KilnColors.ink100,
                                        letterSpacing: 4.0,
                                      ),
                                      decoration: InputDecoration(
                                        errorText: _errorMessage,
                                      ),
                                    ),
                                    const SizedBox(height: KilnSpacing.md),
                                    GradientButton(
                                      label: loading ? '正在连接…' : '进入工作室',
                                      icon: loading ? null : Icons.key_rounded,
                                      expand: true,
                                      onPressed: loading ? null : _submit,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: KilnSpacing.md),
                              Center(
                                child: Text.rich(
                                  TextSpan(
                                    style: KilnTypography.bodyS.copyWith(
                                      color: KilnColors.ink500,
                                    ),
                                    children: [
                                      const TextSpan(text: '已连接到 '),
                                      TextSpan(
                                        text: widget.baseUrl.toString(),
                                        style: KilnTypography.mono(
                                          size: 11,
                                          color: KilnColors.ink300,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Backdrop used by both onboarding and login (kept in sync with
/// `onboarding_screen.dart`).
class _AmberBackdrop extends StatelessWidget {
  const _AmberBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ColoredBox(
          color: KilnColors.ink950,
          child: SizedBox.expand(),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -1.2),
                radius: 1.2,
                colors: [
                  KilnColors.ember500.withValues(alpha: 0.22),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.7],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 1.4),
                radius: 1.3,
                colors: [
                  KilnColors.ember700.withValues(alpha: 0.30),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.7],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(KilnRadii.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: KilnColors.ink900.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(KilnRadii.xl),
            border: Border.all(
              color: KilnColors.hairlineStrong,
              width: 1,
            ),
            boxShadow: KilnShadows.float,
          ),
          padding: const EdgeInsets.all(KilnSpacing.xl),
          child: child,
        ),
      ),
    );
  }
}
