import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'main.dart';
import 'services/auth_service.dart';
import 'change_password_screen.dart';
import 'chatbot_widget.dart';

// ═══════════════════════════════════════════════════════
//  CONSTANTS
// ═══════════════════════════════════════════════════════
const _kBlue = Color(0xFF3A7DFF);
const _kGreen = Color(0xFF00C853);
const _kOrange = Color(0xFFFF6D00);
const _kPurple = Color(0xFF9C27B0);
const _kTeal = Color(0xFF00BCD4);
const _kDark = Color(0xFF1A1A2E);
const _kBg = Color(0xFFF0F2F8);

bool _isWide(BuildContext ctx) => MediaQuery.of(ctx).size.width > 800;

// ═══════════════════════════════════════════════════════
//  ENTRY POINT
// ═══════════════════════════════════════════════════════

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        if (data['role'] == 'super_admin') return const _SAShell();
        return _LAShell(adminData: data);
      },
    );
  }
}

// ═══════════════════════════════════════════════════════
//  SUPER ADMIN SHELL
// ═══════════════════════════════════════════════════════

class _SAShell extends StatefulWidget {
  const _SAShell();
  @override
  State<_SAShell> createState() => _SAShellState();
}

class _SAShellState extends State<_SAShell> {
  int _idx = 0;
  bool _collapsed = false;

  static const _items = [
    (Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    (Icons.verified_user_outlined, Icons.verified_user, 'Verifikime'),
    (Icons.manage_accounts_outlined, Icons.manage_accounts, 'Adminët'),
    (Icons.bar_chart_outlined, Icons.bar_chart, 'Rekorde'),
    (Icons.person_outline, Icons.person, 'Profili'),
  ];

  List<Widget> get _tabs => [
    const _SuperDashboard(),
    const _VerificationTab(lineId: null),
    const _LineAdminsTab(),
    const _RecordsTab(lineId: null),
    const _ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    if (wide) {
      return Scaffold(
        backgroundColor: _kBg,
        body: Row(children: [
          _Sidebar(title: 'Super Admin', subtitle: 'urbane.al', items: _items, idx: _idx, onSelect: (i) => setState(() => _idx = i), collapsed: _collapsed, onToggle: () => setState(() => _collapsed = !_collapsed)),
          Expanded(child: Stack(children: [
            _tabs[_idx],
            const ChatbotFloatingButton(isAdmin: true),
          ])),
        ]),
      );
    }
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(children: [
        _tabs[_idx],
        const ChatbotFloatingButton(isAdmin: true),
      ]),
      bottomNavigationBar: _BottomNav(idx: _idx, onTap: (i) => setState(() => _idx = i), items: _items),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  LINE ADMIN SHELL
// ═══════════════════════════════════════════════════════

class _LAShell extends StatefulWidget {
  final Map<String, dynamic> adminData;
  const _LAShell({required this.adminData});
  @override
  State<_LAShell> createState() => _LAShellState();
}

class _LAShellState extends State<_LAShell> {
  int _idx = 0;
  bool _collapsed = false;

  static const _items = [
    (Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    (Icons.badge_outlined, Icons.badge, 'Faturinot'),
    (Icons.bar_chart_outlined, Icons.bar_chart, 'Rekorde'),
    (Icons.person_outline, Icons.person, 'Profili'),
  ];

  @override
  Widget build(BuildContext context) {
    final lineId = widget.adminData['line_id'] as String?;
    final lineName = widget.adminData['line_name'] as String? ?? 'Linja';
    final wide = _isWide(context);
    final tabs = [
      _LineAdminDashboard(lineId: lineId, lineName: lineName),
      _FatorinosTab(lineId: lineId),
      _RecordsTab(lineId: lineId),
      const _ProfileTab(),
    ];
    if (wide) {
      return Scaffold(
        backgroundColor: _kBg,
        body: Row(children: [
          _Sidebar(title: lineName, subtitle: 'Line Admin', items: _items, idx: _idx, onSelect: (i) => setState(() => _idx = i), collapsed: _collapsed, onToggle: () => setState(() => _collapsed = !_collapsed)),
          Expanded(child: Stack(children: [
            tabs[_idx],
            const ChatbotFloatingButton(isAdmin: true),
          ])),
        ]),
      );
    }
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(children: [
        tabs[_idx],
        const ChatbotFloatingButton(isAdmin: true),
      ]),
      bottomNavigationBar: _BottomNav(idx: _idx, onTap: (i) => setState(() => _idx = i), items: _items),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  SIDEBAR
// ═══════════════════════════════════════════════════════

class _Sidebar extends StatelessWidget {
  final String title, subtitle;
  final List<(IconData, IconData, String)> items;
  final int idx;
  final ValueChanged<int> onSelect;
  final bool collapsed;
  final VoidCallback onToggle;

  const _Sidebar({required this.title, required this.subtitle, required this.items, required this.idx, required this.onSelect, required this.collapsed, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: collapsed ? 70.0 : 230.0,
      color: _kDark,
      child: Column(children: [
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: _kBlue, borderRadius: BorderRadius.circular(9)), child: const Center(child: Text('🚌', style: TextStyle(fontSize: 16)))),
            if (!collapsed) ...[
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5), overflow: TextOverflow.ellipsis),
                Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ])),
            ],
            IconButton(onPressed: onToggle, icon: Icon(collapsed ? Icons.chevron_right : Icons.chevron_left, color: Colors.white38, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ]),
        ),
        const SizedBox(height: 28),
        ...items.asMap().entries.map((e) {
          final selected = idx == e.key;
          final (off, on, label) = e.value;
          return GestureDetector(
            onTap: () => onSelect(e.key),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 12, vertical: 10),
              decoration: BoxDecoration(color: selected ? _kBlue.withOpacity(0.18) : Colors.transparent, borderRadius: BorderRadius.circular(10), border: selected ? Border.all(color: _kBlue.withOpacity(0.4)) : null),
              child: Row(children: [
                Icon(selected ? on : off, color: selected ? Colors.white : Colors.white54, size: 19),
                if (!collapsed) ...[const SizedBox(width: 11), Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white60, fontWeight: selected ? FontWeight.bold : FontWeight.normal, fontSize: 13))],
              ]),
            ),
          );
        }),
        const Spacer(),
        GestureDetector(
          onTap: () async { await AuthService().logout(); if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MyApp())); },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 12, vertical: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.logout, color: Colors.red.shade300, size: 19),
              if (!collapsed) ...[const SizedBox(width: 11), Text('Dil', style: TextStyle(color: Colors.red.shade300, fontSize: 13))],
            ]),
          ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int idx;
  final ValueChanged<int> onTap;
  final List<(IconData, IconData, String)> items;
  const _BottomNav({required this.idx, required this.onTap, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))]),
      child: BottomNavigationBar(
        currentIndex: idx, onTap: onTap, type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white, selectedItemColor: _kBlue, unselectedItemColor: Colors.grey, elevation: 0,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: items.map((e) => BottomNavigationBarItem(icon: Icon(e.$1), activeIcon: Icon(e.$2), label: e.$3)).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  SUPER ADMIN DASHBOARD
// ═══════════════════════════════════════════════════════

class _SuperDashboard extends StatelessWidget {
  const _SuperDashboard();

  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    final pad = wide ? 28.0 : 16.0;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Header
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Dashboard', style: TextStyle(fontSize: wide ? 26 : 20, fontWeight: FontWeight.bold, color: _kDark)),
              const Text('Pasqyra e plotë e sistemit', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ]),
            _TopBarActions(),
          ]),

          SizedBox(height: pad),

          // ── KPI CARDS ──
          _KpiRow(wide: wide),

          SizedBox(height: pad),

          // ── CHARTS ROW ──
          wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 5, child: _ValidationLineChart(lineId: null)),
                  const SizedBox(width: 16),
                  Expanded(flex: 3, child: _AboneDonutChart(lineId: null)),
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: _TopLinesCard()),
                ])
              : Column(children: [
                  _ValidationLineChart(lineId: null),
                  const SizedBox(height: 16),
                  _AboneDonutChart(lineId: null),
                  const SizedBox(height: 16),
                  _TopLinesCard(),
                ]),

          SizedBox(height: pad),

          // ── BOTTOM STATS ROW ──
          _BottomStatsRow(lineId: null, wide: wide),

          SizedBox(height: pad),

          // ── RECENT VALIDATIONS ──
          _RecentValidationsCard(lineId: null, wide: wide),

          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  KPI ROW
