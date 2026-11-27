import 'package:flutter/material.dart';

import '../theme.dart';

class NavItem {
  final IconData icon;
  final String label;
  final bool enabled;
  const NavItem(this.icon, this.label, {this.enabled = false});
}

/// 240px side navigation. Items that are not built yet are shown disabled with a "Soon" tag.
class AppSidebar extends StatelessWidget {
  final List<NavItem> items;
  final int selected;
  final String workspace;
  final String userName;
  final ValueChanged<int>? onSelect;
  const AppSidebar({
    super.key,
    required this.items,
    required this.workspace,
    required this.userName,
    this.selected = 0,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: AppSpacing.sidebarWidth,
      decoration: BoxDecoration(
        color: c.sidebar,
        border: Border(right: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.controlRadius,
                      ),
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assessly',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: c.text,
                          ),
                        ),
                        Text(
                          workspace,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.sm),
                itemCount: items.length,
                itemBuilder: (context, i) => _tile(context, i, c),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: c.secondarySurface,
                    child: Text(
                      userName.isEmpty ? '?' : userName[0].toUpperCase(),
                      style: TextStyle(
                        color: c.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      userName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.text),
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

  Widget _tile(BuildContext context, int i, AppColors c) {
    final item = items[i];
    final active = i == selected;
    final color = !item.enabled
        ? c.textMuted
        : (active ? c.text : c.textSecondary);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: active ? c.secondarySurface : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
        child: InkWell(
          key: Key('nav-item-$i'),
          borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
          onTap: item.enabled ? () => onSelect?.call(i) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 4,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: [
                Icon(item.icon, size: 18, color: color),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: color,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (!item.enabled)
                  Text(
                    'Soon',
                    style: TextStyle(color: c.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
