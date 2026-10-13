import 'package:elimupepe/core/webview/sso_webview.dart';
import 'package:flutter/material.dart';
import 'package:elimupepe/models/menu_item.dart';
import 'package:elimupepe/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:elimupepe/features/home/category_items_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  Future<void> _handleMenuTap(BuildContext context, MenuItem item) async {
    if (item.isComingSoon) return;

    final intendedPath = MenuItem.directIntendedPathFor(item.id);
    if (intendedPath != null) {
      await SsoWebViewScreen.open(context, title: item.title, path: intendedPath);
      return;
    }

    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CategoryItemsScreen(menuItem: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = MenuItem.getDefaultMenuItems();

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.lightGreen.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Explore Menu',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandGreen,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Discover more learning resources and activities.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blueGrey.shade600,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.9,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _MenuTile(
                        item: item,
                        onTap: item.isComingSoon
                            ? null
                            : () => _handleMenuTap(context, item),
                      )
                      .animate()
                      .fadeIn(delay: (100 * index).ms)
                      .scale(
                        begin: const Offset(0.9, 0.9),
                        duration: 400.ms,
                        curve: Curves.easeOutBack,
                      );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.item, this.onTap});

  final MenuItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDisabled = item.isComingSoon;

    // Create a vibrant palette to cycle through for the tiles
    final List<Color> tileColors = [
      AppColors.primaryBlue,
      AppColors.brandGreen,
      AppColors.accentOrange,
      AppColors.accentPurple,
      AppColors.accentCoral,
    ];
    final Color itemColor = tileColors[item.title.hashCode % tileColors.length];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.04,
            ), // Softer, neutral shadow
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          splashColor: itemColor.withValues(alpha: 0.15),
          highlightColor: itemColor.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDisabled ? Colors.blueGrey.shade200 : itemColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, size: 28, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDisabled ? Colors.blueGrey.shade400 : itemColor,
                  ),
                ),
                if (isDisabled) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Coming Soon',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
