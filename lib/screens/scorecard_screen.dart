import 'package:flutter/material.dart';
import '../models.dart';
import 'setup_screen.dart';

class ScorecardScreen extends StatefulWidget {
  final MatchState state;
  final VoidCallback? onBackToTournament;
  const ScorecardScreen({super.key, required this.state, this.onBackToTournament});
  @override
  State<ScorecardScreen> createState() => _ScorecardScreenState();
}

class _ScorecardScreenState extends State<ScorecardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  List<(Innings, int)> get _inningsList {
    final ms = widget.state;
    final result = <(Innings, int)>[];
    result.add((ms.innings1, 1));
    if (ms.currentInnings >= 2) result.add((ms.innings2, 2));
    if (ms.innings3 != null) result.add((ms.innings3!, 3));
    if (ms.innings4 != null) result.add((ms.innings4!, 4));
    return result;
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _inningsList.length, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String _battingTeam(int inningsNum) {
    final ms = widget.state;
    return inningsNum.isOdd
        ? (ms.team1BatsFirst ? ms.setup.team1Name : ms.setup.team2Name)
        : (ms.team1BatsFirst ? ms.setup.team2Name : ms.setup.team1Name);
  }

  @override
  Widget build(BuildContext context) {
    final ms = widget.state;
    final innings = _inningsList;
    final ordinals = ['1st', '2nd', '3rd', '4th'];

    return Scaffold(
      backgroundColor: const Color(0xFF1B3A2D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B1E),
        title: const Text('Scorecard',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (ms.matchOver)
            TextButton.icon(
              onPressed: () {
                if (widget.onBackToTournament != null) {
                  Navigator.pop(context);
                  widget.onBackToTournament!();
                } else {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const SetupScreen()),
                    (_) => false,
                  );
                }
              },
              icon: Icon(
                widget.onBackToTournament != null ? Icons.arrow_back : Icons.refresh,
                color: Colors.greenAccent,
              ),
              label: Text(
                widget.onBackToTournament != null ? 'Back to Tournament' : 'New Match',
                style: const TextStyle(color: Colors.greenAccent),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.greenAccent,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.greenAccent,
          isScrollable: innings.length > 2,
          tabs: innings.map((e) {
            final n = e.$2;
            final label = ms.setup.isTest
                ? '${ordinals[n - 1]} Inn'
                : n == 1
                    ? '${_battingTeam(1)} Inn'
                    : '${_battingTeam(2)} Inn';
            return Tab(text: label);
          }).toList(),
        ),
      ),
      body: Column(
        children: [
          if (ms.matchOver)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              color: Colors.amber.shade900.withOpacity(0.4),
              child: Text(ms.matchResult,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: innings.map((e) => _InningsCard(
                innings: e.$1,
                inningsNum: e.$2,
                ms: ms,
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _InningsCard extends StatelessWidget {
  final Innings innings;
  final int inningsNum;
  final MatchState ms;

  const _InningsCard({
    required this.innings,
    required this.inningsNum,
    required this.ms,
  });

  String get _battingTeam => inningsNum.isOdd
      ? (ms.team1BatsFirst ? ms.setup.team1Name : ms.setup.team2Name)
      : (ms.team1BatsFirst ? ms.setup.team2Name : ms.setup.team1Name);

  String get _bowlingTeam => inningsNum.isOdd
      ? (ms.team1BatsFirst ? ms.setup.team2Name : ms.setup.team1Name)
      : (ms.team1BatsFirst ? ms.setup.team1Name : ms.setup.team2Name);

  int get _setSize => ms.setup.setSize;
  bool get _isHundred => ms.setup.isHundred;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _summaryBar(),
              const SizedBox(height: 12),
              _sectionLabel('BATTING — $_battingTeam'),
              const SizedBox(height: 6),
              _battingTable(),
              const SizedBox(height: 16),
              _sectionLabel('BOWLING — $_bowlingTeam'),
              const SizedBox(height: 6),
              _bowlingTable(),
              const SizedBox(height: 16),
              _extrasSummary(),
              if (innings.fallOfWickets.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionLabel('FALL OF WICKETS'),
                const SizedBox(height: 6),
                _fowSection(),
              ],
              if (innings.partnerships.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionLabel('PARTNERSHIPS'),
                const SizedBox(height: 6),
                _partnershipTable(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryBar() {
    final String oversLine;
    if (_isHundred) {
      oversLine = '${innings.balls} / 100 balls';
    } else if (ms.setup.isTest) {
      oversLine = '${innings.oversDisplay} overs';
    } else {
      oversLine = '${innings.oversDisplay} / ${ms.setup.overs} overs';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0D2B1E), Colors.green.shade900],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_battingTeam, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Text('${innings.totalRuns}/${innings.wickets}',
                style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
            Text(oversLine, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Extras: ${innings.totalExtras}',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Text('W:${innings.wides}  NB:${innings.noBalls}  B:${innings.byes}  LB:${innings.legByes}',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          color: Colors.greenAccent, fontSize: 11,
          fontWeight: FontWeight.bold, letterSpacing: 1.5));

  Widget _battingTable() {
    final played = innings.battingTeamPlayers
        .where((p) => p.battingPosition > 0)
        .toList()
        ..sort((a, b) => a.battingPosition.compareTo(b.battingPosition));
    return _tableContainer(
      header: ['Batter', 'Dismissal', 'R', 'B', '4s', '6s', 'SR'],
      widths: const {
        0: FlexColumnWidth(2.2), 1: FlexColumnWidth(2.5),
        2: FlexColumnWidth(0.8), 3: FlexColumnWidth(0.8),
        4: FlexColumnWidth(0.7), 5: FlexColumnWidth(0.7),
        6: FlexColumnWidth(1.2),
      },
      rows: played.map((p) {
        final sr = p.ballsFaced == 0
            ? '0.0'
            : (p.runsScored / p.ballsFaced * 100).toStringAsFixed(1);
        final idx = innings.battingTeamPlayers.indexOf(p);
        final isStriker = idx == innings.strikerIndex && !innings.isComplete;
        final isNonStriker = idx == innings.nonStrikerIndex && !innings.isComplete;
        final String status;
        if (p.isOut) {
          status = p.dismissalInfo;
        } else if (isStriker) {
          status = 'batting *';
        } else {
          status = 'not out';
        }
        final active = isStriker || isNonStriker;
        return [
          _playerNameCell(p, bold: active),
          _cell(status, small: true, muted: !p.isOut),
          _cell('${p.runsScored}', bold: true),
          _cell('${p.ballsFaced}'),
          _cell('${p.fours}'),
          _cell('${p.sixes}'),
          _cell(sr),
        ];
      }).toList(),
    );
  }

  Widget _bowlingTable() {
    final bowled = innings.bowlingTeamPlayers
        .where((p) => p.bowlingPosition > 0)
        .toList()
        ..sort((a, b) => a.bowlingPosition.compareTo(b.bowlingPosition));
    final ovHeader = _isHundred ? 'Balls' : 'O';
    return _tableContainer(
      header: ['Bowler', ovHeader, 'M', 'R', 'W', 'Eco'],
      widths: const {
        0: FlexColumnWidth(2.5), 1: FlexColumnWidth(1),
        2: FlexColumnWidth(0.8), 3: FlexColumnWidth(0.8),
        4: FlexColumnWidth(0.8), 5: FlexColumnWidth(1.2),
      },
      rows: bowled.map((p) {
        final eco = p.ballsBowled == 0
            ? '0.0'
            : (p.runsConceded / p.ballsBowled * 6).toStringAsFixed(1);
        final oDisplay = _isHundred ? '${p.ballsBowled}' : p.setsString(_setSize);
        return [
          _playerNameCell(p),
          _cell(oDisplay),
          _cell('${p.maidens}'),
          _cell('${p.runsConceded}'),
          _cell('${p.wicketsTaken}', bold: true),
          _cell(eco),
        ];
      }).toList(),
    );
  }

  Widget _tableContainer({
    required List<String> header,
    required Map<int, TableColumnWidth> widths,
    required List<List<Widget>> rows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D2B1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Table(
        columnWidths: widths,
        children: [
          TableRow(
            decoration: BoxDecoration(color: Colors.green.shade900.withOpacity(0.6)),
            children: header
                .map((h) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Text(h,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                    ))
                .toList(),
          ),
          ...rows.asMap().entries.map((e) => TableRow(
                decoration: BoxDecoration(
                    color: e.key.isEven ? Colors.transparent : Colors.white.withOpacity(0.03)),
                children: e.value,
              )),
        ],
      ),
    );
  }

  Widget _cell(String text, {bool bold = false, bool small = false, bool muted = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: muted ? Colors.white54 : Colors.white,
                fontSize: small ? 11 : 12,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      );

  Widget _playerNameCell(Player p, {bool bold = false}) {
    final playerBadges = p.badges;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(p.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: bold ? Colors.greenAccent : Colors.white,
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          if (playerBadges.isNotEmpty) ...[
            const SizedBox(height: 3),
            Wrap(
              spacing: 3,
              children: playerBadges
                  .map((b) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: b.color.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(b.label,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _extrasSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2B1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _extraChip('Wides', innings.wides, Colors.orange),
          _extraChip('No Balls', innings.noBalls, Colors.amber),
          _extraChip('Byes', innings.byes, Colors.teal),
          _extraChip('Leg Byes', innings.legByes, Colors.cyan),
          _extraChip('Total', innings.totalExtras, Colors.greenAccent),
        ],
      ),
    );
  }

  Widget _fowSection() {
    final setSize = ms.setup.setSize;
    final isHundred = ms.setup.isHundred;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2B1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Wrap(
        spacing: 10, runSpacing: 10,
        children: innings.fallOfWickets.map((fow) {
          final String overLabel;
          if (isHundred) {
            overLabel = '${fow.balls} balls';
          } else {
            final ov = fow.balls ~/ setSize;
            final ball = fow.balls % setSize;
            overLabel = '$ov.$ball ov';
          }
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade900.withOpacity(0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${fow.wicketNumber}-${fow.score}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(fow.batsmanName,
                    style: const TextStyle(color: Colors.white60, fontSize: 11)),
                Text(overLabel,
                    style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _partnershipTable() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D2B1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: innings.partnerships.asMap().entries.map((e) {
          final idx = e.key;
          final p = e.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              border: idx > 0
                  ? const Border(top: BorderSide(color: Colors.white10))
                  : null,
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  '${p.bat1Name}\n${p.bat1Runs}(${p.bat1Balls})',
                  style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 12),
                ),
              ),
              SizedBox(
                width: 72,
                child: Text(
                  '${p.totalRuns}(${p.totalBalls})',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
              Expanded(
                child: Text(
                  '${p.bat2Name}\n${p.bat2Runs}(${p.bat2Balls})',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 12),
                ),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _extraChip(String label, int val, Color color) => Column(children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 2),
        Text('$val', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ]);
}
