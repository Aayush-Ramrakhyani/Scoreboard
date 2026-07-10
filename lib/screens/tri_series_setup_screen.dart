import 'package:flutter/material.dart';
import '../tournament_models.dart';
import 'squad_entry.dart';
import 'tournament_home_screen.dart';

class TriSeriesSetupScreen extends StatefulWidget {
  const TriSeriesSetupScreen({super.key});
  @override
  State<TriSeriesSetupScreen> createState() => _TriSeriesSetupScreenState();
}

class _TriSeriesSetupScreenState extends State<TriSeriesSetupScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _names = [
    TextEditingController(text: 'Team A'),
    TextEditingController(text: 'Team B'),
    TextEditingController(text: 'Team C'),
  ];
  MatchFormat _format = MatchFormat.t20;
  late final List<List<PlayerSetupData>> _squads;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _squads = List.generate(
        3, (_) => List.generate(18, (i) => PlayerSetupData('Player ${i + 1}')));
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final c in _names) {
      c.dispose();
    }
    for (final sq in _squads) {
      for (final p in sq) {
        p.dispose();
      }
    }
    super.dispose();
  }

  void _start() {
    final names = _names.map((c) => c.text.trim()).toList();
    if (names.any((n) => n.isEmpty)) { _snack('Enter all three team names'); return; }
    for (int i = 0; i < 3; i++) {
      final err = validateSquad(_squads[i], names[i], min: 18, max: 21);
      if (err != null) { _snack(err); return; }
    }
    final overs = switch (_format) {
      MatchFormat.t10 => 10,
      MatchFormat.t20 => 20,
      MatchFormat.odi => 50,
      _ => 20,
    };
    final state = TriSeriesState(
      teams: List.generate(3, (i) => TournamentTeam(
        name: names[i],
        players: _squads[i].map((p) => p.toInfo()).toList(),
      )),
      overs: overs,
      format: _format,
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/tournament'),
        builder: (_) => TournamentHomeScreen(tournament: TriSeriesHolder(state)),
      ),
    );
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B3A2D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B1E),
        title: const Text('Tri-Series Setup',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.indigoAccent,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.indigoAccent,
          tabs: [
            const Tab(text: 'Info'),
            Tab(text: _names[0].text.isEmpty ? 'Team 1' : _names[0].text),
            Tab(text: _names[1].text.isEmpty ? 'Team 2' : _names[1].text),
            Tab(text: _names[2].text.isEmpty ? 'Team 3' : _names[2].text),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildInfo(),
          ...[0, 1, 2].map((i) {
            final sq = _squads[i];
            final accent = [
              Colors.green.shade700,
              Colors.blue.shade700,
              Colors.purple.shade700,
            ][i];
            return Column(children: [
              _teamHeader(_names[i], accent),
              Expanded(
                  child: SquadEntryWidget(
                      players: sq,
                      accentColor: accent,
                      onAddPlayer: sq.length < 21
                          ? () => setState(
                              () => sq.add(PlayerSetupData('Player ${sq.length + 1}')))
                          : null,
                      onRemovePlayer: sq.length > 18
                          ? (idx) => setState(() {
                                sq[idx].dispose();
                                sq.removeAt(idx);
                              })
                          : null)),
            ]);
          }),
        ],
      ),
    );
  }

  Widget _buildInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 12),
        _infoCard(),
        const SizedBox(height: 20),
        ...[0, 1, 2].map((i) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _field(_names[i], 'Team ${i + 1} Name', Icons.groups),
            )),
        _formatPicker(),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _start,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Start Tri-Series'),
        ),
      ]),
    );
  }

  Widget _infoCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.indigo.shade900.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.indigoAccent.withOpacity(0.3)),
        ),
        child: const Text(
          '• 3 teams · each pair plays twice = 6 league matches\n'
          '• Points: Win = 2, Tie = 1, Loss = 0\n'
          '• Tiebreaker: Net Run Rate\n'
          '• Top 2 teams play the Final',
          style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.6),
        ),
      );

  Widget _formatPicker() {
    const formats = [
      (MatchFormat.t10, 'T10', '10 overs'),
      (MatchFormat.t20, 'T20', '20 overs'),
      (MatchFormat.odi, 'ODI', '50 overs'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('MATCH FORMAT',
            style: TextStyle(color: Colors.white54, fontSize: 10,
                fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: formats.map((f) {
            final sel = _format == f.$1;
            return GestureDetector(
              onTap: () => setState(() => _format = f.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? Colors.indigo.shade700.withOpacity(0.5) : const Color(0xFF0D2B1E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? Colors.indigoAccent : Colors.white24),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.$2, style: TextStyle(
                      color: sel ? Colors.white : Colors.white70,
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13)),
                  Text(f.$3, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ]),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool numeric = false}) {
    return TextField(
      controller: ctrl,
      onChanged: (_) => setState(() {}),
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: Colors.indigoAccent),
        enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.indigo.shade700),
            borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.indigoAccent, width: 2),
            borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: const Color(0xFF0D2B1E),
      ),
    );
  }

  Widget _teamHeader(TextEditingController ctrl, Color color) =>
      ValueListenableBuilder(
        valueListenable: ctrl,
        builder: (_, __, ___) => Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: color.withOpacity(0.3),
          child: Text(ctrl.text.isEmpty ? 'Team' : ctrl.text,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      );
}
