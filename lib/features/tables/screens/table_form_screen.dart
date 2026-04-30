import 'package:flutter/material.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/tables/controllers/table_form_controller.dart';
import 'package:mosaic/features/tables/models/table_form_draft.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

class TableFormScreen extends StatefulWidget {
  const TableFormScreen({
    super.key,
    required this.eventId,
    required this.tableRepository,
    required this.nfcService,
    this.initialTable,
    this.onSaved,
  });

  final String eventId;
  final TableRepository tableRepository;
  final NfcService nfcService;
  final EventTableRecord? initialTable;
  final ValueChanged<EventTableRecord>? onSaved;

  @override
  State<TableFormScreen> createState() => _TableFormScreenState();
}

class _TableFormScreenState extends State<TableFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TableFormController _controller;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(
      text: widget.initialTable?.label ?? '',
    );
    _controller = TableFormController(tableRepository: widget.tableRepository)
      ..addListener(_handleUpdate);
  }

  @override
  void dispose() {
    _labelController.dispose();
    _controller
      ..removeListener(_handleUpdate)
      ..dispose();
    super.dispose();
  }

  void _handleUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  TableFormDraft _buildDraft() {
    return TableFormDraft(
      label: _labelController.text,
    );
  }

  Future<void> _submit() async {
    final EventTableRecord? savedTable;
    if (widget.initialTable == null) {
      savedTable = await _controller.createScannedTable(
        eventId: widget.eventId,
        nfcService: widget.nfcService,
        context: context,
      );
    } else {
      final draft = _buildDraft();
      setState(() {});
      if (!_formKey.currentState!.validate()) {
        return;
      }

      savedTable = await _controller.submit(
        eventId: widget.eventId,
        draft: draft,
        displayOrder: widget.initialTable!.displayOrder,
        existingTable: widget.initialTable,
      );
    }

    if (!mounted || savedTable == null) {
      return;
    }

    widget.onSaved?.call(savedTable);
    if (widget.onSaved == null) {
      Navigator.of(context).pop(savedTable);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTable = _controller.latestTable ?? widget.initialTable;
    final isEditing = widget.initialTable != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialTable == null ? 'Add Table' : 'Edit Table'),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _controller.isSubmitting ? null : _submit,
          child: Text(
            _controller.isSubmitting
                ? (isEditing ? 'Saving...' : 'Scanning...')
                : (isEditing ? 'Save Table' : 'Scan Table Tag'),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (isEditing) ...[
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(labelText: 'Label'),
                validator: (_) => _buildDraft().labelError,
              ),
              const SizedBox(height: 12),
            ],
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Ruleset'),
              subtitle: Text('Hong Kong Standard'),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Rotation Policy'),
              subtitle: Text('dealer_cycle_return_to_initial_east'),
            ),
            if (currentTable?.nfcTagId != null)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Table Tag Bound'),
              ),
            if (currentTable != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _controller.isBindingTag
                    ? null
                    : () => _controller.bindTableTag(
                          table: currentTable,
                          nfcService: widget.nfcService,
                          context: context,
                        ),
                child: Text(
                  _controller.isBindingTag ? 'Binding...' : 'Bind Table Tag',
                ),
              ),
            ],
            if (_controller.submitError != null) ...[
              const SizedBox(height: 12),
              Text(_controller.submitError!),
            ],
          ],
        ),
      ),
    );
  }
}
