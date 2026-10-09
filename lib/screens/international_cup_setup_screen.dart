import 'package:flutter/material.dart';
import '../cup_data.dart';
import '../tournament_models.dart';
import 'squad_review_screen.dart';

class InternationalCupSetupScreen extends StatefulWidget {
  const InternationalCupSetupScreen({super.key});

  @override
  State<InternationalCupSetupScreen> createState() =>
      _InternationalCupSetupScreenState();
}

class _InternationalCupSetupScreenState
    extends State<InternationalCupSetupScreen> {
  CupType _cupType = CupType.odiWorldCup;

  static const _cupMeta = [
    (CupType.odiWorldCup, 'ODI World Cup', '10 teams · All-play-all · Top 4 → Semis → Final', Icons.public),
    (CupType.t20WorldCup, 'T20 World Cup', '20 teams · 4 groups · Random draw → Super 8 → Semis → Final', Icons.bolt),
    (CupType.asiaCup, 'Asia Cup', '6 teams · 2 groups → Super 4 → Final', Icons.public_outlined),
    (CupType.championsTrophy, 'Champions Trophy', '8 teams · 2 groups → Semis → Final', Icons.emoji_events),
  ];

  void _start() {
    final groupAssignments = CupConfig.groupsFor(_cupType);
    final allTeams = CupConfig.teamsFor(_cupType, groupAssignments);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SquadReviewScreen(
          cupType: _cupType,
          groupAssignments: groupAssignments,
          initialTeams: allTeams,
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
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('International Cup',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SELECT CUP',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
          const SizedBox(height: 10),
          ...CupType.values.map((ct) {
            final meta = _cupMeta.firstWhere((m) => m.$1 == ct);
            final selected = _cupType == ct;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => setState(() => _cupType = ct),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.green.shade900.withValues(alpha: 0.6)
                        : const Color(0xFF0D2B1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? Colors.greenAccent : Colors.white12,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Icon(meta.$4,
                        color: selected ? Colors.greenAccent : Colors.white38,
                        size: 24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(meta.$2,
                            style: TextStyle(
                                color: selected ? Colors.white : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(meta.$3,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11)),
                      ]),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle,
                          color: Colors.greenAccent, size: 20),
                  ]),
                ),
              ),
            );
          }),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _start,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Start Tournament'),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}
