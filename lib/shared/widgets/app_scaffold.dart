import 'package:flutter/material.dart';
import 'package:servllama/shared/widgets/app_message.dart';

/// Shared page shell. Runtime/providers stay outside the presentation layer.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
  });
  final PreferredSizeWidget? appBar;
  final Widget? body, floatingActionButton, bottomNavigationBar;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;
  final bool extendBody, extendBodyBehindAppBar;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appBar,
    body: AppMessageHost(child: body ?? const SizedBox()),
    floatingActionButton: floatingActionButton,
    floatingActionButtonLocation: floatingActionButtonLocation,
    bottomNavigationBar: bottomNavigationBar,
    backgroundColor: backgroundColor,
    resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    extendBody: extendBody,
    extendBodyBehindAppBar: extendBodyBehindAppBar,
  );
}
