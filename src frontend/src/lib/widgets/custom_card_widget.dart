import 'package:flutter/material.dart';
import 'package:src/utils/constants/constants.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  /// Use for children that need tight constraints (e.g. [Expanded] inside).
  final bool expandChild;

  const CustomCard({
    super.key,
    this.color,
    this.padding,
    required this.child,
    this.margin,
    this.expandChild = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      padding: padding ?? const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        border: Border.all(
          width: 1,
          color: AppColors.cardBorderColor,
        ),
        borderRadius: const BorderRadius.all(
          Radius.circular(20.0),
        ),
        color: color ?? AppColors.cardBackgroundColor,
      ),
      child: expandChild ? child : Center(child: child),
    );
  }
}
