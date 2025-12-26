import 'package:flutter/material.dart';

class MainButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  // ✅ 디자인 파라미터
  final double height;
  final double? width;
  final EdgeInsets padding;
  final double radius;

  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;

  final double fontSize;
  final Color textColor;

  final Color? splashColor;

  const MainButton({
    super.key,
    required this.text,
    required this.onTap,

    // size
    this.height = 46,
    this.width,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    this.radius = 999,

    // color
    this.backgroundColor = Colors.white,
    this.borderColor = Colors.black,
    this.borderWidth = 1,
    this.textColor = Colors.black,

    // text
    this.fontSize = 16,

    // effect
    this.splashColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          splashColor:
          splashColor ?? backgroundColor.withOpacity(0.2),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: borderColor,
                width: borderWidth,
              ),
            ),
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
