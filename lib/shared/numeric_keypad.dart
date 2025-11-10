import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class NumericKeypad extends StatelessWidget {
  final void Function(String) onTap;
  final double spacing; // gap between keys horizontally/vertically
  final double diameter; // circle size
  final Color keyColor;
  final TextStyle textStyle;
  final List<String>? labels; // optional override for layout (length 12)

  const NumericKeypad({
    super.key,
    required this.onTap,
    this.spacing = 12,
    this.diameter = 64,
    this.keyColor = Colors.transparent,
    this.textStyle = const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
    this.labels,
  });

  List<String> get _layout => labels ?? const ['1','2','3','4','5','6','7','8','9',' ','0','←'];

  @override
  Widget build(BuildContext context) {
    final items = _layout;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (row) {
        return Padding(
          padding: EdgeInsets.only(bottom: row == 3 ? 0 : spacing),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (col) {
              final idx = row * 3 + col;
              final label = items[idx];
              return Padding(
                padding: EdgeInsets.only(right: col == 2 ? 0 : spacing),
                child: _Key(
                  label: label,
                  onTap: onTap,
                  color: keyColor,
                  textStyle: textStyle,
                  diameter: diameter,
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

class _Key extends StatelessWidget {
  final String label;
  final void Function(String) onTap;
  final Color color;
  final TextStyle textStyle;
  final double diameter;

  const _Key({
    required this.label,
    required this.onTap,
    required this.color,
    required this.textStyle,
    required this.diameter,
  });

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) {
      return SizedBox(width: diameter, height: diameter);
    }
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => onTap(label),
          child: Center(
            child: label == '←'
                ? SvgPicture.asset(
                    'assets/img/icons/backspace_keypad.svg',
                    width: diameter * 0.50,
                    height: diameter * 0.50,
                  )
                : Text(label, style: textStyle),
          ),
        ),
      ),
    );
  }
}


