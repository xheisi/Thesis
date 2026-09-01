import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'services/notification_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'Tani';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} orë';
    if (diff.inDays < 7) return '${diff.inDays} ditë';
    final d = ts.toDate();
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text('Jo i kyçur')));

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: const Color(0xFF1A1A2E)),
        title: const Text('Njoftimet',
            style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () async {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) return;

              final unread = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('notifications')
                  .where('read', isEqualTo: false)
                  .get();

              final batch = FirebaseFirestore.instance.batch();

              for (final doc in unread.docs) {
                batch.update(doc.reference, {'read': true});
              }

              await batch.commit();
            },
            child: const Text(
              '✓',
              style: TextStyle(
                color: Color(0xFF3A7DFF),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users').doc(uid)
            .collection('notifications')
            .orderBy('created_at', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('🔔', style: TextStyle(fontSize: 56)),
                SizedBox(height: 14),
                Text('Nuk keni njoftime',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                SizedBox(height: 6),
                Text('Njoftimet tuaja do shfaqen këtu',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ]),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final isRead = data['read'] ?? false;
              final type = data['type'] ?? 'system';
              final color = NotificationService.colorForType(type);
              final icon = NotificationService.iconForType(type);
              final ts = data['created_at'] as Timestamp?;

              return _NotifItem(
                docId: doc.id,
                title: data['title'] ?? '',
                body: data['body'] ?? '',
                timeAgo: _timeAgo(ts),
                isRead: isRead,
                color: color,
                icon: icon,
              );
            },
          );
        },
      ),
    );
  }
}

class _NotifItem extends StatefulWidget {
  final String docId;
  final String title;
  final String body;
  final String timeAgo;
  final bool isRead;
  final Color color;
  final IconData icon;

  const _NotifItem({
    required this.docId,
    required this.title,
    required this.body,
    required this.timeAgo,
    required this.isRead,
    required this.color,
    required this.icon,
  });

  @override
  State<_NotifItem> createState() => _NotifItemState();
}

class _NotifItemState extends State<_NotifItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () async {
          if (!widget.isRead) await NotificationService.markRead(widget.docId);
        },
        onLongPress: () async {
          if (!widget.isRead) await NotificationService.markRead(widget.docId);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.isRead ? Colors.white : const Color(0xFFEEF4FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isRead ? Colors.transparent : widget.color.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(widget.isRead ? 0.03 : 0.07),
              blurRadius: 10,
            )],
          ),
          child: Row(children: [
            // Left icon
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, color: widget.color, size: 22),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title,
                style: TextStyle(
                  fontWeight: widget.isRead ? FontWeight.w500 : FontWeight.bold,
                  fontSize: 14,
                  color: const Color(0xFF1A1A2E),
                )),
              const SizedBox(height: 3),
              Text(widget.body,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(widget.timeAgo,
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ])),

            const SizedBox(width: 8),

            // Right side — unread dot normally, ✓ button on hover/always visible when unread
            if (!widget.isRead)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _hovered
                    ? Tooltip(
                        message: 'Shëno si të lexuar',
                        child: GestureDetector(
                          onTap: () => NotificationService.markRead(widget.docId),
                          child: Container(
                            key: const ValueKey('check'),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: widget.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.check, size: 16, color: widget.color),
                          ),
                        ),
                      )
                    : Container(
                        key: const ValueKey('dot'),
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: widget.color,
                          shape: BoxShape.circle,
                        ),
                      ),
              )
            else
              const Icon(Icons.check, size: 14, color: Colors.grey),
          ]),
        ),
      ),
    );
  }
}

// Unread count badge for bell icon
class UnreadNotifBadge extends StatelessWidget {
  final Widget child;
  const UnreadNotifBadge({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return child;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        if (count == 0) return child;
        return Stack(clipBehavior: Clip.none, children: [
          child,
          Positioned(
            right: -4, top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text('$count',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            ),
          ),
        ]);
      },
    );
  }
}
