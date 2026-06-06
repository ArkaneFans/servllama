import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class ChatAutoFollowScrollController extends ScrollController {
  ChatAutoFollowScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  });

  bool Function() shouldAutoFollow = () => false;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _ChatAutoFollowScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
      controller: this,
    );
  }
}

class _ChatAutoFollowScrollPosition extends ScrollPositionWithSingleContext {
  _ChatAutoFollowScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    required this.controller,
  });

  final ChatAutoFollowScrollController controller;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final result = super.applyContentDimensions(
      minScrollExtent,
      maxScrollExtent,
    );
    if (controller.shouldAutoFollow() &&
        userScrollDirection == ScrollDirection.idle) {
      final gap = this.maxScrollExtent - pixels;
      if (gap > 0.5) {
        correctPixels(this.maxScrollExtent);
        return false;
      }
    }
    return result;
  }
}
