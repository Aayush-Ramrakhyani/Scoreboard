import 'package:flutter/material.dart';
import '../cup_data.dart';
import '../tournament_models.dart';
import 'squad_review_screen.dart';

/// Setup wizard for an international cup (e.g. World Cup): selects the cup
/// type, assigns national teams to groups, then proceeds to [SquadReviewScreen].
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
      appBar: AppBar(
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        title: Text('International Cup',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SELECT CUP',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
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
                        ? Theme.of(context).colorScheme.surface
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Icon(meta.$4,
                        color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                        size: 24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(meta.$2,
                            style: TextStyle(
                                color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(meta.$3,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 11)),
                      ]),
                    ),
                    if (selected)
                      Icon(Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary, size: 20),
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
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
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