// ═══════════════════════════════════════════════════════

class _KpiRow extends StatelessWidget {
  final bool wide;
  const _KpiRow({required this.wide});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('abonements').snapshots(),
      builder: (_, aboneSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('tickets').snapshots(),
          builder: (_, ticketSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('validations').snapshots(),
              builder: (_, valSnap) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'passenger').snapshots(),
                  builder: (_, userSnap) {

                    // Calculate real stats
                    int totalRevenue = 0;
                    int activeAbonements = 0;
                    final now = DateTime.now();
                    if (aboneSnap.hasData) {
                      for (final doc in aboneSnap.data!.docs) {
                        final d = doc.data() as Map<String, dynamic>;
                        final price = (d['price_paid'] as num?)?.toInt() ?? 0;
                        totalRevenue += price;
                        final status = d['status'];
                        final validUntil = (d['valid_until'] as Timestamp?)?.toDate();
                        if (status == 'active' && validUntil != null && validUntil.isAfter(now)) activeAbonements++;
                      }
                    }
                    final totalTickets = ticketSnap.data?.docs.length ?? 0;
                    final totalValidations = valSnap.data?.docs.length ?? 0;
                    final totalUsers = userSnap.data?.docs.length ?? 0;

                    final int ticketRevenue = totalTickets * 50;
                    final int grandTotal = totalRevenue + ticketRevenue;

                    final cards = [
                      _KpiData('Të Ardhura Totale', '$grandTotal L', Icons.attach_money, _kGreen, '+Abone & Bileta'),
                      _KpiData('Bileta të Shitura', '$totalTickets', Icons.confirmation_number, _kBlue, '${totalTickets * 50} Lekë'),
                      _KpiData('Abone Aktive', '$activeAbonements', Icons.card_membership, _kPurple, 'Muaji aktual'),
                      _KpiData('Validime', '$totalValidations', Icons.qr_code_scanner, _kTeal, 'Gjithsej'),
                      _KpiData('Pasagjerë', '$totalUsers', Icons.people, _kOrange, 'Të regjistruar'),
                    ];

                    if (wide) {
                      return Row(children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: _KpiCard(data: c)))).toList());
                    }
                    return GridView.builder(
                      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.5),
                      itemCount: cards.length,
                      itemBuilder: (_, i) => _KpiCard(data: cards[i]),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _KpiData {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  const _KpiData(this.label, this.value, this.icon, this.color, this.sub);
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: data.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(data.icon, color: data.color, size: 20)),
          Icon(Icons.trending_up_rounded, color: _kGreen.withOpacity(0.7), size: 16),
        ]),
        const SizedBox(height: 14),
        Text(data.value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _kDark)),
        const SizedBox(height: 2),
        Text(data.label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(data.sub, style: TextStyle(color: data.color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  VALIDATION LINE CHART (last 30 days)
// ═══════════════════════════════════════════════════════

class _ValidationLineChart extends StatelessWidget {
  final String? lineId;
  const _ValidationLineChart({required this.lineId});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 29));
    Query q = FirebaseFirestore.instance.collection('validations')
        .where('validated_at', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    if (lineId != null) q = q.where('line_id', isEqualTo: lineId);

    return _Card(
      title: 'Validimet — 30 Ditët e Fundit',
      trailing: Row(children: [
        _Legend(_kBlue, 'Periudha aktuale'),
      ]),
      child: StreamBuilder<QuerySnapshot>(
        stream: q.snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
          final Map<int, int> byDay = {for (int i = 0; i < 30; i++) i: 0};
          for (final doc in snap.data!.docs) {
            final d = doc.data() as Map<String, dynamic>;
            final t = (d['validated_at'] as Timestamp?)?.toDate();
            if (t != null) {
              final daysAgo = now.difference(t).inDays;
              if (daysAgo >= 0 && daysAgo < 30) byDay[29 - daysAgo] = (byDay[29 - daysAgo] ?? 0) + 1;
            }
          }

          final spots = byDay.entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList();
          final maxY = byDay.values.fold(0, (a, b) => a > b ? a : b).toDouble();

          if (maxY == 0) {
            return const SizedBox(height: 180, child: Center(child: Text('Nuk ka të dhëna ende', style: TextStyle(color: Colors.grey))));
          }

          return SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 0 ? (maxY / 4).ceilToDouble() : 1,
                  getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, interval: maxY > 0 ? (maxY / 4).ceilToDouble() : 1,
                      getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(color: Colors.grey, fontSize: 10)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 7,
                      getTitlesWidget: (v, _) {
                        final date = from.add(Duration(days: v.toInt()));
                        return Padding(padding: const EdgeInsets.only(top: 6), child: Text('${date.day}/${date.month}', style: const TextStyle(color: Colors.grey, fontSize: 9)));
                      })),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: _kBlue,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: _kBlue.withOpacity(0.08)),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((s) => LineTooltipItem('${s.y.toInt()} validime', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))).toList(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  ABONE DONUT CHART
// ═══════════════════════════════════════════════════════

class _AboneDonutChart extends StatelessWidget {
  final String? lineId;
  const _AboneDonutChart({required this.lineId});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Abone sipas Kategorisë',
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('abonements').where('status', isEqualTo: 'active').snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
          int general = 0, student = 0, elderly = 0;
          int generalRev = 0, elderlyRev = 0;
          for (final doc in snap.data!.docs) {
            final d = doc.data() as Map<String, dynamic>;
            final price = (d['price_paid'] as num?)?.toInt() ?? 0;
            final cat = d['category'] ?? '';
            if (cat == 'general') { general++; generalRev += price; }
            if (cat == 'student') student++;
            if (cat == 'elderly') { elderly++; elderlyRev += price; }
          }
          final total = general + student + elderly;
          if (total == 0) return const SizedBox(height: 200, child: Center(child: Text('Nuk ka abone aktive', style: TextStyle(color: Colors.grey))));

          return Column(children: [
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 45,
                  sections: [
                    if (general > 0) PieChartSectionData(value: general.toDouble(), color: _kBlue, title: '${(general / total * 100).toStringAsFixed(0)}%', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    if (student > 0) PieChartSectionData(value: student.toDouble(), color: _kGreen, title: '${(student / total * 100).toStringAsFixed(0)}%', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    if (elderly > 0) PieChartSectionData(value: elderly.toDouble(), color: _kOrange, title: '${(elderly / total * 100).toStringAsFixed(0)}%', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _LegendRow(_kBlue, 'Gjenerale', general, generalRev),
            const SizedBox(height: 6),
            _LegendRow(_kGreen, 'Studentore', student, 0),
            const SizedBox(height: 6),
            _LegendRow(_kOrange, 'Senior', elderly, elderlyRev),
            const Divider(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('${generalRev + elderlyRev} Lekë', style: const TextStyle(fontWeight: FontWeight.bold, color: _kBlue, fontSize: 13)),
            ]),
          ]);
        },
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final int revenue;
  const _LegendRow(this.color, this.label, this.count, this.revenue);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 12)),
      const Spacer(),
      Text('$count abone', style: const TextStyle(color: Colors.grey, fontSize: 11)),
      if (revenue > 0) ...[
        const SizedBox(width: 8),
        Text('$revenue L', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
      ],
    ]);
  }
}

