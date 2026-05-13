import 'package:flutter/widgets.dart';

enum WindowClass { compact, medium, expanded }

WindowClass windowClassOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 1100) {
    return WindowClass.expanded;
  }
  if (width >= 720) {
    return WindowClass.medium;
  }
  return WindowClass.compact;
}
