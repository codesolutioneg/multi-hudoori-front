import 'package:flutter/material.dart';

import 'mobile_ui.dart';

/// Header that scrolls away above a pinned tab bar, with each tab's primary
/// scrollable driving the whole page (NestedScrollView).
class MobileTabbedPage extends StatelessWidget {
  const MobileTabbedPage({
    super.key,
    required this.header,
    required this.tabBar,
    required this.body,
  });

  final Widget header;
  final Widget tabBar;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          sliver: SliverToBoxAdapter(child: header),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _PinnedTabs(tabBar),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: body,
      ),
    );
  }
}

class _PinnedTabs extends SliverPersistentHeaderDelegate {
  _PinnedTabs(this.child);

  final Widget child;

  static const double _height = 66;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: MobileUi.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Align(alignment: AlignmentDirectional.centerStart, child: child),
      ),
    );
  }

  @override
  bool shouldRebuild(_PinnedTabs old) => old.child != child;
}
