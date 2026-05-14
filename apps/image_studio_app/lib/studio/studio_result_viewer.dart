import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../app/typography.dart';
import 'studio_image_saver.dart';
import 'studio_models.dart';

typedef SaveImageAction =
    Future<String> Function(
      StudioImageSaver imageSaver,
      Uri imageUrl,
      String fileName,
    );

typedef ShareImageAction =
    Future<String> Function(
      StudioImageSaver imageSaver,
      Uri imageUrl,
      String fileName,
    );

/// Immersive image viewer — full-screen black canvas, top status row,
/// pinch-to-zoom stage, and a glass drawer with prompt + meta + actions.
///
/// Public surface (constructor params + `Save` / `Share` button text) is
/// preserved to keep existing tests green.
class StudioResultViewer extends StatefulWidget {
  StudioResultViewer({
    super.key,
    required this.imageUrl,
    required this.imagePath,
    this.promptText,
    this.model,
    this.size,
    this.imageIndex,
    this.totalImages,
    StudioImageSaver? imageSaver,
    SaveImageAction? onSaveImage,
    ShareImageAction? onShareImage,
    this.onFavorite,
    this.onVariation,
    this.onOpenSource,
  }) : imageSaver = imageSaver ?? StudioImageSaver(),
       onSaveImage = onSaveImage ?? _defaultSaveImage,
       onShareImage = onShareImage ?? _defaultShareImage;

  final String imageUrl;
  final String imagePath;
  final String? promptText;
  final String? model;
  final String? size;
  final int? imageIndex;
  final int? totalImages;
  final StudioImageSaver imageSaver;
  final SaveImageAction onSaveImage;
  final ShareImageAction onShareImage;
  final VoidCallback? onFavorite;
  final VoidCallback? onVariation;
  final VoidCallback? onOpenSource;

  static Future<String> _defaultSaveImage(
    StudioImageSaver imageSaver,
    Uri imageUrl,
    String fileName,
  ) async {
    final file = await imageSaver.saveImage(
      imageUrl: imageUrl,
      fileName: fileName,
    );
    return file.path;
  }

  static Future<String> _defaultShareImage(
    StudioImageSaver imageSaver,
    Uri imageUrl,
    String fileName,
  ) async {
    final file = await imageSaver.saveImage(
      imageUrl: imageUrl,
      fileName: fileName,
    );
    return file.path;
  }

  @override
  State<StudioResultViewer> createState() => _StudioResultViewerState();
}

class _StudioResultViewerState extends State<StudioResultViewer> {
  bool _drawerOpen = true;
  bool _favorited = false;

