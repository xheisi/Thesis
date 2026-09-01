import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<Map<String, dynamic>> _lines = [];
  String? _selectedLineId;
  bool _loading = true;

  static const _tiranCenter = LatLng(41.3275, 19.8187);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load bus lines
    final linesSnap = await FirebaseFirestore.instance
        .collection('bus_lines')
        .get();
    _lines = linesSnap.docs.map((d) {
      final data = d.data();
      return {
        'id': d.id,
        'name': data['name'] ?? '',
        'color': data['color'] ?? '#3A7DFF',
        'line_number': data['line_number'] ?? '',
      };
    }).toList();

    // Load stations
    final stationsSnap = await FirebaseFirestore.instance
        .collection('stations')
        .get();

    final markers = <Marker>{};
    for (final doc in stationsSnap.docs) {
      final data = doc.data();
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final lineIds = List<String>.from(data['line_ids'] ?? []);
      final stationName = data['name'] ?? 'Stacion';

      markers.add(Marker(
        markerId: MarkerId(doc.id),
        position: LatLng(lat, lng),
        infoWindow: InfoWindow(
          title: stationName,
          snippet: 'Linjat: ${lineIds.join(', ')}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
    }

    setState(() {
      _markers.addAll(markers);
      _loading = false;
    });
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF3A7DFF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FB),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Harta', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                        Text('Linjat e Urbanit Tiranë', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Line filter chips
            if (_lines.isNotEmpty)
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('Të gjitha'),
                        selected: _selectedLineId == null,
                        onSelected: (_) => setState(() => _selectedLineId = null),
                        selectedColor: const Color(0xFF3A7DFF),
                        labelStyle: TextStyle(
                          color: _selectedLineId == null ? Colors.white : Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        backgroundColor: Colors.white,
                        checkmarkColor: Colors.white,
                      ),
                    ),
                    ..._lines.map((line) {
                      final color = _hexToColor(line['color']);
                      final isSelected = _selectedLineId == line['id'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text('${line['line_number']} ${line['name']}'),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _selectedLineId = isSelected ? null : line['id']),
                          selectedColor: color,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          backgroundColor: Colors.white,
                          checkmarkColor: Colors.white,
                        ),
                      );
                    }),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // Map
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : GoogleMap(
                          initialCameraPosition: const CameraPosition(
                            target: _tiranCenter,
                            zoom: 13,
                          ),
                          markers: _selectedLineId == null
                              ? _markers
                              : _markers.where((m) {
                                  // Filter markers by selected line
                                  return true; // show all for now, can filter by line_ids
                                }).toSet(),
                          polylines: _polylines,
                          onMapCreated: (controller) => _mapController = controller,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                          zoomControlsEnabled: false,
                          mapToolbarEnabled: false,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}