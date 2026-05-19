import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../app/typography.dart';
import 'studio_models.dart';

class TurnDetailScreen extends StatelessWidget {
  const TurnDetailScreen({
    super.key,
    required this.turn,
    this.isFavoriteImage,
    this.onRetry,
    this.onEditPrompt,
    this.onVariation,
    this.onSave,
    this.onOpenImage,
  });

  final StudioTurn turn;
  final bool Function(StudioResultImage image)? isFavoriteImage;
  final VoidCallback? onRetry;
  final VoidCallback? onEditPrompt;
  final VoidCallback? onVariation;
  final VoidCallback? onSave;
  final ValueChanged<StudioResultImage>? onOpenImage;

  @override
  Widget build(BuildContext context) {
    final image = turn.resultImages.isEmpty ? null : turn.resultImages.first;
    return Scaffold(
      appBar: AppBar(title: const Text('Generation Detail')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            KilnSpacing.md,
            KilnSpacing.sm,
            KilnSpacing.md,
            KilnSpacing.xxxl,
          ),
          children: [
            if (image != null)
              _HeroImage(
                image: image,
                prompt: turn.prompt,
                onTap: onOpenImage == null ? null : () => onOpenImage!(image),
              ),
            if (image != null) const SizedBox(height: KilnSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(label: turn.model),
                if ((turn.size ?? '').isNotEmpty) _MetaChip(label: turn.size!),
                _MetaChip(label: _statusLabel(turn.status)),
                _MetaChip(label: _formatTime(turn.updatedAt)),
              ],
            ),
            const SizedBox(height: KilnSpacing.md),
            _PromptSection(prompt: turn.prompt),
            if (turn.resultImages.length > 1) ...[
              const SizedBox(height: KilnSpacing.md),
              _VariantsSection(
                images: turn.resultImages,
                onOpenImage: onOpenImage,
              ),
            ],
            const SizedBox(height: KilnSpacing.md),
            _ActionsSection(
              canSave: image != null,
              onRetry: onRetry,
              onEditPrompt: onEditPrompt,
              onVariation: onVariation,
              onSave: onSave,
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(StudioTurnStatus status) {
    return switch (status) {
      StudioTurnStatus.queued => 'QUEUED',
      StudioTurnStatus.running => 'RUNNING',
      StudioTurnStatus.success => 'SUCCESS',
      StudioTurnStatus.error => 'ERROR',
    };
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.month)}/${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.image, required this.prompt, this.onTap});

  final StudioResultImage image;
  final String prompt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KilnRadii.xl),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KilnRadii.xl),
            border: Border.all(color: KilnColors.hairlineStrong),
            color: KilnColors.ink900,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(KilnRadii.xl),
                ),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.network(
                    image.url.toString(),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: KilnColors.ink850,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: KilnColors.ink500,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(KilnSpacing.md),
                child: Text(
                  prompt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: KilnTypography.display(
                    size: 18,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KilnSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: KilnColors.ink800,
        borderRadius: BorderRadius.circular(KilnRadii.chip),
        border: Border.all(color: KilnColors.hairlineStrong),
      ),
      child: Text(label, style: KilnTypography.chipMono),
    );
  }
}

class _PromptSection extends StatelessWidget {
  const _PromptSection({required this.prompt});

  final String prompt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KilnSpacing.md),
      decoration: BoxDecoration(
        color: KilnColors.ink900,
        borderRadius: BorderRadius.circular(KilnRadii.card),
        border: Border.all(color: KilnColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Full Prompt', style: KilnTypography.label),
          const SizedBox(height: KilnSpacing.xs),
          SelectableText(prompt, style: KilnTypography.bodyM),
        ],
      ),
    );
  }
}

class _VariantsSection extends StatelessWidget {
  const _VariantsSection({required this.images, this.onOpenImage});

  final List<StudioResultImage> images;
  final ValueChanged<StudioResultImage>? onOpenImage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Variants', style: KilnTypography.label),
        const SizedBox(height: KilnSpacing.sm),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (_, _) => const SizedBox(width: KilnSpacing.sm),
            itemBuilder: (context, index) {
              final image = images[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(KilnRadii.md),
                child: Material(
                  color: KilnColors.ink900,
                  child: InkWell(
                    onTap: onOpenImage == null
                        ? null
                        : () => onOpenImage!(image),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Image.network(
                        image.url.toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Container(color: KilnColors.ink850, width: 96),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ActionsSection extends StatelessWidget {
  const _ActionsSection({
    required this.canSave,
    this.onRetry,
    this.onEditPrompt,
    this.onVariation,
    this.onSave,
  });

  final bool canSave;
  final VoidCallback? onRetry;
  final VoidCallback? onEditPrompt;
  final VoidCallback? onVariation;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: onVariation,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Generate Variation'),
        ),
        const SizedBox(height: KilnSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onEditPrompt,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit Prompt'),
              ),
            ),
            const SizedBox(width: KilnSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ),
          ],
        ),
        if (canSave) ...[
          const SizedBox(height: KilnSpacing.sm),
          TextButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Save to Gallery'),
          ),
        ],
      ],
    );
  }
}
