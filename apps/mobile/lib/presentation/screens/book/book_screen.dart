import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/booking_links.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../widgets/app_widgets.dart';

/// Persisted selected transport mode for the Book tab, shared with the Home
/// dashboard booking cards.
final bookModeProvider = StateProvider<String>((ref) => 'train');

class _ModeSpec {
  const _ModeSpec(this.key, this.label, this.icon, this.color, this.soft);
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final Color soft;
}

const _modes = [
  _ModeSpec('train', 'Train', Icons.train_outlined, AppColors.train,
      AppColors.trainSoft),
  _ModeSpec('bus', 'Bus', Icons.directions_bus_outlined, AppColors.bus,
      AppColors.busSoft),
  _ModeSpec('flight', 'Flight', Icons.flight_takeoff, AppColors.flight,
      AppColors.flightSoft),
];

/// Book tab (spec Section 7/16): search trains, buses and flights, compare
/// modes and jump to the real provider to book. No fares or availability are
/// fabricated — until a provider is connected, results are honest.
class BookScreen extends ConsumerStatefulWidget {
  const BookScreen({super.key});

  @override
  ConsumerState<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends ConsumerState<BookScreen> {
  final _from = TextEditingController();
  final _to = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  bool _roundTrip = false;
  int _travellers = 1;
  DateTime? _returnDate;

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isReturn}) async {
    final initial = isReturn ? (_returnDate ?? _date) : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isReturn) {
        _returnDate = picked;
      } else {
        _date = picked;
      }
    });
  }

  void _search(String mode) {
    final to = _to.text.trim();
    if (to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a destination to search.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookResultsScreen(
          mode: mode,
          fromCity: _from.text.trim().isEmpty ? null : _from.text.trim(),
          toCity: to,
          date: _date,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(bookModeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Book'),
        actions: [
          IconButton(
            tooltip: 'Compare transport',
            icon: const Icon(Icons.compare_arrows),
            onPressed: () => _showCompare(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Where are you headed?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Search trains, buses and flights. Booking happens at the real provider.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ModeSelector(
                mode: mode,
                onSelect: (m) => ref.read(bookModeProvider.notifier).state = m),
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    TextField(
                      controller: _from,
                      decoration: const InputDecoration(
                        labelText: 'From',
                        hintText: 'Departure city',
                        prefixIcon: Icon(Icons.trip_origin),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _to,
                      decoration: const InputDecoration(
                        labelText: 'To',
                        hintText: 'Destination city',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            onTap: () => _pickDate(isReturn: false),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date',
                                prefixIcon: Icon(Icons.calendar_today_outlined),
                              ),
                              child: Text(
                                '${_date.day}/${_date.month}/${_date.year}',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            onTap: () => setState(() {
                              _roundTrip = !_roundTrip;
                              if (!_roundTrip) _returnDate = null;
                            }),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Trip',
                                prefixIcon: Icon(Icons.compare_arrows),
                              ),
                              child:
                                  Text(_roundTrip ? 'Round trip' : 'One way'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_roundTrip) ...[
                      const SizedBox(height: AppSpacing.md),
                      InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        onTap: () => _pickDate(isReturn: true),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Return date',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          child: Text(
                            _returnDate == null
                                ? 'Tap to pick'
                                : '${_returnDate!.day}/${_returnDate!.month}/${_returnDate!.year}',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      onTap: () => showDialog<int>(
                        context: context,
                        builder: (ctx) => SimpleDialog(
                          title: const Text('Travellers'),
                          children: [1, 2, 3, 4, 5, 6].map((n) {
                            return SimpleDialogOption(
                              onPressed: () {
                                setState(() => _travellers = n);
                                Navigator.of(ctx).pop();
                              },
                              child: Text(
                                n == 1 ? '1 traveller' : '$n travellers',
                                style: Theme.of(ctx).textTheme.bodyLarge,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Travellers',
                          prefixIcon: Icon(Icons.group_outlined),
                        ),
                        child: Text(
                          _travellers == 1
                              ? '1 traveller'
                              : '$_travellers travellers',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _search(mode),
                        icon: const Icon(Icons.search),
                        label: Text(
                            'Search ${_currentMode(mode).label.toLowerCase()}s'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _ProviderNote(),
          ],
        ),
      ),
    );
  }

  _ModeSpec _currentMode(String key) =>
      _modes.firstWhere((m) => m.key == key, orElse: () => _modes.first);

  void _showCompare(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CompareSheet(),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.onSelect});

  final String mode;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: _modes.map((m) {
          final selected = m.key == mode;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              onTap: () => onSelect(m.key),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: selected ? m.soft : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(m.icon,
                        size: 20,
                        color: selected ? m.color : AppColors.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      m.label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: selected ? m.color : AppColors.textSecondary,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Honest note about where booking actually happens.
class _ProviderNote extends StatelessWidget {
  const _ProviderNote();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.infoSoft,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: AppColors.info),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Route2Go does not invent fares or availability. Live seats and prices are '
                'always shown by the connected provider (e.g. IRCTC, RedBus). We take you '
                'there and pre-fill your search.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Results page for a transport search. Honest: no fabricated schedules or
/// fares. If a provider can be reached, we hand off the search.
class BookResultsScreen extends StatelessWidget {
  const BookResultsScreen({
    super.key,
    required this.mode,
    required this.fromCity,
    required this.toCity,
    required this.date,
  });

  final String mode;
  final String? fromCity;
  final String toCity;
  final DateTime date;

  _ModeSpec get _spec => _modes.firstWhere(
        (m) => m.key == mode,
        orElse: () => _modes.first,
      );

  String get _providerName {
    switch (mode) {
      case 'bus':
        return 'RedBus';
      case 'flight':
        return 'Google Flights';
      default:
        return 'IRCTC';
    }
  }

  Future<void> _openProvider(BuildContext context) async {
    final String url;
    switch (mode) {
      case 'bus':
        url = BookingLinks.redBus(
            fromCity: fromCity, toCity: toCity, onDate: date);
        break;
      case 'flight':
        url = BookingLinks.flights(toCity: toCity, onDate: date);
        break;
      default:
        url = BookingLinks.irctcTrain();
    }
    final ok =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not open the provider. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${_spec.label}s · $toCity'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_spec.icon, color: _spec.color, size: 30),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            '${fromCity ?? 'Anywhere'} → $toCity',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${date.day}/${date.month}/${date.year} · search via $_providerName',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Live availability not connected yet',
              message:
                  'No booking provider is connected yet, so Route2Go will not invent '
                  'schedules or fares. Open $_providerName to see real options and book '
                  'securely on their site.',
              action: FilledButton.icon(
                onPressed: () => _openProvider(context),
                icon: const Icon(Icons.open_in_new),
                label: Text('Open $_providerName'),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: TextButton.icon(
                onPressed: () => context.push(AppRoutes.planTrip),
                icon: const Icon(Icons.route_outlined),
                label: const Text('Plan this journey in Route2Go'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mode-by-mode comparison of what each transport channel offers. Fares are
/// illustrative of the channel, never fake live prices.
class CompareSheet extends StatelessWidget {
  const CompareSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final rows = <_ModeSpec, String>{
      const _ModeSpec('train', 'Train', Icons.train_outlined, AppColors.train,
              AppColors.trainSoft):
          'IRCTC official site · confirmed PNR on booking · best for sleeper/AC coaches',
      const _ModeSpec('bus', 'Bus', Icons.directions_bus_outlined,
              AppColors.bus, AppColors.busSoft):
          'RedBus network · live seats & operator ratings · AC/Non-AC options',
      const _ModeSpec('flight', 'Flight', Icons.flight_takeoff,
              AppColors.flight, AppColors.flightSoft):
          'Compare airlines · fastest option · fares quoted live by the airline',
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Compare transport',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Each mode books at its real provider. Live prices and seats always come '
              'from the provider — Route2Go never fabricates them.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            ...rows.entries.map((e) {
              final m = e.key;
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: m.soft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(m.icon, color: m.color, size: 22),
                  ),
                  title: Text('${m.label}s'),
                  subtitle: Text(e.value),
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go(AppRoutes.book);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
