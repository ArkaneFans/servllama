import 'dart:async';
import 'package:flutter/material.dart';
import 'package:servllama/shared/widgets/app_message_card.dart';
export 'app_message_card.dart' show AppMessageTone;

/// One transient message, anchored to a mounted page's content area.
abstract final class AppMessage {
  static final _hosts = <ModalRoute<dynamic>, AppMessageHostState>{};
  static AppMessageHostState? _active;

  static void show(
    BuildContext context,
    String text, {
    AppMessageTone tone = AppMessageTone.info,
  }) {
    if (!context.mounted) return;
    final route = ModalRoute.of(context);
    final navigator = Navigator.maybeOf(context);
    final candidates = _hosts.entries.where(
      (e) => e.key.navigator == navigator && e.key.isActive,
    );
    // Async completion should be visible on the current page. Popup routes
    // reuse the underlying page anchor, while the overlay stays above the popup.
    final current = candidates.where((e) => e.key.isCurrent).firstOrNull?.value;
    final host = current ?? _hosts[route] ?? candidates.lastOrNull?.value;
    host?.show(text, tone: tone);
  }

  static void dismiss() => _active?._remove();
}

/// Mount inside Scaffold.body; the follower uses the actual body position,
/// including custom toolbar/tab heights, sidebars and window insets.
class AppMessageHost extends StatefulWidget {
  const AppMessageHost({super.key, required this.child});
  final Widget child;
  static AppMessageHostState of(BuildContext context) =>
      context.findAncestorStateOfType<AppMessageHostState>()!;
  @override
  State<AppMessageHost> createState() => AppMessageHostState();
}

class AppMessageHostState extends State<AppMessageHost>
    with SingleTickerProviderStateMixin {
  final _link = LayerLink();
  final _anchor = GlobalKey();
  late final AnimationController _animation;
  OverlayEntry? _entry;
  Timer? _expiry;
  ModalRoute<dynamic>? _route;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      if (AppMessage._hosts[_route] == this) AppMessage._hosts.remove(_route);
      _route = route;
      // Embedded library pages share the outer page's AppBar and anchor.
      if (route != null && !AppMessage._hosts.containsKey(route)) {
        AppMessage._hosts[route] = this;
      }
    }
    if (_entry != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _entry?.markNeedsBuild(),
      );
    }
  }

  void show(String text, {AppMessageTone tone = AppMessageTone.success}) {
    final box = _anchor.currentContext?.findRenderObject();
    if (!mounted || box is! RenderBox || !box.hasSize) return;
    AppMessage.dismiss();
    AppMessage._active = this;
    _revision++;
    _animation.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    _entry = OverlayEntry(
      builder: (overlayContext) {
        final anchorBox = _anchor.currentContext?.findRenderObject();
        if (!mounted || anchorBox is! RenderBox || !anchorBox.hasSize) {
          return const SizedBox();
        }
        // Theme is captured afresh when switching light/dark in the gallery.
        return InheritedTheme.captureAll(
          context,
          Positioned(
            left: 0,
            top: 0,
            child: CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: const Offset(16, 12),
              child: SizedBox(
                width: (anchorBox.size.width - 32).clamp(0, double.infinity),
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: 1,
                  child: FadeTransition(
                    opacity: _animation,
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(0, (1 - _animation.value) * 8),
                        child: child,
                      ),
                      child: AppMessageCard(
                        text: text,
                        tone: tone,
                        onClose: hide,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    _animation.forward(from: 0);
    _expiry = Timer(const Duration(seconds: 3), hide);
  }

  void hide() {
    _expiry?.cancel();
    final revision = _revision;
    _animation.reverse().then((_) {
      if (mounted && revision == _revision) _remove();
    });
  }

  void _remove() {
    _revision++;
    _expiry?.cancel();
    _animation.stop();
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
    if (AppMessage._active == this) AppMessage._active = null;
  }

  @override
  void dispose() {
    _remove();
    if (AppMessage._hosts[_route] == this) AppMessage._hosts.remove(_route);
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    key: _anchor,
    link: _link,
    child: SizedBox.expand(child: widget.child),
  );
}
