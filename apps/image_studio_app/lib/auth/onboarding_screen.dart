import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/defaults.dart';
import '../app/tokens.dart';
import '../app/typography.dart';
import '../shared/brand/kiln_logo.dart';
import '../shared/components/gradient_button.dart';

/// Step 1 of the entry flow — connect to a chatgpt2api backend.
///
/// Visual: a warm gradient background, brand mark + Fraunces "Kiln" wordmark,
/// a glass-card form with one input and the primary CTA.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onContinue});

  final ValueChanged<Uri> onContinue;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: defaultBackendUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) {
      setState(() => _error = '请填入完整的服务器地址（含 https://）');
      return;
    }
    setState(() => _error = null);
    widget.onContinue(uri);
  }

  @override
  Widget build(BuildContext context) {
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
                                '把每一次 prompt\n变成一段视觉对话。',
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
                                '第 1 步 / 共 2 步 · 服务器'.toUpperCase(),
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
                                      '连接你的工作室',
                                      style: KilnTypography.display(
                                        size: 22,
                                        weight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '填入任意 chatgpt2api 服务地址。之后可以随时在「我的」里更换。',
                                      style: KilnTypography.bodyS,
                                    ),
                                    const SizedBox(height: KilnSpacing.lg),
                                    Text('服务器地址', style: KilnTypography.label),
                                    const SizedBox(height: KilnSpacing.xs),
                                    TextField(
                                      controller: _controller,
                                      keyboardType: TextInputType.url,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      style: KilnTypography.mono(
                                        size: 13,
                                        color: KilnColors.ink100,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'https://example.com',
                                        errorText: _error,
                                      ),
                                    ),
                                    const SizedBox(height: KilnSpacing.md),
                                    GradientButton(
                                      label: '继续',
                                      icon: Icons.arrow_forward_rounded,
                                      expand: true,
                                      onPressed: _submit,
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
                                      const TextSpan(text: '需要帮助？'),
                                      TextSpan(
                                        text: '查看接入指南 ↗',
                                        style: TextStyle(
                                          color: KilnColors.ember400,
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

/// Warm radial gradient backdrop — the same atmosphere used in both
/// onboarding and login.
class _AmberBackdrop extends StatelessWidget {
  const _AmberBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ColoredBox(color: KilnColors.ink950, child: SizedBox.expand()),
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

/// Glass card with backdrop blur — used for all auth forms.
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
            border: Border.all(color: KilnColors.hairlineStrong, width: 1),
            boxShadow: KilnShadows.float,
          ),
          padding: const EdgeInsets.all(KilnSpacing.xl),
          child: child,
        ),
      ),
    );
  }
}
