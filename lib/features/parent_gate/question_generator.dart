import 'dart:math';

/// A Parent gate question (PAR-01, PAR-02).
typedef GateQuestion = ({int a, int b});

/// PAR-02: both factors 3 to 9 and the answer 20 to 81. Randomness is fine
/// here: the gate is not part of a run (SRS 4.7 covers runs only).
class QuestionGenerator {
  QuestionGenerator([Random? random]) : _random = random ?? Random();

  static const minFactor = 3;
  static const maxFactor = 9;
  static const minAnswer = 20;

  final Random _random;

  /// A new question, never the same as [previous] (a wrong answer gets a
  /// new question).
  GateQuestion next({GateQuestion? previous}) {
    while (true) {
      final a = minFactor + _random.nextInt(maxFactor - minFactor + 1);
      final b = minFactor + _random.nextInt(maxFactor - minFactor + 1);
      if (a * b < minAnswer) continue;
      if (previous != null && previous.a == a && previous.b == b) continue;
      return (a: a, b: b);
    }
  }
}