// ═══════════════════════════════════════════════════════
//  TOP LINES CARD
// ═══════════════════════════════════════════════════════

class _TopLinesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Linjat Kryesore',
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('bus_lines').snapshots(),
        builder: (_, linesSnap) {
          if (!linesSnap.hasData) return const _Loading();
          final lines = linesSnap.data!.docs;
          if (lines.isEmpty) return const _EmptyState(emoji: '🚌', label: 'Nuk ka linja');
          return Column(
            children: lines.take(6).toList().asMap().entries.map((e) {
              final lineDoc = e.value;
              final lineData = lineDoc.data() as Map<String, dynamic>;
              final rank = e.key + 1;
              final rankColors = [_kBlue, _kGreen, _kPurple, _kOrange, _kTeal, Colors.pink];
              final rankColor = rankColors[e.key % rankColors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('validations').where('line_id', isEqualTo: lineDoc.id).snapshots(),
                  builder: (_, valSnap) {
                    final count = valSnap.data?.docs.length ?? 0;
                    return Row(children: [
                      Container(width: 26, height: 26,
                          decoration: BoxDecoration(color: rankColor, borderRadius: BorderRadius.circular(8)),
                          child: Center(child: Text('$rank', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)))),
                      const SizedBox(width: 12),
                      Expanded(child: Text(lineData['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('$count validime', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kDark)),
                        Row(children: [
                          Icon(Icons.arrow_upward, size: 10, color: _kGreen),
                          Text(' aktive', style: TextStyle(color: _kGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                        ]),
                      ]),
                    ]);
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  BOTTOM STATS ROW (validation bar chart by hour)
// ═══════════════════════════════════════════════════════

class _BottomStatsRow extends StatelessWidget {
  final String? lineId;
  final bool wide;
  const _BottomStatsRow({required this.lineId, required this.wide});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Validimet sipas Orës — Sot',
      child: StreamBuilder<QuerySnapshot>(
        stream: () {
          final now = DateTime.now();
          final start = DateTime(now.year, now.month, now.day);
          Query q = FirebaseFirestore.instance.collection('validations')
              .where('validated_at', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
          if (lineId != null) q = q.where('line_id', isEqualTo: lineId);
          return q.snapshots();
        }(),
        builder: (_, snap) {
          if (!snap.hasData) return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
          final docs = snap.data!.docs;
          final Map<int, int> byHour = {for (int i = 5; i <= 22; i++) i: 0};
          for (final doc in docs) {
            final d = doc.data() as Map<String, dynamic>;
            final t = (d['validated_at'] as Timestamp?)?.toDate();
            if (t != null && t.hour >= 5 && t.hour <= 22) byHour[t.hour] = (byHour[t.hour] ?? 0) + 1;
          }
          final maxY = byHour.values.fold(0, (a, b) => a > b ? a : b).toDouble();
          final currentHour = DateTime.now().hour;

          if (docs.isEmpty) {
            return const SizedBox(height: 160, child: Center(child: Text('Nuk ka validime sot ende', style: TextStyle(color: Colors.grey))));
          }

          return SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxY + 1,
                gridData: FlGridData(show: true, drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
                      getTitlesWidget: (v, _) {
                        final h = v.toInt();
                        if (h % 3 != 0) return const SizedBox();
                        return Padding(padding: const EdgeInsets.only(top: 6), child: Text('$h', style: const TextStyle(fontSize: 10, color: Colors.grey)));
                      })),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
                      getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey)))),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: byHour.entries.map((e) => BarChartGroupData(
                  x: e.key,
                  barRods: [BarChartRodData(
                    toY: e.value.toDouble(),
                    color: e.key == currentHour ? _kBlue : _kBlue.withOpacity(0.25),
                    width: 14,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  )],
                )).toList(),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (g, gi, r, ri) => BarTooltipItem('${g.x}:00\n${r.toY.toInt()} validime', const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  RECENT VALIDATIONS TABLE
// ═══════════════════════════════════════════════════════

class _RecentValidationsCard extends StatelessWidget {
  final String? lineId;
  final bool wide;
  const _RecentValidationsCard({required this.lineId, required this.wide});

  @override
  Widget build(BuildContext context) {
    Query q = FirebaseFirestore.instance.collection('validations').orderBy('validated_at', descending: true);
    if (lineId != null) q = q.where('line_id', isEqualTo: lineId);

    return _Card(
      title: 'Validimet e Fundit',
      child: StreamBuilder<QuerySnapshot>(
        stream: q.limit(8).snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const _Loading();
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const _EmptyState(emoji: '📋', label: 'Nuk ka rekorde');

          if (wide) {
            return Table(
              columnWidths: const {0: FlexColumnWidth(2.5), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2), 3: FlexColumnWidth(1.2), 4: FlexColumnWidth(1.8)},
              children: [
                TableRow(
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEF0F4), width: 2))),
                  children: ['Pasagjeri', 'Linja', 'Stacioni', 'Lloji', 'Koha'].map((h) =>
                    Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(h, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)))).toList(),
                ),
                ...docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final t = (data['validated_at'] as Timestamp?)?.toDate();
                  final timeStr = t != null ? '${t.day}/${t.month} ${t.hour}:${t.minute.toString().padLeft(2, '0')}' : '-';
                  final isAbone = (data['type'] ?? '') == 'abone';
                  return TableRow(
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF7F8FA)))),
                    children: [
                      Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: _PassengerName(userId: data['user_id'])),
                      Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(data['line_name'] ?? '-', style: const TextStyle(fontSize: 13))),
                      Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(data['station_name'] ?? '-', style: const TextStyle(fontSize: 13, color: Colors.grey))),
                      Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: isAbone ? _kBlue.withOpacity(0.1) : _kOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(isAbone ? 'Abone' : 'Biletë', style: TextStyle(color: isAbone ? _kBlue : _kOrange, fontSize: 11, fontWeight: FontWeight.bold)),
                      )),
                      Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(timeStr, style: const TextStyle(fontSize: 12, color: Colors.grey))),
                    ],
                  );
                }),
              ],
            );
          }

          return Column(children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final t = (data['validated_at'] as Timestamp?)?.toDate();
            final timeStr = t != null ? '${t.day}/${t.month} ${t.hour}:${t.minute.toString().padLeft(2, '0')}' : '-';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: _kBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.qr_code_scanner, color: _kBlue, size: 18)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _PassengerName(userId: data['user_id']),
                  Text('${data['line_name'] ?? '-'} • $timeStr', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ])),
              ]),
            );
          }).toList());
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  LINE ADMIN DASHBOARD
// ═══════════════════════════════════════════════════════

