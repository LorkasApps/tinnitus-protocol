import 'package:flutter/material.dart';

class ScaleSlider extends StatelessWidget {
  const ScaleSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.minLabel = '1',
    this.maxLabel = '10',
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final String minLabel;
  final String maxLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.titleMedium),
            Text(
              '$value',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(minLabel, style: theme.textTheme.bodySmall),
            Text(maxLabel, style: theme.textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}
