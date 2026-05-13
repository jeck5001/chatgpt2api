import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../app/typography.dart';
import '../shared/components/ember_pulse_dot.dart';
import '../shared/components/kiln_card.dart';
import '../shared/components/shimmer_placeholder.dart';
import 'studio_models.dart';

/// One conversation turn rendered as a large card.
///
/// Renders three faces depending on [StudioTurn.status]:
///   • success — prompt + meta + image grid + action row, plus the warm
///     "kiln heat" glow at the bottom edge.
///   • running — shimmer placeholders + pulsing ember dot status line +
///     an optional Cancel action.
///   • error — calm red-edge block + Retry / Edit prompt actions.
class TurnCard extends StatelessWidget {
  const TurnCard({
    super.key,
    required this.turn,
    this.onImageTap,
    this.onFavorite,
    this.onVariation,
    this.onEdit,
    this.onSave,
    this.onShare,
    this.onCancel,
    this.onRetry,
    this.onEditPrompt,
    this.isFavoriteImage,
    this.runningElapsed,
  });

  final StudioTurn turn;
  final void Function(StudioResultImage image, int index)? onImageTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onVariation;
  final VoidCallback? onEdit;
  final VoidCallback? onSave;
  final VoidCallback? onShare;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onEditPrompt;
  final bool Function(StudioResultImage image)? isFavoriteImage;
  final String? runningElapsed;

  bool get _isError => turn.status == StudioTurnStatus.error;

  @override
  Widget build(BuildContext context) {
    return KilnCard(
      emberGlow: !_isError,
      borderColor: _isError
          ? const Color(0x4DE07A6B)
          : KilnColors.hairline,
      background: _isError
          ? const Color(0x0FE07A6B)
          : KilnColors.ink900,
      padding: const EdgeInsets.all(KilnSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PromptBlock(turn: turn),
          const SizedBox(height: KilnSpacing.sm),
          _MetaRow(turn: turn),
          ..._buildBodyForStatus(),
        ],
      ),
    );
  }

  List<Widget> _buildBodyForStatus() {
    switch (turn.status) {
      case StudioTurnStatus.success:
        if (turn.resultImages.isEmpty) {
          return const [SizedBox.shrink()];
        }
        return [
          const SizedBox(height: KilnSpacing.md),
          _ImageGrid(turn: turn, onImageTap: onImageTap),
          const SizedBox(height: KilnSpacing.md),
          _ActionsRow(
            onFavorite: onFavorite,
            onVariation: onVariation,
            onEdit: onEdit,
            onSave: onSave,
            onShare: onShare,
            isFavorite: _isAnyFavorite(),
          ),
        ];
      case StudioTurnStatus.queued:
      case StudioTurnStatus.running:
        return [
          const SizedBox(height: KilnSpacing.md),
          _RunningGrid(count: turn.resultImages.isEmpty ? 2 : turn.resultImages.length),
          const SizedBox(height: KilnSpacing.sm),
          _RunningStatusLine(elapsed: runningElapsed),
          if (onCancel != null) ...[
            const SizedBox(height: KilnSpacing.sm),
            _CancelButton(onPressed: onCancel),
          ],
        ];
      case StudioTurnStatus.error:
        return [
          const SizedBox(height: KilnSpacing.md),
          _ErrorBlock(error: turn.error),
          const SizedBox(height: KilnSpacing.md),
          _ErrorActions(
            onEditPrompt: onEditPrompt,
            onRetry: onRetry,
          ),
        ];
    }
  }

  bool _isAnyFavorite() {
    final fn = isFavoriteImage;
    if (fn == null) return false;
    return turn.resultImages.any(fn);
  }
}

class _PromptBlock extends StatelessWidget {
  const _PromptBlock({required this.turn});
  final StudioTurn turn;

