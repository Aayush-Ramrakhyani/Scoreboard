import 'package:flutter/material.dart';
import '../tournament_models.dart';
import '../saved_template.dart';
import '../services/template_service.dart';
import 'squad_entry.dart';
import 'tournament_home_screen.dart';

class MultiFormatSeriesSetupScreen extends StatefulWidget {
  final String? templateName;
  const MultiFormatSeriesSetupScreen({super.key, this.templateName});
  @override
  State<MultiFormatSeriesSetupScreen> createState() =>
      _MultiFormatSeriesSetupScreenState();
}

class _MultiFormatSeriesSetupScreenState
    extends State<MultiFormatSeriesSetupScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _t1Ctrl = TextEditingController(text: 'Team A');
  final _t2Ctrl = TextEditingController(text: 'Team B');

  // Segment builder state
  MatchFormat _addFormat = MatchFormat.t20;
  int _addCount = 3;
  int _addDays = 5;

  // Added segments (stored as simple records; FormatSegment built on Start)
  final List<({MatchFormat format, int count, int days})> _segments = [];

  late final List<PlayerSetupData> _squad1;
  late final List<PlayerSetupData> _squad2;

  static const _color = Color(0xFFE65100); // deep orange accent

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _squad1 = List.generate(18, (i) => PlayerSetupData('Player ${i + 1}'));
    _squad2 = List.generate(18, (i) => PlayerSetupData('Player ${i + 1}'));
  }

  @override
  void dispose() {
    _tab.dispose();
    _t1Ctrl.dispose();
    _t2Ctrl.dispose();
    for (final p in _squad1) { p.dispose(); }
    for (final p in _squad2) { p.dispose(); }
    super.dispose();
  }

  String _formatName(MatchFormat f) => switch (f) {
        MatchFormat.t10 => 'T10',
        MatchFormat.t20 => 'T20',
        MatchFormat.odi => 'ODI',
        MatchFormat.test => 'Test',
        _ => f.name.toUpperCase(),
      };

  void _addSegment() {
    setState(() {
      _segments.add((format: _addFormat, count: _addCount, days: _addDays));
    });
  }

  void _start() {
    final t1 = _t1Ctrl.text.trim();
    final t2 = _t2Ctrl.text.trim();
    if (t1.isEmpty || t2.isEmpty) {
      _snack('Enter both team names');
      return;
    }
    if (t1 == t2) {
      _snack('Team names must be different');
      return;
    }
    if (_segments.isEmpty) {
      _snack('Add at least one format series');
      return;
    }
    final e1 = validateSquad(_squad1, t1, min: 18, max: 21);
    if (e1 != null) { _snack(e1); return; }
    final e2 = validateSquad(_squad2, t2, min: 18, max: 21);
    if (e2 != null) { _snack(e2); return; }

    final p1 = _squad1.map((p) => p.toInfo()).toList();
    final p2 = _squad2.map((p) => p.toInfo()).toList();
    final state = MultiFormatSeriesState(
      teams: [TournamentTeam(name: t1, players: p1), TournamentTeam(name: t2, players: p2)],
      segments: _segments
          .map((s) => FormatSegment(format: s.format, matchCount: s.count, days: s.days, team1Name: t1, team2Name: t2))
          .toList(),
    );

    final tName = widget.templateName ?? '$t1 vs $t2 Tour';
    final now = DateTime.now().millisecondsSinceEpoch;
    TemplateService.save(SavedTemplate(
      id: TemplateService.newId(),
      name: tName,
      type: 'multiformat',
      teams: [TemplateTeam(name: t1, players: p1), TemplateTeam(name: t2, players: p2)],
      format: _segments.first.format,
      segments: _segments.map((s) => TemplateSegment(format: s.format, matchCount: s.count, days: s.days)).toList(),
      createdAt: now,
      updatedAt: now,
    ));

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/tournament'),
        builder: (_) => TournamentHomeScreen(
          tournament: MultiFormatSeriesHolder(state),
          customTitle: '$tName – Season 1',
        ),
      ),
    );
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _loadTeam(
      BuildContext ctx, TextEditingController nameCtrl, List<PlayerSetupData> squad) async {
    final team = await showTeamPickerSheet(ctx);
    if (team == null) return;
    applyTeamToSquad(team: team, squad: squad, nameCtrl: nameCtrl, setState: setState);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B3A2D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B1E),
        title: const Text('Multi-Format Series',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.deepOrangeAccent,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.deepOrangeAccent,
          tabs: [
            const Tab(text: 'Series Info'),
            Tab(text: _t1Ctrl.text.isEmpty ? 'Team 1' : _t1Ctrl.text),
            Tab(text: _t2Ctrl.text.isEmpty ? 'Team 2' : _t2Ctrl.text),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildInfo(),
          Column(children: [
            _teamHeader(_t1Ctrl, Colors.green.shade700, _squad1),
            Expanded(
                child: SquadEntryWidget(
                    players: _squad1,
                    accentColor: Colors.green.shade700,
                    onAddPlayer: _squad1.length < 21
                        ? () => setState(() => _squad1
                            .add(PlayerSetupData('Player ${_squad1.length + 1}')))
                        : null,
                    onRemovePlayer: _squad1.length > 18
                        ? (i) => setState(() {
                              _squad1[i].dispose();
                              _squad1.removeAt(i);
                            })
                        : null)),
          ]),
          Column(children: [
            _teamHeader(_t2Ctrl, Colors.blue.shade700, _squad2),
            Expanded(
                child: SquadEntryWidget(
                    players: _squad2,
                    accentColor: Colors.blue.shade700,
                    onAddPlayer: _squad2.length < 21
                        ? () => setState(() => _squad2
                            .add(PlayerSetupData('Player ${_squad2.length + 1}')))
                        : null,
                    onRemovePlayer: _squad2.length > 18
                        ? (i) => setState(() {
                              _squad2[i].dispose();
                              _squad2.removeAt(i);
                            })
                        : null)),
          ]),
        ],
      ),
    );
  }

  Widget _buildInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 12),
        _field(_t1Ctrl, 'Team 1 Name', Icons.groups),
        const SizedBox(height: 14),
        _field(_t2Ctrl, 'Team 2 Name', Icons.groups_2),
        const SizedBox(height: 24),

        // ── Segment builder ───────────────────────────────────────────────
        _label('ADD FORMAT SERIES'),
        const SizedBox(height: 10),
        _formatPicker(),
        const SizedBox(height: 14),
        if (_addFormat == MatchFormat.test) ...[
          _label('DAYS PER TEST'),
          const SizedBox(height: 8),
          _daysPicker(),
          const SizedBox(height: 14),
        ],
        _label('NUMBER OF MATCHES'),
        const SizedBox(height: 8),
        _countPicker(),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _addSegment,
          icon: const Icon(Icons.add, color: Colors.deepOrangeAccent),
          label: Text(
            'Add $_addCount × ${_formatName(_addFormat)}${_addFormat == MatchFormat.test ? " ($_addDays-day)" : ""}',
            style: const TextStyle(color: Colors.deepOrangeAccent),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.deepOrangeAccent),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),

        // ── Added segments list ───────────────────────────────────────────
        if (_segments.isNotEmpty) ...[
          const SizedBox(height: 20),
          _label('SERIES SCHEDULE'),
          const SizedBox(height: 10),
          ..._segments.asMap().entries.map((e) => _segmentChip(e.key, e.value)),
        ],

        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _segments.isEmpty ? null : _start,
          style: ElevatedButton.styleFrom(
            backgroundColor: _color,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.white12,
            padding: const EdgeInsets.symmetric(vertical: 18),
            textStyle:
                const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Start Multi-Format Series'),
        ),
      ]),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: Colors.white54,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5));

  Widget _formatPicker() {
    const formats = [
      (MatchFormat.t10, 'T10', '10 overs'),
      (MatchFormat.t20, 'T20', '20 overs'),
      (MatchFormat.odi, 'ODI', '50 overs'),
      (MatchFormat.test, 'Test', '2 innings'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: formats.map((f) {
        final sel = _addFormat == f.$1;
        return GestureDetector(
          onTap: () => setState(() {
            _addFormat = f.$1;
            _addCount = f.$1 == MatchFormat.test ? 2 : 3;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: sel
                  ? Colors.deepOrange.shade700.withValues(alpha:0.4)
                  : const Color(0xFF0D2B1E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: sel ? Colors.deepOrangeAccent : Colors.white24),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.$2,
                      style: TextStyle(
                          color: sel ? Colors.white : Colors.white70,
                          fontWeight: sel
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13)),
                  Text(f.$3,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _daysPicker() {
    return Row(
      children: [3, 4, 5].map((d) {
        final sel = _addDays == d;
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: () => setState(() => _addDays = d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: sel
                    ? Colors.deepOrange.shade700
                    : const Color(0xFF0D2B1E),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: sel ? Colors.deepOrangeAccent : Colors.white24),
              ),
              child: Text('$d days',
                  style: TextStyle(
                      color: sel ? Colors.white : Colors.white60,
                      fontWeight:
                          sel ? FontWeight.bold : FontWeight.normal)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _countPicker() {
    final options =
        _addFormat == MatchFormat.test ? [1, 2, 3, 4, 5] : [1, 2, 3, 4, 5, 7];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((n) {
        final sel = _addCount == n;
        return GestureDetector(
          onTap: () => setState(() => _addCount = n),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: sel
                  ? Colors.deepOrange.shade700
                  : const Color(0xFF0D2B1E),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: sel ? Colors.deepOrangeAccent : Colors.white24),
            ),
            child: Text('$n',
                style: TextStyle(
                    color: sel ? Colors.white : Colors.white60,
                    fontWeight:
                        sel ? FontWeight.bold : FontWeight.normal,
                    fontSize: 15)),
          ),
        );
      }).toList(),
    );
  }

  Widget _segmentChip(
      int idx, ({MatchFormat format, int count, int days}) seg) {
    final fmt = _formatName(seg.format);
    final extra = seg.format == MatchFormat.test ? ' · ${seg.days}-day' : '';
    final label = '${seg.count} × $fmt$extra';
    final colors = {
      MatchFormat.t10: Colors.purple.shade700,
      MatchFormat.t20: Colors.teal.shade700,
      MatchFormat.odi: Colors.blue.shade700,
      MatchFormat.test: Colors.brown.shade600,
      MatchFormat.hundred: Colors.amber.shade700,
    };
    final c = colors[seg.format] ?? Colors.grey.shade700;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha:0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha:0.5)),
      ),
      child: Row(children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: c.withValues(alpha:0.7),
              borderRadius: BorderRadius.circular(6)),
          child: Text(fmt,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ),
        GestureDetector(
          onTap: () => setState(() => _segments.removeAt(idx)),
          child: const Icon(Icons.close, color: Colors.white38, size: 18),
        ),
      ]),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: Colors.deepOrangeAccent),
        enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.deepOrange.shade700),
            borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
            borderSide:
                const BorderSide(color: Colors.deepOrangeAccent, width: 2),
            borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: const Color(0xFF0D2B1E),
      ),
    );
  }

  Widget _teamHeader(TextEditingController ctrl, Color color, List<PlayerSetupData> squad) =>
      ValueListenableBuilder(
        valueListenable: ctrl,
        builder: (ctx, __, ___) => Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          color: color.withValues(alpha: 0.3),
          child: Row(children: [
            Expanded(
              child: Text(
                ctrl.text.isEmpty ? 'Team' : ctrl.text,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.file_download_outlined, size: 15),
              label: const Text('Load', style: TextStyle(fontSize: 12)),
              onPressed: () => _loadTeam(ctx, ctrl, squad),
            ),
          ]),
        ),
      );
}
