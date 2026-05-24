import 'package:flutter/material.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/features/checkin/models/cover_entry_form_draft.dart';
import 'package:mosaic/features/events/models/event_form_formatters.dart';
import 'package:mosaic/widgets/money_text_form_field.dart';

class AddCoverEntryScreen extends StatefulWidget {
  const AddCoverEntryScreen({
    super.key,
    this.title = 'Record Cover Entry',
    this.submitButtonLabel = 'Save Cover Entry',
    this.initialAmountCents = 0,
    this.initialMethod,
    this.initialTransactionOn,
    this.initialNote,
  });

  final String title;
  final String submitButtonLabel;
  final int initialAmountCents;
  final CoverEntryMethod? initialMethod;
  final DateTime? initialTransactionOn;
  final String? initialNote;

  @override
  State<AddCoverEntryScreen> createState() => _AddCoverEntryScreenState();
}

class _AddCoverEntryScreenState extends State<AddCoverEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late DateTime _transactionOn;
  CoverEntryMethod? _selectedMethod;
  bool _hasTriedSubmit = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: formatMoneyCents(widget.initialAmountCents),
    );
    _noteController = TextEditingController(text: widget.initialNote ?? '');
    _selectedMethod = widget.initialMethod;
    _transactionOn = _dateOnly(widget.initialTransactionOn ?? DateTime.now());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  CoverEntryFormDraft _buildDraft() {
    return CoverEntryFormDraft(
      amountText: _amountController.text,
      method: _selectedMethod,
      transactionOn: _transactionOn,
      note: _noteController.text,
    );
  }

  void _submit() {
    setState(() {
      _hasTriedSubmit = true;
    });
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(_buildDraft().toSubmission());
  }

  Future<void> _pickTransactionDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _transactionOn,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
    );
    if (pickedDate == null) {
      return;
    }

    setState(() {
      _transactionOn = _dateOnly(pickedDate);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _submit,
          child: Text(widget.submitButtonLabel),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            MoneyTextFormField(
              controller: _amountController,
              labelText: 'Amount',
              validator: (_) => _buildDraft().amountError,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickTransactionDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date'),
                child: Text(_formatDate(_transactionOn)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Method',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CoverEntryMethod.values
                  .map(
                    (method) => _selectedMethod == method
                        ? FilledButton(
                            onPressed: () {
                              setState(() {
                                _selectedMethod = method;
                              });
                            },
                            child: Text(_labelForMethod(method)),
                          )
                        : OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _selectedMethod = method;
                              });
                            },
                            child: Text(_labelForMethod(method)),
                          ),
                  )
                  .toList(growable: false),
            ),
            if (_hasTriedSubmit)
              if (_buildDraft().methodError case final methodError?) ...[
                const SizedBox(height: 8),
                Text(
                  methodError,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
          ],
        ),
      ),
    );
  }

  String _labelForMethod(CoverEntryMethod method) {
    return switch (method) {
      CoverEntryMethod.cash => 'Cash',
      CoverEntryMethod.venmo => 'Venmo',
      CoverEntryMethod.zelle => 'Zelle',
      CoverEntryMethod.other => 'Other',
      CoverEntryMethod.comp => 'Comp',
      CoverEntryMethod.refund => 'Refund',
    };
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _formatDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }
}