class _LineAdminDashboard extends StatelessWidget {
  final String? lineId;
  final String lineName;
  const _LineAdminDashboard({required this.lineId, required this.lineName});

  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    final pad = wide ? 28.0 : 16.0;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (_, snap) {
            final d = snap.data?.data() as Map<String, dynamic>? ?? {};
            final rawN = '${d['name'] ?? ''} ${d['surname'] ?? ''}'.trim();
            final name = rawN.split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');
            final hour = DateTime.now().hour;
            final greeting = hour < 12 ? 'Mirëmëngjes' : hour < 17 ? 'Mirëdita' : hour < 21 ? 'Mirëmbrëma' : 'Përshëndetje';
            final first = name.isNotEmpty ? name.split(' ').first : 'Admin';

            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$greeting, $first!', style: TextStyle(fontSize: wide ? 24 : 20, fontWeight: FontWeight.bold, color: _kDark)),
                  Text('Linja: $lineName', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ]),
                _TopBarActions(),
              ]),

              SizedBox(height: pad),

              // KPIs for line admin
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('validations').where('line_id', isEqualTo: lineId).snapshots(),
                builder: (_, valSnap) {
                  final total = valSnap.data?.docs.length ?? 0;
                  final now = DateTime.now();
                  final todayCount = valSnap.data?.docs.where((doc) {
                    final t = ((doc.data() as Map<String, dynamic>)['validated_at'] as Timestamp?)?.toDate();
                    return t != null && t.year == now.year && t.month == now.month && t.day == now.day;
                  }).length ?? 0;

                  final cards = [
                    _KpiData('Validime Sot', '$todayCount', Icons.today, _kBlue, 'Dita aktuale'),
                    _KpiData('Validime Totale', '$total', Icons.bar_chart, _kPurple, 'Gjithsej'),
                  ];

                  return Row(children: cards.asMap().entries.map((e) => Expanded(child: Padding(padding: EdgeInsets.only(right: e.key == cards.length - 1 ? 0 : 12), child: _KpiCard(data: e.value)))).toList());
                },
              ),

              SizedBox(height: pad),

              wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(flex: 3, child: _ValidationLineChart(lineId: lineId)),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _AboneDonutChart(lineId: lineId)),
                    ])
                  : Column(children: [
                      _ValidationLineChart(lineId: lineId),
                      const SizedBox(height: 16),
                      _AboneDonutChart(lineId: lineId),
                    ]),

              SizedBox(height: pad),
              _BottomStatsRow(lineId: lineId, wide: wide),
              SizedBox(height: pad),
              _RecentValidationsCard(lineId: lineId, wide: wide),
              const SizedBox(height: 24),
            ]);
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  RECORDS TAB
// ═══════════════════════════════════════════════════════

