import 'package:flutter/material.dart';

class CustomCard2 extends StatelessWidget {
  final Widget child;

  const CustomCard2({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
        color: const Color(0xff020227),
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: child,
        ),
      );
}
