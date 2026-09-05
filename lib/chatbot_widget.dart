import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;


class ChatbotFloatingButton extends StatefulWidget {
  final bool isAdmin;
  const ChatbotFloatingButton({super.key, this.isAdmin = false});

  @override
  State<ChatbotFloatingButton> createState() => _ChatbotFloatingButtonState();
}

class _ChatbotFloatingButtonState extends State<ChatbotFloatingButton> with TickerProviderStateMixin {
  bool _isOpen = false;
  bool _isExpanded = false;
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _bounceAnim = Tween<double>(begin: 0, end: 5).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    final chatW = _isExpanded
        ? (isWide ? 520.0 : MediaQuery.of(context).size.width * 0.92)
        : (isWide ? 360.0 : MediaQuery.of(context).size.width * 0.88);
    final chatH = _isExpanded ? 600.0 : 460.0;

    // ✅ FIX: bottom 90 on mobile (above bottom nav ~56px + 20 gap + 14 extra)
    // On web admin there's no bottom nav so just 20
    final bubbleBottom = isWide ? 20.0 : 90.0;
    final chatBottom = isWide ? 90.0 : 160.0;

    return Stack(
      children: [
        // Chat window
        if (_isOpen)
          Positioned(
            bottom: chatBottom,
            right: isWide ? 20 : 12,
            child: Material(
              color: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                width: chatW,
                height: chatH,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 30, offset: const Offset(0, 10))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _ChatWindow(
                    isAdmin: widget.isAdmin,
                    isExpanded: _isExpanded,
                    onClose: () => setState(() => _isOpen = false),
                    onToggleExpand: () => setState(() => _isExpanded = !_isExpanded),
                  ),
                ),
              ),
            ),
          ),

        // Floating bubble
        Positioned(
          bottom: bubbleBottom,
          right: isWide ? 20 : 12,
          child: AnimatedBuilder(
            animation: _bounceAnim,
            builder: (_, child) => Transform.translate(
              offset: _isOpen ? Offset.zero : Offset(0, -_bounceAnim.value),
              child: child,
            ),
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: () => setState(() {
                  _isOpen = !_isOpen;
                  if (_isOpen) _bounceCtrl.stop();
                  else _bounceCtrl.repeat(reverse: true);
                }),
                child: Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [Color(0xFF3A7DFF), Color(0xFF1A3AFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    boxShadow: [BoxShadow(color: const Color(0xFF3A7DFF).withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 5))],
                  ),
                  child: Center(
                    child: _isOpen
                        ? const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 26)
                        : ClipOval(child: Image.asset('assets/images/ubi_avatar.png',
                            width: 40, height: 40, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Text('🤖', style: TextStyle(fontSize: 24)))),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
//  CHAT WINDOW
// ═══════════════════════════════════════════════════════

class _ChatWindow extends StatefulWidget {
  final bool isAdmin, isExpanded;
  final VoidCallback onClose, onToggleExpand;
  const _ChatWindow({required this.isAdmin, required this.isExpanded, required this.onClose, required this.onToggleExpand});

  @override
  State<_ChatWindow> createState() => _ChatWindowState();
}

class _ChatWindowState extends State<_ChatWindow> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Msg> _msgs = [];
  bool _loading = false;

  static const apiKey = "YOUR_GROQ_API_KEY";

  @override
  void initState() {
    super.initState();
    _msgs.add(_Msg(
      text: widget.isAdmin
          ? 'Përshëndetje! Unë jam UBI 🤖\n\nMund të më pyesni për statistika, linja, validime dhe çdo gjë tjetër rreth sistemit.'
          : 'Përshëndetje! Unë jam UBI, asistenti dixhital i Urbane 🚌\n\nMund të më pyesni për:\n• Cilën linjë të merrni\n• Si blini biletë ose abone\n• Si funksionon QR-i\n• Stacionet e linjave',
      isBot: true,
      time: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  Future<String> _buildContext() async {
    final db = FirebaseFirestore.instance;
    final buf = StringBuffer();
    try {
      final lines = await db.collection('bus_lines').get();
      final stationsSnap = await db.collection('stations').get();

      buf.writeln('LINJAT E AUTOBUSËVE NË TIRANË:');
      for (final doc in lines.docs) {
        final d = doc.data();
        final lineName = d['name'] ?? doc.id;
        buf.writeln('- $lineName');

        // Stations have line_ids as array containing the bus_lines document ID
        final lineStations = stationsSnap.docs.where((s) {
          final sd = s.data();
          final lineIds = sd['line_ids'];
          if (lineIds is List) return lineIds.contains(doc.id);
          return false;
        }).map((s) => (s.data())['name'] ?? '').where((s) => s.isNotEmpty).join(', ');

        if (lineStations.isNotEmpty) buf.writeln('  Stacionet: $lineStations');
      }
    } catch (_) {}

    if (widget.isAdmin) {
      try {
        final allVal = await db.collection('validations').get();
        final allAbone = await db.collection('abonements').get();
        final passengers = await db.collection('users').where('role', isEqualTo: 'passenger').get();
        final tickets = await db.collection('tickets').get();

        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        final startOfWeek = now.subtract(const Duration(days: 7));

        // Count by time period
        int todayCount = 0, weekCount = 0;
        final Map<String, int> byLine = {};
        final Map<int, int> byHour = {};

        for (final doc in allVal.docs) {
          final d = doc.data();
          final t = (d['validated_at'] as Timestamp?)?.toDate();
          if (t != null) {
            if (t.isAfter(startOfDay)) { todayCount++; byHour[t.hour] = (byHour[t.hour] ?? 0) + 1; }
            if (t.isAfter(startOfWeek)) weekCount++;
          }
          final line = d['line_name'] as String?;
          if (line != null && line.isNotEmpty) byLine[line] = (byLine[line] ?? 0) + 1;
        }

        // Count abonements
        int active = 0, gen = 0, stu = 0, eld = 0, rev = 0;
        for (final doc in allAbone.docs) {
          final d = doc.data();
          final status = d['status'] ?? '';
          final validUntil = (d['valid_until'] as Timestamp?)?.toDate();
          if (status == 'active' && (validUntil == null || validUntil.isAfter(now))) {
            active++;
            final cat = d['category'] ?? '';
            final price = (d['price_paid'] as num?)?.toInt() ?? 0;
            if (cat == 'general') { gen++; rev += price; }
            if (cat == 'student') stu++;
            if (cat == 'elderly') { eld++; rev += price; }
          }
        }

        buf.writeln('\nSTATISTIKAT:');
        buf.writeln('- Validime totale: ${allVal.docs.length}');
        buf.writeln('- Validime sot: $todayCount');
        buf.writeln('- Validime 7 ditët e fundit: $weekCount');
        buf.writeln('- Abone aktive: $active (Gjenerale=$gen, Studentore=$stu, Senior=$eld)');
        buf.writeln('- Të ardhura nga abone: $rev Lekë');
        buf.writeln('- Bileta totale: ${tickets.docs.length} (${tickets.docs.length * 50} Lekë)');
        buf.writeln('- Pasagjerë: ${passengers.docs.length}');

        if (byLine.isNotEmpty) {
          final sorted = byLine.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          buf.writeln('\nVALIDIMET SIPAS LINJËS:');
          for (final e in sorted) buf.writeln('- ${e.key}: ${e.value} validime');
        } else {
          buf.writeln('\nShënim: Skanime ekzistojnë por pa emër linje të regjistruar.');
        }

        if (byHour.isNotEmpty) {
          final bh = byHour.entries.reduce((a, b) => a.value > b.value ? a : b);
          buf.writeln('Ora më e ngarkuar sot: ${bh.key}:00 (${bh.value} validime)');
        }
      } catch (e) {
        buf.writeln('\nGabim në leximin e statistikave: $e');
      }
    }
    return buf.toString();
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _ctrl.clear();
    setState(() { _msgs.add(_Msg(text: text.trim(), isBot: false, time: DateTime.now())); _loading = true; });
    _scrollDown();

    try {
      final ctx = await _buildContext();
      final sys = widget.isAdmin
          ? 'Ju jeni UBI, asistenti i sistemit Urbane të autobusëve të Tiranës. Ndihmoni administratorët me statistika. Përgjigjuni GJITHMONË në shqip, saktë dhe konciz (max 4 fjali). Mos shpikni të dhëna. Të dhënat e sistemit:\n\n$ctx'
          : 'Ju jeni UBI, asistenti i aplikacionit Urbane për autobusët e Tiranës. Ndihmoni pasagjerët. Përgjigjuni GJITHMONË në shqip, me mirësjellje, max 4 fjali.\n\nINFO APLIKACIONI:\n- Biletë: 50 Lekë, vlen 1 orë nga skanimi\n- Abone Gjenerale: 1600 Lekë/muaj\n- Abone Studentore: FALAS (kërkon verifikim kartë studenti)\n- Abone Senior 65+: 800 Lekë/muaj (kërkon verifikim ID)\n- Bli biletë: butoni "Bli Biletë" në ekranin kryesor\n- QR skaноhet nga faturino kur hipni në autobus\n\n$ctx';

      final history = _msgs.skip(_msgs.length > 8 ? _msgs.length - 8 : 0).map((m) => {'role': m.isBot ? 'assistant' : 'user', 'content': m.text}).toList();

      final res = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_groqKey'},
        body: jsonEncode({
          'model': 'openai/gpt-oss-20b',
          'max_tokens': 350,
          'temperature': 0.5,
          'messages': [{'role': 'system', 'content': sys}, ...history, {'role': 'user', 'content': text.trim()}],
        }),
      );

      String reply;
      if (res.statusCode == 200) {
        reply = (jsonDecode(utf8.decode(res.bodyBytes))['choices'][0]['message']['content'] as String).trim();
      } else {
        final errorBody = utf8.decode(res.bodyBytes);
        debugPrint('Groq error ${res.statusCode}: $errorBody');
        reply = 'Groq error ${res.statusCode}: $errorBody';
      }

      setState(() { _msgs.add(_Msg(text: reply, isBot: true, time: DateTime.now())); _loading = false; });
    } catch (e) {
      debugPrint('UBI catch error: $e');
      setState(() { _msgs.add(_Msg(text: 'Error: ${e.toString()}', isBot: true, time: DateTime.now())); _loading = false; });
    }
    _scrollDown();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF3A7DFF), Color(0xFF1A3AFF)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Row(children: [
          Container(width: 38, height: 38, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: ClipOval(child: Image.asset('assets/images/ubi_avatar.png',
                width: 38, height: 38, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(child: Text('🤖', style: TextStyle(fontSize: 19)))))),
          const SizedBox(width: 10),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('UBI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            Text('Asistenti dixhital i Urbane', style: TextStyle(color: Colors.white70, fontSize: 10)),
          ])),
          GestureDetector(onTap: widget.onToggleExpand, child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(7)), child: Icon(widget.isExpanded ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white, size: 16))),
          const SizedBox(width: 6),
          GestureDetector(onTap: widget.onClose, child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(7)), child: const Icon(Icons.close, color: Colors.white, size: 16))),
        ]),
      ),

      // Messages
      Expanded(
        child: Container(
          color: const Color(0xFFF5F7FA),
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(12),
            itemCount: _msgs.length + (_loading ? 1 : 0),
            itemBuilder: (_, i) => i == _msgs.length ? const _Dots() : _Bubble(msg: _msgs[i]),
          ),
        ),
      ),

      // Quick chips
      if (_msgs.length == 1)
        Container(
          color: const Color(0xFFF5F7FA),
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
          child: Wrap(spacing: 6, runSpacing: 5, children: (widget.isAdmin
              ? ['Validimet sot', 'Linja me pak validime', 'Ora më e ngarkuar', 'Sa abone studentore?']
              : ['Cilën linjë të marr?', 'Si blej biletë?', 'Çfarë është abonja?', 'Si funksionon QR?']
          ).map((q) => GestureDetector(
            onTap: () => _send(q),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF3A7DFF).withOpacity(0.3))),
              child: Text(q, style: const TextStyle(color: Color(0xFF3A7DFF), fontSize: 11, fontWeight: FontWeight.w500)),
            ),
          )).toList()),
        ),

      // Input
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, -2))]),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              onSubmitted: _send,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Shkruaj kërkesën tënde...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                filled: true, fillColor: const Color(0xFFF5F7FA),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 7),
          GestureDetector(
            onTap: () => _send(_ctrl.text),
            child: Container(width: 38, height: 38, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF3A7DFF), Color(0xFF1A3AFF)]), shape: BoxShape.circle), child: const Icon(Icons.arrow_upward, color: Colors.white, size: 18)),
          ),
        ]),
      ),
    ]);
  }
}

