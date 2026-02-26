import 'package:flutter/material.dart';

/// Business shell scaffold.
///
/// Simple wrapper — full layout built in a later task.
class BusinessShell extends StatelessWidget {
  const BusinessShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: child);
  }
}
