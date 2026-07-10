import 'package:flutter/material.dart';
import 'setup_screen.dart';
import 'series_setup_screen.dart';
import 'multi_format_series_setup_screen.dart';
import 'tri_series_setup_screen.dart';
import 'big_tournament_setup_screen.dart';

class ModeSelectScreen extends StatelessWidget {
  const ModeSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B3A2D),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sports_cricket, color: Colors.greenAccent, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Cricket Scoreboard',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose a match format to begin',
                  style: TextStyle(color: Colors.white54, fontSize: 15),
                ),
                const SizedBox(height: 40),
                _modeCard(
                  context,
                  icon: Icons.sports_cricket,
                  title: 'Single Match',
                  subtitle: 'One-off game between two teams',
                  color: Colors.green.shade700,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SetupScreen()),
                  ),
                ),
                const SizedBox(height: 14),
                _modeCard(
                  context,
                  icon: Icons.replay,
                  title: 'Series',
                  subtitle: 'Multiple matches — winner by most wins',
                  color: Colors.teal.shade700,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SeriesSetupScreen()),
                  ),
                ),
                const SizedBox(height: 14),
                _modeCard(
                  context,
                  icon: Icons.view_list_rounded,
                  title: 'Multi-Format Series',
                  subtitle: 'Mix T20 + ODI + Test · separate winner per format',
                  color: Colors.deepOrange.shade700,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MultiFormatSeriesSetupScreen()),
                  ),
                ),
                const SizedBox(height: 14),
                _modeCard(
                  context,
                  icon: Icons.group,
                  title: 'Tri-Series',
                  subtitle: '3 teams · 6 league matches · top 2 play Final',
                  color: Colors.indigo.shade600,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TriSeriesSetupScreen()),
                  ),
                ),
                const SizedBox(height: 14),
                _modeCard(
                  context,
                  icon: Icons.emoji_events,
                  title: 'Big Tournament',
                  subtitle: 'Groups · Super Groups · Semis · Final',
                  color: Colors.amber.shade800,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const BigTournamentSetupScreen()),
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ]),
          ),
          Icon(Icons.chevron_right, color: color.withOpacity(0.7)),
        ]),
      ),
    );
  }
}
