import 'package:flutter/material.dart';

class GuestQuickActionBar extends StatelessWidget {
  const GuestQuickActionBar({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: children,
    );
  }
}
