import 'package:flutter/material.dart';

/// Client shell scaffold.
///
/// Simple wrapper — full layout built in a later task.
class ClientShell extends StatelessWidget {
  const ClientShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: child);
  }
}
