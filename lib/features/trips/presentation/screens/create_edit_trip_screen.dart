import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/utils/money.dart';
import '../../domain/entities/trip.dart';
import '../../domain/repositories/trip_repository.dart';
import '../providers/trip_providers.dart';

class CreateEditTripScreen extends ConsumerStatefulWidget {
  const CreateEditTripScreen({this.trip, super.key});

  final Trip? trip;

  @override
  ConsumerState<CreateEditTripScreen> createState() =>
      _CreateEditTripScreenState();
}

class _CreateEditTripScreenState extends ConsumerState<CreateEditTripScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _destination;
  late final TextEditingController _description;
  late final TextEditingController _budget;
  late DateTime _startDate;
  late DateTime _endDate;
  String? _coverImagePath;

  bool get _isEditing => widget.trip != null;

  @override
  void initState() {
    super.initState();
    final trip = widget.trip;
    final tomorrow = DateUtils.dateOnly(
      DateTime.now().add(const Duration(days: 1)),
    );
    _destination = TextEditingController(text: trip?.destination);
    _description = TextEditingController(text: trip?.description);
    _budget = TextEditingController(
      text: trip == null ? '' : (trip.budgetCents / 100).toStringAsFixed(2),
    );
    _startDate = trip?.startDate ?? tomorrow;
    _endDate = trip?.endDate ?? tomorrow.add(const Duration(days: 3));
  }

  @override
  void dispose() {
    _destination.dispose();
    _description.dispose();
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final operation = ref.watch(tripControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit trip' : 'Create a trip')),
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
                    Text(
                      _isEditing
                          ? 'Update the shared trip details.'
                          : 'Where is your group going?',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Start with the essentials. Activities and members come after the trip exists.',
                    ),
                    const SizedBox(height: 28),
                    _CoverPicker(
                      localPath: _coverImagePath,
                      networkUrl: widget.trip?.coverImageUrl,
                      onTap: _pickCover,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _destination,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Destination',
                        hintText: 'Example: Kyoto, Japan',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                      validator: (value) => (value?.trim().length ?? 0) < 2
                          ? 'Enter a destination'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _description,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Trip description',
                        hintText: 'What is this trip about?',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _DateField(
                            label: 'Start date',
                            value: _startDate,
                            onTap: _chooseStartDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateField(
                            label: 'End date',
                            value: _endDate,
                            onTap: _chooseEndDate,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _budget,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Group budget',
                        prefixText: 'RM ',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      ),
                      validator: _validateBudget,
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: operation.isLoading ? null : _save,
                        child: operation.isLoading
                            ? const SizedBox.square(
                                dimension: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _isEditing ? 'Save changes' : 'Create trip',
                              ),
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

  String? _validateBudget(String? value) {
    final cents = parseMoneyToCents(value ?? '');
    if (cents == null) return 'Enter a valid amount with up to 2 decimals';
    if (cents > 999999999999) return 'Budget is too large';
    return null;
  }

  Future<void> _pickCover() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1600,
    );
    if (image != null) setState(() => _coverImagePath = image.path);
  }

  Future<void> _chooseStartDate() async {
    final date = await _pickDate(_startDate);
    if (date == null) return;
    setState(() {
      _startDate = date;
      if (_endDate.isBefore(date)) _endDate = date;
    });
  }

  Future<void> _chooseEndDate() async {
    final date = await _pickDate(_endDate, firstDate: _startDate);
    if (date != null) setState(() => _endDate = date);
  }

  Future<DateTime?> _pickDate(DateTime initial, {DateTime? firstDate}) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 10),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final budgetCents = parseMoneyToCents(_budget.text)!;
    final draft = TripDraft(
      destination: _destination.text,
      description: _description.text,
      startDate: _startDate,
      endDate: _endDate,
      budgetCents: budgetCents,
      coverImagePath: _coverImagePath,
    );
    final controller = ref.read(tripControllerProvider.notifier);
    final success = _isEditing
        ? await controller.updateTrip(trip: widget.trip!, draft: draft)
        : await controller.createTrip(draft);
    if (!mounted) return;
    if (!success) {
      final error = ref.read(tripControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error?.toString() ?? 'Unable to save trip.')),
      );
      return;
    }
    Navigator.of(context).pop();
  }
}

class _CoverPicker extends StatelessWidget {
  const _CoverPicker({
    required this.localPath,
    required this.networkUrl,
    required this.onTap,
  });

  final String? localPath;
  final String? networkUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    if (localPath != null) {
      image = FileImage(File(localPath!));
    } else if (networkUrl != null) {
      image = NetworkImage(networkUrl!);
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        height: 190,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(20),
          image: image == null
              ? null
              : DecorationImage(image: image, fit: BoxFit.cover),
        ),
        child: image == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 36),
                  SizedBox(height: 8),
                  Text('Add a cover photo (optional)'),
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

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(
          '${value.day.toString().padLeft(2, '0')}/'
          '${value.month.toString().padLeft(2, '0')}/${value.year}',
        ),
      ),
    );
  }
}
