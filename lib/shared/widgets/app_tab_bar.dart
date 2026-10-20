import 'package:flutter/material.dart';

class AppTabBar extends StatefulWidget implements PreferredSizeWidget {
  const AppTabBar({super.key, this.controller, required this.tabs, this.onTap});
  final TabController? controller;
  final List<Widget> tabs;
  final ValueChanged<int>? onTap;
  @override
  Size get preferredSize => const Size.fromHeight(64);
  @override
  State<AppTabBar> createState() => _AppTabBarState();
}

class _AppTabBarState extends State<AppTabBar> {
  TabController? _controller;
  int? _index;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindController();
  }

  @override
  void didUpdateWidget(covariant AppTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bindController();
  }

  void _bindController() {
    final next = widget.controller ?? DefaultTabController.maybeOf(context);
    if (identical(next, _controller)) return;
    _controller?.removeListener(_onChanged);
    _controller = next;
    _index = next?.index;
    next?.addListener(_onChanged);
  }

  void _onChanged() {
    final index = _controller?.index;
    if (index == _index) return;
    _index = index;
    // Observe the index, so taps, swipes and programmatic switches agree.
    if (ModalRoute.isCurrentOf(context) == true) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    child: TabBar(
      controller: widget.controller,
      tabs: widget.tabs,
      onTap: widget.onTap,
    ),
  );
}