class _RecordsTab extends StatefulWidget {
  final String? lineId;
  const _RecordsTab({required this.lineId});
  @override
  State<_RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<_RecordsTab> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 7));
  DateTime _to = DateTime.now();
  String _groupBy = 'hour';

  Future<void> _pickDate(BuildContext context, bool isFrom) async {
    final picked = await showDatePicker(
      context: context, initialDate: isFrom ? _from : _to, firstDate: DateTime(2024), lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: _kBlue)), child: child!),
    );
    if (picked != null) setState(() => isFrom ? _from = picked : _to = picked);
  }

  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    final fromTs = Timestamp.fromDate(DateTime(_from.year, _from.month, _from.day));
    final toTs = Timestamp.fromDate(DateTime(_to.year, _to.month, _to.day, 23, 59, 59));
    Query q = FirebaseFirestore.instance.collection('validations')
        .where('validated_at', isGreaterThanOrEqualTo: fromTs)
        .where('validated_at', isLessThanOrEqualTo: toTs);
    if (widget.lineId != null) q = q.where('line_id', isEqualTo: widget.lineId);

    final groupOptions = [
      if (widget.lineId == null) ('line', 'Linja'),
      ('hour', 'Ora'),
      ('day', 'Dita'),
      ('station', 'Stacioni'),
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(wide ? 28 : 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Rekorde & Statistika', style: TextStyle(fontSize: wide ? 24 : 20, fontWeight: FontWeight.bold, color: _kDark)),
          const Text('Filtro dhe analizo të dhënat', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 20),

          // Filter bar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
            child: Wrap(spacing: 10, runSpacing: 10, children: [
              GestureDetector(onTap: () => _pickDate(context, true), child: _FilterChip(label: '${_from.day}/${_from.month}/${_from.year}', icon: Icons.calendar_today)),
              const Text('→', style: TextStyle(color: Colors.grey, fontSize: 16)),
              GestureDetector(onTap: () => _pickDate(context, false), child: _FilterChip(label: '${_to.day}/${_to.month}/${_to.year}', icon: Icons.calendar_today)),
              ...groupOptions.map((e) => GestureDetector(
                onTap: () => setState(() => _groupBy = e.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: _groupBy == e.$1 ? _kBlue : Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                  child: Text(e.$2, style: TextStyle(color: _groupBy == e.$1 ? Colors.white : Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              )),
            ]),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: q.limit(500).snapshots(),
              builder: (_, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs;
                if (docs.isEmpty) return const _EmptyState(emoji: '📊', label: 'Nuk ka rekorde për këtë interval');

                final Map<String, int> groups = {};
                for (final doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  String key = '';
                  if (_groupBy == 'hour') { final t = (data['validated_at'] as Timestamp?)?.toDate(); key = t != null ? '${t.hour}:00' : '-'; }
                  else if (_groupBy == 'day') { final t = (data['validated_at'] as Timestamp?)?.toDate(); key = t != null ? '${t.day}/${t.month}' : '-'; }
                  else if (_groupBy == 'line') key = data['line_name'] ?? 'E panjohur';
                  else if (_groupBy == 'station') key = data['station_name'] ?? 'E panjohur';
                  if (key.isNotEmpty) groups[key] = (groups[key] ?? 0) + 1;
                }

                final sorted = groups.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                final maxVal = sorted.isEmpty ? 1.0 : sorted.first.value.toDouble();

                return _Card(
                  title: '${docs.length} validime gjithsej',
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final e = sorted[i];
                      return Row(children: [
                        SizedBox(width: 70, child: Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 10),
                        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(value: e.value / maxVal, backgroundColor: _kBlue.withOpacity(0.1), color: _kBlue, minHeight: 14))),
                        const SizedBox(width: 10),
                        Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.bold, color: _kBlue, fontSize: 13)),
                      ]);
                    },
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  VERIFICATION TAB
// ═══════════════════════════════════════════════════════

class _VerificationTab extends StatelessWidget {
  final String? lineId;
  const _VerificationTab({required this.lineId});

  Future<void> _approve(BuildContext context, DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final category = data['category'] ?? 'general';
    await FirebaseFirestore.instance.collection('abonements').doc(doc.id).update({
      'status': category == 'student' ? 'active' : 'approved_for_payment',
      'verified_by': FirebaseAuth.instance.currentUser?.uid,
      'verified_at': FieldValue.serverTimestamp(),
    });
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aprovuar ✓'), backgroundColor: _kGreen));
  }

  Future<void> _reject(BuildContext context, String docId) async {
    await FirebaseFirestore.instance.collection('abonements').doc(docId).update({'status': 'rejected', 'verified_by': FirebaseAuth.instance.currentUser?.uid, 'verified_at': FieldValue.serverTimestamp()});
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refuzuar.'), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(wide ? 28 : 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Verifikime', style: TextStyle(fontSize: wide ? 24 : 20, fontWeight: FontWeight.bold, color: _kDark)),
          const Text('Aplikimet për abone studentore dhe senior', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('abonements').where('status', isEqualTo: 'pending_verification').orderBy('created_at', descending: true).snapshots(),
              builder: (_, snap) {
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) return const _EmptyState(emoji: '✅', label: 'Nuk ka aplikime në pritje');
                return wide
                    ? GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 380, childAspectRatio: 0.9, crossAxisSpacing: 16, mainAxisSpacing: 16),
                        itemCount: docs.length,
                        itemBuilder: (_, i) => _VerifCard(doc: docs[i], onApprove: _approve, onReject: _reject),
                      )
                    : ListView.separated(
                        itemCount: docs.length, separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _VerifCard(doc: docs[i], onApprove: _approve, onReject: _reject),
                      );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _VerifCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final Future<void> Function(BuildContext, DocumentSnapshot) onApprove;
  final Future<void> Function(BuildContext, String) onReject;
  const _VerifCard({required this.doc, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final imageUrl = data['verification_image_url'] as String?;
    final category = data['category'] ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(data['user_id']).get(),
          builder: (_, snap) {
            String name = 'I panjohur';
            if (snap.hasData && snap.data!.exists) { final u = snap.data!.data() as Map<String, dynamic>; name = '${u['name'] ?? ''} ${u['surname'] ?? ''}'.trim(); }
            return Row(children: [
              CircleAvatar(backgroundColor: const Color(0xFFE8F0FF), child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(fontWeight: FontWeight.bold, color: _kBlue))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(category == 'student' ? 'Abone Studentore (Falas)' : 'Abone Senior (800 Lekë)', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ])),
            ]);
          },
        ),
        if (imageUrl != null && imageUrl.isNotEmpty) ...[
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(imageUrl, height: 140, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 60, color: Colors.grey.shade100, child: const Center(child: Text('Foto nuk u ngarkua'))))),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => onReject(context, doc.id), style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.red.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text('Refuzo', style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.bold)))),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(onPressed: () => onApprove(context, doc), style: ElevatedButton.styleFrom(backgroundColor: _kGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Aprovo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  LINE ADMINS TAB
// ═══════════════════════════════════════════════════════

class _LineAdminsTab extends StatelessWidget {
  const _LineAdminsTab();

  void _showAdd(BuildContext context) {
    final n = TextEditingController(), s = TextEditingController(), e = TextEditingController(), p = TextEditingController();
    String? selLineId, selLineName;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      bool obs = true;
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Shto Admin Linje', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [Expanded(child: _DField(c: n, l: 'Emri')), const SizedBox(width: 10), Expanded(child: _DField(c: s, l: 'Mbiemri'))]),
          const SizedBox(height: 10), _DField(c: e, l: 'Email', t: TextInputType.emailAddress),
          const SizedBox(height: 10), _PField(c: p, obs: obs, toggle: () => setS(() => obs = !obs)),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('bus_lines').snapshots(), builder: (_, snap) {
            final lines = snap.data?.docs ?? [];
            return DropdownButtonFormField<String>(value: selLineId, decoration: InputDecoration(labelText: 'Linja', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              items: lines.map((d) => DropdownMenuItem(value: d.id, child: Text((d.data() as Map<String, dynamic>)['name'] ?? ''))).toList(),
              onChanged: (val) { setS(() { selLineId = val; selLineName = (lines.firstWhere((d) => d.id == val).data() as Map<String, dynamic>)['name']; }); });
          }),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anulo')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _kBlue), onPressed: () async {
            if (n.text.isEmpty || e.text.isEmpty || p.text.length < 6) return;
            Navigator.pop(ctx);
            try {
              await FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('createStaffAccount').call({'name': n.text.trim(), 'surname': s.text.trim(), 'email': e.text.trim(), 'password': p.text.trim(), 'role': 'line_admin', 'lineId': selLineId, 'lineName': selLineName});
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin u shtua ✓'), backgroundColor: _kGreen));
            } catch (err) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gabim: $err'), backgroundColor: Colors.red)); }
          }, child: const Text('Shto', style: TextStyle(color: Colors.white))),
        ],
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    return SafeArea(child: Padding(padding: EdgeInsets.all(wide ? 28 : 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Line Adminët', style: TextStyle(fontSize: wide ? 24 : 20, fontWeight: FontWeight.bold, color: _kDark)),
          const Text('Menaxho adminët e linjave', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ]),
        _PBtn(label: 'Shto Admin', icon: Icons.add, onTap: () => _showAdd(context)),
      ]),
      const SizedBox(height: 20),
      Expanded(child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'line_admin').snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const _EmptyState(emoji: '👤', label: 'Nuk ka line adminë');
          return wide
              ? GridView.builder(gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 340, childAspectRatio: 2.2, crossAxisSpacing: 14, mainAxisSpacing: 14), itemCount: docs.length, itemBuilder: (_, i) => _AdminCard(doc: docs[i]))
              : ListView.separated(itemCount: docs.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (_, i) => _AdminCard(doc: docs[i]));
        },
      )),
    ])));
  }
}