class _Msg { final String text; final bool isBot; final DateTime time; const _Msg({required this.text, required this.isBot, required this.time}); }

class _Bubble extends StatelessWidget {
  final _Msg msg;
  const _Bubble({required this.msg});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: msg.isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (msg.isBot) Container(width: 28, height: 28, margin: const EdgeInsets.only(right: 7),
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          child: ClipOval(child: Image.asset('assets/images/ubi_avatar.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Center(child: Text('🤖', style: TextStyle(fontSize: 13)))))),
          Flexible(child: Column(
            crossAxisAlignment: msg.isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: msg.isBot ? Colors.white : const Color(0xFF3A7DFF),
                  borderRadius: BorderRadius.only(topLeft: const Radius.circular(14), topRight: const Radius.circular(14), bottomLeft: Radius.circular(msg.isBot ? 3 : 14), bottomRight: Radius.circular(msg.isBot ? 14 : 3)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                ),
                child: Text(msg.text, style: TextStyle(color: msg.isBot ? const Color(0xFF1A1A2E) : Colors.white, fontSize: 13, height: 1.4)),
              ),
              const SizedBox(height: 2),
              Text('${msg.time.hour}:${msg.time.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.grey, fontSize: 9)),
            ],
          )),
        ],
      ),
    );
  }
}

class _Dots extends StatefulWidget { const _Dots(); @override State<_Dots> createState() => _DotsState(); }
class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late AnimationController _c; late Animation<double> _a;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(); _a = Tween<double>(begin: 0, end: 1).animate(_c); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(width: 28, height: 28, margin: const EdgeInsets.only(right: 7),
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          child: ClipOval(child: Image.asset('assets/images/ubi_avatar.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Center(child: Text('🤖', style: TextStyle(fontSize: 13)))))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
          child: AnimatedBuilder(animation: _a, builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) {
            final phase = (_a.value + i * 0.33) % 1.0;
            final op = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
            return Container(margin: const EdgeInsets.symmetric(horizontal: 2), width: 6, height: 6, decoration: BoxDecoration(color: const Color(0xFF3A7DFF).withOpacity(0.3 + op * 0.7), shape: BoxShape.circle));
          }))),
        ),
      ]),
    );
  }
}