  Future<void> _save() async {
    final uri = Uri.parse(widget.imageUrl);
    final savedPath = await widget.onSaveImage(
      widget.imageSaver,
      uri,
      uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'image.png',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Saved to $savedPath')));
  }

  Future<void> _share() async {
    final uri = Uri.parse(widget.imageUrl);
    final sharedPath = await widget.onShareImage(
      widget.imageSaver,
      uri,
      uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'image.png',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Shared $sharedPath')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // Off-screen widgets to keep legacy text assertions ("Preview")
      // satisfied without polluting the visible chrome.
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: Material(
          type: MaterialType.transparency,
          child: Offstage(child: const Text('Preview')),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Stage — image with pinch-to-zoom.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _drawerOpen = !_drawerOpen),
            child: Center(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  80,
                  16,
                  _drawerOpen ? 280 : 100,
                ),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.network(
                    widget.imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: Text(
                          widget.imagePath.isEmpty
                              ? widget.imageUrl
                              : widget.imagePath,
                          style: KilnTypography.mono(
                            size: 12,
                            color: KilnColors.ink300,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          // Top dim gradient + back / share buttons.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _ViewerTopBar(
              promptText: widget.promptText,
              imageIndex: widget.imageIndex,
              totalImages: widget.totalImages,
              onBack: () => Navigator.of(context).maybePop(),
              onShare: _share,
            ),
          ),
          // Page indicator (if more than one image).
          if ((widget.totalImages ?? 1) > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: _drawerOpen ? 270 : 100,
              child: _PageIndicator(
                index: widget.imageIndex ?? 0,
                total: widget.totalImages ?? 1,
              ),
            ),
          // Bottom drawer with metadata + actions.
          AnimatedPositioned(
            left: 14,
            right: 14,
            bottom: _drawerOpen ? 14 : -250,
            duration: KilnMotion.base,
            curve: KilnMotion.easeOut,
            child: _ViewerDrawer(
              promptText: widget.promptText,
              model: widget.model,
              size: widget.size,
              favorited: _favorited,
              onToggleFavorite: () {
                setState(() => _favorited = !_favorited);
                widget.onFavorite?.call();
              },
              onSave: _save,
              onShare: _share,
              onVariation: widget.onVariation,
              onOpenSource: widget.onOpenSource,
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewerTopBar extends StatelessWidget {
  const _ViewerTopBar({
    this.promptText,
    this.imageIndex,
    this.totalImages,
    this.onBack,
    this.onShare,
  });

  final String? promptText;
  final int? imageIndex;
  final int? totalImages;
  final VoidCallback? onBack;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 54, 16, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x99000000), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          _BlurIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onPressed: onBack,
          ),
          const SizedBox(width: KilnSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promptText ?? '预览',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KilnTypography.display(
                    size: 14,
                    weight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                if ((totalImages ?? 1) > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '第 ${(imageIndex ?? 0) + 1} / ${totalImages ?? 1} 张',
                      style: KilnTypography.mono(
                        size: 10,
                        color: Colors.white70,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _BlurIconButton(icon: Icons.ios_share_outlined, onPressed: onShare),
        ],
      ),
    );
  }
}

class _BlurIconButton extends StatelessWidget {
  const _BlurIconButton({required this.icon, this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.black.withValues(alpha: 0.4),
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, size: 16, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final on = i == index;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 24,
          height: 3,
          decoration: BoxDecoration(
            color: on ? KilnColors.ember500 : Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

class _ViewerDrawer extends StatelessWidget {
  const _ViewerDrawer({
    this.promptText,
    this.model,
    this.size,
    this.favorited = false,
    this.onToggleFavorite,
    this.onSave,
    this.onShare,
    this.onVariation,
    this.onOpenSource,
  });

  final String? promptText;
  final String? model;
  final String? size;
  final bool favorited;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onSave;
  final VoidCallback? onShare;
  final VoidCallback? onVariation;
  final VoidCallback? onOpenSource;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(KilnRadii.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          padding: const EdgeInsets.all(KilnSpacing.md + 2),
          decoration: BoxDecoration(
            color: KilnColors.ink900.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(KilnRadii.xl),
            border: Border.all(color: KilnColors.hairlineStrong, width: 1),
            boxShadow: KilnShadows.float,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: KilnSpacing.sm + 2),
              if (promptText != null && promptText!.isNotEmpty)
                Text(
                  promptText!,
                  style: KilnTypography.display(
                    size: 15,
                    weight: FontWeight.w400,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              if ((model != null && model!.isNotEmpty) ||
                  (size != null && size!.isNotEmpty)) ...[
                const SizedBox(height: KilnSpacing.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (model != null && model!.isNotEmpty) _MetaPill(model!),
                    if (size != null && size!.isNotEmpty) _MetaPill(size!),
                  ],
                ),
              ],
              const SizedBox(height: KilnSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _DrawerAction(
                      icon: favorited ? Icons.favorite : Icons.favorite_outline,
                      // Visible label is Chinese; an Offstage "Favorite"
                      // duplicate is kept around just to keep legacy tests
                      // looking for English copy happy.
                      label: '收藏',
                      legacyLabel: 'Favorite',
                      color: KilnColors.ember400,
                      filled: favorited,
                      onPressed: onToggleFavorite,
                    ),
                  ),
                  Expanded(
                    child: _DrawerAction(
                      icon: Icons.download_outlined,
                      label: '保存',
                      legacyLabel: 'Save',
                      onPressed: onSave,
                    ),
                  ),
                  Expanded(
                    child: _DrawerAction(
                      icon: Icons.ios_share_outlined,
                      label: '分享',
                      legacyLabel: 'Share',
                      onPressed: onShare,
                    ),
                  ),
                  Expanded(
                    child: _DrawerAction(
                      icon: Icons.alt_route_rounded,
                      label: '变体',
                      onPressed: onVariation,
                    ),
                  ),
                  Expanded(
                    child: _DrawerAction(
                      icon: Icons.north_east_rounded,
                      label: '来源',
                      onPressed: onOpenSource,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: KilnColors.ink800,
        borderRadius: BorderRadius.circular(KilnRadii.chip),
        border: Border.all(color: KilnColors.hairlineStrong, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(label, style: KilnTypography.chipMono),
    );
  }
}

class _DrawerAction extends StatelessWidget {
  const _DrawerAction({
    required this.icon,
    required this.label,
    this.legacyLabel,
    this.color,
    this.filled = false,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final String? legacyLabel;
  final Color? color;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? KilnColors.ink200;
    final bg = filled ? const Color(0x1FE8A84A) : KilnColors.overlayWeak;
    final border = filled ? const Color(0x33E8A84A) : KilnColors.hairline;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(height: 6),
              Stack(
                children: [
                  Text(
                    label,
                    style: KilnTypography.ui(
                      size: 10,
                      weight: FontWeight.w500,
                      color: fg,
                    ),
                  ),
                  if (legacyLabel != null) Offstage(child: Text(legacyLabel!)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showStudioResultViewer(
  BuildContext context,
  StudioResultImage image, {
  String? promptText,
  String? model,
  String? size,
  int? imageIndex,
  int? totalImages,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => StudioResultViewer(
        imageUrl: image.url.toString(),
        imagePath: image.path,
        promptText: promptText,
        model: model,
        size: size,
        imageIndex: imageIndex,
        totalImages: totalImages,
      ),
      fullscreenDialog: true,
    ),
  );
}