class _AdminCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _AdminCard({required this.doc});
  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final name = '${data['name'] ?? ''} ${data['surname'] ?? ''}'.trim();
    final isActive = (data['status'] ?? 'active') == 'active';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: isActive ? Colors.white : Colors.grey.shade50, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Row(children: [
        CircleAvatar(backgroundColor: isActive ? const Color(0xFFE8F0FF) : Colors.grey.shade100, child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(color: isActive ? _kBlue : Colors.grey, fontWeight: FontWeight.bold))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name.isNotEmpty ? name : 'Pa emër', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isActive ? _kDark : Colors.grey)),
          Text(data['email'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(data['line_name'] ?? 'Pa linjë', style: TextStyle(color: isActive ? _kBlue : Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
        ])),
        Switch(value: isActive, activeColor: _kBlue,
            onChanged: (val) => FirebaseFirestore.instance.collection('users').doc(doc.id).update({'status': val ? 'active' : 'inactive'})),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  FATURINOS TAB
// ═══════════════════════════════════════════════════════

class _FatorinosTab extends StatelessWidget {
  final String? lineId;
  const _FatorinosTab({required this.lineId});

  void _showAdd(BuildContext context) {
    final n = TextEditingController(), s = TextEditingController(), e = TextEditingController(), p = TextEditingController();
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      bool obs = true;
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Shto Faturino', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [Expanded(child: _DField(c: n, l: 'Emri')), const SizedBox(width: 10), Expanded(child: _DField(c: s, l: 'Mbiemri'))]),
          const SizedBox(height: 10), _DField(c: e, l: 'Email', t: TextInputType.emailAddress),
          const SizedBox(height: 10), _PField(c: p, obs: obs, toggle: () => setS(() => obs = !obs)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anulo')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _kBlue), onPressed: () async {
            if (n.text.isEmpty || e.text.isEmpty || p.text.length < 6) return;
            Navigator.pop(ctx);
            try {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              String? lineName;
              if (uid != null) { final d = await FirebaseFirestore.instance.collection('users').doc(uid).get(); lineName = (d.data() as Map<String, dynamic>?)?['line_name']; }
              final res = await FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('createStaffAccount').call({'name': n.text.trim(), 'surname': s.text.trim(), 'email': e.text.trim(), 'password': p.text.trim(), 'role': 'faturino', 'lineId': lineId, 'lineName': lineName});
              if (context.mounted) showDialog(context: context, builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text('Faturino u shtua ✓', style: TextStyle(fontWeight: FontWeight.bold)),
                content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Email: ${e.text.trim()}'),
                  const SizedBox(height: 8),
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFE8F0FF), borderRadius: BorderRadius.circular(8)),
                      child: Text(res.data['tempPassword'] ?? p.text, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 16, color: _kBlue))),
                ]),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
              ));
            } catch (err) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gabim: $err'), backgroundColor: Colors.red)); }
          }, child: const Text('Shto', style: TextStyle(color: Colors.white))),
        ],
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    Query q = FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'faturino');
    if (lineId != null) q = q.where('line_id', isEqualTo: lineId);
    return SafeArea(child: Padding(padding: EdgeInsets.all(wide ? 28 : 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Faturinot', style: TextStyle(fontSize: wide ? 24 : 20, fontWeight: FontWeight.bold, color: _kDark)),
          const Text('Personeli aktiv', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ]),
        _PBtn(label: 'Shto Faturino', icon: Icons.add, onTap: () => _showAdd(context)),
      ]),
      const SizedBox(height: 20),
      Expanded(child: StreamBuilder<QuerySnapshot>(
        stream: q.snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const _EmptyState(emoji: '👮', label: 'Nuk ka faturino');
          return ListView.separated(itemCount: docs.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (_, i) {
            final doc = docs[i]; final data = doc.data() as Map<String, dynamic>;
            final name = '${data['name'] ?? ''} ${data['surname'] ?? ''}'.trim();
            final isActive = (data['status'] ?? 'active') == 'active';
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
              child: Row(children: [
                CircleAvatar(backgroundColor: isActive ? const Color(0xFFE8F0FF) : Colors.grey.shade100, child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? _kBlue : Colors.grey))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name.isNotEmpty ? name : 'Pa emër', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(data['email'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('validations').where('faturino_id', isEqualTo: doc.id).snapshots(), builder: (_, s) => Text('${s.data?.docs.length ?? 0} validime', style: const TextStyle(color: Colors.grey, fontSize: 12))),
                ])),
                Switch(value: isActive, activeColor: _kBlue, onChanged: (val) => FirebaseFirestore.instance.collection('users').doc(doc.id).update({'status': val ? 'active' : 'inactive'})),
              ]),
            );
          });
        },
      )),
    ])));
  }
}

