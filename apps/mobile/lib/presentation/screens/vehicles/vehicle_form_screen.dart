import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/vehicle_provider.dart';
import '../../../domain/entities/vehicle.dart';

class VehicleFormScreen extends ConsumerStatefulWidget {
  const VehicleFormScreen({super.key, this.vehicleId});

  final String? vehicleId;

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _mileageCtrl;
  late final TextEditingController _batteryCtrl;
  late final TextEditingController _efficiencyCtrl;
  late final TextEditingController _cngCtrl;

  String _fuelType = 'petrol';
  bool _isDefault = false;
  bool _saving = false;
  String? _formError;

  bool get _isEditing => widget.vehicleId != null;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController();
    _mileageCtrl = TextEditingController();
    _batteryCtrl = TextEditingController();
    _efficiencyCtrl = TextEditingController();
    _cngCtrl = TextEditingController();

    if (_isEditing) {
      final vehicle = _currentVehicle();
      if (vehicle != null) {
        _labelCtrl.text = vehicle.label;
        _fuelType = vehicle.fuelType;
        _isDefault = vehicle.isDefault;
        _mileageCtrl.text = vehicle.mileageKmpl?.toString() ?? '';
        _batteryCtrl.text = vehicle.evBatteryKwh?.toString() ?? '';
        _efficiencyCtrl.text = vehicle.evEfficiencyKwhPerKm?.toString() ?? '';
        _cngCtrl.text = vehicle.cngMileageKmPerKg?.toString() ?? '';
      }
    }
  }

  Vehicle? _currentVehicle() {
    final list = ref.read(vehicleListProvider).valueOrNull;
    if (list == null) return null;
    for (final v in list) {
      if (v.id == widget.vehicleId) return v;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Vehicle' : 'Add Vehicle')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            TextField(
              controller: _labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Vehicle name',
                hintText: 'e.g. My Swift',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              initialValue: _fuelType,
              decoration: const InputDecoration(labelText: 'Fuel type'),
              items: const [
                DropdownMenuItem(value: 'petrol', child: Text('Petrol')),
                DropdownMenuItem(value: 'diesel', child: Text('Diesel')),
                DropdownMenuItem(value: 'ev', child: Text('Electric (EV)')),
                DropdownMenuItem(value: 'cng', child: Text('CNG')),
              ],
              onChanged: (v) {
                setState(() {
                  _fuelType = v ?? 'petrol';
                  _formError = null;
                });
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_fuelType == 'ev') ...[
              TextField(
                controller: _efficiencyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Efficiency (kWh/km)',
                  helperText: VehicleRanges.describe('ev'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _batteryCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Battery capacity (kWh)',
                ),
              ),
            ] else if (_fuelType == 'cng')
              TextField(
                controller: _cngCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'CNG mileage (km/kg)',
                  helperText: VehicleRanges.describe('cng'),
                ),
              )
            else
              TextField(
                controller: _mileageCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Mileage (km/l)',
                  helperText: VehicleRanges.describe(_fuelType),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            CheckboxListTile(
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v ?? false),
              title: const Text('Use as my default vehicle'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (_formError != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Text(_formError!, style: const TextStyle(color: AppColors.error)),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            ElevatedButton(
              onPressed: _saving ? null : _onSave,
              child: Text(_saving ? 'Saving…' : (_isEditing ? 'Save Changes' : 'Add Vehicle')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    setState(() {
      _formError = null;
      _saving = true;
    });

    final label = _labelCtrl.text.trim();
    if (label.isEmpty) {
      setState(() {
        _formError = 'Give this vehicle a name, e.g. "My Swift".';
        _saving = false;
      });
      return;
    }

    final result = _applyValidation();
    if (result != null) {
      setState(() {
        _formError = result;
        _saving = false;
      });
      return;
    }

    try {
      final notifier = ref.read(vehicleListProvider.notifier);
      if (_isEditing) {
        final existing = _currentVehicle();
        if (existing != null) {
          await notifier.updateVehicle(Vehicle(
            id: existing.id,
            label: label,
            fuelType: _fuelType,
            mileageKmpl: _mileageValue,
            evBatteryKwh: _batteryValue,
            evEfficiencyKwhPerKm: _efficiencyValue,
            cngMileageKmPerKg: _cngValue,
            isDefault: _isDefault,
          ));
        }
      } else {
        await notifier.add(Vehicle(
          id: '',
          label: label,
          fuelType: _fuelType,
          mileageKmpl: _mileageValue,
          evBatteryKwh: _batteryValue,
          evEfficiencyKwhPerKm: _efficiencyValue,
          cngMileageKmPerKg: _cngValue,
          isDefault: _isDefault,
        ));
      }

      if (mounted && ref.read(vehicleListProvider).hasError == false) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _formError = 'Could not save the vehicle. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Returns an inline human explanation when a value is outside the realistic
  /// range for the fuel type — never silently clamps and never silently accepts.
  String? _applyValidation() {
    switch (_fuelType) {
      case 'petrol':
        return _validateRange(_mileageValue, VehicleRanges.petrolMileage, 'petrol');
      case 'diesel':
        return _validateRange(_mileageValue, VehicleRanges.dieselMileage, 'diesel');
      case 'cng':
        return _validateRange(_cngValue, VehicleRanges.cngMileage, 'cng');
      case 'ev':
        final e = _efficiencyValue;
        if (e == null) {
          return 'EV efficiency is required (0.05–0.50 kWh/km).';
        }
        if (!VehicleRanges.evEfficiency.contains(e)) {
          return 'EV efficiency looks unrealistic for a car (range 0.05–0.50 kWh/km).';
        }
        final b = _batteryValue;
        if (b != null && !VehicleRanges.evBattery.contains(b)) {
          return 'EV battery capacity looks unrealistic (range 5–150 kWh).';
        }
        return null;
      default:
        return null;
    }
  }

  String? _validateRange(double? value, Range range, String fuelType) {
    if (value == null) {
      return 'Enter ${VehicleRanges.unitFor(fuelType)} to calculate fuel cost.';
    }
    if (!range.contains(value)) {
      return 'That value looks unrealistic. ${VehicleRanges.describe(fuelType)}';
    }
    return null;
  }

  double? get _mileageValue => double.tryParse(_mileageCtrl.text.trim());
  double? get _batteryValue => double.tryParse(_batteryCtrl.text.trim());
  double? get _efficiencyValue => double.tryParse(_efficiencyCtrl.text.trim());
  double? get _cngValue => double.tryParse(_cngCtrl.text.trim());

  @override
  void dispose() {
    _labelCtrl.dispose();
    _mileageCtrl.dispose();
    _batteryCtrl.dispose();
    _efficiencyCtrl.dispose();
    _cngCtrl.dispose();
    super.dispose();
  }
}