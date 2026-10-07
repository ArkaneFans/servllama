import 'package:flutter/material.dart';
import 'package:servllama/shared/widgets/app_message.dart';

/// Clears transient presentation state when the visible route changes.
class AppNavigationObserver extends NavigatorObserver {
  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    AppMessage.dismiss();
    final focus = FocusManager.instance.primaryFocus;
    final context = focus?.context;
    if (previousTopRoute == null || context == null || !context.mounted) return;
    if (ModalRoute.of(context) == previousTopRoute) {
      // Clear the departing input's scope history before Flutter restores it
      // on return. A delayed global unfocus would steal destination autofocus.
      focus!.unfocus();
    }
  }
}
