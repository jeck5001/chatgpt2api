import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../app/typography.dart';
import '../shared/components/section_header.dart';
import '../shared/empty_state.dart';
import 'studio_models.dart';

/// Projects index — a cover-grid view of all projects (top) and the
/// conversations under the active project (below).
///
/// Class name preserved (`ProjectsScreen`) so router and tests keep working.
/// Public surface: `projects` / `conversations` / `activeProjectId` /
/// `activeConversationId` / `onProjectSelected` / `onConversationSelected`.
class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({
    super.key,
    this.projects = const [],
    this.conversations = const [],
    this.activeProjectId,
    this.activeConversationId,
    this.onProjectSelected,
    this.onConversationSelected,
  });

  final List<StudioProject> projects;
  final List<StudioConversation> conversations;
  final String? activeProjectId;
  final String? activeConversationId;
  final ValueChanged<String>? onProjectSelected;
  final ValueChanged<String>? onConversationSelected;

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return const _EmptyProjects();
    }
    final activeProject = projects.firstWhere(
      (p) => p.id == activeProjectId,
      orElse: () => projects.first,
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SectionHeader.large(
                kicker: '06 · 集合',
                title: '项目',
                subtitle:
                    '${projects.length} 个项目 · ${conversations.length} 个会话',
                trailing: _AddButton(onTap: () {}),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: KilnSpacing.sm)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: KilnSpacing.lg),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final project = projects[index];
                  return _CoverCard(
                    project: project,
                    isActive: project.id == activeProjectId,
                    conversationsCount: _conversationsFor(
                      project.id,
                      projects,
                      conversations,
                    ),
                    onTap: () => onProjectSelected?.call(project.id),
                  );
                }, childCount: projects.length),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  KilnSpacing.lg,
                  KilnSpacing.xxl,
                  KilnSpacing.lg,
                  KilnSpacing.sm,
                ),
                child: SectionHeader.inline(
                  title: '${activeProject.name} · 会话',
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                KilnSpacing.lg,
                0,
                KilnSpacing.lg,
                KilnSpacing.xxxl,
              ),
              sliver: SliverList.builder(
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final conv = conversations[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: KilnSpacing.xs),
                    child: _ConversationRow(
                      conversation: conv,
                      isActive: conv.id == activeConversationId,
                      onTap: () => onConversationSelected?.call(conv.id),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _conversationsFor(
    String projectId,
    List<StudioProject> projects,
    List<StudioConversation> conversations,
  ) {
    return conversations.where((c) => c.projectId == projectId).length;
  }
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      title: '还没有',
      accent: '项目',
      message: '生成第一张图后，它就会自动归到一个项目里。',
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KilnRadii.button),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: KilnGradients.kiln,
          borderRadius: BorderRadius.circular(KilnRadii.button),
          boxShadow: KilnShadows.cta,
        ),
        child: const Icon(Icons.add, size: 18, color: Color(0xFF1A0E04)),
      ),
    );
  }
}

class _CoverCard extends StatelessWidget {
  const _CoverCard({
    required this.project,
    required this.isActive,
    required this.conversationsCount,
    this.onTap,
  });

  final StudioProject project;
  final bool isActive;
  final int conversationsCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KilnColors.ink800,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Placeholder gradient background; real cover image would be
            // sourced from the project's latest result image.
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    KilnColors.ember500.withValues(alpha: 0.20),
                    KilnColors.ember700.withValues(alpha: 0.10),
                    KilnColors.ink900,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: KilnGradients.coverOverlay),
              ),
            ),
            if (isActive)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '进行中',
                    style: KilnTypography.mono(
                      size: 9,
                      color: KilnColors.ember400,
                      letterSpacing: 1.8,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    project.name,
                    style: KilnTypography.display(
                      size: 18,
                      weight: FontWeight.w500,
                      color: Colors.white,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$conversationsCount 个会话',
                    style: KilnTypography.mono(
                      size: 10,
                      color: Colors.white.withValues(alpha: 0.65),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.isActive,
    this.onTap,
  });

  final StudioConversation conversation;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? KilnColors.ink800 : KilnColors.ink900,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: KilnSpacing.sm + 2,
            vertical: KilnSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? const Color(0x33E8A84A) : KilnColors.hairline,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0x1FE8A84A)
                      : KilnColors.overlayWeak,
                  borderRadius: BorderRadius.circular(KilnRadii.md),
                ),
                alignment: Alignment.center,
                child: Icon(
                  conversation.mode == StudioTurnMode.edit
                      ? Icons.brush_outlined
                      : Icons.auto_awesome_outlined,
                  size: 16,
                  color: isActive ? KilnColors.ember400 : KilnColors.ink400,
                ),
              ),
              const SizedBox(width: KilnSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.title,
                      style: KilnTypography.ui(
                        size: 14,
                        weight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(conversation.updatedAt),
                      style: KilnTypography.metaMono,
                    ),
                  ],
                ),
              ),
              if (isActive)
                const Padding(
                  padding: EdgeInsets.only(left: KilnSpacing.xs),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: KilnColors.ember400,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }
}
