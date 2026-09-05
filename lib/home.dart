import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'abone_screen.dart';
import 'qr_screen.dart';
import 'main.dart';
import 'services/auth_service.dart';
import 'services/payment_service.dart';
import 'notifications_screen.dart';
import 'map_screen.dart';
import 'ticket_screen.dart';
import 'chatbot_widget.dart';

// translation helper — reads from global notifier
String _t(String sq, String en) => languageNotifier.value == 'sq' ? sq : en;

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    languageNotifier.addListener(_onLangChange);
  }

  @override
  void dispose() {
    languageNotifier.removeListener(_onLangChange);
    super.dispose();
  }

  void _onLangChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const _HomeTab(),
      const _TicketsTab(),
      const _MapTab(),
      const _ProfileTab(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FB),
      body: Stack(
        children: [
          tabs[_currentIndex],
          const ChatbotFloatingButton(isAdmin: false),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF3A7DFF),
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          elevation: 0,
          items: [
            BottomNavigationBarItem(icon: const Icon(Icons.home_outlined), activeIcon: const Icon(Icons.home), label: _t('Kryefaqja', 'Home')),
            BottomNavigationBarItem(icon: const Icon(Icons.confirmation_number_outlined), activeIcon: const Icon(Icons.confirmation_number), label: _t('Bileta', 'Tickets')),
            BottomNavigationBarItem(icon: const Icon(Icons.map_outlined), activeIcon: const Icon(Icons.map), label: _t('Harta', 'Map')),
            BottomNavigationBarItem(icon: const Icon(Icons.person_outline), activeIcon: const Icon(Icons.person), label: _t('Profili', 'Profile')),
          ],
        ),
      ),
    );
  }
}

// HOME TAB
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  String _greeting() {
    final h = DateTime.now().hour;
    if (languageNotifier.value == 'en') {
      if (h >= 5 && h < 12) return 'Good morning';
      if (h >= 12 && h < 17) return 'Good afternoon';
      if (h >= 17 && h < 21) return 'Good evening';
      return 'Hello';
    }
    if (h >= 5 && h < 12) return 'Mirëmëngjes';
    if (h >= 12 && h < 17) return 'Mirëdita';
    if (h >= 17 && h < 21) return 'Mirëmbrëma';
    return 'Përshëndetje';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, _) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
                builder: (context, snapshot) {
                  String name = _t('Pasagjer', 'Passenger');
                  if (snapshot.hasData && snapshot.data!.exists) {
                    name = (snapshot.data!.data() as Map<String, dynamic>)['name'] ?? name;
                  }
                  return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_greeting(), style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                      Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                    ]),
                    UnreadNotifBadge(
                      child: GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                        child: Container(width: 44, height: 44,
                          decoration: BoxDecoration(color: const Color(0xFF3A7DFF), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22)),
                      ),
                    ),
                  ]);
                },
              ),
              const SizedBox(height: 24),
              _PassengerAboneSection(userId: user?.uid),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TicketScreen())),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF00B894), Color(0xFF00856F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: const Color(0xFF00B894).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('URBANE', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                        child: const Text('50 Lekë', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                    ]),
                    const SizedBox(height: 16),
                    Text(_t('Bli Biletë', 'Buy Ticket'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_t('Vlen 1 orë • Të gjitha linjat', 'Valid 1 hour • All lines'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(_t('🎫 Biletë e vetme', '🎫 Single ticket'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.add, color: Color(0xFF00B894), size: 14),
                          const SizedBox(width: 4),
                          Text(_t('Bli Tani', 'Buy Now'), style: const TextStyle(color: Color(0xFF00B894), fontWeight: FontWeight.bold, fontSize: 12)),
                        ]),
                      ),
                    ]),
                  ]),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ABONE SECTION
class _PassengerAboneSection extends StatefulWidget {
  final String? userId;
  const _PassengerAboneSection({required this.userId});
  @override
  State<_PassengerAboneSection> createState() => _PassengerAboneSectionState();
}

