import 'package:flutter/material.dart';

/// Scrollable form with consistent space between fields, help and actions.
class FormListView extends StatelessWidget {
  const FormListView({
    super.key,
    required this.children,
    this.controller,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 24),
  });
  final List<Widget> children;
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => ListView(
    controller: controller,
    padding: padding,
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: 16),
        children[i],
      ],
    ],
  );
}