// ═══════════════════════════════════════════════════════
//  PROFILE TAB
// ═══════════════════════════════════════════════════════

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();
  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(padding: const EdgeInsets.all(24), child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (_, snap) {
          final data = snap.data?.data() as Map<String, dynamic>? ?? {};
          final rawN = '${data['name'] ?? ''} ${data['surname'] ?? ''}'.trim();
          final name = rawN.split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');
          final role = data['role'] ?? 'admin';
          final roleLabel = role == 'super_admin' ? 'Super Admin' : 'Line Admin — ${data['line_name'] ?? ''}';
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20)]),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 80, height: 80, decoration: const BoxDecoration(gradient: LinearGradient(colors: [_kBlue, Color(0xFF1A3AFF)]), shape: BoxShape.circle), child: const Center(child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 36))),
              const SizedBox(height: 14),
              Text(name.isNotEmpty ? name : 'Administrator', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(FirebaseAuth.instance.currentUser?.email ?? '', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFE8F0FF), borderRadius: BorderRadius.circular(20)), child: Text(roleLabel, style: const TextStyle(color: _kBlue, fontWeight: FontWeight.bold))),
              const SizedBox(height: 28),
              SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())), style: ElevatedButton.styleFrom(backgroundColor: _kBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: const Icon(Icons.lock_reset, color: Colors.white), label: const Text('Ndrysho fjalëkalimin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, height: 48, child: OutlinedButton.icon(onPressed: () async { await AuthService().logout(); if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MyApp())); }, style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.red.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: Icon(Icons.logout, color: Colors.red.shade400), label: Text('Dil nga llogaria', style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.bold)))),
            ]),
          );
        },
      )),
    )));
  }
}

