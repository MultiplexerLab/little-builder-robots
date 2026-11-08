import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:little_builder_robots/app/providers.dart';
import 'package:little_builder_robots/app/router.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/core/l10n/gen/app_localizations.dart';
import 'package:little_builder_robots/features/parent_gate/question_generator.dart';

/// Opens the Parent gate in front of the current screen; true once a
/// grown-up answers correctly (PAR-03). Closing returns false.
Future<bool> askParentGate(BuildContext context) async {
  final passed = await context.push<bool>(AppRoute.parentGate.path);
  return passed ?? false;
}

/// The Parent gate (PAR-01 to PAR-03): a multiplication question written in
/// words with a number pad. No purchases are mentioned in v1.0.
class ParentGateScreen extends ConsumerStatefulWidget {
  const ParentGateScreen({this.generator, super.key});

  /// For tests.
  final QuestionGenerator? generator;

  @override
  ConsumerState<ParentGateScreen> createState() => _ParentGateScreenState();
}

class _ParentGateScreenState extends ConsumerState<ParentGateScreen> {
  late final QuestionGenerator _generator =
      widget.generator ?? QuestionGenerator();
  late GateQuestion _question = _generator.next();
  String _answer = '';
  bool _wrong = false;

  void _key(String digit) {
    if (_answer.length >= 2) return;
    setState(() {
      _answer += digit;
      _wrong = false;
    });
  }

  void _delete() {
    if (_answer.isEmpty) return;
    setState(() => _answer = _answer.substring(0, _answer.length - 1));
  }

  void _check() {
    if (int.tryParse(_answer) == _question.a * _question.b) {
      ref.read(gatePassedProvider.notifier).set(true);
      context.pop(true);
    } else {
      // PAR-02: a wrong answer shows a new question.
      setState(() {
        _question = _generator.next(previous: _question);
        _answer = '';
        _wrong = true;
      });
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop(false);
    } else {
      context.go(AppRoute.home.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = AppTheme.grownUps();
    final question = l10n.gateQuestion(
      l10n.numberWord(_question.a.toString()),
      l10n.numberWord(_question.b.toString()),
    );
    return Theme(
      data: theme,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 340),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.gateTitle,
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.gateExplanation,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              question,
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: 160,
                              height: 56,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _answer,
                                style: theme.textTheme.titleLarge,
                                semanticsLabel: l10n.gateAnswerLabel,
                              ),
                            ),
                            if (_wrong) ...[
                              const SizedBox(height: 8),
                              Text(
                                l10n.gateWrong,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      _NumberPad(
                        onDigit: _key,
                        onDelete: _delete,
                        onDone: _check,
                        doneLabel: l10n.gateDone,
                        deleteLabel: l10n.gateDelete,
                      ),
                    ],
                  ),
                ),
              ),
              // PAR-01: close button placed clear of the pad.
              Positioned(
                left: 16,
                top: 16,
                child: Semantics(
                  button: true,
                  label: l10n.buttonClose,
                  child: IconButton(
                    iconSize: 32,
                    constraints: const BoxConstraints.tightFor(
                      width: AppSizes.grownUpsTarget,
                      height: AppSizes.grownUpsTarget,
                    ),
                    onPressed: _close,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keys 56 pt (PAR-01: 48 pt+).
class _NumberPad extends StatelessWidget {
  const _NumberPad({
    required this.onDigit,
    required this.onDelete,
    required this.onDone,
    required this.doneLabel,
    required this.deleteLabel,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback onDone;
  final String doneLabel;
  final String deleteLabel;

  static const _key = 56.0;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleLarge;
    Widget key(Widget child, VoidCallback onTap, String label) => Padding(
      padding: const EdgeInsets.all(4),
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox.square(
              dimension: _key,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
    Widget digit(String d) => key(Text(d, style: style), () => onDigit(d), d);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: row.map(digit).toList(),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            key(const Icon(Icons.backspace_outlined), onDelete, deleteLabel),
            digit('0'),
            key(const Icon(Icons.check_rounded), onDone, doneLabel),
          ],
        ),
      ],
    );
  }
}
