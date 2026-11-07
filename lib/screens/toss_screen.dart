import 'package:flutter/material.dart';
import '../models.dart';
import 'match_screen.dart';

/// Captures the toss result (winner + bat/field choice) and derives which
/// team bats first before pushing to [MatchScreen].
class TossScreen extends StatefulWidget {
  final MatchSetup setup;
  final void Function(MatchState)? onMatchComplete;
  const TossScreen({super.key, required this.setup, this.onMatchComplete});
  @override
  State<TossScreen> createState() => _TossScreenState();
}

class _TossScreenState extends State<TossScreen> {
  String? _tossWinner;
  String? _choice;

  void _proceed() {
    if (_tossWinner == null || _choice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select toss winner and their choice')),
      );
      return;
    }
    final state = MatchState(widget.setup);
    final team1WonToss = _tossWinner == widget.setup.team1Name;
    final choseBat = _choice == 'bat';
    // team1 bats first when: team1 won toss AND chose bat, OR team1 lost toss AND opposition chose field
    state.team1BatsFirst = (team1WonToss && choseBat) || (!team1WonToss && !choseBat);
    state.startInnings();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (_) => MatchScreen(
              state: state, onMatchComplete: widget.onMatchComplete)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t1 = widget.setup.team1Name;
    final t2 = widget.setup.team2Name;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Toss'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.monetization_on, color: cs.onSurface, size: 64),
                const SizedBox(height: 16),
                Text('Toss',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                Text('Who won the toss?',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.7),
                        fontSize: 16)),
                const SizedBox(height: 12),
                _teamButton(cs, t1),
                const SizedBox(height: 10),
                _teamButton(cs, t2),
                const SizedBox(height: 28),
                if (_tossWinner != null) ...[
                  Text('$_tossWinner chose to...',
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.7),
                          fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _choiceButton(cs, 'bat', Icons.sports_cricket)),
                      const SizedBox(width: 12),
                      Expanded(child: _choiceButton(cs, 'bowl', Icons.album)),
                    ],
                  ),
                  const SizedBox(height: 28),
                ],
                ElevatedButton(
                  onPressed: _proceed,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Start Match'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _teamButton(ColorScheme cs, String name) {
    final selected = _tossWinner == name;
    return GestureDetector(
      onTap: () => setState(() => _tossWinner = name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: selected
              ? cs.onSurface.withValues(alpha: 0.12)
              : cs.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? cs.onSurface : cs.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(name,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: selected
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: 0.6),
                fontSize: 16,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _choiceButton(ColorScheme cs, String choice, IconData icon) {
    final selected = _choice == choice;
    return GestureDetector(
      onTap: () => setState(() => _choice = choice),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? cs.onSurface.withValues(alpha: 0.12)
              : cs.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? cs.onSurface : cs.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: selected
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: 0.55),
                size: 20),
            const SizedBox(width: 8),
            Text(choice[0].toUpperCase() + choice.substring(1),
                style: TextStyle(
                    color: selected
                        ? cs.onSurface
                        : cs.onSurface.withValues(alpha: 0.6),
                    fontSize: 15,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