// ═══════════════════════════════════════════════════════
//  SMALL SHARED WIDGETS
// ═══════════════════════════════════════════════════════

class _TopBarActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
        child: Row(children: [
          const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Text('${now.day}/${now.month}/${now.year}', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
      ),
    ]);
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _Card({required this.title, required this.child, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _kDark)),
          if (trailing != null) trailing!,
        ]),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 20, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 5),
    Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
  ]);
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _FilterChip({required this.label, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(10)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: _kBlue),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
    ]),
  );
}

class _PBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PBtn({required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 15, color: Colors.white),
    label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
    style: ElevatedButton.styleFrom(backgroundColor: _kBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
  );
}

class _PassengerName extends StatelessWidget {
  final String? userId;
  const _PassengerName({required this.userId});
  @override
  Widget build(BuildContext context) {
    if (userId == null) return const Text('I panjohur', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13));
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (_, snap) {
        if (!snap.hasData) return const Text('...', style: TextStyle(fontSize: 13));
        final d = snap.data!.data() as Map<String, dynamic>? ?? {};
        final name = '${d['name'] ?? ''} ${d['surname'] ?? ''}'.trim();
        return Text(name.isNotEmpty ? name : 'Pa emër', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13));
      },
    );
  }
}

class _DField extends StatelessWidget {
  final TextEditingController c;
  final String l;
  final TextInputType t;
  const _DField({required this.c, required this.l, this.t = TextInputType.text});
  @override
  Widget build(BuildContext context) => TextField(controller: c, keyboardType: t, decoration: InputDecoration(labelText: l, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)));
}

class _PField extends StatelessWidget {
  final TextEditingController c;
  final bool obs;
  final VoidCallback toggle;
  const _PField({required this.c, required this.obs, required this.toggle});
  @override
  Widget build(BuildContext context) => TextField(controller: c, obscureText: obs, decoration: InputDecoration(
    labelText: 'Fjalëkalimi', hintText: 'Min. 6 karaktere',
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    prefixIcon: const Icon(Icons.lock_outline, size: 18),
    suffixIcon: IconButton(icon: Icon(obs ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18), onPressed: toggle),
  ));
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
}

class _EmptyState extends StatelessWidget {
  final String emoji, label;
  const _EmptyState({required this.emoji, required this.label});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text(emoji, style: const TextStyle(fontSize: 48)),
    const SizedBox(height: 14),
    Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey)),
  ]));
}