  @override
  Widget build(BuildContext context) {
    return Text(
      turn.prompt,
      style: KilnTypography.prompt,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.turn});
  final StudioTurn turn;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      turn.model,
      if (turn.size != null && turn.size!.isNotEmpty) turn.size!,
      if (turn.resultImages.isNotEmpty) '×${turn.resultImages.length} 张',
      _formatTime(turn.updatedAt),
    ];
    return DefaultTextStyle(
      style: KilnTypography.metaMono,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: KilnSpacing.xs,
        children: [
          for (var i = 0; i < parts.length; i++) ...[
            if (i > 0)
              Text('·', style: KilnTypography.metaMono.copyWith(color: KilnColors.ink600)),
            Text(parts[i]),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }
}

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({required this.turn, this.onImageTap});
  final StudioTurn turn;
  final void Function(StudioResultImage image, int index)? onImageTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width > 520
            ? 4
            : width > 320
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemCount: turn.resultImages.length,
          itemBuilder: (context, index) {
            final image = turn.resultImages[index];
            return _ImageTile(
              image: image,
              onTap: onImageTap == null ? null : () => onImageTap!(image, index),
            );
          },
        );
      },
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.image, this.onTap});
  final StudioResultImage image;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Image.network(
          image.url.toString(),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: KilnColors.ink800,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(KilnSpacing.md),
              child: Text(
                image.path.isNotEmpty ? image.path : image.url.toString(),
                textAlign: TextAlign.center,
                style: KilnTypography.metaMono,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RunningGrid extends StatelessWidget {
  const _RunningGrid({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width > 520
            ? 4
            : width > 320
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemCount: count,
          itemBuilder: (context, _) =>
              const ShimmerPlaceholder(borderRadius: 14),
        );
      },
    );
  }
}

class _RunningStatusLine extends StatelessWidget {
  const _RunningStatusLine({this.elapsed});
  final String? elapsed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const EmberPulseDot(),
        const SizedBox(width: KilnSpacing.xs + 2),
        Text(
          elapsed == null ? '正在绘制' : '正在绘制 · $elapsed',
          style: KilnTypography.mono(
            size: 11,
            weight: FontWeight.w500,
            color: KilnColors.ember400,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: KilnSpacing.xs),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.cancel_outlined, size: 14),
        label: const Text('取消'),
        style: TextButton.styleFrom(
          foregroundColor: KilnColors.ink300,
          textStyle: KilnTypography.ui(size: 12, weight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    this.onFavorite,
    this.onVariation,
    this.onEdit,
    this.onSave,
    this.onShare,
    this.isFavorite = false,
  });

  final VoidCallback? onFavorite;
  final VoidCallback? onVariation;
  final VoidCallback? onEdit;
  final VoidCallback? onSave;
  final VoidCallback? onShare;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: KilnColors.hairline, width: 1)),
      ),
      padding: const EdgeInsets.only(top: KilnSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: _ActionTile(
              icon: isFavorite ? Icons.favorite : Icons.favorite_outline,
              color: KilnColors.ember400,
              onPressed: onFavorite,
            ),
          ),
          Expanded(
            child: _ActionTile(
              icon: Icons.refresh_rounded,
              label: '变体',
              onPressed: onVariation,
            ),
          ),
          Expanded(
            child: _ActionTile(
              icon: Icons.edit_outlined,
              label: '编辑',
              onPressed: onEdit,
            ),
          ),
          Expanded(
            child: _ActionTile(
              icon: Icons.download_outlined,
              onPressed: onSave,
            ),
          ),
          Expanded(
            child: _ActionTile(
              icon: Icons.ios_share_outlined,
              onPressed: onShare,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    this.label,
    this.onPressed,
    this.color,
  });

  final IconData icon;
  final String? label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? KilnColors.ink300;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(KilnRadii.sm),
      child: SizedBox(
        height: 36,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: fg),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(
                label!,
                style: KilnTypography.ui(
                  size: 12,
                  weight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KilnSpacing.sm + 2),
      decoration: BoxDecoration(
        color: const Color(0x12E07A6B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x2EE07A6B), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0x2EE07A6B),
              borderRadius: BorderRadius.circular(KilnRadii.sm),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: KilnColors.danger,
            ),
          ),
          const SizedBox(width: KilnSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '上游请求失败',
                  style: KilnTypography.ui(
                    size: 13,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  error.isEmpty ? '未知错误，请稍后重试。' : error,
                  style: KilnTypography.mono(
                    size: 12,
                    color: KilnColors.ink300,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorActions extends StatelessWidget {
  const _ErrorActions({this.onEditPrompt, this.onRetry});
  final VoidCallback? onEditPrompt;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onEditPrompt,
            icon: const Icon(Icons.edit_outlined, size: 14),
            label: const Text('编辑 prompt'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 36),
              textStyle: KilnTypography.ui(size: 13, weight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: KilnSpacing.sm),
        Expanded(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: const Text('重试'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 36),
              textStyle: KilnTypography.ui(size: 13, weight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