class _PassengerAboneSectionState extends State<_PassengerAboneSection> {
  bool _isPaying = false;

  int _priceFor(String category, Map<String, dynamic> data) {
    final p = data['price_due'];
    if (p is int) return p;
    if (p is num) return p.toInt();
    if (category == 'elderly') return 800;
    if (category == 'student') return 0;
    return 1600;
  }

  String _catLabel(String category) {
    if (category == 'student') return _t('Studentore', 'Student');
    if (category == 'elderly') return _t('Senior', 'Senior');
    return _t('Gjenerale', 'General');
  }

  Future<void> _payApproved(BuildContext context, DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final cat = data['category'] ?? 'general';
    final price = _priceFor(cat, data);
    setState(() => _isPaying = true);
    final ok = await PaymentService.processPayment(context: context, amount: price, description: 'Pagesë abone ${_catLabel(cat)}');
    if (!mounted) return;
    if (!ok) {
      setState(() => _isPaying = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('Pagesa dështoi.', 'Payment failed.')), backgroundColor: Colors.red));
      return;
    }
    await FirebaseFirestore.instance.collection('abonements').doc(doc.id).update({'status': 'active', 'payment_status': 'paid', 'price_paid': price, 'paid_at': FieldValue.serverTimestamp(), 'updated_at': FieldValue.serverTimestamp()});
    setState(() => _isPaying = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('Abonja u aktivizua ✓', 'Abonement activated ✓')), backgroundColor: const Color(0xFF00C853)));
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.userId;
    if (uid == null) return _NoAboneCard(onBuyAbone: null);

    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, _, __) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('abonements').where('user_id', isEqualTo: uid).snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            docs.sort((a, b) {
              final at = (a.data() as Map<String, dynamic>)['created_at'];
              final bt = (b.data() as Map<String, dynamic>)['created_at'];
              if (at is Timestamp && bt is Timestamp) return bt.compareTo(at);
              return 0;
            });
            DocumentSnapshot? active, approved, pending, rejected;
            final now = DateTime.now();
            for (final d in docs) {
              final data2 = d.data() as Map<String, dynamic>;
              final s = data2['status'];
              // ✅ Check valid_until — expired abonements should not show as active
              final validUntil = (data2['valid_until'] as Timestamp?)?.toDate();
              final isReallyActive = s == 'active' && (validUntil == null || validUntil.isAfter(now));
              if (isReallyActive && active == null) active = d;
              // Auto-expire in Firestore if status is active but date passed
              if (s == 'active' && validUntil != null && validUntil.isBefore(now)) {
                d.reference.update({'status': 'expired'});
              }
              if (s == 'approved_for_payment' && approved == null) approved = d;
              if (s == 'pending_verification' && pending == null) pending = d;
              if (s == 'rejected' && rejected == null) rejected = d;
            }
            if (active != null) {
              final data = active.data() as Map<String, dynamic>;
              final cat = data['category'] ?? 'general';
              final until = (data['valid_until'] as Timestamp?)?.toDate();
              final untilStr = until != null ? '${until.day}/${until.month}/${until.year}' : '-';
              final owner = '${data['user_name'] ?? ''} ${data['user_surname'] ?? ''}'.trim();
              final id = active.id;
              return _AboneCard(label: '${_t('Abone', 'Pass')} ${_catLabel(cat)}', validUntil: untilStr,
                onShowQR: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QRScreen(aboneId: id, categoryLabel: _catLabel(cat), validUntil: untilStr, ownerName: owner.isNotEmpty ? owner : uid))));
            }
            if (approved != null) {
              final data = approved.data() as Map<String, dynamic>;
              final cat = data['category'] ?? 'general';
              return _ApprovedForPaymentCard(categoryLabel: _catLabel(cat), price: _priceFor(cat, data), isPaying: _isPaying, onPay: () => _payApproved(context, approved!));
            }
            if (pending != null) return const _PendingAboneCard();
            if (rejected != null) return const _RejectedAboneCard();
            return _NoAboneCard(onBuyAbone: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboneScreen())));
          },
        );
      },
    );
  }
}

