import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'main.dart';
import 'change_password_screen.dart';
import 'services/auth_service.dart';

class FatorinoHomePage extends StatefulWidget {
  const FatorinoHomePage({super.key});

  @override
  State<FatorinoHomePage> createState() => _FatorinoHomePageState();
}

class _FatorinoHomePageState extends State<FatorinoHomePage> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;
  bool _torchOn = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<Position?> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      return null;
    }
  }

  // Find nearest station to faturino's GPS position
  Future<Map<String, String?>?> _getNearestStation(double lat, double lng) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('stations').get();
      if (snap.docs.isEmpty) return null;

      double minDist = double.infinity;
      Map<String, dynamic>? nearest;

      for (final doc in snap.docs) {
        final data = doc.data();
        final sLat = (data['lat'] as num?)?.toDouble();
        final sLng = (data['lng'] as num?)?.toDouble();
        if (sLat == null || sLng == null) continue;
        final dist = Geolocator.distanceBetween(lat, lng, sLat, sLng);
        if (dist < minDist) {
          minDist = dist;
          nearest = data;
        }
      }

      if (nearest == null) return null;
      return {
        'station_name': nearest['name'] as String?,
        'distance_m': minDist.toStringAsFixed(0),
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final scannedValue = barcode!.rawValue!;
    setState(() => _isProcessing = true);
    await cameraController.stop();

    // Detect if this is a ticket or abone
    if (scannedValue.startsWith('ticket:')) {
      final ticketId = scannedValue.replaceFirst('ticket:', '');
      await _validateTicket(ticketId);
    } else {
      await _validateAbone(scannedValue);
    }
  }

  Future<void> _validateTicket(String ticketId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('tickets').doc(ticketId).get();

      if (!doc.exists) {
        _showResult(_ValidationResult.notFound());
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] ?? '';
      final expiresAt = (data['expires_at'] as Timestamp?)?.toDate();
      final now = DateTime.now();
      final ownerName = data['owner_name'] ?? 'E panjohur';

      if (status != 'active') {
        _showResult(_ValidationResult.invalid(
          passengerName: ownerName,
          categoryLabel: 'Biletë',
          reason: status == 'expired' ? 'Bileta ka skaduar' : 'Bileta është e pavlefshme',
        ));
        return;
      }

      if (expiresAt != null && now.isAfter(expiresAt)) {
        await doc.reference.update({'status': 'expired'});
        _showResult(_ValidationResult.invalid(
          passengerName: ownerName,
          categoryLabel: 'Biletë',
          reason: 'Bileta ka skaduar',
        ));
        return;
      }

      // Get faturino's info and GPS
      final fatorinoUid = FirebaseAuth.instance.currentUser?.uid;
      String? fatorinoLineId;
      String? fatorinoLineName;
      if (fatorinoUid != null) {
        final fatDoc = await FirebaseFirestore.instance.collection('users').doc(fatorinoUid).get();
        if (fatDoc.exists) {
          final fd = fatDoc.data() as Map<String, dynamic>;
          fatorinoLineId = fd['line_id'] as String?;
          fatorinoLineName = fd['line_name'] as String?;
        }
      }

      // Get GPS + nearest station
      final position = await _getLocation();
      Map<String, String?>? stationInfo;
      if (position != null) {
        stationInfo = await _getNearestStation(position.latitude, position.longitude);
      }

      final stationName = stationInfo?['station_name'];

      // ✅ FIX: Check if this ticket was already scanned by THIS faturino on THIS line today
      // This prevents duplicate records if faturino accidentally scans twice
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final existingVal = await FirebaseFirestore.instance.collection('validations')
          .where('ticket_id', isEqualTo: ticketId)
          .where('faturino_id', isEqualTo: fatorinoUid)
          .where('validated_at', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      if (existingVal.docs.isNotEmpty) {
        // Already scanned today by this faturino - show valid but don't save duplicate
        _showResult(_ValidationResult.valid(
          passengerName: ownerName,
          categoryLabel: 'Biletë (Skanim i njëjtë)',
          validUntil: 'Tashmë skanuar nga ky faturino sot',
        ));
        return;
      }

      // Mark ticket as scanned + save record
      await doc.reference.update({
        'status': 'active',
        'scanned': true,
        'line_id': fatorinoLineId,
        'line_name': fatorinoLineName,
        'stop_name': stationName,
        'scanned_at': FieldValue.serverTimestamp(),
        'faturino_id': fatorinoUid,
      });

      // Save validation record (only once per faturino per day per ticket)
      await FirebaseFirestore.instance.collection('validations').add({
        'type': 'ticket',
        'ticket_id': ticketId,
        'user_id': data['owner_user_id'],
        'faturino_id': fatorinoUid,
        'line_id': fatorinoLineId,
        'line_name': fatorinoLineName ?? '',
        'station_name': stationName ?? '',
        'lat': position?.latitude,
        'lng': position?.longitude,
        'validated_at': FieldValue.serverTimestamp(),
      });

      final expStr = expiresAt != null
          ? '${expiresAt.hour}:${expiresAt.minute.toString().padLeft(2, '0')}'
          : '-';

      _showResult(_ValidationResult.valid(
        passengerName: ownerName,
        categoryLabel: 'Biletë',
        validUntil: 'Skadon: $expStr${stationName != null ? '\nStacioni: $stationName' : ''}',
      ));
    } catch (e) {
      debugPrint('Ticket validation error: $e');
      _showResult(_ValidationResult.error());
    }
  }

  Future<void> _validateAbone(String aboneId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('abonements').doc(aboneId).get();

      if (!doc.exists) {
        _showResult(_ValidationResult.notFound());
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] ?? '';
      final validUntil = (data['valid_until'] as Timestamp?)?.toDate();
      final now = DateTime.now();

      final userId = data['user_id'] as String?;
      String passengerName = 'E panjohur';
      if (userId != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final ud = userDoc.data() as Map<String, dynamic>;
          passengerName = '${ud['name'] ?? ''} ${ud['surname'] ?? ''}'.trim();
        }
      }

      final category = data['category'] ?? 'general';
      final categoryLabel = category == 'student' ? 'Studentore' : category == 'elderly' ? 'Senior' : 'Gjenerale';

      if (status != 'active') {
        _showResult(_ValidationResult.invalid(
          passengerName: passengerName,
          categoryLabel: categoryLabel,
          reason: status == 'pending_verification' || status == 'approved_for_payment'
              ? 'Abonja nuk është paguar ende'
              : status == 'expired' ? 'Abonja ka skaduar' : 'Abonja është e pavlefshme',
        ));
        return;
      }

      if (validUntil != null && now.isAfter(validUntil)) {
        await doc.reference.update({'status': 'expired'});
        _showResult(_ValidationResult.invalid(
          passengerName: passengerName,
          categoryLabel: categoryLabel,
          reason: 'Abonja ka skaduar',
        ));
        return;
      }

      // Get faturino info
      final fatorinoUid = FirebaseAuth.instance.currentUser?.uid;
      String? fatorinoLineId;
      String? fatorinoLineName;
      if (fatorinoUid != null) {
        final fatDoc = await FirebaseFirestore.instance.collection('users').doc(fatorinoUid).get();
        if (fatDoc.exists) {
          final fd = fatDoc.data() as Map<String, dynamic>;
          fatorinoLineId = fd['line_id'] as String?;
          fatorinoLineName = fd['line_name'] as String?;
        }
      }

      // Get GPS + nearest station
      final position = await _getLocation();
      Map<String, String?>? stationInfo;
      if (position != null) {
        stationInfo = await _getNearestStation(position.latitude, position.longitude);
      }
      final stationName = stationInfo?['station_name'];

      // Save validation record
      await FirebaseFirestore.instance.collection('validations').add({
        'type': 'abone',
        'abone_id': aboneId,
        'user_id': userId,
        'faturino_id': fatorinoUid,
        'line_id': fatorinoLineId,
        'line_name': fatorinoLineName ?? '',
        'station_name': stationName ?? '',
        'category': category,
        'lat': position?.latitude,
        'lng': position?.longitude,
        'validated_at': FieldValue.serverTimestamp(),
      });

      final validUntilStr = validUntil != null
          ? '${validUntil.day}/${validUntil.month}/${validUntil.year}'
          : '-';

      _showResult(_ValidationResult.valid(
        passengerName: passengerName,
        categoryLabel: categoryLabel,
        validUntil: '$validUntilStr${stationName != null ? '\nStacioni: $stationName' : ''}',
      ));
    } catch (e) {
      debugPrint('Abone validation error: $e');
      _showResult(_ValidationResult.error());
    }
  }

  void _showResult(_ValidationResult result) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _ResultSheet(
        result: result,
        onScanAgain: () {
          Navigator.pop(context);
          setState(() => _isProcessing = false);
          cameraController.start();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: cameraController, onDetect: _onDetect),
          _ScanOverlay(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('URBANE', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 3, fontWeight: FontWeight.bold)),
                      Text('Faturino', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(children: [
                    GestureDetector(
                      onTap: () { setState(() => _torchOn = !_torchOn); cameraController.toggleTorch(); },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _torchOn ? Colors.yellow.withOpacity(0.3) : Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_torchOn ? Icons.flash_on : Icons.flash_off,
                            color: _torchOn ? Colors.yellow : Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.lock_reset, color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () async {
                        await AuthService().logout();
                        if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MyApp()));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.logout, color: Colors.white, size: 22),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 60, left: 0, right: 0,
            child: Column(children: [
              if (_isProcessing)
                const CircularProgressIndicator(color: Colors.white)
              else
                const Text('Skanoni QR kodin e biletës ose abonës',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 15)),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Scan overlay ──────────────────────────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const boxSize = 260.0;
    final top = (size.height - boxSize) / 2 - 40;
    final left = (size.width - boxSize) / 2;
    return Stack(children: [
      Container(color: Colors.black.withOpacity(0.55)),
      Positioned(
        top: top, left: left,
        child: Container(
          width: boxSize, height: boxSize,
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      ..._buildCorners(top, left, boxSize),
    ]);
  }

  static List<Widget> _buildCorners(double top, double left, double size) {
    const c = 24.0; const t = 4.0;
    const color = Color(0xFF3A7DFF);
    Widget corner(double ct, double cl, bool isTop, bool isLeft) => Positioned(
      top: ct, left: cl,
      child: SizedBox(width: c, height: c,
        child: CustomPaint(painter: _CornerPainter(color: color, thickness: t, isTop: isTop, isLeft: isLeft))),
    );
    return [
      corner(top - t/2, left - t/2, true, true),
      corner(top - t/2, left + size - c + t/2, true, false),
      corner(top + size - c + t/2, left - t/2, false, true),
      corner(top + size - c + t/2, left + size - c + t/2, false, false),
    ];
  }
}

class _CornerPainter extends CustomPainter {
  final Color color; final double thickness; final bool isTop; final bool isLeft;
  const _CornerPainter({required this.color, required this.thickness, required this.isTop, required this.isLeft});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = thickness * 2..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final path = Path();
    if (isTop && isLeft) { path.moveTo(0, size.height); path.lineTo(0, 0); path.lineTo(size.width, 0); }
    else if (isTop && !isLeft) { path.moveTo(0, 0); path.lineTo(size.width, 0); path.lineTo(size.width, size.height); }
    else if (!isTop && isLeft) { path.moveTo(0, 0); path.lineTo(0, size.height); path.lineTo(size.width, size.height); }
    else { path.moveTo(0, size.height); path.lineTo(size.width, size.height); path.lineTo(size.width, 0); }
    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Validation result ─────────────────────────────────────────────────────────

enum _ResultType { valid, invalid, notFound, error }

class _ValidationResult {
  final _ResultType type;
  final String? passengerName;
  final String? categoryLabel;
  final String? validUntil;
  final String? reason;
  const _ValidationResult._({required this.type, this.passengerName, this.categoryLabel, this.validUntil, this.reason});
  factory _ValidationResult.valid({required String passengerName, required String categoryLabel, required String validUntil}) =>
      _ValidationResult._(type: _ResultType.valid, passengerName: passengerName, categoryLabel: categoryLabel, validUntil: validUntil);
  factory _ValidationResult.invalid({required String passengerName, required String categoryLabel, required String reason}) =>
      _ValidationResult._(type: _ResultType.invalid, passengerName: passengerName, categoryLabel: categoryLabel, reason: reason);
  factory _ValidationResult.notFound() => const _ValidationResult._(type: _ResultType.notFound, reason: 'QR kodi nuk u gjet në sistem');
  factory _ValidationResult.error() => const _ValidationResult._(type: _ResultType.error, reason: 'Gabim gjatë verifikimit. Provo përsëri.');
}

class _ResultSheet extends StatelessWidget {
  final _ValidationResult result;
  final VoidCallback onScanAgain;
  const _ResultSheet({required this.result, required this.onScanAgain});

  @override
  Widget build(BuildContext context) {
    final isValid = result.type == _ResultType.valid;
    final bgColor = isValid ? const Color(0xFF00C853) : const Color(0xFFE53935);
    final icon = isValid ? Icons.check_circle_rounded : Icons.cancel_rounded;
    final title = isValid ? 'E VLEFSHME ✓' : 'E PAVLEFSHME ✗';

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 30)]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(children: [
            Icon(icon, color: Colors.white, size: 64),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            if (result.passengerName != null) ...[
              _DetailRow(icon: Icons.person, label: 'Pasagjeri', value: result.passengerName!),
              const SizedBox(height: 12),
            ],
            if (result.categoryLabel != null) ...[
              _DetailRow(icon: Icons.card_membership, label: 'Lloji', value: result.categoryLabel!),
              const SizedBox(height: 12),
            ],
            if (isValid && result.validUntil != null) ...[
              _DetailRow(icon: Icons.calendar_today, label: 'Detaje', value: result.validUntil!),
              const SizedBox(height: 12),
            ],
            if (!isValid && result.reason != null) ...[
              Container(
                width: double.infinity, padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                child: Text(result.reason!, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: onScanAgain,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1A2E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Skano tjetër', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon; final String label; final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: const Color(0xFF3A7DFF), size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ])),
    ]);
  }
}