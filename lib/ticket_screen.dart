import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'services/payment_service.dart';
import 'main.dart';

String _t(String sq, String en) => languageNotifier.value == 'sq' ? sq : en;

class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key});
  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  bool _isPaying = false;

  @override
  void initState() {
    super.initState();
    languageNotifier.addListener(_rebuild);
  }

  @override
  void dispose() {
    languageNotifier.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  Future<void> _buyTicket() async {
    setState(() => _isPaying = true);

    final success = await PaymentService.processPayment(
      context: context,
      amount: 50,
      description: 'Biletë Urbane — 1 orë',
    );

    if (!mounted) return;

    if (!success) {
      setState(() => _isPaying = false);
      return; // payment_service already shows the error
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};

    await FirebaseFirestore.instance.collection('tickets').add({
      'owner_user_id': uid,
      'owner_name': '${userData['name'] ?? ''} ${userData['surname'] ?? ''}'.trim(),
      'status': 'active',
      'price_paid': 50,
      'created_at': FieldValue.serverTimestamp(),
      'expires_at': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 1))),
      'line_name': null,
      'stop_name': null,
      'scanned': false,
    });

    setState(() => _isPaying = false);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: const Color(0xFF1A1A2E)),
        title: Text(_t('Bileta', 'Tickets'), style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tickets')
            .where('owner_user_id', isEqualTo: uid)
            .where('status', isEqualTo: 'active')
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final now = DateTime.now();

          // Auto-expire and filter
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final expiresAt = (data['expires_at'] as Timestamp?)?.toDate();
            if (expiresAt != null && now.isAfter(expiresAt)) {
              doc.reference.update({'status': 'expired'});
            }
          }

          final activeTickets = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final expiresAt = (data['expires_at'] as Timestamp?)?.toDate();
            return expiresAt != null && now.isBefore(expiresAt);
          }).toList();

          // ── NO ACTIVE TICKET: show buy screen ──
          if (activeTickets.isEmpty) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _isPaying ? null : _buyTicket,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF3A7DFF), Color(0xFF1A3AFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [BoxShadow(color: const Color(0xFF3A7DFF).withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 10))],
                    ),
                    child: Column(children: [
                      const Text('🎫', style: TextStyle(fontSize: 52)),
                      const SizedBox(height: 14),
                      Text(_t('Bli Biletë Urbane', 'Buy Urban Ticket'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                      const SizedBox(height: 6),
                      Text(_t('50 Lekë • Vlen 1 orë • Të gjitha linjat', '50 Lekë • Valid 1 hour • All lines'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
                        child: _isPaying
                            ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
                            : Text(_t('Paguaj tani', 'Pay now'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_t('Si funksionon?', 'How does it work?'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 14),
                    _Step(number: '1', text: _t('Paguaj 50 Lekë me kartë', 'Pay 50 Lekë by card')),
                    _Step(number: '2', text: _t('Merr QR kodin tënd', 'Get your QR code')),
                    _Step(number: '3', text: _t('Trego QR-in faturinos kur hipni', 'Show QR to inspector when boarding')),
                    _Step(number: '4', text: _t('Bileta vlen 1 orë nga skanimi', 'Ticket valid 1 hour from scan')),
                  ]),
                ),
              ]),
            );
          }

          // ── HAS ACTIVE TICKET ──
          final activeDoc = activeTickets.first;
          final activeData = activeDoc.data() as Map<String, dynamic>;
          final expiresAt = (activeData['expires_at'] as Timestamp?)?.toDate();
          final lineName = activeData['line_name'] as String?;
          final expStr = expiresAt != null ? '${expiresAt.hour}:${expiresAt.minute.toString().padLeft(2, '0')}' : '-';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(color: const Color(0xFF3A7DFF).withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 8))],
                  border: Border.all(color: const Color(0xFF3A7DFF).withOpacity(0.25), width: 1.5),
                ),
                child: Column(children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF3A7DFF), Color(0xFF1A3AFF)]),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('URBANE', style: const TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 2.5, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_t('Biletë Aktive', 'Active Ticket'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      ]),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                        child: Text('${_t('Skadon', 'Expires')}: $expStr', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ]),
                  ),
                  // QR
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF3A7DFF).withOpacity(0.2), width: 2)),
                        child: QrImageView(
                          data: 'ticket:${activeDoc.id}',
                          version: QrVersions.auto,
                          size: 200,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1A1A2E)),
                          dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1A1A2E)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(_t('Trego këtë QR faturinos', 'Show this QR to the inspector'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1A1A2E))),
                      const SizedBox(height: 4),
                      Text('50 Lekë • ${lineName ?? _t('Të gjitha linjat', 'All lines')}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.check_circle, color: Color(0xFF00C853), size: 16),
                          const SizedBox(width: 6),
                          Text(_t('Aktive • Të gjitha linjat', 'Active • All lines'), style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 13)),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              // Buy another
              GestureDetector(
                onTap: _isPaying ? null : _buyTicket,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF3A7DFF).withOpacity(0.3)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                  ),
                  child: Row(children: [
                    Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFE8F0FF), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add, color: Color(0xFF3A7DFF), size: 24)),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_t('Bli biletë tjetër', 'Buy another ticket'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(_t('Për person tjetër • 50 Lekë', 'For another person • 50 Lekë'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ])),
                    if (_isPaying)
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3A7DFF)))
                    else
                      const Icon(Icons.arrow_forward_ios, color: Color(0xFF3A7DFF), size: 16),
                  ]),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number, text;
  const _Step({required this.number, required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(width: 28, height: 28, decoration: const BoxDecoration(color: Color(0xFF3A7DFF), shape: BoxShape.circle), child: Center(child: Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)))),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E))),
      ]),
    );
  }
}