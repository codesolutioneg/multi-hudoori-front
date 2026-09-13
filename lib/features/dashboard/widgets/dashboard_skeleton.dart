import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/widgets/skeleton_box.dart';

/// Full-page placeholder while dashboard data loads.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key, this.showCharts = true});

  final bool showCharts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showCharts) ...[
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 1100 ? 4 : (c.maxWidth >= 700 ? 2 : 1);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: cols == 1 ? 0.92 : 0.82,
                ),
                itemCount: 4,
                itemBuilder: (context, index) => const _DonutSkeletonCard(),
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth >= 900) {
                return const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _PanelSkeleton(height: 280)),
                    SizedBox(width: 12),
                    Expanded(child: _PanelSkeleton(height: 280)),
                  ],
                );
              }
              return const Column(
                children: [
                  _PanelSkeleton(height: 220),
                  SizedBox(height: 12),
                  _PanelSkeleton(height: 260),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
        ],
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 800 ? 3 : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.4,
              ),
              itemCount: cols == 1 ? 1 : 3,
              itemBuilder: (context, index) => const _StatSkeletonCard(),
            );
          },
        ),
      ],
    );
  }
}

class _DonutSkeletonCard extends StatelessWidget {
  const _DonutSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radius2xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: AlignmentDirectional.centerEnd,
            child: SkeletonBox(height: 18, width: 56),
          ),
          const SizedBox(height: 6),
          const Flexible(
            child: Center(
              child: SkeletonBox(
                height: 96,
                width: 96,
                borderRadius: BorderRadius.all(Radius.circular(48)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const SkeletonBox(height: 9, width: 120),
          const SizedBox(height: 4),
          const SkeletonBox(height: 9, width: 88),
        ],
      ),
    );
  }
}

class _PanelSkeleton extends StatelessWidget {
  const _PanelSkeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radius2xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(height: 14, width: 160),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: 3,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) => const SkeletonListTile(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatSkeletonCard extends StatelessWidget {
  const _StatSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radius2xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: const Row(
        children: [
          SkeletonBox(height: 44, width: 44, borderRadius: BorderRadius.all(Radius.circular(10))),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 12, width: 80),
                SizedBox(height: 8),
                SkeletonBox(height: 22, width: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
