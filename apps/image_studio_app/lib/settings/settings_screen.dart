import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../app/typography.dart';
import '../shared/components/section_header.dart';

/// "Me" — five quiet cards. The visible class name stays
/// `SettingsScreen` so existing imports (router, shell) keep working.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.onSignOut,
    this.userName = '王剑锋',
    this.serverUrl = '192.168.5.35:3030',
    this.keyActive = true,
    this.cachedBytes = 342 * 1024 * 1024,
    this.cacheBudgetBytes = 1024 * 1024 * 1024,
    this.appVersion = '1.0.0 (24)',
  });

  final Future<void> Function()? onSignOut;
  final String userName;
  final String serverUrl;
  final bool keyActive;
  final int cachedBytes;
  final int cacheBudgetBytes;
  final String appVersion;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoFavorite = false;
  String _accent = 'ember';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SectionHeader.large(kicker: '07 · 账号', title: '我的'),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                KilnSpacing.lg,
                KilnSpacing.sm,
                KilnSpacing.lg,
                KilnSpacing.xxxl,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _AccountCard(
                    name: widget.userName,
                    serverUrl: widget.serverUrl,
                    keyActive: widget.keyActive,
                    onSignOut: widget.onSignOut,
                  ),
                  const SizedBox(height: KilnSpacing.sm + 2),
                  _DefaultsCard(
                    autoFavorite: _autoFavorite,
                    onToggleAutoFavorite: (v) =>
                        setState(() => _autoFavorite = v),
                  ),
                  const SizedBox(height: KilnSpacing.sm + 2),
                  _AppearanceCard(
                    accent: _accent,
                    onAccentChanged: (v) => setState(() => _accent = v),
                  ),
                  const SizedBox(height: KilnSpacing.sm + 2),
                  _StorageCard(
                    usedBytes: widget.cachedBytes,
                    budgetBytes: widget.cacheBudgetBytes,
                  ),
                  const SizedBox(height: KilnSpacing.sm + 2),
                  _AboutCard(version: widget.appVersion),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== shared atoms ======================================================

class _MeCard extends StatelessWidget {
  const _MeCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KilnSpacing.md + 2),
      decoration: BoxDecoration(
        color: KilnColors.ink900,
        borderRadius: BorderRadius.circular(KilnRadii.card),
        border: Border.all(color: KilnColors.hairline, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            offset: Offset(0, 6),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader.inline(title: title),
          const SizedBox(height: KilnSpacing.sm + 2),
          child,
        ],
      ),
    );
  }
}

class _RowToggle extends StatelessWidget {
  const _RowToggle({
    required this.label,
    this.sub,
    this.value,
    this.toggle,
    this.onToggle,
    this.onTap,
  });

  final String label;
  final String? sub;
  final String? value;
  final bool? toggle;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KilnSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: KilnTypography.ui(size: 13, weight: FontWeight.w500),
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub!,
                      style: KilnTypography.metaMono.copyWith(
                        color: KilnColors.ink500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: KilnTypography.mono(
                  size: 11,
                  color: KilnColors.ember400,
                ),
              ),
            if (toggle != null) ...[
              const SizedBox(width: KilnSpacing.sm),
              Switch.adaptive(
                value: toggle!,
                onChanged: onToggle,
                activeThumbColor: Colors.white,
                activeTrackColor: KilnColors.ember500,
              ),
            ],
            if (value != null && toggle == null)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.keyboard_arrow_right_rounded,
                  size: 16,
                  color: KilnColors.ink500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ===== cards =============================================================

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.name,
    required this.serverUrl,
    required this.keyActive,
    this.onSignOut,
  });

  final String name;
  final String serverUrl;
  final bool keyActive;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    return _MeCard(
      title: '账号',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: KilnGradients.kiln,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: KilnShadows.cta,
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isNotEmpty ? name.characters.first : '?',
                  style: KilnTypography.display(
                    size: 22,
                    weight: FontWeight.w500,
                    color: const Color(0xFF1A0E04),
                  ),
                ),
              ),
              const SizedBox(width: KilnSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: KilnTypography.display(
                        size: 18,
                        weight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: keyActive
                                ? KilnColors.success
                                : KilnColors.danger,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (keyActive
                                            ? KilnColors.success
                                            : KilnColors.danger)
                                        .withValues(alpha: 0.6),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '$serverUrl · ${keyActive ? "密钥有效" : "密钥过期"}',
                            style: KilnTypography.metaMono,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KilnSpacing.lg),
          OutlinedButton(
            onPressed: onSignOut,
            style: OutlinedButton.styleFrom(
              foregroundColor: KilnColors.danger,
              minimumSize: const Size(0, 42),
              side: const BorderSide(color: Color(0x59E07A6B), width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(KilnRadii.button),
              ),
            ),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
  }
}