// TICKETS TAB
class _TicketsTab extends StatefulWidget {
  const _TicketsTab();
  @override
  State<_TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends State<_TicketsTab> {
  String _period = 'month';

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, _) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(_t('Udhëtimet', 'Trips'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _PeriodBtn(label: _t('Muaji', 'Month'), selected: _period == 'month', onTap: () => setState(() => _period = 'month')),
                    _PeriodBtn(label: _t('Viti', 'Year'), selected: _period == 'year', onTap: () => setState(() => _period = 'year')),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('validations').where('user_id', isEqualTo: user?.uid).snapshots(),
                builder: (context, snapshot) {
                  final all = snapshot.data?.docs ?? [];
                  final now = DateTime.now();
                  final filtered = all.where((doc) {
                    final t = ((doc.data() as Map<String, dynamic>)['validated_at'] as Timestamp?)?.toDate();
                    if (t == null) return false;
                    if (_period == 'month') return t.year == now.year && t.month == now.month;
                    return t.year == now.year;
                  }).toList();
                  final Map<String, int> lineCount = {};
                  for (final doc in filtered) {
                    final line = (doc.data() as Map<String, dynamic>)['line_name'] as String?;
                    if (line != null && line.isNotEmpty) lineCount[line] = (lineCount[line] ?? 0) + 1;
                  }
                  final topLine = lineCount.isEmpty ? '-' : lineCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
                  return Row(children: [
                    Expanded(child: _StatCard(value: '${filtered.length}', label: _t('Udhëtime', 'Trips'), icon: Icons.directions_bus, color: const Color(0xFF3A7DFF))),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(value: topLine, label: _t('Linja kryesore', 'Top line'), icon: Icons.star, color: const Color(0xFFFF6D00), small: true)),
                  ]);
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('validations').where('user_id', isEqualTo: user?.uid).orderBy('validated_at', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    final now = DateTime.now();
                    final docs = (snapshot.data?.docs ?? []).where((doc) {
                      final t = ((doc.data() as Map<String, dynamic>)['validated_at'] as Timestamp?)?.toDate();
                      if (t == null) return false;
                      if (_period == 'month') return t.year == now.year && t.month == now.month;
                      return t.year == now.year;
                    }).toList();

                    if (docs.isEmpty) {
                      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text('🚌', style: TextStyle(fontSize: 56)),
                        const SizedBox(height: 16),
                        Text(_period == 'month' ? _t('Nuk keni udhëtime këtë muaj', 'No trips this month') : _t('Nuk keni udhëtime këtë vit', 'No trips this year'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ]));
                    }

                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final data = docs[i].data() as Map<String, dynamic>;
                        final t = (data['validated_at'] as Timestamp?)?.toDate();
                        final dateStr = t != null ? '${t.day}/${t.month}/${t.year}  ${t.hour}:${t.minute.toString().padLeft(2, '0')}' : '-';
                        final lineName = data['line_name'] as String?;
                        final stationName = data['station_name'] as String?;
                        final isAbone = (data['type'] ?? '') == 'abone';
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
                          child: Row(children: [
                            Container(width: 44, height: 44,
                              decoration: BoxDecoration(color: isAbone ? const Color(0xFFE8F0FF) : const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
                              child: Icon(isAbone ? Icons.card_membership : Icons.directions_bus, color: isAbone ? const Color(0xFF3A7DFF) : const Color(0xFFFF6D00), size: 22)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(lineName?.isNotEmpty == true ? lineName! : _t('Linjë e panjohur', 'Unknown line'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              if (stationName?.isNotEmpty == true) Text(stationName!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            ])),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: isAbone ? const Color(0xFFE8F0FF) : const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(10)),
                              child: Text(isAbone ? _t('Abone', 'Pass') : _t('Biletë', 'Ticket'),
                                style: TextStyle(color: isAbone ? const Color(0xFF3A7DFF) : const Color(0xFFFF6D00), fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ]),
                        );
                      },
                    );
                  },
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _PeriodBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PeriodBtn({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: selected ? const Color(0xFF3A7DFF) : Colors.transparent, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: selected ? Colors.white : Colors.grey)),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  final bool small;
  const _StatCard({required this.value, required this.label, required this.icon, required this.color, this.small = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: small ? 13 : 22, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A2E)), overflow: TextOverflow.ellipsis, maxLines: 1),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ])),
      ]),
    );
  }
}

