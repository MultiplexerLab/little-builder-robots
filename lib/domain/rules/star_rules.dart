import 'dart:math';

import 'package:little_builder_robots/domain/models/progress.dart';
import 'package:little_builder_robots/domain/models/run_outcome.dart';

/// The three stars of RES-02, one flag per star so Result can show each
/// rule's icon under its star (RES-01).
typedef StarAward = ({bool finish, bool allBolts, bool noFalls});

extension StarAwardCount on StarAward {
  int get count => [finish, allBolts, noFalls].where((earned) => earned).length;
}

/// RES-02: 1 for finishing, +1 for all bolts, +1 for no falls. Bumps are not
/// falls. A run that did not finish earns nothing.
StarAward starsFor(RunOutcome outcome) {
  if (!outcome.finished) {
    return (finish: false, allBolts: false, noFalls: false);
  }
  return (
    finish: true,
    allBolts: outcome.boltsCollected >= outcome.boltsOnCourse,
    noFalls: outcome.falls == 0,
  );
}

/// RES-06: merges a run into the stored best. A worse replay never lowers
/// stars or best bolts.
CourseResult bestResult(CourseResult previous, RunOutcome outcome) =>
    previous.copyWith(
      stars: max(previous.stars, starsFor(outcome).count),
      bestBolts: max(previous.bestBolts, outcome.boltsCollected),
      completed: previous.completed || outcome.finished,
      foundGear: previous.foundGear || (outcome.finished && outcome.foundGear),
    );
