import 'package:flutter/material.dart';
import '../database/history_database.dart';
import '../services/tournament_history_service.dart';
import 'tournament_home_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<HistoryEntry> _all = [];
  bool _loading = true;

  static const _tabs = ['All', 'Matches', 'Series', 'Tournaments'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      HistoryDatabase.loadAll(),
      TournamentHistoryService.loadSummaries(),
    ]);
    final local = results[0];
    final cloud = results[1];

    List<HistoryEntry> merged;
    if (cloud.isNotEmpty) {
      // Use Firestore as the source of truth for tournaments/series.
      // Keep local only for standalone matches to avoid duplicates.
      final localMatches = local.where((e) => e.type == 'match').toList();
      merged = [...localMatches, ...cloud];
    } else {
      merged = local;
    }
    merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (mounted) setState(() { _all = merged; _loading = false; });
  }

  List<HistoryEntry> _filter(String tab) {
    if (tab == 'All') return _all;
    if (tab == 'Matches') return _all.where((e) => e.type == 'match').toList();
    if (tab == 'Series') {
      return _all
          .where((e) =>
              e.type == 'series' ||
              e.type == 'triseries' ||
              e.type == 'multiformat')
          .toList();
    }
    if (tab == 'Tournaments') {
      return _all.where((e) => e.type == 'tournament').toList();
    }
    return _all;
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0D2B1E),
            title: const Text('Clear History',
                style: TextStyle(color: Colors.white)),
            content: const Text('Delete all history?\nThis cannot be undone.',
                style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white54))),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Clear All',
                      style: TextStyle(color: Colors.redAccent))),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    await Future.wait([
      HistoryDatabase.clear(),
      TournamentHistoryService.clearAll(),
    ]);
    if (mounted) setState(() => _all = []);
  }

  Future<void> _deleteEntry(HistoryEntry entry) async {
    if (entry.firestoreId != null) {
      await TournamentHistoryService.deleteById(entry.firestoreId!);
    } else {
      await HistoryDatabase.removeEntry(entry.id);
    }
    if (mounted) setState(() => _all.removeWhere((e) => e.id == entry.id));
  }

  Future<void> _openTournament(HistoryEntry entry) async {
    final fid = entry.firestoreId;
    if (fid == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
    );

    final tournament = await TournamentHistoryService.loadById(fid);
    if (!mounted) return;
    Navigator.pop(context); // dismiss loader

    if (tournament == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load tournament data.')));
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TournamentHomeScreen(
          tournament: tournament,
          firestoreId: fid,
          isResume: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B3A2D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B1E),
        title: const Text('History',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (_all.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined,
                  color: Colors.redAccent),
              tooltip: 'Clear all',
              onPressed: _clearAll,
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.greenAccent,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.greenAccent,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent))
          : TabBarView(
              controller: _tab,
              children: _tabs.map((t) => _buildList(_filter(t))).toList(),
            ),
    );
  }

  Widget _buildList(List<HistoryEntry> entries) {
    if (entries.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.history, color: Colors.white12, size: 64),
          SizedBox(height: 16),
          Text('No history yet',
              style: TextStyle(color: Colors.white38, fontSize: 16)),
          SizedBox(height: 6),
          Text("Play matches and they'll appear here",
              style: TextStyle(color: Colors.white24, fontSize: 13)),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildCard(entries[i]),
    );
  }

  Widget _buildCard(HistoryEntry entry) {
    final color = _typeColor(entry.type);
    final icon = _typeIcon(entry.type);
    final date = DateTime.fromMillisecondsSinceEpoch(entry.timestamp);
    final isTournament = entry.firestoreId != null;

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        decoration: BoxDecoration(
          color: Colors.red.shade900,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => _deleteEntry(entry),
      child: GestureDetector(
        onTap: isTournament ? () => _openTournament(entry) : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0D2B1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(entry.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(entry.format,
                        style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(entry.result,
                    style:
                        const TextStyle(color: Colors.greenAccent, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [
                  Text(_dateLabel(date),
                      style:
                          const TextStyle(color: Colors.white30, fontSize: 11)),
                  if (isTournament) ...const [
                    SizedBox(width: 8),
                    Text('Tap to view details',
                        style: TextStyle(
                            color: Colors.white24,
                            fontSize: 10,
                            fontStyle: FontStyle.italic)),
                  ],
                ]),
              ]),
            ),
            if (isTournament)
              const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
          ]),
        ),
      ),
    );
  }

  Color _typeColor(String type) => switch (type) {
        'match' => Colors.green.shade400,
        'series' => Colors.teal.shade400,
        'triseries' => Colors.indigo.shade400,
        'multiformat' => Colors.deepOrange.shade400,
        'tournament' => Colors.amber.shade500,
        _ => Colors.white54,
      };

  IconData _typeIcon(String type) => switch (type) {
        'match' => Icons.sports_cricket,
        'series' => Icons.replay,
        'triseries' => Icons.group,
        'multiformat' => Icons.view_list_rounded,
        'tournament' => Icons.emoji_events,
        _ => Icons.sports_cricket,
      };

  String _dateLabel(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}