// MAP TAB
class _MapTab extends StatelessWidget {
  const _MapTab();
  @override
  Widget build(BuildContext context) => const MapScreen();
}

// PROFILE TAB
class _ProfileTab extends StatefulWidget {
  const _ProfileTab();
  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  Future<void> _setLanguage(String lang) async {
    languageNotifier.value = lang;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) await FirebaseFirestore.instance.collection('users').doc(uid).update({'language': lang});
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, _) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
              builder: (context, snapshot) {
                String name = '', surname = '', email = user?.email ?? '', gender = '';
                if (snapshot.hasData && snapshot.data!.exists) {
                  final d = snapshot.data!.data() as Map<String, dynamic>;
                  name = d['name'] ?? ''; surname = d['surname'] ?? ''; email = d['email'] ?? email; gender = d['gender'] ?? '';
                }
                return Column(children: [
                  Container(width: 90, height: 90,
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF3A7DFF), Color(0xFF1A3AFF)]), shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: const Color(0xFF3A7DFF).withOpacity(0.3), blurRadius: 20)]),
                    child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)))),
                  const SizedBox(height: 12),
                  Text('$name $surname', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(email, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 24),
                  Container(padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                    child: Column(children: [
                      _ProfileRow(icon: Icons.person_outline, label: _t('Emri', 'Name'), value: '$name $surname'),
                      const Divider(height: 24),
                      _ProfileRow(icon: Icons.email_outlined, label: 'Email', value: email),
                      if (gender.isNotEmpty) ...[const Divider(height: 24), _ProfileRow(icon: Icons.people_outline, label: _t('Gjinia', 'Gender'), value: gender)],
                      const Divider(height: 24),
                      _ProfileRow(icon: Icons.shield_outlined, label: _t('Roli', 'Role'), value: _t('Pasagjer', 'Passenger')),
                    ])),
                  const SizedBox(height: 16),
                  Container(padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [const Icon(Icons.language, color: Color(0xFF3A7DFF), size: 20), const SizedBox(width: 10), Text(_t('Gjuha', 'Language'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: GestureDetector(onTap: () => _setLanguage('sq'),
                          child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(color: lang == 'sq' ? const Color(0xFF3A7DFF) : const Color(0xFFF8FAFF), borderRadius: BorderRadius.circular(12), border: Border.all(color: lang == 'sq' ? const Color(0xFF3A7DFF) : Colors.grey.shade200)),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('🇦🇱', style: TextStyle(fontSize: 20)), const SizedBox(width: 8), Text('Shqip', style: TextStyle(fontWeight: FontWeight.bold, color: lang == 'sq' ? Colors.white : Colors.grey.shade700))])))),
                        const SizedBox(width: 12),
                        Expanded(child: GestureDetector(onTap: () => _setLanguage('en'),
                          child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(color: lang == 'en' ? const Color(0xFF3A7DFF) : const Color(0xFFF8FAFF), borderRadius: BorderRadius.circular(12), border: Border.all(color: lang == 'en' ? const Color(0xFF3A7DFF) : Colors.grey.shade200)),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('🇬🇧', style: TextStyle(fontSize: 20)), const SizedBox(width: 8), Text('English', style: TextStyle(fontWeight: FontWeight.bold, color: lang == 'en' ? Colors.white : Colors.grey.shade700))])))),
                      ]),
                    ])),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () async { await AuthService().logout(); if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MyApp())); },
                      style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.red.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      icon: Icon(Icons.logout, color: Colors.red.shade400, size: 20),
                      label: Text(_t('Dil nga llogaria', 'Sign out'), style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.bold)),
                    )),
                ]);
              },
            ),
          ),
        );
      },
    );
  }
}

