import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../providers/trip_planning_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/guest_gate.dart';
import '../../../domain/entities/geo.dart';
import '../../../domain/entities/vehicle.dart';

class PlanTripScreen extends ConsumerStatefulWidget {
  const PlanTripScreen({super.key});

  @override
  ConsumerState<PlanTripScreen> createState() => _PlanTripScreenState();
}

class _PlanTripScreenState extends ConsumerState<PlanTripScreen> {
  final _mileageCtrl = TextEditingController();
  final _fuelPriceCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();

  String? _originLabel;
  GeoPlace? _origin;
  String? _destinationLabel;
  GeoPlace? _destination;

  String _tripType = 'one_way';
  int _travellers = 1;
  String _fuelType = 'petrol';
  bool _vehicleUsed = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _prefillDefaultVehicle());
  }

  void _prefillDefaultVehicle() {
    final vehicle = ref.read(defaultVehicleProvider);
    if (vehicle == null || _vehicleUsed) return;
    _vehicleUsed = true;
    if (mounted) {
      setState(() {
        _fuelType = vehicle.fuelType;
        _mileageCtrl.text = _mileageTextFor(vehicle);
      });
    }
  }

  String _mileageTextFor(Vehicle v) {
    switch (v.fuelType) {
      case 'ev':
        return v.evEfficiencyKwhPerKm?.toString() ?? '';
      case 'cng':
        return v.cngMileageKmPerKg?.toString() ?? '';
      default:
        return v.mileageKmpl?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _mileageCtrl.dispose();
    _fuelPriceCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tripCalculationProvider, (previous, next) {
      next.when(
        data: (result) {
          if (result != null) context.push(AppRoutes.routeResults);
        },
        loading: () {},
        error: (err, st) {
          final message = err.toString().contains('AppException')
              ? err.toString().split(': ').sublist(1).join(': ')
              : err.toString();
          setState(() => _formError = message);
        },
      );
    });

    final isCalculating = ref.watch(tripCalculationProvider).isLoading;
    final isLoggedIn = ref.watch(isLoggedInProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan a Trip'),
        actions: [
          IconButton(
            icon: const Icon(Icons.directions_car_outlined),
            tooltip: 'My vehicles',
            onPressed: () {
              if (!isLoggedIn) {
                showGuestGate(context);
                return;
              }
              context.push(AppRoutes.vehicles);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (_formError != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Text(_formError!,
                    style: const TextStyle(color: AppColors.error)),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            _LocationField(
              label: 'Starting point',
              value: _originLabel,
              hint: 'Search or drop a pin',
              icon: Icons.trip_origin,
              onTap: () => _pickLocation('origin'),
              onClear: () => setState(() {
                _origin = null;
                _originLabel = null;
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            _LocationField(
              label: 'Destination',
              value: _destinationLabel,
              hint: 'Search or drop a pin',
              icon: Icons.location_on_outlined,
              onTap: () => _pickLocation('destination'),
              onClear: () => setState(() {
                _destination = null;
                _destinationLabel = null;
              }),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Trip type', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'one_way', label: Text('One-way')),
                ButtonSegment(value: 'round_trip', label: Text('Round trip')),
              ],
              selected: {_tripType},
              onSelectionChanged: (s) => setState(() => _tripType = s.first),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Vehicle & fuel',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: _fuelType,
              decoration: const InputDecoration(labelText: 'Fuel type'),
              items: const [
                DropdownMenuItem(value: 'petrol', child: Text('Petrol')),
                DropdownMenuItem(value: 'diesel', child: Text('Diesel')),
                DropdownMenuItem(value: 'ev', child: Text('Electric (EV)')),
                DropdownMenuItem(value: 'cng', child: Text('CNG')),
              ],
              onChanged: (v) => setState(() {
                _fuelType = v ?? 'petrol';
                if (_fuelType != 'petrol' && _fuelType != 'diesel') {
                  // EV/CNG cost paths are flagged server-side; still let users
                  // enter values and receive "unavailable" cost badges.
                }
              }),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _mileageCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: switch (_fuelType) {
                  'ev' => 'Efficiency (kWh/km)',
                  'cng' => 'Mileage (km/kg)',
                  _ => 'Mileage (km/l)',
                },
                helperText: VehicleRanges.describe(_fuelType),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _fuelPriceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _fuelType == 'ev'
                    ? 'Charging rate per kWh (₹) — blank uses known rate'
                    : 'Fuel price per litre (₹) — blank uses the latest known price',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Budget & travellers',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _budgetCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Total trip budget (₹) — optional'),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<int>(
              initialValue: _travellers,
              decoration: const InputDecoration(labelText: 'Travellers'),
              items: List.generate(
                  10,
                  (i) =>
                      DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
              onChanged: (v) => setState(() => _travellers = v ?? 1),
            ),
            const SizedBox(height: AppSpacing.xxl),
            ElevatedButton(
              onPressed: isCalculating ? null : _onCalculate,
              child: Text(isCalculating ? 'Calculating…' : 'Calculate Route'),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLocation(String target) async {
    final picked = await context.push<GeoPlace>(
      AppRoutes.locationPicker,
      extra: target,
    );
    if (picked == null) return;
    setState(() {
      if (target == 'origin') {
        _origin = picked;
        _originLabel = picked.label;
      } else {
        _destination = picked;
        _destinationLabel = picked.label;
      }
    });
  }

  void _onCalculate() {
    setState(() => _formError = null);

    if (_origin == null || _destination == null) {
      setState(() => _formError =
          'Choose both a starting point and a destination on the map.');
      return;
    }
    if (_origin!.lat == _destination!.lat &&
        _origin!.lng == _destination!.lng) {
      setState(() =>
          _formError = 'Origin and destination cannot be the same place.');
      return;
    }

    final mileageText = _mileageCtrl.text.trim();
    final mileage = double.tryParse(mileageText);
    if (mileageText.isNotEmpty && mileage == null) {
      setState(() => _formError =
          'Mileage must be a number. ${VehicleRanges.describe(_fuelType)}');
      return;
    }
    if (mileage != null &&
        _fuelType != 'ev' &&
        !(VehicleRanges.rangeFor(_fuelType)?.contains(mileage) ?? true)) {
      setState(() => _formError =
          'That mileage looks unrealistic. ${VehicleRanges.describe(_fuelType)}');
      return;
    }
    if (_fuelType == 'ev' &&
        mileage != null &&
        !VehicleRanges.evEfficiency.contains(mileage)) {
      setState(() => _formError =
          'EV efficiency looks unrealistic (range 0.05–0.50 kWh/km).');
      return;
    }

    final form = TripPlanningForm(
      originLabel: _origin!.label,
      originLat: _origin!.lat,
      originLng: _origin!.lng,
      destinationLabel: _destination!.label,
      destinationLat: _destination!.lat,
      destinationLng: _destination!.lng,
      tripType: _tripType,
      travellers: _travellers,
      fuelType: _fuelType,
      mileageKmpl: mileage,
      fuelPricePerLitre: _fuelType == 'ev'
          ? null
          : double.tryParse(_fuelPriceCtrl.text.trim()),
      evPricePerKwh: _fuelType == 'ev'
          ? double.tryParse(_fuelPriceCtrl.text.trim())
          : null,
      budgetTotal: double.tryParse(_budgetCtrl.text.trim()),
    );

    ref.read(tripPlanningFormProvider.notifier).state = form;
    ref.read(tripCalculationProvider.notifier).calculate();
  }
}

class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final String? value;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.primary),
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  tooltip: 'Clear',
                  onPressed: onClear)
              : null,
        ),
        child: value != null
            ? Text(value!, maxLines: 1, overflow: TextOverflow.ellipsis)
            : const SizedBox.shrink(),
      ),
    );
  }
}
