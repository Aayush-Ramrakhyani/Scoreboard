import 'package:flutter/material.dart';
import '../models.dart';
import 'match_screen.dart';

class TossScreen extends StatefulWidget {
  final MatchSetup setup;
  final void Function(MatchState)? onMatchComplete;
  const TossScreen({super.key, required this.setup, this.onMatchComplete});
  @override
  State<TossScreen> createState() => _TossScreenState();
}

class _TossScreenState extends State<TossScreen> {
  String? _tossWinner;
  String? _choice; // 'bat' or 'bowl'

  void _proceed() {
    if (_tossWinner == null || _choice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select toss winner and their choice')),
      );
      return;
    }
    final state = MatchState(widget.setup);
    // team1BatsFirst = true if team1 won toss & chose bat, or team2 won & chose bowl
    final team1WonToss = _tossWinner == widget.setup.team1Name;
    final choseBat = _choice == 'bat';
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
    final t1 = widget.setup.team1Name;
    final t2 = widget.setup.team2Name;

    return Scaffold(
      backgroundColor: const Color(0xFF1B3A2D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B1E),
        title: const Text('Toss', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                const Icon(Icons.monetization_on, color: Colors.amber, size: 64),
                const SizedBox(height: 16),
                const Text('Toss', textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                const Text('Who won the toss?',
                    style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 12),
                _teamButton(t1),
                const SizedBox(height: 10),
                _teamButton(t2),
                const SizedBox(height: 28),
                if (_tossWinner != null) ...[
                  Text('$_tossWinner chose to...',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _choiceButton('bat', Icons.sports_cricket)),
                      const SizedBox(width: 12),
                      Expanded(child: _choiceButton('bowl', Icons.album)),
                    ],
                  ),
                  const SizedBox(height: 28),
                ],
                ElevatedButton(
                  onPressed: _proceed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _teamButton(String name) {
    final selected = _tossWinner == name;
    return GestureDetector(
      onTap: () => setState(() => _tossWinner = name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: selected ? Colors.green.shade700 : const Color(0xFF0D2B1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Colors.greenAccent : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(name,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: selected ? Colors.white : Colors.white60,
                fontSize: 16,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _choiceButton(String choice, IconData icon) {
    final selected = _choice == choice;
    return GestureDetector(
      onTap: () => setState(() => _choice = choice),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? Colors.amber.shade700 : const Color(0xFF0D2B1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Colors.amber : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? Colors.white : Colors.white54, size: 20),
            const SizedBox(width: 8),
            Text(choice[0].toUpperCase() + choice.substring(1),
                style: TextStyle(
                    color: selected ? Colors.white : Colors.white60,
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
