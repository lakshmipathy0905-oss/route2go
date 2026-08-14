import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../providers/profile_provider.dart';
import '../../../domain/entities/geo.dart';
import '../../../domain/entities/profile.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final TextEditingController _nameCtrl;
  String _language = 'en';
  String _travelPref = 'balanced';
  String? _homeLabel;
  double? _homeLat;
  double? _homeLng;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(profileProvider).valueOrNull;
      if (profile == null) return;
      _nameCtrl.text = profile.name ?? '';
      _language = profile.language;
      _travelPref = profile.travelPref;
      _homeLabel = profile.homeLocationLabel;
      _homeLat = profile.homeLocationLat;
      _homeLng = profile.homeLocationLng;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              initialValue: _language,
              decoration: const InputDecoration(labelText: 'Language'),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                DropdownMenuItem(value: 'kn', child: Text('Kannada')),
                DropdownMenuItem(value: 'ta', child: Text('Tamil')),
              ],
              onChanged: (v) => setState(() => _language = v ?? 'en'),
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              initialValue: _travelPref,
              decoration: const InputDecoration(labelText: 'Travel preference'),
              items: const [
                DropdownMenuItem(value: 'budget', child: Text('Budget-conscious')),
                DropdownMenuItem(value: 'balanced', child: Text('Balanced')),
                DropdownMenuItem(value: 'premium', child: Text('Premium')),
              ],
              onChanged: (v) => setState(() => _travelPref = v ?? 'balanced'),
            ),
            const SizedBox(height: AppSpacing.lg),
            InkWell(
              onTap: _pickHome,
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Home location',
                  prefixIcon: Icon(Icons.home_outlined),
                  suffixIcon: Icon(Icons.chevron_right),
                ),
                child: Text(_homeLabel ?? 'Choose on the map'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save Profile'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickHome() async {
    final picked = await context.push<GeoPlace>(AppRoutes.locationPicker, extra: 'origin');
    if (picked != null) {
      setState(() {
        _homeLabel = picked.label;
        _homeLat = picked.lat;
        _homeLng = picked.lng;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final profile = ref.read(profileProvider).valueOrNull ?? const Profile();
    try {
      await ref.read(profileProvider.notifier).save(profile.copyWith(
            name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
            language: _language,
            travelPref: _travelPref,
            homeLocationLabel: _homeLabel,
            homeLocationLat: _homeLat,
            homeLocationLng: _homeLng,
          ));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save your profile. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}