import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/core/theme/app_theme.dart';

/// Dialog untuk owner mengatur titik lokasi & radius geofence outlet,
/// dipakai app shift malam (flutter_laundry_nightshift_app) untuk
/// mendeteksi kalau pegawai keluar radius sebelum jam 06:00.
///
/// Sengaja langsung baca/tulis ke Supabase (bukan lewat Outlet model/
/// OutletRepository/local SQLite) -- kolom latitude/longitude/
/// geofence_radius_m murni fitur online untuk app kedua, tidak perlu ikut
/// alur sync offline-first outlet yang sudah ada.
class OutletGeofenceDialog extends StatefulWidget {
  final String outletRemoteId;
  final String outletName;

  const OutletGeofenceDialog({
    super.key,
    required this.outletRemoteId,
    required this.outletName,
  });

  @override
  State<OutletGeofenceDialog> createState() => _OutletGeofenceDialogState();
}

class _OutletGeofenceDialogState extends State<OutletGeofenceDialog> {
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController(text: '150');

  bool _loading = true;
  bool _saving = false;
  bool _fetchingLocation = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrent() async {
    try {
      final data = await SupabaseService.instance.client
          .from('outlets')
          .select('latitude, longitude, geofence_radius_m')
          .eq('id', widget.outletRemoteId)
          .maybeSingle();

      if (data != null) {
        if (data['latitude'] != null) {
          _latController.text = (data['latitude'] as num).toString();
        }
        if (data['longitude'] != null) {
          _lngController.text = (data['longitude'] as num).toString();
        }
        if (data['geofence_radius_m'] != null) {
          _radiusController.text = (data['geofence_radius_m'] as num).toInt().toString();
        }
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Aktifkan GPS/Lokasi HP terlebih dahulu.');

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi ditolak.');
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _latController.text = pos.latitude.toStringAsFixed(6);
      _lngController.text = pos.longitude.toStringAsFixed(6);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppThemeColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  Future<void> _save() async {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    final radius = int.tryParse(_radiusController.text.trim());

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lokasi (lat/lng) belum valid.'),
          backgroundColor: AppThemeColors.warning,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await SupabaseService.instance.client.from('outlets').update({
        'latitude': lat,
        'longitude': lng,
        'geofence_radius_m': radius ?? 150,
      }).eq('id', widget.outletRemoteId);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppThemeColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Lokasi Shift Malam — ${widget.outletName}'),
      content: _loading
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dipakai app shift malam untuk mendeteksi kalau pegawai '
                    'keluar radius outlet sebelum jam 06:00.',
                    style: AppTypography.bodySmall,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(_error!, style: AppTypography.bodySmall.copyWith(color: AppThemeColors.error)),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: _fetchingLocation ? null : _useCurrentLocation,
                    icon: _fetchingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location, size: 18),
                    label: const Text('Ambil Lokasi Saat Ini'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _latController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'Latitude'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _lngController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'Longitude'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _radiusController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Radius Geofence (meter)',
                      hintText: '150',
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: (_loading || _saving) ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
