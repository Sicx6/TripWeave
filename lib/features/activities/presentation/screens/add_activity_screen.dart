import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/utils/money.dart';
import '../../../trips/domain/entities/trip.dart';
import '../../domain/repositories/activity_repository.dart';
import '../providers/activity_providers.dart';

class AddActivityScreen extends ConsumerStatefulWidget {
  const AddActivityScreen({required this.trip, super.key});

  final Trip trip;

  @override
  ConsumerState<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends ConsumerState<AddActivityScreen> {
  static const _categories = [
    'Attractions',
    'Restaurants',
    'Accommodation',
    'Transport',
    'Shopping',
    'Custom',
  ];

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _cost = TextEditingController(text: '0.00');
  final _description = TextEditingController();
  final _customCategory = TextEditingController();
  String _category = _categories.first;
  late DateTime _date;
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _date = DateUtils.dateOnly(widget.trip.startDate);
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _cost.dispose();
    _description.dispose();
    _customCategory.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final operation = ref.watch(activityControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Suggest an activity')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add your idea',
                        style: Theme.of(context).textTheme.displaySmall),
                    const SizedBox(height: 8),
                    const Text(
                      'The group can vote before the owner approves it.',
                    ),
                    const SizedBox(height: 24),
                    _ImagePicker(
                      imagePath: _imagePath,
                      onTap: _pickImage,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Activity title',
                        hintText: 'Example: Visit Fushimi Inari Shrine',
                      ),
                      validator: (value) => (value?.trim().length ?? 0) < 2
                          ? 'Enter an activity title'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: _categories
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _category = value ?? _category),
                    ),
                    if (_category == 'Custom') ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _customCategory,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Custom category name',
                          hintText: 'Example: Photography',
                        ),
                        validator: (value) => (value?.trim().length ?? 0) < 2
                            ? 'Name your custom category'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _location,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                      validator: (value) => (value?.trim().length ?? 0) < 2
                          ? 'Enter a location'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _PickerField(
                            label: 'Date',
                            value:
                                '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                            icon: Icons.calendar_today_outlined,
                            onTap: _chooseDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PickerField(
                            label: 'Time',
                            value: _time.format(context),
                            icon: Icons.schedule_outlined,
                            onTap: _chooseTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _cost,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Estimated cost per group',
                        prefixText: 'RM ',
                      ),
                      validator: (value) =>
                          parseMoneyToCents(value ?? '') == null
                              ? 'Enter a valid amount with up to 2 decimals'
                              : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _description,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Why should the group add this activity?',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: operation.isLoading ? null : _submit,
                        child: operation.isLoading
                            ? const SizedBox.square(
                                dimension: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Submit suggestion'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1400,
    );
    if (image != null) setState(() => _imagePath = image.path);
  }

  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateUtils.dateOnly(widget.trip.startDate),
      lastDate: DateUtils.dateOnly(widget.trip.endDate),
    );
    if (date != null) setState(() => _date = date);
  }

  Future<void> _chooseTime() async {
    final time = await showTimePicker(context: context, initialTime: _time);
    if (time != null) setState(() => _time = time);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final proposedAt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    final draft = ActivityDraft(
      title: _title.text,
      category: _category,
      customCategory: _category == 'Custom' ? _customCategory.text : null,
      location: _location.text,
      proposedAt: proposedAt,
      estimatedCostCents: parseMoneyToCents(_cost.text)!,
      description: _description.text,
      imagePath: _imagePath,
    );
    final success = await ref
        .read(activityControllerProvider.notifier)
        .createProposal(tripId: widget.trip.id, draft: draft);
    if (!mounted) return;
    if (!success) {
      final error = ref.read(activityControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error?.toString() ?? 'Unable to add activity.')),
      );
      return;
    }
    Navigator.of(context).pop();
  }
}

class _ImagePicker extends StatelessWidget {
  const _ImagePicker({required this.imagePath, required this.onTap});

  final String? imagePath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        width: double.infinity,
        height: 170,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(20),
          image: imagePath == null
              ? null
              : DecorationImage(
                  image: FileImage(File(imagePath!)),
                  fit: BoxFit.cover,
                ),
        ),
        child: imagePath == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 36),
                  SizedBox(height: 8),
                  Text('Add an optional activity photo'),
                ],
              )
            : const Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircleAvatar(child: Icon(Icons.edit_outlined)),
                ),
              ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        child: Text(value),
      ),
    );
  }
}
