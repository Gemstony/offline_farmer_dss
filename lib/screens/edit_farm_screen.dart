// lib/screens/edit_farm_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/farm_model.dart';
import '../providers/farm_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/weather_provider.dart';

class EditFarmScreen extends ConsumerStatefulWidget {
  final Farm? farm; // if null, we are adding new
  const EditFarmScreen({super.key, this.farm});

  @override
  ConsumerState<EditFarmScreen> createState() => _EditFarmScreenState();
}

class _EditFarmScreenState extends ConsumerState<EditFarmScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _cropType;
  late double _areaHectares;
  late String _soilType;
  late DateTime _plantingDate;
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  String? _locationError;

  final List<String> _cropOptions = ['maize', 'rice', 'beans', 'cassava', 'tomatoes'];
  final List<String> _soilOptions = ['sandy', 'clay', 'loam'];

  @override
  void initState() {
    super.initState();
    if (widget.farm != null) {
      _cropType = widget.farm!.cropType;
      _areaHectares = widget.farm!.areaHectares;
      _soilType = widget.farm!.soilType;
      _plantingDate = widget.farm!.plantingDate;
      _currentPosition = Position(
        latitude: widget.farm!.latitude,
        longitude: widget.farm!.longitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
        isMocked: false,
      );
    } else {
      _cropType = 'maize';
      _areaHectares = 1.0;
      _soilType = 'loam';
      _plantingDate = DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.farm == null ? 'Ongeza Shamba' : 'Badilisha Shamba'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<String>(
              value: _cropType,
              decoration: InputDecoration(
                labelText: 'Aina ya mmea',
                prefixIcon: const Icon(Icons.agriculture),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              items: _cropOptions.map((crop) => DropdownMenuItem(value: crop, child: Text(crop.toUpperCase()))).toList(),
              onChanged: (val) => setState(() => _cropType = val!),
              validator: (val) => val == null ? 'Chagua aina ya mmea' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Eneo (hekta)',
                prefixIcon: const Icon(Icons.straighten),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              keyboardType: TextInputType.number,
              initialValue: _areaHectares.toString(),
              onChanged: (val) => _areaHectares = double.tryParse(val) ?? 1.0,
              validator: (val) => val == null || double.tryParse(val) == null ? 'Weka namba halali' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _soilType,
              decoration: InputDecoration(
                labelText: 'Aina ya udongo',
                prefixIcon: const Icon(Icons.terrain),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              items: _soilOptions.map((soil) => DropdownMenuItem(value: soil, child: Text(soil.toUpperCase()))).toList(),
              onChanged: (val) => setState(() => _soilType = val!),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today, color: Colors.green),
              title: const Text('Tarehe ya kupanda'),
              subtitle: Text(_plantingDate.toLocal().toString().split(' ')[0]),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _plantingDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _plantingDate = picked);
              },
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        const Text('Mahali (GPS)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingLocation)
                      const Center(child: CircularProgressIndicator())
                    else if (_locationError != null)
                      Text(_locationError!, style: const TextStyle(color: Colors.red))
                    else if (_currentPosition != null)
                      Text('Lat: ${_currentPosition!.latitude}, Lon: ${_currentPosition!.longitude}')
                    else
                      const Text('Hakuna eneo lililochaguliwa'),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _getCurrentLocation,
                          icon: const Icon(Icons.my_location),
                          label: const Text('Chukua eneo langu'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _showManualLocationDialog(),
                          icon: const Icon(Icons.edit),
                          label: const Text('Weka mwenyewe'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green.shade700,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: _saveFarm,
                child: Text(widget.farm == null ? 'HIFADHI SHAMBA' : 'SASISHA SHAMBA', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });
    var status = await Permission.location.request();
    if (status.isGranted) {
      try {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        setState(() => _currentPosition = position);
      } catch (e) {
        setState(() => _locationError = 'Imeshindwa kupata eneo: $e');
      }
    } else {
      setState(() => _locationError = 'Ruhusa ya eneo haikubaliwa. Tafadhali ruhusu kwenye mipangilio.');
    }
    setState(() => _isLoadingLocation = false);
  }

  void _showManualLocationDialog() {
    final latController = TextEditingController(text: _currentPosition?.latitude.toString() ?? '');
    final lonController = TextEditingController(text: _currentPosition?.longitude.toString() ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Weka viwianishi mwenyewe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: latController, decoration: const InputDecoration(labelText: 'Latitude'), keyboardType: TextInputType.number),
            TextField(controller: lonController, decoration: const InputDecoration(labelText: 'Longitude'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ghairi')),
          TextButton(
            onPressed: () {
              final lat = double.tryParse(latController.text);
              final lon = double.tryParse(lonController.text);
              if (lat != null && lon != null) {
                setState(() {
                  _currentPosition = Position(
                    latitude: lat, longitude: lon, timestamp: DateTime.now(),
                    accuracy: 0, altitude: 0, altitudeAccuracy: 0, heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0, isMocked: true,
                  );
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Hifadhi'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveFarm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tafadhali chukua au weka eneo la shamba')));
      return;
    }

    final db = ref.read(databaseServiceProvider);
    final farm = Farm(
      id: widget.farm?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      cropType: _cropType,
      areaHectares: _areaHectares,
      soilType: _soilType,
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      plantingDate: _plantingDate,
    );
    await db.upsertFarm(farm);
    await ref.read(farmListNotifierProvider.notifier).refresh();

    if (widget.farm == null) {
      // Also sync weather for new farm
      final sync = ref.read(syncServiceProvider);
      await sync.syncWeatherForFarm(farm);
      // If this is the first farm, auto‑select it
      final allFarms = await db.getAllFarms();
      if (allFarms.length == 1) {
        ref.read(selectedFarmIdProvider.notifier).setSelectedFarmId(farm.id);
      }
      ref.invalidate(weatherDataProvider);
    } else {
      // After edit, if the current selected farm was edited, refresh its data
      final selectedId = ref.read(selectedFarmIdProvider);
      if (selectedId == farm.id) {
        ref.invalidate(selectedFarmProvider);
        ref.invalidate(weatherDataProvider);
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.farm == null ? 'Shamba limeongezwa!' : 'Shamba limesasishwa!')));
    Navigator.pop(context);
  }
}