// CARD WIDGETS
class _AboneCard extends StatelessWidget {
  final String label, validUntil;
  final VoidCallback onShowQR;
  const _AboneCard({required this.label, required this.validUntil, required this.onShowQR});
  @override
  Widget build(BuildContext context) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF3A7DFF), Color(0xFF1A3AFF)]), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: const Color(0xFF3A7DFF).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('URBANE', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: Text(_t('Aktive ✓', 'Active ✓'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 16),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('${_t('Skadon', 'Expires')}: $validUntil', style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('🚌 ${_t('Të gjitha linjat', 'All lines')}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Material(color: Colors.white, borderRadius: BorderRadius.circular(20),
            child: InkWell(onTap: onShowQR, borderRadius: BorderRadius.circular(20),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.qr_code, color: Color(0xFF3A7DFF), size: 14), const SizedBox(width: 5),
                  Text(_t('Shiko QR', 'Show QR'), style: const TextStyle(color: Color(0xFF3A7DFF), fontWeight: FontWeight.bold, fontSize: 12)),
                ])))),
        ]),
      ]));
  }
}

class _ApprovedForPaymentCard extends StatelessWidget {
  final String categoryLabel; final int price; final bool isPaying; final VoidCallback onPay;
  const _ApprovedForPaymentCard({required this.categoryLabel, required this.price, required this.isPaying, required this.onPay});
  @override
  Widget build(BuildContext context) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Text('✅', style: TextStyle(fontSize: 34)), const SizedBox(width: 12), Expanded(child: Text(_t('Aplikimi u aprovua', 'Application approved'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))]),
        const SizedBox(height: 8),
        Text('${_t('Abone', 'Pass')} $categoryLabel ${_t('është gati për pagesë.', 'ready for payment.')}', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, height: 46,
          child: ElevatedButton(onPressed: isPaying ? null : onPay,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: isPaying ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('${_t('Paguaj', 'Pay')} $price Lekë', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
      ]));
  }
}

class _PendingAboneCard extends StatelessWidget {
  const _PendingAboneCard();
  @override
  Widget build(BuildContext context) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.shade200)),
      child: Row(children: [
        const Text('⏳', style: TextStyle(fontSize: 36)), const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_t('Aplikimi në pritje', 'Application pending'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(_t('Dokumenti juaj është duke u verifikuar.', 'Your document is being verified.'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ])),
      ]));
  }
}

class _RejectedAboneCard extends StatelessWidget {
  const _RejectedAboneCard();
  @override
  Widget build(BuildContext context) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.red.shade200)),
      child: Column(children: [
        Row(children: [const Text('❌', style: TextStyle(fontSize: 36)), const SizedBox(width: 16), Expanded(child: Text(_t('Aplikimi u refuzua', 'Application rejected'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))]),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 44,
          child: ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboneScreen())),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3A7DFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(_t('Apliko përsëri', 'Apply again'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
      ]));
  }
}

class _NoAboneCard extends StatelessWidget {
  final VoidCallback? onBuyAbone;
  const _NoAboneCard({required this.onBuyAbone});
  @override
  Widget build(BuildContext context) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF3A7DFF).withOpacity(0.3)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
      child: Column(children: [
        const Text('🚌', style: TextStyle(fontSize: 40)), const SizedBox(height: 12),
        Text(_t('Nuk keni abone aktive', 'No active abonement'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 6),
        Text(_t('Bli një abone mujore dhe udhëto pa limit!', 'Buy a monthly pass and travel unlimited!'), style: const TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 46,
          child: ElevatedButton(onPressed: onBuyAbone,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3A7DFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(_t('Bli Abone', 'Buy Abonement'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
      ]));
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon; final String label, value;
  const _ProfileRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: const Color(0xFF3A7DFF), size: 20), const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ])),
    ]);
  }
}