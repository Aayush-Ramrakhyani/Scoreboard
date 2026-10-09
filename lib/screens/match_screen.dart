import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../models.dart';
import '../database/app_database.dart';
import '../database/history_database.dart';
import '../services/motm_service.dart';
import '../services/live_session_service.dart';
import '../widgets/pulsing_dot.dart';
import 'scorecard_screen.dart';
import 'toss_screen.dart';

class MatchScreen extends StatefulWidget {
  final MatchState state;
  final void Function(MatchState)? onMatchComplete;
  final bool isResuming;
  const MatchScreen({
    super.key,
    required this.state,
    this.onMatchComplete,
    this.isResuming = false,
  });
  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen>
    with SingleTickerProviderStateMixin {
  MatchState get ms => widget.state;

  // Live broadcast (standalone match only; tournament uses LiveSessionService.activeTournamentCode)
  String? _liveCode;

  late final AnimationController _flashCtrl;
  late final Animation<double> _flashScale;
  late final Animation<double> _flashOpacity;
  String _flashLabel = '';
  Color _flashColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _flashCtrl = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    );
    _flashScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.2, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 30,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_flashCtrl);
    _flashOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(_flashCtrl);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isResuming) {
        _handleResumeState();
      } else {
        _showOpeningSelection();
      }
    });
  }

  @override
  void dispose() {
    _flashCtrl.dispose();
    super.dispose();
  }

  // ── persist helpers ────────────────────────────────────────────────────────

  void _autoSave() {
    if (widget.onMatchComplete == null) {
      if (!ms.matchOver) AppDatabase.saveMatch(ms);
    }
    _pushLive();
  }

  void _pushLive() {
    final code = _liveCode ?? LiveSessionService.activeTournamentCode;
    if (code == null) return;
    // Tick first: ~300 bytes, reaches viewers before the full state write.
    LiveSessionService.pushLiveTick(code, ms);
    if (_liveCode != null) {
      LiveSessionService.pushStandaloneMatch(code, ms);
    } else {
      LiveSessionService.pushTournamentCurrentMatch(code, ms);
    }
  }

  Future<void> _goLive() async {
    if (_liveCode != null) {
      // Already live — show code again
      _showLiveCodeDialog(_liveCode!);
      return;
    }
    final code = await LiveSessionService.createMatchSession(ms);
    if (!mounted) return;
    setState(() => _liveCode = code);
    _showLiveCodeDialog(code);
  }

  void _showLiveCodeDialog(String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D2B1E),
        title: const Text('Live Code',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Share this code with viewers:',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.greenAccent, width: 2),
            ),
            child: Text(code,
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8)),
          ),
          const SizedBox(height: 12),
          const Text('Viewers open the app → Watch Live → enter this code',
              style: TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied!')));
              }
            },
            child: const Text('Copy', style: TextStyle(color: Colors.greenAccent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              LiveSessionService.endSession(code);
              if (mounted) setState(() => _liveCode = null);
            },
            child: const Text('Stop Live', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  void _clearSave() {
    if (widget.onMatchComplete == null) AppDatabase.clearMatch();
  }

  // On resume, detect whether the game is mid-innings, at an innings break,
  // or already over and show the correct dialog.
  void _handleResumeState() {
    if (ms.matchOver) {
      _showMatchOver();
      return;
    }
    if (ms.currentInningsObj.isComplete) {
      _endInnings();
      return;
    }
  }

  void _showFlash(String label, Color color) {
    setState(() {
      _flashLabel = label;
      _flashColor = color;
    });
    _flashCtrl.forward(from: 0.0);
  }

  Widget _buildFlash() {
    final isNumeric = _flashLabel == '6' || _flashLabel == '4';
    final isOut = _flashLabel == 'OUT!';
    final fontSize = isNumeric ? 108.0 : isOut ? 72.0 : 50.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isNumeric ? 40.0 : 28.0,
        vertical: isNumeric ? 24.0 : 16.0,
      ),
      decoration: BoxDecoration(
        color: _flashColor.withValues(alpha:0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _flashColor.withValues(alpha:0.65),
            blurRadius: 60,
            spreadRadius: 20,
          ),
        ],
      ),
      child: Text(
        _flashLabel,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          height: 1.0,
          letterSpacing: isNumeric ? -2.0 : 0.0,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha:0.4),
              blurRadius: 8,
              offset: const Offset(2, 3),
            ),
          ],
        ),
      ),
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  bool get _isHundred => ms.setup.isHundred;
  bool get _isTest => ms.setup.isTest;
  int get _setSize => ms.setup.setSize; // 5 for Hundred, 6 for others

  // Max "sets" per bowler. Test = no limit (9999). Hundred = 4 sets of 5 = 20 balls.
  int get _maxSetsPerBowler {
    if (_isTest) return 9999;
    return (ms.setup.overs / 5).floor().clamp(1, ms.setup.overs);
  }

  bool _canBowl(Player p) =>
      p.role == PlayerRole.bowler || p.role == PlayerRole.allRounder;

  bool _quotaReached(Player p) =>
      (p.ballsBowled ~/ _setSize) >= _maxSetsPerBowler;

  String _bowlerSetsDisplay(Player p) => p.setsString(_setSize);

  Widget _bowlerTypeBadge(Player p) {
    final label = p.bowlerType == BowlerType.fast ? 'Fast'
        : p.bowlerType == BowlerType.spin ? 'Spin' : '';
    if (label.isEmpty) return const SizedBox.shrink();
    final color = p.bowlerType == BowlerType.fast ? Colors.deepOrange : Colors.indigo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  // ── core scoring ──────────────────────────────────────────────────────────

  void _addRuns(int runs, {bool wide = false, bool noBall = false, bool bye = false, bool legBye = false}) {
    bool setEnded = false;
    setState(() {
      final inn = ms.currentInningsObj;
      final bowler = inn.currentBowler;
      final striker = inn.striker;

      if (wide) {
        inn.wides++;
        inn.totalRuns++;
        bowler.runsConceded++;
        bowler.widesBowled++;
        if (runs > 0) { inn.totalRuns += runs; bowler.runsConceded += runs; }
        inn.ballLog.add('WD${runs > 0 ? "+$runs" : ""}');
        _checkWinCondition();
        return;
      }

      if (noBall) {
        inn.noBalls++;
        inn.totalRuns++;
        bowler.runsConceded++;
        bowler.noBallsBowled++;
        if (!bye && !legBye) {
          striker.runsScored += runs;
          striker.ballsFaced++;
          if (runs == 4) striker.fours++;
          if (runs == 6) striker.sixes++;
        } else {
          if (bye) { inn.byes += runs; } else { inn.legByes += runs; }
        }
        inn.totalRuns += runs;
        bowler.runsConceded += runs;
        inn.ballLog.add('NB${runs > 0 ? "+$runs" : ""}');
        if (runs % 2 != 0) _swapEnds(inn);
        _checkWinCondition();
        return;
      }

      // legal ball
      inn.balls++;
      striker.ballsFaced++;

      if (bye || legBye) {
        if (bye) { inn.byes += runs; } else { inn.legByes += runs; }
        inn.totalRuns += runs;
        bowler.runsConceded += runs;
        inn.ballLog.add(bye ? 'B$runs' : 'LB$runs');
      } else {
        striker.runsScored += runs;
        if (runs == 4) striker.fours++;
        if (runs == 6) striker.sixes++;
        inn.totalRuns += runs;
        bowler.runsConceded += runs;
        inn.ballLog.add('$runs');
      }

      bowler.ballsBowled++;
      if (runs % 2 != 0) _swapEnds(inn);

      if (_checkWinCondition()) return;
      if (_isInningsOver()) return;

      if (inn.balls % _setSize == 0) {
        // Hundred: end change every 10 balls, not every 5
        final swapEnds = _isHundred ? (inn.balls % 10 == 0) : true;
        _finalizeSet(swapEnds: swapEnds);
        setEnded = true;
      }
    });
    _autoSave();
    if (setEnded) _showChangeBowler();
    // Score flash animations
    if (!wide && !bye && !legBye && runs == 6) {
      _showFlash('6', const Color(0xFFFFB300));
    } else if (!wide && !bye && !legBye && runs == 4) {
      _showFlash('4', const Color(0xFF0288D1));
    } else if (wide) {
      _showFlash('Wide', Colors.orange.shade700);
    } else if (noBall && runs == 0) {
      _showFlash('No Ball', Colors.amber.shade800);
    }
  }

  void _swapEnds(Innings inn) {
    final tmp = inn.strikerIndex;
    inn.strikerIndex = inn.nonStrikerIndex;
    inn.nonStrikerIndex = tmp;
  }

  // State-only — safe inside setState. Caller must call _showChangeBowler() after.
  void _finalizeSet({bool swapEnds = true}) {
    final inn = ms.currentInningsObj;
    if (inn.currentBowler.checkMaiden()) inn.currentBowler.maidens++;
    inn.overHistory.add(List.from(inn.ballLog));
    inn.ballLog.clear();
    if (swapEnds) _swapEnds(inn);
  }

  bool _isInningsOver() {
    final inn = ms.currentInningsObj;
    final maxWickets = ms.setup.isSuperOver ? 2 : 10;
    final allOut = inn.wickets >= maxWickets;
    final ballsUp = !_isTest && inn.balls >= ms.setup.ballsPerInnings;
    if (allOut || ballsUp) {
      // Ball-limit: current partnership is still ongoing, save it
      if (!allOut) inn.saveCurrentPartnership();
      inn.isComplete = true;
      _endInnings();
      return true;
    }
    return false;
  }

  bool _checkWinCondition() {
    // Limited-overs: innings 2 chase
    if (!_isTest && ms.currentInnings == 2) {
      final inn = ms.currentInningsObj;
      if (inn.totalRuns >= ms.target) {
        inn.saveCurrentPartnership();
        inn.isComplete = true;
        final maxWickets = ms.setup.isSuperOver ? 2 : 10;
        final wl = maxWickets - inn.wickets;
        ms.matchResult = '${ms.battingTeamName} won by $wl wicket${wl != 1 ? "s" : ""}';
        ms.winnerName = ms.battingTeamName;
        ms.matchOver = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _showMatchOver());
        return true;
      }
    }
    // Test: innings 4 chase
    if (_isTest && ms.currentInnings == 4) {
      final inn = ms.currentInningsObj;
      if (inn.totalRuns >= ms.target) {
        inn.saveCurrentPartnership();
        inn.isComplete = true;
        final wl = 10 - inn.wickets;
        ms.matchResult = '${ms.battingTeamName} won by $wl wicket${wl != 1 ? "s" : ""}';
        ms.winnerName = ms.battingTeamName;
        ms.matchOver = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _showMatchOver());
        return true;
      }
    }
    return false;
  }

  void _endInnings() {
    final inn = ms.currentInningsObj;
    if (inn.ballLog.isNotEmpty) {
      inn.overHistory.add(List.from(inn.ballLog));
      inn.ballLog.clear();
    }

    if (_isTest) {
      _endTestInnings();
      return;
    }

    // Limited-overs
    if (ms.currentInnings == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showInningsBreak());
    } else {
      if (!ms.matchOver) {
        final inn2 = ms.innings2;
        final deficit = ms.target - 1 - inn2.totalRuns;
        if (deficit > 0) {
          ms.matchResult = '${ms.bowlingTeamName} won by $deficit run${deficit != 1 ? "s" : ""}';
          ms.winnerName = ms.bowlingTeamName;
          ms.matchOver = true;
        } else {
          // Tie (deficit == 0)
          if (ms.setup.isSuperOver) {
            // This super over itself tied — signal caller silently and pop
            ms.matchResult = 'Tied';
            ms.winnerName = '';
            ms.matchOver = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _clearSave();
              widget.onMatchComplete?.call(ms);
              if (mounted) Navigator.pop(context);
            });
            return;
          } else if (!ms.setup.isTest) {
            // Regular limited-overs tie — start super over chain
            WidgetsBinding.instance.addPostFrameCallback((_) => _startSuperOver(1));
            return;
          } else {
            ms.matchResult = 'Match Tied';
            ms.winnerName = '';
            ms.matchOver = true;
          }
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _showMatchOver());
    }
  }

  void _endTestInnings() {
    switch (ms.currentInnings) {
      case 1:
        WidgetsBinding.instance.addPostFrameCallback((_) => _showTestBreak());
      case 2:
        WidgetsBinding.instance.addPostFrameCallback((_) => _showTestBreak());
      case 3:
        final teamATotal = ms.innings1.totalRuns + ms.innings3!.totalRuns;
        if (teamATotal <= ms.innings2.totalRuns) {
          // Innings victory for team B
          final diff = ms.innings2.totalRuns - teamATotal;
          ms.matchResult = '${ms.bowlingTeamName} won by an innings and $diff run${diff != 1 ? "s" : ""}';
          ms.winnerName = ms.bowlingTeamName;
          ms.matchOver = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _showMatchOver());
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) => _showTestBreak());
        }
      case 4:
        if (!ms.matchOver) {
          final teamATotal = ms.innings1.totalRuns + ms.innings3!.totalRuns;
          final teamBTotal = ms.innings2.totalRuns + ms.innings4!.totalRuns;
          if (teamATotal > teamBTotal) {
            final diff = teamATotal - teamBTotal;
            ms.matchResult = '${ms.bowlingTeamName} won by $diff run${diff != 1 ? "s" : ""}';
            ms.winnerName = ms.bowlingTeamName;
          } else if (teamBTotal > teamATotal) {
            ms.matchResult = 'Match Tied';
            ms.winnerName = '';
          } else {
            ms.matchResult = 'Match Drawn';
            ms.winnerName = '';
          }
          ms.matchOver = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _showMatchOver());
        }
    }
  }

  // ── dialogs ───────────────────────────────────────────────────────────────

  void _showChangeBowler() {
    final inn = ms.currentInningsObj;
    final justBowledIdx = inn.currentBowlerIndex;
    // Hundred: same bowler can continue — no "just bowled" lock
    final lockJustBowled = !_isHundred;
    // Is this a 10-ball end-change moment in Hundred?
    final isEndChange = _isHundred && inn.balls % 10 == 0;

    final eligible = inn.bowlingTeamPlayers
        .asMap()
        .entries
        .where((e) => _canBowl(e.value))
        .toList();

    // Relax quota if every non-locked eligible bowler hit their limit
    final quotaRelaxed = eligible
        .where((e) => !(lockJustBowled && e.key == justBowledIdx))
        .every((e) => _quotaReached(e.value));

    final quotaLabel = _isTest
        ? 'No limit'
        : _isHundred
            ? 'Max 20 balls'
            : 'Max $_maxSetsPerBowler ov';

    final dialogTitle = isEndChange
        ? 'End Changed — Select Next Bowler'
        : _isHundred
            ? 'Select Next Bowler (5 balls)'
            : 'Select Next Bowler';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        int? selected;
        // Pre-select current bowler for Hundred (likely to continue)
        if (_isHundred) selected = justBowledIdx;
        return StatefulBuilder(builder: (ctx, setSt) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0D2B1E),
            title: Text(dialogTitle,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isEndChange)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade900.withValues(alpha:0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.lightBlueAccent.withValues(alpha:0.4)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.swap_horiz, color: Colors.lightBlueAccent, size: 16),
                        SizedBox(width: 6),
                        Text('Ends have changed — batting from other end',
                            style: TextStyle(color: Colors.lightBlueAccent, fontSize: 12)),
                      ]),
                    ),
                  Row(children: [
                    Expanded(
                      child: Text(
                        _isHundred
                            ? 'Same bowler can continue or pick another:'
                            : 'Choose the bowler for the next over:',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade900.withValues(alpha:0.4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(quotaLabel,
                          style: const TextStyle(
                              color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  if (eligible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('No eligible bowlers.', style: TextStyle(color: Colors.redAccent)),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: eligible.map((e) {
                            final i = e.key;
                            final p = e.value;
                            final isJustBowled = lockJustBowled && i == justBowledIdx;
                            final hitQuota = !quotaRelaxed && _quotaReached(p);
                            final disabled = isJustBowled || hitQuota;
                            final isContinue = _isHundred && i == justBowledIdx;
                            return ListTile(
                              enabled: !disabled,
                              onTap: disabled ? null : () => setSt(() => selected = i),
                              leading: Radio<int>(
                                value: i,
                                groupValue: selected,
                                onChanged: disabled ? null : (v) => setSt(() => selected = v),
                                fillColor: WidgetStateProperty.all(
                                    disabled ? Colors.white24 : Colors.greenAccent),
                              ),
                              title: Row(children: [
                                Flexible(
                                  child: Text(p.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: disabled ? Colors.white30 : Colors.white,
                                          decoration: disabled ? TextDecoration.lineThrough : null)),
                                ),
                                const SizedBox(width: 6),
                                _bowlerTypeBadge(p),
                                if (isContinue && !hitQuota) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                        color: Colors.green.shade900,
                                        borderRadius: BorderRadius.circular(4)),
                                    child: const Text('Cont.',
                                        style: TextStyle(
                                            color: Colors.greenAccent, fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                                if (hitQuota) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                        color: Colors.red.shade900,
                                        borderRadius: BorderRadius.circular(4)),
                                    child: const Text('Full',
                                        style: TextStyle(
                                            color: Colors.redAccent, fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ]),
                              subtitle: Text(
                                  _isHundred
                                      ? '${p.ballsBowled} / 20 balls  ${p.runsConceded}R  ${p.wicketsTaken}W'
                                      : '${_bowlerSetsDisplay(p)} / $_maxSetsPerBowler ov  ${p.runsConceded}R  ${p.wicketsTaken}W',
                                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: selected == null
                    ? null
                    : () {
                        setState(() {
                          inn.currentBowlerIndex = selected!;
                          inn.currentBowler.startNewOver();
                          if (inn.currentBowler.bowlingPosition == 0) {
                            inn.currentBowler.bowlingPosition =
                                inn.bowlingTeamPlayers.where((p) => p.bowlingPosition > 0).length + 1;
                          }
                        });
                        Navigator.pop(ctx);
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                child: const Text('Confirm', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }

  void _showWicketDialog() {
    final inn = ms.currentInningsObj;
    String? dismissal = 'Bowled';
    int? nextBatsman;
    int? fielderIndex;
    int runsCompleted = 0; // for Run Out: runs completed before dismissal

    final dismissals = ['Bowled', 'Caught', 'LBW', 'Run Out', 'Stumped', 'Hit Wicket', 'Retired'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0D2B1E),
          title: const Text('Wicket!',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 22)),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Batsman: ${inn.striker.name}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Dismissal type:', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: dismissals.map((d) {
                      final sel = dismissal == d;
                      return ChoiceChip(
                        label: Text(d), selected: sel,
                        onSelected: (_) => setSt(() {
                          dismissal = d;
                          runsCompleted = 0;
                        }),
                        selectedColor: Colors.red.shade700,
                        labelStyle: TextStyle(color: sel ? Colors.white : Colors.white70),
                        backgroundColor: const Color(0xFF1B3A2D),
                      );
                    }).toList(),
                  ),
                  // Run Out: runs completed before the dismissal
                  if (dismissal == 'Run Out') ...[
                    const SizedBox(height: 16),
                    const Text('Runs completed before dismissal:',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [0, 1, 2, 3, 4].map((r) {
                        final sel = runsCompleted == r;
                        return GestureDetector(
                          onTap: () => setSt(() => runsCompleted = r),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel ? Colors.orange.shade800 : const Color(0xFF1B3A2D),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: sel ? Colors.orange : Colors.white24),
                            ),
                            child: Text('$r',
                                style: TextStyle(
                                    color: sel ? Colors.white : Colors.white60,
                                    fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  if (dismissal == 'Caught' || dismissal == 'Run Out' || dismissal == 'Stumped') ...[
                    const SizedBox(height: 16),
                    const Text('Fielder:', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 6),
                    DropdownButton<int>(
                      dropdownColor: const Color(0xFF0D2B1E),
                      hint: const Text('Select fielder', style: TextStyle(color: Colors.white54)),
                      value: fielderIndex, isExpanded: true,
                      items: List.generate(inn.bowlingTeamPlayers.length, (i) =>
                          DropdownMenuItem(
                            value: i,
                            child: Text(inn.bowlingTeamPlayers[i].name,
                                style: const TextStyle(color: Colors.white)),
                          )),
                      onChanged: (v) => setSt(() => fielderIndex = v),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text('Next Batsman:', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  DropdownButton<int>(
                    dropdownColor: const Color(0xFF0D2B1E),
                    hint: const Text('Select next batsman', style: TextStyle(color: Colors.white54)),
                    value: nextBatsman, isExpanded: true,
                    items: List.generate(inn.battingTeamPlayers.length, (i) {
                      final p = inn.battingTeamPlayers[i];
                      if (p.isOut || p.hasPlayedInnings) return null;
                      if (i == inn.strikerIndex || i == inn.nonStrikerIndex) return null;
                      return DropdownMenuItem(
                          value: i,
                          child: Text('${i + 1}. ${p.name}',
                              style: const TextStyle(color: Colors.white)));
                    }).whereType<DropdownMenuItem<int>>().toList(),
                    onChanged: (v) => setSt(() => nextBatsman = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: nextBatsman == null && inn.wickets < 9 ? null : () {
                bool setEnded = false;
                setState(() {
                  final bowler = inn.currentBowler;
                  final striker = inn.striker;

                  // Run Out: credit completed runs to batsman + team total
                  if (dismissal == 'Run Out' && runsCompleted > 0) {
                    striker.runsScored += runsCompleted;
                    inn.totalRuns += runsCompleted;
                    bowler.runsConceded += runsCompleted;
                  }

                  inn.balls++;
                  striker.ballsFaced++;
                  bowler.ballsBowled++;
                  if (dismissal != 'Run Out' && dismissal != 'Retired') bowler.wicketsTaken++;
                  final fielderName = fielderIndex != null
                      ? inn.bowlingTeamPlayers[fielderIndex!].name : '';
                  String info = dismissal ?? 'Out';
                  if (fielderName.isNotEmpty) info += ' c/b $fielderName';
                  striker.dismissalInfo = info;
                  striker.isOut = true;
                  inn.wickets++;

                  // Record Fall of Wicket
                  inn.fallOfWickets.add(FallOfWicket(
                    wicketNumber: inn.wickets,
                    score: inn.totalRuns,
                    balls: inn.balls,
                    batsmanName: striker.name,
                  ));

                  // Save current partnership (strikerIndex still on out batsman)
                  inn.savePartnership(
                    outIdx: inn.strikerIndex,
                    partnerIdx: inn.nonStrikerIndex,
                  );

                  inn.ballLog.add(runsCompleted > 0 ? '$runsCompleted+W' : 'W');
                  if (inn.wickets < 10 && nextBatsman != null) {
                    inn.strikerIndex = nextBatsman!;
                    inn.battingTeamPlayers[nextBatsman!].hasPlayedInnings = true;
                    inn.battingTeamPlayers[nextBatsman!].battingPosition = inn.wickets + 2;
                    inn.startPartnership();
                  }
                  if (!_checkWinCondition() && !_isInningsOver() &&
                      inn.balls % _setSize == 0) {
                    final swapEnds = _isHundred ? (inn.balls % 10 == 0) : true;
                    _finalizeSet(swapEnds: swapEnds);
                    setEnded = true;
                  }
                });
                Navigator.pop(ctx);
                _autoSave();
                if (setEnded) _showChangeBowler();
                _showFlash('OUT!', Colors.red.shade700);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
              child: const Text('Confirm Wicket', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
  }

  void _showInningsBreak() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D2B1E),
        title: const Text('Innings Break',
            style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 22)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_scoreText(ms.innings1),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('${ms.bowlingTeamName} needs ${ms.innings1.totalRuns + 1} runs to win'
              '${_isTest ? "" : " in ${ms.setup.overs} ${_isHundred ? "sets" : "overs"}"}',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 15),
              textAlign: TextAlign.center),
        ]),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() { ms.currentInnings = 2; ms.startInnings(); });
              Navigator.pop(context);
              _showOpeningSelection();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
            child: const Text('Start 2nd Innings', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showTestBreak() {
    final inn = ms.currentInnings;
    final String title, body, nextLabel;
    final teamA = ms.team1BatsFirst ? ms.setup.team1Name : ms.setup.team2Name;
    final teamB = ms.team1BatsFirst ? ms.setup.team2Name : ms.setup.team1Name;

    if (inn == 1) {
      title = 'End of 1st Innings';
      body = '$teamA scored ${ms.innings1.totalRuns}/${ms.innings1.wickets}.\n$teamB now bats.';
      nextLabel = 'Start 2nd Innings';
    } else if (inn == 2) {
      final lead = ms.innings1.totalRuns - ms.innings2.totalRuns;
      title = 'End of 2nd Innings';
      body = lead > 0
          ? '$teamA leads by $lead runs.\n$teamA bats again.'
          : lead < 0
              ? '$teamB leads by ${-lead} runs.\n$teamA bats again.'
              : 'Scores level. $teamA bats again.';
      nextLabel = 'Start 3rd Innings';
    } else {
      // inn == 3 and no innings victory (already handled in _endTestInnings)
      final teamATotal = ms.innings1.totalRuns + ms.innings3!.totalRuns;
      final target = teamATotal - ms.innings2.totalRuns + 1;
      title = 'End of 3rd Innings';
      body = '$teamB needs $target runs to win.';
      nextLabel = 'Start 4th Innings';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D2B1E),
        title: Text(title,
            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 20)),
        content: Text(body,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            textAlign: TextAlign.center),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() { ms.currentInnings++; ms.startInnings(); });
              Navigator.pop(context);
              _showOpeningSelection();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
            child: Text(nextLabel, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _scoreText(Innings inn) {
    if (_isHundred) {
      return '${inn.battingTeamPlayers.first.name.split(' ').first}... ${inn.totalRuns}/${inn.wickets} (${inn.balls} balls)';
    }
    return '${ms.battingTeamName} scored ${inn.totalRuns}/${inn.wickets} in ${inn.oversDisplay} overs';
  }

  void _showOpeningSelection() {
    final inn = ms.currentInningsObj;
    final ordinals = ['1st', '2nd', '3rd', '4th'];
    final inningsLabel = ordinals[(ms.currentInnings - 1).clamp(0, 3)];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        int? strikerIdx, nonStrikerIdx, bowlerIdx;
        return StatefulBuilder(builder: (ctx, setSt) {
          final canConfirm = strikerIdx != null && nonStrikerIdx != null && bowlerIdx != null;

          Widget sectionLabel(String text) => Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 8),
                child: Text(text,
                    style: const TextStyle(
                        color: Colors.greenAccent, fontSize: 11,
                        fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              );

          Widget playerTile({
            required int index, required Player p,
            required int? groupValue, required void Function(int?) onChanged,
            bool disabled = false, Color radioColor = Colors.greenAccent,
          }) =>
              ListTile(
                dense: true, enabled: !disabled,
                onTap: disabled ? null : () => onChanged(index),
                leading: Radio<int>(
                  value: index, groupValue: groupValue,
                  onChanged: disabled ? null : onChanged,
                  fillColor: WidgetStateProperty.all(disabled ? Colors.white24 : radioColor),
                ),
                title: Text(p.name,
                    style: TextStyle(color: disabled ? Colors.white30 : Colors.white, fontSize: 13)),
              );

          return AlertDialog(
            backgroundColor: const Color(0xFF0D2B1E),
            title: Text('$inningsLabel Innings — Opening Selection',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    sectionLabel('STRIKER (faces first ball)'),
                    ...List.generate(inn.battingTeamPlayers.length, (i) => playerTile(
                      index: i, p: inn.battingTeamPlayers[i], groupValue: strikerIdx,
                      disabled: i == nonStrikerIdx, onChanged: (v) => setSt(() => strikerIdx = v),
                    )),
                    sectionLabel('NON-STRIKER'),
                    ...List.generate(inn.battingTeamPlayers.length, (i) => playerTile(
                      index: i, p: inn.battingTeamPlayers[i], groupValue: nonStrikerIdx,
                      disabled: i == strikerIdx, onChanged: (v) => setSt(() => nonStrikerIdx = v),
                    )),
                    sectionLabel('OPENING BOWLER'),
                    ...() {
                      final eb = inn.bowlingTeamPlayers.asMap().entries
                          .where((e) => _canBowl(e.value)).toList();
                      if (eb.isEmpty) {
                        return [const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('No eligible bowlers.', style: TextStyle(color: Colors.redAccent)),
                        )];
                      }
                      return eb.map((e) => ListTile(
                        dense: true,
                        onTap: () => setSt(() => bowlerIdx = e.key),
                        leading: Radio<int>(
                          value: e.key, groupValue: bowlerIdx,
                          onChanged: (v) => setSt(() => bowlerIdx = v),
                          fillColor: WidgetStateProperty.all(Colors.redAccent),
                        ),
                        title: Row(children: [
                          Flexible(child: Text(e.value.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 13))),
                          const SizedBox(width: 6),
                          _bowlerTypeBadge(e.value),
                        ]),
                      )).toList();
                    }(),
                  ],
                ),
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: canConfirm ? () {
                  setState(() {
                    inn.strikerIndex = strikerIdx!;
                    inn.nonStrikerIndex = nonStrikerIdx!;
                    inn.nextBatsmanIndex = 2;
                    inn.battingTeamPlayers[strikerIdx!].hasPlayedInnings = true;
                    inn.battingTeamPlayers[strikerIdx!].battingPosition = 1;
                    inn.battingTeamPlayers[nonStrikerIdx!].hasPlayedInnings = true;
                    inn.battingTeamPlayers[nonStrikerIdx!].battingPosition = 2;
                    inn.currentBowlerIndex = bowlerIdx!;
                    inn.currentBowler.startNewOver();
                    inn.currentBowler.bowlingPosition = 1;
                    inn.startPartnership();
                  });
                  Navigator.pop(ctx);
                } : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                child: const Text('Start Innings', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }

  void _startSuperOver(int round) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D2B1E),
        title: Text(
          round == 1 ? 'Super Over!' : 'Super Over #$round!',
          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 22),
          textAlign: TextAlign.center,
        ),
        content: Text(
          round == 1
              ? 'Match tied!\nEach team faces 1 over to decide the winner.'
              : 'Super over tied again!\nAnother super over will decide the winner.',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _launchSuperOver(round);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(round == 1 ? 'Start Super Over' : 'Start Super Over #$round'),
            ),
          ),
        ],
      ),
    );
  }

  void _launchSuperOver(int round) {
    final superSetup = MatchSetup(
      team1Name: ms.setup.team1Name,
      team2Name: ms.setup.team2Name,
      team1Players: ms.setup.team1Players,
      team2Players: ms.setup.team2Players,
      format: ms.setup.format,
      isSuperOver: true,
      customOvers: 1,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/superover'),
        builder: (_) => TossScreen(
          setup: superSetup,
          onMatchComplete: (superMs) {
            if (superMs.winnerName.isEmpty) {
              // Another tie — show next super over dialog on this screen
              if (mounted) _startSuperOver(round + 1);
            } else {
              // Winner found — patch original result and show match over
              ms.matchResult = '${superMs.winnerName} won (Super Over)';
              ms.winnerName = superMs.winnerName;
              ms.matchOver = true;
              if (mounted) _showMatchOver();
            }
          },
        ),
      ),
    );
  }

  void _showMatchOver() {
    _clearSave();
    // Super over: no dialog — silently call onMatchComplete and pop back
    if (ms.setup.isSuperOver) {
      widget.onMatchComplete?.call(ms);
      if (mounted) Navigator.pop(context);
      return;
    }
    if (widget.onMatchComplete == null) HistoryDatabase.addMatch(ms);
    widget.onMatchComplete?.call(ms);
    final mom = MotmService.calculateMotm(ms);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D2B1E),
        title: const Text('Match Over!',
            style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ms.matchResult,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center),
            if (mom != null) ...[
              const SizedBox(height: 16),
              _MotmCard(mom: mom, label: 'Man of the Match'),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ScorecardScreen(
                        state: ms,
                        onBackToTournament: widget.onMatchComplete != null
                            ? () => Navigator.popUntil(
                                context, (r) => r.settings.name == '/tournament')
                            : null,
                      )));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
            child: const Text('View Scorecard', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final inn = ms.currentInningsObj;
    final isSecond = ms.currentInnings == 2 ||
        (_isTest && ms.currentInnings == 4);

    return Scaffold(
      backgroundColor: const Color(0xFF1B3A2D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B1E),
        title: Text('${ms.battingTeamName} vs ${ms.bowlingTeamName}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        actions: [
          if (widget.onMatchComplete == null)
            _liveCode != null
                ? GestureDetector(
                    onTap: _goLive,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const PulsingDot(),
                        const SizedBox(width: 5),
                        Text(_liveCode!,
                            style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1)),
                      ]),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.wifi_tethering, color: Colors.white54),
                    tooltip: 'Go Live',
                    onPressed: _goLive,
                  ),
          TextButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => ScorecardScreen(state: ms))),
            icon: const Icon(Icons.list_alt, color: Colors.greenAccent),
            label: const Text('Scorecard', style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
      body: Stack(children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _scoreHeader(inn),
                  const SizedBox(height: 10),
                  if (isSecond) _targetBar(),
                  const SizedBox(height: 10),
                  _currentSetBar(inn),
                  const SizedBox(height: 10),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _batsmenCard(inn)),
                    const SizedBox(width: 10),
                    Expanded(child: _bowlerCard(inn)),
                  ]),
                  const SizedBox(height: 16),
                  if (!ms.matchOver) _scoringButtons(),
                  const SizedBox(height: 16),
                  _overHistorySection(inn),
                ],
              ),
            ),
          ),
        ),
        // Flash overlay
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _flashCtrl,
            builder: (_, __) {
              if (_flashOpacity.value < 0.01) return const SizedBox.shrink();
              return Center(
                child: Opacity(
                  opacity: _flashOpacity.value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: _flashScale.value,
                    child: _buildFlash(),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _scoreHeader(Innings inn) {
    final String oversLine;
    if (_isHundred) {
      oversLine = '${inn.balls} / 100 balls';
    } else if (_isTest) {
      oversLine = '${inn.oversDisplay} overs  ·  Innings ${ms.currentInnings}';
    } else {
      oversLine = '${inn.oversDisplay} / ${ms.setup.overs} overs';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0D2B1E), Colors.green.shade900],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withValues(alpha:0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ms.battingTeamName,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Text('${inn.totalRuns}/${inn.wickets}',
                style: const TextStyle(color: Colors.white, fontSize: 42,
                    fontWeight: FontWeight.bold, height: 1.1)),
            Text(oversLine,
                style: const TextStyle(color: Colors.white60, fontSize: 13)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (_isHundred) ...[
              Text('${100 - inn.balls} balls left',
                  style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
            ],
            Text('Extras: ${inn.totalExtras}',
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
            Text('W${inn.wides} NB${inn.noBalls} B${inn.byes} LB${inn.legByes}',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
            if (!_isHundred) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.green.shade900,
                    borderRadius: BorderRadius.circular(6)),
                child: Text(ms.setup.formatLabel,
                    style: const TextStyle(
                        color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _targetBar() {
    // Test innings 4: show target
    if (_isTest && ms.currentInnings == 4) {
      final needed = ms.runsNeeded;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.amber.shade900.withValues(alpha:0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withValues(alpha:0.4)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _statPill('Target', '${ms.target}', Colors.amber),
          _statPill('Need', '$needed runs', Colors.orangeAccent),
          _statPill('Team A Total',
              '${ms.innings1.totalRuns + (ms.innings3?.totalRuns ?? 0)}',
              Colors.lightBlueAccent),
        ]),
      );
    }
    // Test innings 2: show 1st innings lead/deficit
    if (_isTest && ms.currentInnings == 2) {
      final lead = ms.innings1.totalRuns - ms.innings2.totalRuns;
      final color = lead > 0 ? Colors.redAccent : Colors.greenAccent;
      final label = lead > 0 ? 'Trail by $lead' : 'Lead by ${-lead}';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade900.withValues(alpha:0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blueGrey.withValues(alpha:0.3)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _statPill('1st Inn Target', '${ms.innings1.totalRuns + 1}', Colors.white70),
          _statPill('Status', label, color),
        ]),
      );
    }
    // Limited-overs innings 2
    final needed = ms.runsNeeded;
    final balls = ms.ballsRemaining;
    final rrr = balls > 0 ? (needed / (balls / 6)).toStringAsFixed(2) : '—';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade900.withValues(alpha:0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha:0.4)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _statPill('Target', '${ms.target}', Colors.amber),
        _statPill('Need', '$needed runs', Colors.orangeAccent),
        if (_isHundred)
          _statPill('Balls left', '$balls', Colors.lightBlueAccent)
        else ...[
          _statPill('Balls left', '${balls ~/ 6}.${balls % 6} ($balls)', Colors.lightBlueAccent),
          _statPill('Req RR', rrr, Colors.pinkAccent),
        ],
      ]),
    );
  }

  Widget _statPill(String label, String value, Color color) =>
      Column(children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
      ]);

  Widget _currentSetBar(Innings inn) {
    final label = _isHundred ? 'This set: ' : 'This over: ';
    // For Hundred, also show which 10-ball period we're in
    final ballsInPeriod = _isHundred ? (inn.balls % 10) : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2B1E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        if (_isHundred && ballsInPeriod != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text('(${ballsInPeriod + 1}/10)',
                style: const TextStyle(color: Colors.white24, fontSize: 11)),
          ),
        ...inn.ballLog.map(_ballChip),
        if (inn.ballLog.isEmpty)
          const Text('—', style: TextStyle(color: Colors.white30, fontSize: 13)),
      ]),
    );
  }

  Widget _ballChip(String label) {
    final Color bg;
    if (label == 'W') {
      bg = Colors.red.shade700;
    } else if (label == '4') {
      bg = Colors.blue.shade700;
    } else if (label == '6') {
      bg = Colors.purple.shade700;
    } else if (label.startsWith('WD')) {
      bg = Colors.orange.shade800;
    } else if (label.startsWith('NB')) {
      bg = Colors.amber.shade800;
    } else {
      bg = Colors.grey.shade800;
    }
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _batsmenCard(Innings inn) {
    return _card(
      title: 'Batsmen',
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.5), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1),
          3: FlexColumnWidth(0.8), 4: FlexColumnWidth(0.8), 5: FlexColumnWidth(1.2),
        },
        children: [
          _tableHeader(['Batter', 'R', 'B', '4s', '6s', 'SR']),
          _batsmanRow(inn.striker, inn, isStriker: true),
          _batsmanRow(inn.nonStriker, inn, isStriker: false),
        ],
      ),
    );
  }

  TableRow _tableHeader(List<String> cols) => TableRow(
    decoration: BoxDecoration(color: Colors.green.shade900.withValues(alpha:0.5)),
    children: cols.map((c) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Text(c, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
    )).toList(),
  );

  TableRow _batsmanRow(Player p, Innings inn, {required bool isStriker}) {
    final sr = p.ballsFaced == 0 ? '0.0' : (p.runsScored / p.ballsFaced * 100).toStringAsFixed(1);
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(children: [
          if (isStriker) const Text('* ', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          Flexible(child: Text(p.name,
              style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis)),
        ]),
      ),
      _tc('${p.runsScored}', bold: true),
      _tc('${p.ballsFaced}'),
      _tc('${p.fours}'),
      _tc('${p.sixes}'),
      _tc(sr),
    ]);
  }

  Widget _tc(String text, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    child: Text(text,
        style: TextStyle(color: Colors.white, fontSize: 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
  );

  Widget _bowlerCard(Innings inn) {
    final b = inn.currentBowler;
    final eco = b.ballsBowled == 0 ? '0.0'
        : (b.runsConceded / b.ballsBowled * 6).toStringAsFixed(1);
    final oDisplay = _bowlerSetsDisplay(b);
    return _card(
      title: 'Bowler',
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.5), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1),
          3: FlexColumnWidth(0.8), 4: FlexColumnWidth(1.2),
        },
        children: [
          _tableHeader([_isHundred ? 'Bowler' : 'Bowler', _isHundred ? 'Balls' : 'O', 'R', 'W', 'Eco']),
          TableRow(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Text(b.name,
                  style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis),
            ),
            _tc(_isHundred ? '${b.ballsBowled}' : oDisplay),
            _tc('${b.runsConceded}'),
            _tc('${b.wicketsTaken}', bold: true),
            _tc(eco),
          ]),
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2B1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(color: Colors.greenAccent, fontSize: 12,
                fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 8),
        child,
      ]),
    );
  }

  Widget _scoringButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('SCORE', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 2)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _runBtn('0', 0), _runBtn('1', 1), _runBtn('2', 2), _runBtn('3', 3),
          _runBtn('4', 4, color: Colors.blue.shade700),
          _runBtn('6', 6, color: Colors.purple.shade700),
        ]),
        const SizedBox(height: 12),
        const Text('EXTRAS', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 2)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _extraBtn('Wide', Colors.orange.shade800, _showWideDialog),
          _extraBtn('No Ball', Colors.amber.shade800, _showNoBallDialog),
          _extraBtn('Bye', Colors.teal.shade700, () => _showByeDialog(bye: true)),
          _extraBtn('Leg Bye', Colors.cyan.shade800, () => _showByeDialog(bye: false)),
          _extraBtn('Wicket', Colors.red.shade700, _showWicketDialog),
        ]),
      ],
    );
  }

  Widget _runBtn(String label, int runs, {Color? color}) => SizedBox(
    width: 68, height: 68,
    child: ElevatedButton(
      onPressed: () => _addRuns(runs),
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? Colors.green.shade800, foregroundColor: Colors.white,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    ),
  );

  Widget _extraBtn(String label, Color color, VoidCallback onTap) => ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: color, foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
  );

  void _showWideDialog() {
    final inn = ms.currentInningsObj;
    int extraRuns = 0;
    bool isStumped = false;
    int? nextBatsman;
    int? stumpedByIdx;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) {
        final canConfirm = !isStumped || nextBatsman != null || inn.wickets >= 9;
        return AlertDialog(
          backgroundColor: const Color(0xFF0D2B1E),
          title: const Text('Wide', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Extra runs (overthrows):', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(
                    icon: const Icon(Icons.remove, color: Colors.white),
                    onPressed: () { if (extraRuns > 0) setSt(() => extraRuns--); },
                  ),
                  Text('$extraRuns',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: () => setSt(() => extraRuns++),
                  ),
                ]),
                const Divider(color: Colors.white12, height: 24),
                // Stumping on wide
                GestureDetector(
                  onTap: () => setSt(() {
                    isStumped = !isStumped;
                    if (!isStumped) { nextBatsman = null; stumpedByIdx = null; }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isStumped ? Colors.red.shade900.withValues(alpha:0.3) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isStumped ? Colors.redAccent.withValues(alpha:0.5) : Colors.white24),
                    ),
                    child: Row(children: [
                      Icon(
                        isStumped ? Icons.check_box : Icons.check_box_outline_blank,
                        color: isStumped ? Colors.redAccent : Colors.white54,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Wicket — Stumped on this wide',
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ),
                    ]),
                  ),
                ),
                if (isStumped) ...[
                  const SizedBox(height: 14),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Stumped by (keeper):', style: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(height: 6),
                  DropdownButton<int>(
                    dropdownColor: const Color(0xFF0D2B1E),
                    hint: const Text('Select keeper', style: TextStyle(color: Colors.white54)),
                    value: stumpedByIdx, isExpanded: true,
                    items: List.generate(inn.bowlingTeamPlayers.length, (i) =>
                        DropdownMenuItem(
                          value: i,
                          child: Text(inn.bowlingTeamPlayers[i].name,
                              style: const TextStyle(color: Colors.white)),
                        )),
                    onChanged: (v) => setSt(() => stumpedByIdx = v),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Next Batsman:', style: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(height: 6),
                  DropdownButton<int>(
                    dropdownColor: const Color(0xFF0D2B1E),
                    hint: const Text('Select next batsman', style: TextStyle(color: Colors.white54)),
                    value: nextBatsman, isExpanded: true,
                    items: List.generate(inn.battingTeamPlayers.length, (i) {
                      final p = inn.battingTeamPlayers[i];
                      if (p.isOut || p.hasPlayedInnings) return null;
                      if (i == inn.strikerIndex || i == inn.nonStrikerIndex) return null;
                      return DropdownMenuItem(
                          value: i,
                          child: Text('${i + 1}. ${p.name}',
                              style: const TextStyle(color: Colors.white)));
                    }).whereType<DropdownMenuItem<int>>().toList(),
                    onChanged: (v) => setSt(() => nextBatsman = v),
                  ),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: canConfirm ? () {
                if (isStumped) {
                  _processWideWithStumping(extraRuns, nextBatsman, stumpedByIdx);
                  _showFlash('OUT!', Colors.red.shade700);
                } else {
                  _addRuns(extraRuns, wide: true);
                }
                Navigator.pop(ctx);
              } : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: isStumped ? Colors.red.shade700 : Colors.orange.shade800),
              child: Text(isStumped ? 'Wide + Wicket' : 'Add Wide',
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
  }

  void _processWideWithStumping(int extraRuns, int? nextBatsman, int? stumpedByIdx) {
    setState(() {
      final inn = ms.currentInningsObj;
      final bowler = inn.currentBowler;
      final striker = inn.striker;

      // Wide penalty: 1 run + any overthrows (all go to extras + team total)
      inn.wides++;
      inn.totalRuns++;
      bowler.runsConceded++;
      bowler.widesBowled++;
      if (extraRuns > 0) {
        inn.totalRuns += extraRuns;
        bowler.runsConceded += extraRuns;
      }

      // Stumped: bowler gets wicket credit (same as normal stumped)
      bowler.wicketsTaken++;
      final keeperName = stumpedByIdx != null
          ? inn.bowlingTeamPlayers[stumpedByIdx].name : '';
      striker.dismissalInfo =
          keeperName.isNotEmpty ? 'Stumped $keeperName (Wide)' : 'Stumped (Wide)';
      striker.isOut = true;
      inn.wickets++;

      // Wide does NOT count as a legal ball — balls count unchanged
      inn.fallOfWickets.add(FallOfWicket(
        wicketNumber: inn.wickets,
        score: inn.totalRuns,
        balls: inn.balls,
        batsmanName: striker.name,
      ));

      // Save current partnership (wide does not increment balls — snapshot is still valid)
      inn.savePartnership(
        outIdx: inn.strikerIndex,
        partnerIdx: inn.nonStrikerIndex,
      );

      inn.ballLog.add('WD+W');

      if (inn.wickets < 10 && nextBatsman != null) {
        inn.strikerIndex = nextBatsman;
        inn.battingTeamPlayers[nextBatsman].hasPlayedInnings = true;
        inn.battingTeamPlayers[nextBatsman].battingPosition = inn.wickets + 2;
        inn.startPartnership();
      }

      if (_checkWinCondition()) return;
      _isInningsOver();
    });
  }

  void _showNoBallDialog() {
    int runs = 0; bool isBye = false;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0D2B1E),
          title: const Text('No Ball', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Runs off the bat:', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [0,1,2,3,4,6].map((r) => ChoiceChip(
              label: Text('$r'), selected: runs == r,
              onSelected: (_) => setSt(() => runs = r),
              selectedColor: Colors.amber.shade700,
              labelStyle: TextStyle(color: runs == r ? Colors.white : Colors.white70),
              backgroundColor: const Color(0xFF1B3A2D),
            )).toList()),
            const SizedBox(height: 12),
            Row(children: [
              Checkbox(value: isBye, onChanged: (v) => setSt(() => isBye = v ?? false),
                  activeColor: Colors.teal),
              const Text('Bye off No Ball', style: TextStyle(color: Colors.white70)),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: () { _addRuns(runs, noBall: true, bye: isBye); Navigator.pop(ctx); },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800),
              child: const Text('Add No Ball', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
  }

  void _showByeDialog({required bool bye}) {
    int runs = 1;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0D2B1E),
          title: Text(bye ? 'Bye' : 'Leg Bye',
              style: TextStyle(color: bye ? Colors.teal : Colors.cyan, fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Runs:', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [1,2,3,4].map((r) => ChoiceChip(
              label: Text('$r'), selected: runs == r,
              onSelected: (_) => setSt(() => runs = r),
              selectedColor: Colors.teal.shade700,
              labelStyle: TextStyle(color: runs == r ? Colors.white : Colors.white70),
              backgroundColor: const Color(0xFF1B3A2D),
            )).toList()),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: () { _addRuns(runs, bye: bye, legBye: !bye); Navigator.pop(ctx); },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700),
              child: Text('Add ${bye ? "Bye" : "Leg Bye"}', style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
  }

  Widget _overHistorySection(Innings inn) {
    if (inn.overHistory.isEmpty) return const SizedBox.shrink();
    final setLabel = _isHundred ? 'Set' : 'Over';
    return _card(
      title: '${setLabel.toUpperCase()} HISTORY',
      child: Column(
        children: inn.overHistory.asMap().entries.map((e) {
          final num = e.key + 1;
          final balls = e.value;
          final total = balls.fold<int>(0, (sum, b) {
            if (b == 'W' || b.startsWith('WD') && b.length == 2) return sum + 1;
            final n = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), ''));
            return sum + (n ?? 0);
          });
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              SizedBox(width: 36,
                  child: Text('$setLabel $num',
                      style: const TextStyle(color: Colors.white54, fontSize: 11))),
              const SizedBox(width: 6),
              ...balls.map(_ballChip),
              const Spacer(),
              Text('$total',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

class _MotmCard extends StatelessWidget {
  final MotmResult mom;
  final String label;
  const _MotmCard({required this.mom, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 14),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8)),
          ]),
          const SizedBox(height: 6),
          Text(mom.playerName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('${mom.teamName} · ${mom.roleLabel}',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          if (mom.statsLine.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(mom.statsLine,
                style: const TextStyle(color: Colors.greenAccent, fontSize: 11),
                textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
