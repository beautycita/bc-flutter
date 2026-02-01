import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/category.dart';
import '../providers/auth_provider.dart';
import '../providers/category_provider.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import 'subcategory_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return 'Buenos días';
    } else if (hour >= 12 && hour < 19) {
      return 'Buenas tardes';
    } else {
      return 'Buenas noches';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final categories = ref.watch(categoriesProvider);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculate section heights
    final topSectionHeight = screenHeight * 0.40;

    return Scaffold(
      backgroundColor: BeautyCitaTheme.backgroundWhite,
      body: SafeArea(
        child: Column(
          children: [
            // Top Section (40% of screen)
            SizedBox(
              height: topSectionHeight,
              child: Stack(
                children: [
                  // Background gradient
                  Container(
                    decoration: const BoxDecoration(
                      gradient: BeautyCitaTheme.primaryGradient,
                    ),
                  ),

                  // Content
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.screenPaddingHorizontal,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // BeautyCita brand text
                          Text(
                            AppConstants.appName,
                            style: textTheme.displayLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 40,
                            ),
                          ),
                          const SizedBox(height: BeautyCitaTheme.spaceMD),

                          // Greeting with username
                          Text(
                            authState.username != null
                                ? '${_getGreeting()}, ${authState.username}'
                                : _getGreeting(),
                            style: textTheme.headlineMedium?.copyWith(
                              color: Colors.white.withOpacity(0.95),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Top-right buttons
                  Positioned(
                    top: BeautyCitaTheme.spaceMD,
                    right: BeautyCitaTheme.spaceMD,
                    child: Row(
                      children: [
                        // My Bookings button
                        Material(
                          color: Colors.white.withOpacity(0.2),
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: () => context.push('/my-bookings'),
                            customBorder: const CircleBorder(),
                            child: const Padding(
                              padding: EdgeInsets.all(BeautyCitaTheme.spaceMD),
                              child: Icon(
                                Icons.calendar_today,
                                color: Colors.white,
                                size: AppConstants.iconSizeMD,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: BeautyCitaTheme.spaceSM),
                        // Settings button
                        Material(
                          color: Colors.white.withOpacity(0.2),
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: () => _showSettingsDialog(context, ref),
                            customBorder: const CircleBorder(),
                            child: const Padding(
                              padding: EdgeInsets.all(BeautyCitaTheme.spaceMD),
                              child: Icon(
                                Icons.settings_outlined,
                                color: Colors.white,
                                size: AppConstants.iconSizeMD,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Section (60% of screen) - Category Grid
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(BeautyCitaTheme.spaceMD),
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppConstants.gridSpacing,
                    mainAxisSpacing: AppConstants.gridSpacing,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return _CategoryCard(
                      category: category,
                      onTap: () => _showSubcategorySheet(context, category),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubcategorySheet(BuildContext context, ServiceCategory category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SubcategorySheet(category: category),
    );
  }

  void _showSettingsDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BeautyCitaTheme.backgroundWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BeautyCitaTheme.radiusXL),
        ),
      ),
      builder: (sheetContext) {
        final username = ref.read(authStateProvider).username ?? '';
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(BeautyCitaTheme.spaceLG),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: AppConstants.bottomSheetDragHandleWidth,
                  height: AppConstants.bottomSheetDragHandleHeight,
                  decoration: BoxDecoration(
                    color: BeautyCitaTheme.dividerLight,
                    borderRadius: BorderRadius.circular(
                      AppConstants.bottomSheetDragHandleRadius,
                    ),
                  ),
                ),
                const SizedBox(height: BeautyCitaTheme.spaceLG),

                // Username display
                Text(
                  username,
                  style: Theme.of(sheetContext).textTheme.headlineMedium?.copyWith(
                    color: BeautyCitaTheme.primaryRose,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: BeautyCitaTheme.spaceXL),

                // Logout button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await ref.read(authStateProvider.notifier).logout();
                      if (context.mounted) {
                        context.go('/auth');
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                  ),
                ),
                const SizedBox(height: BeautyCitaTheme.spaceMD),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final ServiceCategory category;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Card(
      elevation: BeautyCitaTheme.elevationCard,
      shadowColor: category.color.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
            gradient: LinearGradient(
              colors: [
                category.color.withOpacity(0.15),
                category.color.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Emoji icon
              Text(
                category.icon,
                style: const TextStyle(
                  fontSize: 48,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: BeautyCitaTheme.spaceSM),

              // Category name
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: BeautyCitaTheme.spaceXS,
                ),
                child: Text(
                  category.nameEs,
                  style: textTheme.titleMedium?.copyWith(
                    color: category.color.withOpacity(0.9),
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
