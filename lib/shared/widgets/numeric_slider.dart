import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:servllama/l10n/l10n.dart';

/// Coarse pointer selection and precise entry share the parent's single value.
class NumericSlider extends StatefulWidget {
  const NumericSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    required this.divisions,
  });
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  State<NumericSlider> createState() => _NumericSliderState();
}

class _NumericSliderState extends State<NumericSlider> {
  late final TextEditingController _input;
  final _focus = FocusNode();
  bool _invalid = false;

  static String _format(double value) =>
      value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  double? _parse(String text) {
    final normalized = text.trim().replaceAll(',', '.');
    if (!RegExp(r'^-?(?:\d+(?:\.\d{0,2})?|\.\d{1,2})$').hasMatch(normalized)) {
      return null;
    }
    final value = double.tryParse(normalized);
    return value != null &&
            value.isFinite &&
            value >= widget.min &&
            value <= widget.max
        ? value
        : null;
  }

  @override
  void initState() {
    super.initState();
    _input = TextEditingController(text: _format(widget.value));
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (!_focus.hasFocus) _commit();
  }

  void _commit() {
    final value = _parse(_input.text);
    setState(() => _invalid = value == null);
    if (value != null) {
      _input.text = _format(value);
      widget.onChanged(value);
    }
  }

  @override
  void didUpdateWidget(NumericSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value &&
        _parse(_input.text) != widget.value) {
      _input.text = _format(widget.value);
      _invalid = false;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(widget.label)),
            Text(
              '${_format(widget.min)}–${_format(widget.max)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Slider(
                key: const Key('ui_lab_numeric_slider'),
                value: widget.value,
                min: widget.min,
                max: widget.max,
                divisions: widget.divisions,
                label: _format(widget.value),
                semanticFormatterCallback: (value) =>
                    '${widget.label} ${_format(value)}',
                onChanged: (value) {
                  _input.text = _format(value);
                  setState(() => _invalid = false);
                  widget.onChanged(value);
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 108,
              child: TextField(
                key: const Key('ui_lab_numeric_input'),
                controller: _input,
                focusNode: _focus,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: true,
                  signed: widget.min < 0,
                ),
                textInputAction: TextInputAction.done,
                inputFormatters: [LengthLimitingTextInputFormatter(12)],
                decoration: InputDecoration(
                  labelText: l.numericExactValue,
                  enabledBorder: _invalid
                      ? OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: theme.colorScheme.error,
                          ),
                        )
                      : null,
                  focusedBorder: _invalid
                      ? OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: theme.colorScheme.error,
                            width: 1.5,
                          ),
                        )
                      : null,
                ),
                onChanged: (text) {
                  final value = _parse(text);
                  setState(() => _invalid = text.isNotEmpty && value == null);
                  if (value != null) widget.onChanged(value);
                },
                onSubmitted: (_) => _commit(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: _invalid,
          child: Text(
            _invalid
                ? l.numericError(_format(widget.min), _format(widget.max))
                : l.numericHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: _invalid ? theme.colorScheme.error : null,
            ),
          ),
        ),
      ],
    );
  }
}
