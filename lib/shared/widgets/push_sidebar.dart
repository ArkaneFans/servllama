import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum PushSidebarSide { left, right }

class PushSidebarController {
  _PushSidebarControllerDelegate? _delegate;

  bool get isAttached => _delegate != null;

  bool get isDrawerMode => _delegate?.isDrawerMode ?? false;

  bool get isOpen => _delegate?.isOpen ?? false;

  double get progress => _delegate?.progress ?? 0;

  Future<void> open() => _delegate?.open() ?? Future<void>.value();

  Future<void> close() => _delegate?.close() ?? Future<void>.value();

  Future<void> toggle() => _delegate?.toggle() ?? Future<void>.value();

  Future<void> animateTo(double progress) =>
      _delegate?.animateTo(progress) ?? Future<void>.value();

  void jumpTo(double progress) {
    _delegate?.jumpTo(progress);
  }

  void _attach(_PushSidebarControllerDelegate delegate) {
    _delegate = delegate;
  }

  void _detach(_PushSidebarControllerDelegate delegate) {
    if (identical(_delegate, delegate)) {
      _delegate = null;
    }
  }
}

class PushSidebar extends StatefulWidget {
  const PushSidebar({
    super.key,
    required this.child,
    required this.drawer,
    this.controller,
    this.side = PushSidebarSide.left,
    this.semanticLabel,
    this.breakpoint = 900,
    this.drawerWidth,
    this.duration = const Duration(milliseconds: 250),
    this.curve = Curves.easeOutCubic,
    this.scrimColor,
    this.maxScrimOpacity = 0.12,
    this.barrierDismissible = true,
    this.enableDrawerTapToClose = false,
    this.elevation = 0,
    this.onScrimTap,
    this.largeScreenInitiallyOpen = true,
    this.embeddedSidebarWidth,
    this.sidebarMinWidth = 200,
    this.sidebarMaxWidth = 360,
    this.sidebarAnimDuration = const Duration(milliseconds: 260),
    this.sidebarAnimCurve = Curves.easeOutCubic,
    this.showResizeHandle,
    this.resizeHitWidth = 6,
    this.resizeLineWidth = 1,
    this.onSidebarWidthChanged,
    this.onSidebarWidthChangeEnd,
    this.flingVelocityThreshold = 365,
    this.settleThreshold = 0.5,
  });

  final Widget child;
  final Widget drawer;
  final PushSidebarController? controller;
  final PushSidebarSide side;
  final String? semanticLabel;
  final double breakpoint;
  final double? drawerWidth;
  final Duration duration;
  final Curve curve;
  final Color? scrimColor;
  final double maxScrimOpacity;
  final bool barrierDismissible;
  final bool enableDrawerTapToClose;
  final double elevation;
  final VoidCallback? onScrimTap;
  final bool largeScreenInitiallyOpen;
  final double? embeddedSidebarWidth;
  final double sidebarMinWidth;
  final double sidebarMaxWidth;
  final Duration sidebarAnimDuration;
  final Curve sidebarAnimCurve;
  final bool? showResizeHandle;
  final double resizeHitWidth;
  final double resizeLineWidth;
  final ValueChanged<double>? onSidebarWidthChanged;
  final ValueChanged<double>? onSidebarWidthChangeEnd;
  final double flingVelocityThreshold;
  final double settleThreshold;

  @override
  State<PushSidebar> createState() => _PushSidebarState();
}

abstract class _PushSidebarControllerDelegate {
  bool get isDrawerMode;

  bool get isOpen;

  double get progress;

  Future<void> open();

  Future<void> close();

  Future<void> toggle();

  Future<void> animateTo(double progress);

  void jumpTo(double progress);
}

