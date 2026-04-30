import 'package:flutter/material.dart';

class SliderNumberSetting extends StatefulWidget {
  const SliderNumberSetting({
    super.key,
    required this.label,
    this.description,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
    this.displayBuilder,
    this.specialValue,
    this.specialValueLabel,
  });

  final String label;
  final String? description;
  final int value;
  final int min;
  final int max;
  final int? divisions;
  final ValueChanged<int> onChanged;
  final String Function(int value)? displayBuilder;
  final int? specialValue;
  final String? specialValueLabel;

  @override
  State<SliderNumberSetting> createState() => _SliderNumberSettingState();
}

class _SliderNumberSettingState extends State<SliderNumberSetting> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _displayValue(widget.value));
  }

  @override
  void didUpdateWidget(covariant SliderNumberSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextValue = _displayValue(widget.value);
    if (_controller.text == nextValue) {
      return;
    }
    _controller.value = TextEditingValue(
      text: nextValue,
      selection: TextSelection.collapsed(offset: nextValue.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentValue = _displayValue(widget.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withAlpha(90),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                currentValue,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (widget.description != null) ...[
          const SizedBox(height: 2),
          Text(
            widget.description!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                ),
                child: Slider(
                  min: widget.min.toDouble(),
                  max: widget.max.toDouble(),
                  divisions: widget.divisions,
                  value: widget.value.clamp(widget.min, widget.max).toDouble(),
                  onChanged: (value) => widget.onChanged(value.round()),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 76,
              child: TextField(
                controller: _controller,
                textAlign: TextAlign.center,
                keyboardType: widget.specialValue != null
                    ? const TextInputType.numberWithOptions(signed: true)
                    : TextInputType.number,
                onSubmitted: _handleSubmitted,
                onEditingComplete: () => _handleSubmitted(_controller.text),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withAlpha(90),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colorScheme.primary),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _handleSubmitted(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) {
      _controller.text = _displayValue(widget.value);
      return;
    }

    if (widget.specialValueLabel != null &&
        widget.specialValue != null &&
        value == widget.specialValueLabel) {
      widget.onChanged(widget.specialValue!);
      return;
    }

    final parsedValue = int.tryParse(value);
    if (parsedValue == null) {
      _controller.text = _displayValue(widget.value);
      return;
    }

    final nextValue = parsedValue.clamp(widget.min, widget.max);
    widget.onChanged(nextValue);
  }

  String _displayValue(int value) {
    if (widget.specialValue != null &&
        widget.specialValueLabel != null &&
        value == widget.specialValue) {
      return widget.specialValueLabel!;
    }
    if (widget.displayBuilder != null) {
      return widget.displayBuilder!(value);
    }
    return '$value';
  }
}