class _DefaultsCard extends StatelessWidget {
  const _DefaultsCard({
    required this.autoFavorite,
    required this.onToggleAutoFavorite,
  });
  final bool autoFavorite;
  final ValueChanged<bool> onToggleAutoFavorite;

  @override
  Widget build(BuildContext context) {
    return _MeCard(
      title: '生成偏好',
      child: Column(
        children: [
          _RowToggle(
            label: '默认模型',
            sub: '用于每一个新会话',
            value: 'gpt-image-2',
            onTap: () {},
          ),
          const Divider(color: KilnColors.hairline, height: 1),
          _RowToggle(
            label: '默认尺寸',
            sub: '新作品的画幅',
            value: '1024×1024',
            onTap: () {},
          ),
          const Divider(color: KilnColors.hairline, height: 1),
          _RowToggle(label: '每次生成张数', value: '2', onTap: () {}),
          const Divider(color: KilnColors.hairline, height: 1),
          _RowToggle(
            label: '成功后自动收藏',
            sub: '每张成功生成的图自动加星',
            toggle: autoFavorite,
            onToggle: onToggleAutoFavorite,
          ),
        ],
      ),
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard({required this.accent, required this.onAccentChanged});
  final String accent;
  final ValueChanged<String> onAccentChanged;

  @override
  Widget build(BuildContext context) {
    return _MeCard(
      title: '外观',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RowToggle(label: '主题', sub: '浅色主题敬请期待', value: '深色'),
          const Divider(color: KilnColors.hairline, height: 1),
          const SizedBox(height: KilnSpacing.sm + 2),
          Text('强调色', style: KilnTypography.label),
          const SizedBox(height: KilnSpacing.xs + 2),
          Row(
            children: [
              _Swatch(
                gradient: KilnGradients.kiln,
                selected: accent == 'ember',
                onTap: () => onAccentChanged('ember'),
                label: '琥珀',
              ),
              const SizedBox(width: 10),
              _Swatch(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF9CC09F),
                    Color(0xFF5E8B6C),
                    Color(0xFF2E4F3A),
                  ],
                ),
                selected: accent == 'sage',
                onTap: () => onAccentChanged('sage'),
                label: '青苔',
              ),
              const SizedBox(width: 10),
              _Swatch(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFA3B0F2),
                    Color(0xFF5E73C8),
                    Color(0xFF2B3580),
                  ],
                ),
                selected: accent == 'indigo',
                onTap: () => onAccentChanged('indigo'),
                label: '靛蓝',
              ),
              const SizedBox(width: 10),
              _Swatch(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFB8B4A8),
                    Color(0xFF7A766B),
                    Color(0xFF3F3D38),
                  ],
                ),
                selected: accent == 'slate',
                onTap: () => onAccentChanged('slate'),
                label: '岩灰',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.gradient,
    required this.selected,
    required this.onTap,
    required this.label,
  });

  final Gradient gradient;
  final bool selected;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Tooltip(
        message: label,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? KilnColors.ink100 : Colors.transparent,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.usedBytes, required this.budgetBytes});

  final int usedBytes;
  final int budgetBytes;

  @override
  Widget build(BuildContext context) {
    final pct = (usedBytes / budgetBytes).clamp(0.0, 1.0);
    return _MeCard(
      title: '存储',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '图片缓存',
            style: KilnTypography.ui(size: 13, weight: FontWeight.w500),
          ),
          const SizedBox(height: KilnSpacing.xs + 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: KilnColors.ink700),
                  FractionallySizedBox(
                    widthFactor: pct,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(gradient: KilnGradients.kiln),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: KilnSpacing.xs + 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '已用 ${_formatMB(usedBytes)}',
                style: KilnTypography.metaMono.copyWith(
                  color: KilnColors.ink400,
                ),
              ),
              Text(
                '上限 ${_formatMB(budgetBytes)}',
                style: KilnTypography.metaMono.copyWith(
                  color: KilnColors.ink500,
                ),
              ),
            ],
          ),
          const SizedBox(height: KilnSpacing.lg),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    textStyle: KilnTypography.ui(
                      size: 13,
                      weight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('清理缓存'),
                ),
              ),
              const SizedBox(width: KilnSpacing.xs + 2),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    textStyle: KilnTypography.ui(
                      size: 13,
                      weight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('导出收藏'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatMB(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.version});
  final String version;

  @override
  Widget build(BuildContext context) {
    return _MeCard(
      title: '关于',
      child: Column(
        children: [
          _RowToggle(label: '版本', value: version),
          const Divider(color: KilnColors.hairline, height: 1),
          _RowToggle(label: 'GitHub 源码', value: '↗', onTap: () {}),
          const Divider(color: KilnColors.hairline, height: 1),
          _RowToggle(label: '反馈意见', value: '✉', onTap: () {}),
        ],
      ),
    );
  }
}