class _PushSidebarState extends State<PushSidebar>
    with SingleTickerProviderStateMixin
    implements _PushSidebarControllerDelegate {
  late final AnimationController _mobileController;
  late PushSidebarController _controller;
  late bool _embeddedOpen;
  late double _uncontrolledEmbeddedWidth;

  bool _isDrawerMode = false;
  bool _isResizeHovered = false;
  bool _isResizing = false;
  bool? _lastLayoutWasDrawerMode;

  double get _direction => widget.side == PushSidebarSide.left ? 1 : -1;

  double get _embeddedWidth {
    final widgetWidth = widget.embeddedSidebarWidth;
    if (widgetWidth != null) {
      return _clampWidth(widgetWidth);
    }
    return _uncontrolledEmbeddedWidth;
  }

  @override
  bool get isDrawerMode => _isDrawerMode;

  @override
  bool get isOpen => _isDrawerMode ? progress >= 0.05 : _embeddedOpen;

  @override
  double get progress => _mobileController.value;

  @override
  void initState() {
    super.initState();
    _mobileController = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 0,
    )..addListener(_handleMobileProgressChanged);
    _embeddedOpen = widget.largeScreenInitiallyOpen;
    _uncontrolledEmbeddedWidth = _clampWidth(
      widget.embeddedSidebarWidth ?? 300,
    );
    _controller = widget.controller ?? PushSidebarController();
    _controller._attach(this);
  }

  @override
  void didUpdateWidget(covariant PushSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller._detach(this);
      _controller = widget.controller ?? PushSidebarController();
      _controller._attach(this);
    }
    if (oldWidget.duration != widget.duration) {
      _mobileController.duration = widget.duration;
    }
    if (oldWidget.embeddedSidebarWidth != widget.embeddedSidebarWidth &&
        widget.embeddedSidebarWidth == null) {
      _uncontrolledEmbeddedWidth = _clampWidth(_uncontrolledEmbeddedWidth);
    }
  }

  @override
  void dispose() {
    _controller._detach(this);
    _mobileController
      ..removeListener(_handleMobileProgressChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Future<void> open() async {
    if (_isDrawerMode) {
      await _animateMobileTo(1);
      return;
    }
    if (_embeddedOpen || !mounted) {
      return;
    }
    setState(() {
      _embeddedOpen = true;
    });
  }

  @override
  Future<void> close() async {
    if (_isDrawerMode) {
      await _animateMobileTo(0);
      return;
    }
    if (!_embeddedOpen || !mounted) {
      return;
    }
    setState(() {
      _embeddedOpen = false;
    });
  }

  @override
  Future<void> toggle() {
    return isOpen ? close() : open();
  }

  @override
  Future<void> animateTo(double progress) async {
    final clampedProgress = progress.clamp(0.0, 1.0);
    if (_isDrawerMode) {
      await _animateMobileTo(clampedProgress);
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _embeddedOpen = clampedProgress >= widget.settleThreshold;
    });
  }

  @override
  void jumpTo(double progress) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    if (_isDrawerMode) {
      _mobileController.stop();
      _mobileController.value = clampedProgress;
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _embeddedOpen = clampedProgress >= widget.settleThreshold;
    });
  }

  void _handlePopInvoked(bool didPop) {
    if (didPop) {
      return;
    }
    if (_isDrawerMode && isOpen) {
      close();
    }
  }

  Future<void> _animateMobileTo(double target) async {
    final clampedTarget = target.clamp(0.0, 1.0);
    _mobileController.stop();
    if (_mobileController.value == clampedTarget) {
      return;
    }
    await _mobileController.animateTo(
      clampedTarget,
      duration: widget.duration,
      curve: widget.curve,
    );
  }

  void _handleMobileProgressChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleDrawerDragStart(DragStartDetails details) {
    _mobileController.stop();
  }

  void _handleDrawerDragUpdate(DragUpdateDetails details, double drawerWidth) {
    final delta = (details.primaryDelta ?? 0) * _direction;
    if (delta == 0 || drawerWidth <= 0) {
      return;
    }
    _mobileController.value = (_mobileController.value + delta / drawerWidth)
        .clamp(0.0, 1.0);
  }

  void _handleDrawerDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx * _direction;
    if (velocity.abs() >= widget.flingVelocityThreshold) {
      if (velocity > 0) {
        open();
      } else {
        close();
      }
      return;
    }
    if (_mobileController.value >= widget.settleThreshold) {
      open();
    } else {
      close();
    }
  }

  void _handleScrimTap() {
    widget.onScrimTap?.call();
    if (widget.barrierDismissible) {
      close();
    }
  }

  void _handleEmbeddedResizeStart(DragStartDetails details) {
    if (!_embeddedOpen || !mounted) {
      return;
    }
    setState(() {
      _isResizing = true;
    });
  }

  void _handleEmbeddedResizeUpdate(DragUpdateDetails details) {
    if (!_embeddedOpen) {
      return;
    }
    final delta = details.primaryDelta ?? 0;
    final nextWidth = _clampWidth(_embeddedWidth + (delta * _direction));
    _setEmbeddedWidth(nextWidth, notifyEnd: false);
  }

  void _handleEmbeddedResizeEnd(DragEndDetails details) {
    if (!_isResizing) {
      return;
    }
    final width = _embeddedWidth;
    widget.onSidebarWidthChangeEnd?.call(width);
    if (mounted) {
      setState(() {
        _isResizing = false;
      });
    }
  }

  void _setEmbeddedWidth(double width, {required bool notifyEnd}) {
    final clampedWidth = _clampWidth(width);
    widget.onSidebarWidthChanged?.call(clampedWidth);
    if (widget.embeddedSidebarWidth == null && mounted) {
      setState(() {
        _uncontrolledEmbeddedWidth = clampedWidth;
      });
    }
    if (notifyEnd) {
      widget.onSidebarWidthChangeEnd?.call(clampedWidth);
    }
  }

  double _clampWidth(double width) {
    return width.clamp(widget.sidebarMinWidth, widget.sidebarMaxWidth);
  }

  bool _resolveShowResizeHandle(double width) {
    final explicit = widget.showResizeHandle;
    if (explicit != null) {
      return explicit && _embeddedOpen;
    }
    return _embeddedOpen && width >= 1200 && _isDesktopPlatform();
  }

  bool _isDesktopPlatform() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
  }

  Widget _buildMobileLayout(BuildContext context, double drawerWidth) {
    final theme = Theme.of(context);
    final opacity = (widget.maxScrimOpacity * progress).clamp(0.0, 1.0);
    final scrimColor = (widget.scrimColor ?? theme.colorScheme.onSurface)
        .withAlpha((255 * opacity).round());
    final mainOffset = drawerWidth * progress * _direction;
    final panelOffset = -drawerWidth * (1 - progress) * _direction;

    return Stack(
      children: [
        Transform.translate(
          key: const Key('push_sidebar_main_content'),
          offset: Offset(mainOffset, 0),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: _handleDrawerDragStart,
            onHorizontalDragUpdate: (details) =>
                _handleDrawerDragUpdate(details, drawerWidth),
            onHorizontalDragEnd: _handleDrawerDragEnd,
            child: Stack(
              children: [
                Positioned.fill(child: widget.child),
                if (progress > 0)
                  Positioned.fill(
                    child: GestureDetector(
                      key: const Key('push_sidebar_scrim'),
                      behavior: HitTestBehavior.opaque,
                      onTap: _handleScrimTap,
                      child: ColoredBox(color: scrimColor),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (progress > 0)
          Align(
            alignment: widget.side == PushSidebarSide.left
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Transform.translate(
              offset: Offset(panelOffset, 0),
              child: SizedBox(
                width: drawerWidth,
                height: double.infinity,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: widget.enableDrawerTapToClose ? _handleScrimTap : null,
                  onHorizontalDragStart: _handleDrawerDragStart,
                  onHorizontalDragUpdate: (details) =>
                      _handleDrawerDragUpdate(details, drawerWidth),
                  onHorizontalDragEnd: _handleDrawerDragEnd,
                  child: _SidebarPanel(
                    key: const Key('push_sidebar_panel'),
                    elevation: widget.elevation,
                    semanticLabel: widget.semanticLabel,
                    child: widget.drawer,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmbeddedLayout(BuildContext context, double width) {
    final targetWidth = _embeddedWidth;
    final visibleWidth = _embeddedOpen ? targetWidth : 0.0;
    final showResizeHandle = _resolveShowResizeHandle(width);
    final resizeLineColor = _isResizeHovered
        ? Theme.of(context).colorScheme.primary.withAlpha(46)
        : Theme.of(context).colorScheme.outlineVariant.withAlpha(42);
    final sidebar = AnimatedContainer(
      key: const Key('push_sidebar_panel'),
      duration: _isResizing ? Duration.zero : widget.sidebarAnimDuration,
      curve: widget.sidebarAnimCurve,
      width: visibleWidth,
      child: ClipRect(
        child: Align(
          alignment: widget.side == PushSidebarSide.left
              ? Alignment.centerLeft
              : Alignment.centerRight,
          child: SizedBox(
            width: targetWidth,
            height: double.infinity,
            child: _SidebarPanel(
              elevation: widget.elevation,
              semanticLabel: widget.semanticLabel,
              child: widget.drawer,
            ),
          ),
        ),
      ),
    );
    final resizeHandle = showResizeHandle
        ? MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            onEnter: (_) {
              setState(() {
                _isResizeHovered = true;
              });
            },
            onExit: (_) {
              setState(() {
                _isResizeHovered = false;
              });
            },
            child: GestureDetector(
              key: const Key('push_sidebar_resize_handle'),
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: _handleEmbeddedResizeStart,
              onHorizontalDragUpdate: _handleEmbeddedResizeUpdate,
              onHorizontalDragEnd: _handleEmbeddedResizeEnd,
              child: SizedBox(
                width: widget.resizeHitWidth,
                child: Center(
                  child: Container(
                    width: widget.resizeLineWidth,
                    color: resizeLineColor,
                  ),
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    final leadingSection = Row(
      mainAxisSize: MainAxisSize.min,
      children: widget.side == PushSidebarSide.left
          ? [sidebar, resizeHandle]
          : [resizeHandle, sidebar],
    );

    return Row(
      children: [
        if (widget.side == PushSidebarSide.left) leadingSection,
        Expanded(child: widget.child),
        if (widget.side == PushSidebarSide.right) leadingSection,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDrawerMode = constraints.maxWidth < widget.breakpoint;
        if (_lastLayoutWasDrawerMode != isDrawerMode) {
          final wasDrawerMode = _lastLayoutWasDrawerMode;
          final wasOpen = wasDrawerMode == null
              ? false
              : (wasDrawerMode ? progress >= 0.05 : _embeddedOpen);
          _isDrawerMode = isDrawerMode;
          _lastLayoutWasDrawerMode = isDrawerMode;
          if (wasDrawerMode != null) {
            if (_isDrawerMode) {
              _mobileController.value = wasOpen ? 1 : 0;
            } else {
              _embeddedOpen = wasOpen;
            }
          }
        }
        final drawerWidth = widget.drawerWidth ?? constraints.maxWidth * 0.75;

        return PopScope(
          canPop: !(_isDrawerMode && isOpen),
          onPopInvokedWithResult: (didPop, _) => _handlePopInvoked(didPop),
          child: _isDrawerMode
              ? _buildMobileLayout(context, drawerWidth)
              : _buildEmbeddedLayout(context, constraints.maxWidth),
        );
      },
    );
  }
}

class _SidebarPanel extends StatelessWidget {
  const _SidebarPanel({
    super.key,
    required this.child,
    required this.elevation,
    required this.semanticLabel,
  });

  final Widget child;
  final double elevation;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final content = Material(
      elevation: elevation,
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: child,
    );
    if (semanticLabel == null) {
      return content;
    }
    return Semantics(container: true, label: semanticLabel, child: content);
  }
}
