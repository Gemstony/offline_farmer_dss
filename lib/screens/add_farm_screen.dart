import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/farm_model.dart';
import '../providers/farm_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/weather_provider.dart';

class AddFarmScreen extends ConsumerStatefulWidget {
  const AddFarmScreen({super.key});

  @override
  ConsumerState<AddFarmScreen> createState() => _AddFarmScreenState();
}

class _AddFarmScreenState extends ConsumerState<AddFarmScreen> {
  final _formKey = GlobalKey<FormState>();

  String _cropType = 'maize';
  double _areaHectares = 1.0;
  String _soilType = 'loam';
  DateTime _plantingDate = DateTime.now();
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  String? _locationError;

  final List<String> _cropOptions = [
    'maize',
    'rice',
    'beans',
    'cassava',
    'tomatoes',
  ];
  final List<String> _soilOptions = ['sandy', 'clay', 'loam'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ongeza Shamba')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: _cropType,
              decoration: InputDecoration(
                labelText: 'Aina ya mmea',
                border: OutlineInputBorder(),
              ),
              items: _cropOptions.map((crop) {
                return DropdownMenuItem(
                  value: crop,
                  child: Text(crop.toUpperCase()),
                );
              }).toList(),
              onChanged: (val) => setState(() => _cropType = val!),
              validator: (val) => val == null ? 'Chagua aina ya mmea' : null,
            ),
            SizedBox(height: 12),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Eneo (hekta)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              initialValue: _areaHectares.toString(),
              onChanged: (val) => _areaHectares = double.tryParse(val) ?? 1.0,
              validator: (val) => val == null || double.tryParse(val) == null
                  ? 'Weka namba halali'
                  : null,
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _soilType,
              decoration: InputDecoration(
                labelText: 'Aina ya udongo',
                border: OutlineInputBorder(),
              ),
              items: _soilOptions.map((soil) {
                return DropdownMenuItem(
                  value: soil,
                  child: Text(soil.toUpperCase()),
                );
              }).toList(),
              onChanged: (val) => setState(() => _soilType = val!),
            ),
            SizedBox(height: 12),
            ListTile(
              title: Text('Tarehe ya kupanda'),
              subtitle: Text(_plantingDate.toLocal().toString().split(' ')[0]),
              trailing: Icon(Icons.calendar_today),
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
            SizedBox(height: 12),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mahali (GPS)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    if (_isLoadingLocation)
                      Center(child: CircularProgressIndicator())
                    else if (_locationError != null)
                      Text(_locationError!, style: TextStyle(color: Colors.red))
                    else if (_currentPosition != null)
                      Text(
                        'Lat: ${_currentPosition!.latitude}, Lon: ${_currentPosition!.longitude}',
                      )
                    else
                      Text('Hakuna eneo lililochaguliwa'),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _getCurrentLocation,
                          icon: Icon(Icons.my_location),
                          label: Text('Chukua eneo langu'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                        SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _showManualLocationDialog(),
                          icon: Icon(Icons.edit),
                          label: Text('Weka mwenyewe'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: _saveFarm,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('HIFADHI SHAMBA', style: TextStyle(fontSize: 16)),
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

    // Request permission
    var status = await Permission.location.request();
    if (status.isGranted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        setState(() {
          _currentPosition = position;
        });
      } catch (e) {
        setState(() {
          _locationError = 'Imeshindwa kupata eneo: $e';
        });
      }
    } else {
      setState(() {
        _locationError =
            'Ruhusa ya eneo haikubaliwa. Tafadhali ruhusu kwenye mipangilio.';
      });
    }
    setState(() => _isLoadingLocation = false);
  }

  void _showManualLocationDialog() {
    final latController = TextEditingController(
      text: _currentPosition?.latitude.toString() ?? '',
    );
    final lonController = TextEditingController(
      text: _currentPosition?.longitude.toString() ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Weka viwianishi mwenyewe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latController,
              decoration: InputDecoration(labelText: 'Latitude'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: lonController,
              decoration: InputDecoration(labelText: 'Longitude'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Ghairi'),
          ),
          TextButton(
            onPressed: () {
              final lat = double.tryParse(latController.text);
              final lon = double.tryParse(lonController.text);
              if (lat != null && lon != null) {
                setState(() {
                  _currentPosition = Position(
                    latitude: lat,
                    longitude: lon,
                    timestamp: DateTime.now(),
                    accuracy: 0,
                    altitude: 0,
                    altitudeAccuracy: 0,
                    heading: 0,
                    headingAccuracy: 0,
                    speed: 0,
                    speedAccuracy: 0,
                    isMocked: true,
                  );
                });
              }
              Navigator.pop(ctx);
            },
            child: Text('Hifadhi'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveFarm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tafadhali chukua au weka eneo la shamba')),
      );
      return;
    }

    final newFarm = Farm(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      cropType: _cropType,
      areaHectares: _areaHectares,
      soilType: _soilType,
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      plantingDate: _plantingDate,
    );

    final db = ref.read(databaseServiceProvider);
    await db.upsertFarm(newFarm);
    // Refresh farm list provider
    ref.read(farmListProvider.notifier).refresh();

    // Optionally trigger weather sync for this farm
    final sync = ref.read(syncServiceProvider);
    await sync.syncWeatherForFarm(newFarm);
    ref.invalidate(weatherDataProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Shamba limeongezwa! Hali ya hewa imesasishwa')),
    );
    Navigator.pop(context);
  }
}
