import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/vehicles_bloc.dart';

class CreateVehiclePage extends StatefulWidget {
  const CreateVehiclePage({super.key});

  @override
  State<CreateVehiclePage> createState() => _CreateVehiclePageState();
}

class _CreateVehiclePageState extends State<CreateVehiclePage> {
  final _formKey = GlobalKey<FormState>();
  final _currentCityCtrl = TextEditingController();
  final _destCityCtrl = TextEditingController();
  final _vehicleNumberCtrl = TextEditingController();
  final _driverNameCtrl = TextEditingController();
  final _driverMobileCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _vehicleType = 'sedan';
  DateTime? _availableDate;
  TimeOfDay? _availableTime;

  final _vehicleTypes = ['hatchback', 'sedan', 'suv', 'muv', 'traveller', 'tempo_traveller', 'mini_bus', 'bus'];

  @override
  void dispose() {
    _currentCityCtrl.dispose(); _destCityCtrl.dispose();
    _vehicleNumberCtrl.dispose(); _driverNameCtrl.dispose();
    _driverMobileCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_availableDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select available date')));
      return;
    }
    context.read<VehiclesBloc>().add(CreateVehicleEvent({
      'currentCity': _currentCityCtrl.text.trim(),
      'destinationCity': _destCityCtrl.text.trim().isEmpty ? null : _destCityCtrl.text.trim(),
      'vehicleType': _vehicleType,
      'vehicleNumber': _vehicleNumberCtrl.text.trim().toUpperCase(),
      'driverName': _driverNameCtrl.text.trim(),
      'driverMobile': _driverMobileCtrl.text.trim(),
      'availableDate': _availableDate!.toIso8601String().split('T').first,
      'availableTime': _availableTime != null ? '${_availableTime!.hour.toString().padLeft(2, '0')}:${_availableTime!.minute.toString().padLeft(2, '0')}' : '00:00',
      'notes': _notesCtrl.text.trim(),
    }));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post Available Cab'), centerTitle: true),
      body: BlocListener<VehiclesBloc, VehiclesState>(
        listener: (context, state) {
          if (state is VehicleCreated) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vehicle listed!'), backgroundColor: Colors.green));
            context.pop();
          }
          if (state is VehiclesError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _currentCityCtrl,
                          decoration: const InputDecoration(labelText: 'Current City *', prefixIcon: Icon(Icons.my_location_outlined)),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _destCityCtrl,
                          decoration: const InputDecoration(labelText: 'Available For (Destination City)', prefixIcon: Icon(Icons.location_on_outlined)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Vehicle Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _vehicleType,
                          decoration: const InputDecoration(labelText: 'Vehicle Type'),
                          items: _vehicleTypes.map((v) => DropdownMenuItem(value: v, child: Text(v.replaceAll('_', ' ').toUpperCase()))).toList(),
                          onChanged: (v) => setState(() => _vehicleType = v!),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _vehicleNumberCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(labelText: 'Vehicle Number *', prefixIcon: Icon(Icons.badge_outlined)),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Driver Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _driverNameCtrl,
                          decoration: const InputDecoration(labelText: 'Driver Name *', prefixIcon: Icon(Icons.person_outline)),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _driverMobileCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Driver Mobile *', prefixIcon: Icon(Icons.phone_outlined)),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (v.length != 10) return 'Enter 10 digit number';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Availability', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.calendar_today_outlined),
                          title: Text(_availableDate != null
                              ? '${_availableDate!.day}/${_availableDate!.month}/${_availableDate!.year}'
                              : 'Select Available Date *'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 90)),
                            );
                            if (d != null) setState(() => _availableDate = d);
                          },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.access_time),
                          title: Text(_availableTime != null ? _availableTime!.format(context) : 'Select Available Time'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                            if (t != null) setState(() => _availableTime = t);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextFormField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Additional Notes (Optional)',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                BlocBuilder<VehiclesBloc, VehiclesState>(
                  builder: (context, state) => ElevatedButton(
                    onPressed: state is VehiclesLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: state is VehiclesLoading
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : const Text('Post Available Cab', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
