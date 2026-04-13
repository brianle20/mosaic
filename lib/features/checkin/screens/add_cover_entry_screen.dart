import 'package:flutter/material.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/features/checkin/models/cover_entry_form_draft.dart';

class AddCoverEntryScreen extends StatefulWidget {
  const AddCoverEntryScreen({super.key});

  @override
  State<AddCoverEntryScreen> createState() => _AddCoverEntryScreenState();
}

class _AddCoverEntryScreenState extends State<AddCoverEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  CoverEntryMethod? _selectedMethod;

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
      note: _noteController.text,
    );
  }

  void _submit() {
    setState(() {});
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(_buildDraft().toSubmission());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record Cover Entry')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _submit,
          child: const Text('Save Cover Entry'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (cents)'),
              validator: (_) => _buildDraft().amountError,
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
              maxLines: 3,
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
}
