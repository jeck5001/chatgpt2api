import 'package:flutter/material.dart';

import '../app/accent.dart';
import '../app/tokens.dart';
import '../app/typography.dart';

/// Sticky bottom composer used in Studio.
///
/// One row for the prompt input + send button, second row for the
/// parameter chips (model / size / count / style / + ref image).
class ComposerBar extends StatelessWidget {
  const ComposerBar({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.canSubmit,
    this.params = const [],
    this.onAddReference,
    this.hint = '描述你想要的画面…',
    this.submitting = false,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool canSubmit;
  final List<ComposerChipData> params;
  final VoidCallback? onAddReference;
  final String hint;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final palette = KilnThemeScope.of(context);
    return Container(
      decoration: BoxDecoration(
        color: KilnColors.ink900.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(KilnRadii.xl),
        border: Border.all(color: KilnColors.hairlineStrong, width: 1),
        boxShadow: [
          const BoxShadow(
            color: Color(0x99000000),
            blurRadius: 50,
            offset: Offset(0, 20),
          ),
          BoxShadow(
            color: palette.shade500.withValues(alpha: 0.06),
            blurRadius: 1,
            offset: const Offset(0, 0),
            spreadRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.all(KilnSpacing.sm + 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1 — input + send
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (onAddReference != null) ...[
                _AddRefButton(onPressed: onAddReference),
                const SizedBox(width: KilnSpacing.xs + 2),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  style: KilnTypography.ui(size: 14),
                  cursorColor: palette.shade500,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: KilnTypography.ui(
                      size: 14,
                      color: KilnColors.ink500,
                    ),
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: KilnSpacing.xs + 2,
                      horizontal: KilnSpacing.xs,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                  onSubmitted: (_) {
                    if (canSubmit) onSubmit();
                  },
                ),
              ),
              const SizedBox(width: KilnSpacing.xs),
              _SendButton(
                key: const ValueKey('composer-submit'),
                enabled: canSubmit && !submitting,
                onPressed: onSubmit,
                submitting: submitting,
              ),
            ],
          ),
          if (params.isNotEmpty) ...[
            const SizedBox(height: KilnSpacing.xs + 2),
            const Divider(height: 1, color: KilnColors.hairline),
            const SizedBox(height: KilnSpacing.xs + 2),
            SizedBox(
              height: 28,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: params.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) =>
                    _ComposerChip(data: params[index]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ComposerChipData {
  const ComposerChipData({
    required this.label,
    this.active = false,
    this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;
}

class _ComposerChip extends StatelessWidget {
  const _ComposerChip({required this.data});
  final ComposerChipData data;

  @override
  Widget build(BuildContext context) {
    final palette = KilnThemeScope.of(context);
    final bg = data.active
        ? palette.shade500.withValues(alpha: 0.12)
        : KilnColors.ink800;
    final fg = data.active ? palette.shade400 : KilnColors.ink200;
    final border = data.active
        ? palette.shade500.withValues(alpha: 0.30)
        : KilnColors.hairlineStrong;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(KilnRadii.chip),
        onTap: data.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: KilnSpacing.sm),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(KilnRadii.chip),
            border: Border.all(color: border, width: 1),
          ),
          child: Center(
            child: Text(
              data.label,
              style: KilnTypography.chipMono.copyWith(color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddRefButton extends StatelessWidget {
  const _AddRefButton({this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(KilnRadii.md),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: KilnColors.overlayWeak,
          borderRadius: BorderRadius.circular(KilnRadii.md),
        ),
        child: const Icon(Icons.add, size: 18, color: KilnColors.ink300),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    super.key,
    required this.enabled,
    required this.onPressed,
    required this.submitting,
  });

  final bool enabled;
  final VoidCallback onPressed;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final palette = KilnThemeScope.of(context);
    return AnimatedOpacity(
      duration: KilnMotion.base,
      opacity: enabled ? 1.0 : 0.45,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(KilnRadii.button),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: palette.gradient,
            borderRadius: BorderRadius.circular(KilnRadii.button),
            boxShadow: enabled ? KilnShadows.cta : null,
          ),
          child: submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Color(0xFF1A0E04)),
                    ),
                  ),
                )
              : const Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: Color(0xFF1A0E04),
                ),
        ),
      ),
    );
  }
}
