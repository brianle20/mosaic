import 'package:flutter/material.dart';
import 'package:mosaic/features/events/models/event_form_formatters.dart';

class MoneyTextFormField extends StatelessWidget {
  const MoneyTextFormField({
    super.key,
    this.fieldKey,
    required this.controller,
    required this.labelText,
    this.validator,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final String labelText;
  final String? Function(String value)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: const [MoneyCentsInputFormatter()],
      decoration: InputDecoration(
        labelText: labelText,
        prefixText: r'$',
      ),
      validator: (value) => validator?.call(value ?? ''),
    );
  }
}
