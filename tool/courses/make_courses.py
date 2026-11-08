"""Writes assets/data/world1/course_01.json .. course_15.json.

Every course follows teach -> twist -> payoff (SRS 4.5): one easy obstacle,
a harder version, then a reward moment (bolt arcs, a ramp, a bolt shower).
Courses take 15 to 25 s with the intended build. Each hides a golden gear,
often high up so it needs a part the child gets later (RUN-16).

Positions are px from the course start; heights are px above the ground.
The solver test (test/domain/sim/course_solver_test.dart) checks every
course after a change.

Usage, from the project root: python tool/courses/make_courses.py
"""

import json
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "assets" / "data" / "world1"


def steps(x, h, top=200, w=160):
    return {"type": "steps", "x": x, "stepWidth": w, "stepHeights": h,
            "topWidth": top}


def gap(x, w, water=False):
    d = {"type": "gap", "x": x, "width": w}
    if water:
        d["water"] = True
    return d


def gate(plate, x, seconds):
    return {"type": "timedGate", "plateX": plate, "x": x,
            "openSeconds": seconds}


def bar(x, w):
    return {"type": "barGap", "x": x, "width": w}


def switch(plate, x):
    return {"type": "heavySwitch", "plateX": plate, "x": x}


def mud(x, w):
    return {"type": "mud", "x": x, "width": w}


def leaf(x, w=60, h=170):
    return {"type": "leafPile", "x": x, "width": w, "height": h}


def ceiling(x, w, h=200):
    return {"type": "lowCeiling", "x": x, "width": w, "height": h}


def ramp(x, w=200):
    return {"type": "ramp", "x": x, "width": w}


def cps(*xs, pits=()):
    return [{"x": x, **({"pitStop": True} if x in pits else {})} for x in xs]


def b(*points):
    """Bolts as (x, y); a bare number is a bolt on the ground."""
    return [{"x": p, "y": 24} if isinstance(p, (int, float))
            else {"x": p[0], "y": p[1]} for p in points]


COURSES = {
    # Tutorial: just roll and collect. Gear: needs Spring feet (course 3).
    1: dict(rewardBolts=5, lengthPx=4600, checkpoints=cps(0, 2300),
            obstacles=[],
            bolts=b(700, 1400, 3800, 3950, 4100),
            gear={"x": 2600, "y": 200},
            intendedBuilds=[{}, {"parts": ["moves_legs"]}]),
    # One step, two steps, a tall staircase. Gear: on top, found by Legs.
    2: dict(rewardBolts=5, lengthPx=4000, checkpoints=cps(0, 1100, 2000),
            obstacles=[steps(600, [48], top=250),
                       steps(1300, [48, 48], top=250),
                       steps(2200, [48, 48, 48], top=350)],
            bolts=b((680, 72), (1550, 120), (2500, 120), (2800, 168),
                    3400, 3550),
            gear={"x": 2900, "y": 215},
            intendedBuilds=[{"parts": ["moves_legs"]}]),
    # A gap, a double gap, a splash gap. Gear: needs Spring feet.
    3: dict(rewardPartId="moves_spring_feet", lengthPx=4400,
            checkpoints=cps(0, 1300, 2500, 3300),
            obstacles=[gap(900, 100), gap(1700, 120), gap(2000, 120),
                       gap(2800, 130, water=True)],
            bolts=b(500, (960, 60), (1760, 60), (2060, 60), (2860, 60),
                    3900),
            gear={"x": 3600, "y": 200},
            intendedBuilds=[{}, {"parts": ["moves_legs"]}]),
    # Climb, swap at the pit stop, race two gates. Gear: Spring feet after
    # the pit stop.
    4: dict(rewardBolts=8, lengthPx=4700,
            checkpoints=cps(0, 1250, 1900, 3200, pits=(1900,)),
            obstacles=[steps(600, [48, 48], top=250), steps(1350, [48], top=150),
                       gate(2300, 3050, 3.2), gate(3450, 4200, 3.2)],
            bolts=b((680, 72), (900, 120), (1400, 72), 2500, 2700, 3700,
                    4450),
            gear={"x": 2080, "y": 200},
            intendedBuilds=[{"parts": ["moves_legs"],
                             "pitStops": [["moves_wheels"]]}]),
    # Big gaps for Spring feet, with bolt arcs. Gear: needs the Jetpack.
    5: dict(rewardBolts=8, lengthPx=4200,
            checkpoints=cps(0, 1300, 2400, 3000),
            obstacles=[gap(800, 160), gap(1500, 200),
                       gap(1900, 200, water=True), gap(2600, 200)],
            bolts=b(500, (900, 150), (1600, 150), (2000, 150), (2700, 150),
                    3500, 3600, 3700),
            gear={"x": 3250, "y": 330},
            intendedBuilds=[{"parts": ["moves_spring_feet"]}]),
    # A hop, then zoom off two ramps. Gear: needs the Jetpack.
    6: dict(rewardPartId="moves_jetpack", lengthPx=4300,
            checkpoints=cps(0, 1100, 2300, 3200),
            obstacles=[gap(700, 100), ramp(1400), gap(1600, 280),
                       ramp(2600), gap(2800, 280, water=True)],
            bolts=b(450, (760, 60), (1740, 150), (2940, 150), 3550, 3700,
                    3850, 4000),
            gear={"x": 3350, "y": 330},
            intendedBuilds=[{}]),
    # Fly over wide gaps, under a low roof. Gear: up high, found by flying.
    7: dict(rewardBolts=10, lengthPx=4600,
            checkpoints=cps(0, 1350, 2400, 3150),
            obstacles=[gap(700, 400), ceiling(1550, 600), gap(1700, 400),
                       gap(2600, 400, water=True)],
            bolts=b(400, (900, 72), (1900, 72), (2800, 72), 3800, 3900,
                    4000, 4100, 4200),
            gear={"x": 3400, "y": 330},
            intendedBuilds=[{"parts": ["moves_jetpack"]}]),
    # Climb, hop, climb; then longer gaps after the pit stop. Gear: Spring
    # feet in the second half.
    8: dict(rewardBolts=10, lengthPx=4100,
            checkpoints=cps(0, 1220, 2100, 3150, pits=(2100,)),
            obstacles=[steps(600, [48, 48]), gap(1300, 100),
                       steps(1600, [48], top=150), gap(2500, 140),
                       gap(2900, 140, water=True), gap(3300, 140)],
            bolts=b((680, 72), (950, 120), (1360, 60), (1700, 72),
                    (2560, 60), (2960, 60), (3360, 60), 3850, 3950),
            gear={"x": 3600, "y": 200},
            intendedBuilds=[{"parts": ["moves_legs"]},
                            {"parts": ["moves_legs"],
                             "pitStops": [["moves_spring_feet"]]}]),
    # Mud, then mud with gaps between. Gear: Spring feet.
    9: dict(rewardPartId="body_heavy_frame", lengthPx=4400,
            checkpoints=cps(0, 1250, 2300, 3400),
            obstacles=[mud(700, 400), gap(1400, 100), mud(1700, 500),
                       gap(2500, 100, water=True), mud(2900, 300)],
            bolts=b(500, 800, 1000, (1460, 60), 1800, 2000, (2560, 60),
                    3600, 3750),
            gear={"x": 3950, "y": 200},
            intendedBuilds=[{}]),
    # A heavy switch, then a switch and a hop, then one more. Gear: Spring
    # feet with the Heavy frame.
    10: dict(rewardBolts=12, lengthPx=4200,
             checkpoints=cps(0, 1400, 2550),
             obstacles=[switch(700, 1100), switch(1700, 2100), gap(2300, 100),
                        switch(2700, 3100)],
             bolts=b(400, 750, 1300, 1750, (2360, 60), 2500, 2750, 3400,
                     3550, 3700),
             gear={"x": 3900, "y": 200},
             intendedBuilds=[{"parts": ["body_heavy_frame"]}]),
    # Heavy for the switches, light for the mud. Gear: Spring feet after the
    # pit stop.
    11: dict(rewardPartId="arms_grabber", lengthPx=4400,
             checkpoints=cps(0, 1200, 2100, 3000, pits=(2100,)),
             obstacles=[switch(600, 1000), switch(1400, 1800), mud(2400, 500),
                        mud(3200, 500)],
             bolts=b(400, 650, 1200, 1450, 1900, 2500, 2800, 3300, 3600,
                     3950),
             gear={"x": 4150, "y": 200},
             intendedBuilds=[{"parts": ["body_heavy_frame"],
                              "pitStops": [["body_light_frame"]]}]),
    # Swing on a bar, then two in a row, then hop. Gear: Spring feet with
    # Grabber arms.
    12: dict(rewardBolts=12, lengthPx=4300,
             checkpoints=cps(0, 1150, 2450),
             obstacles=[bar(700, 300), bar(1300, 400), bar(1900, 400),
                        gap(2600, 100)],
             bolts=b(400, 850, 1500, 2100, (2660, 60), 3000, 3200, 3400,
                     3600, 3800),
             gear={"x": 4050, "y": 200},
             intendedBuilds=[{"parts": ["arms_grabber"]}]),
    # Leaf piles to fly over or blow away. Gear: in reach of the Jetpack or
    # Spring feet with Fan arms.
    13: dict(rewardBolts=15, lengthPx=4200,
             checkpoints=cps(0, 1150, 2200, 2800),
             obstacles=[leaf(800), leaf(1500), leaf(1800), gap(2500, 120)],
             bolts=b(400, (830, 200), (1530, 200), (1830, 200), (2560, 72),
                     3350, 3450, 3550, 3650, 3750, 3850),
             gear={"x": 3000, "y": 215},
             intendedBuilds=[{"parts": ["moves_jetpack"]}]),
    # Steps, gaps and switches with two pit stops. Gear: Spring feet with
    # the Heavy frame, at the end.
    14: dict(rewardBolts=15, lengthPx=4500,
             checkpoints=cps(0, 1030, 1600, 2150, 2700, 3450,
                             pits=(1600, 2700)),
             obstacles=[steps(500, [48, 48], top=150), steps(1100, [48], top=150),
                        gap(1900, 200), gap(2300, 200, water=True),
                        switch(2950, 3300), switch(3600, 3950)],
             bolts=b(300, (550, 72), (800, 120), (1200, 72), 1500,
                     (2000, 150), (2400, 150), 2800, 3000, 3400, 3650, 4100),
             gear={"x": 4300, "y": 200},
             intendedBuilds=[{"parts": ["moves_legs"],
                              "pitStops": [["moves_spring_feet"],
                                           ["body_heavy_frame"]]}]),
    # The finale: every obstacle, three pit stops. Gear: Spring feet in the
    # last part.
    15: dict(rewardPartId="head_gold", lengthPx=5900,
             checkpoints=cps(0, 830, 1500, 2300, 3050, 3900, 4400, 5000,
                             pits=(1500, 3050, 4400)),
             obstacles=[steps(300, [48, 48], top=150), gap(900, 100),
                        mud(1100, 250), gate(1650, 2250, 2.6), ramp(2400),
                        gap(2600, 280, water=True), ceiling(3250, 600),
                        gap(3350, 400), leaf(4100), switch(4550, 4900),
                        bar(5050, 400)],
             bolts=b(200, (450, 72), (960, 60), 1200, 1800, 2100,
                     (2740, 150), (3550, 72), (4130, 200), 4600, 5250, 5500),
             gear={"x": 5700, "y": 200},
             intendedBuilds=[{"parts": ["moves_legs"],
                              "pitStops": [["moves_wheels"],
                                           ["moves_jetpack"],
                                           ["moves_wheels", "body_heavy_frame",
                                            "arms_grabber"]]}]),
}

ORDER = ["id", "world", "index", "hintKey", "rewardBolts", "rewardPartId",
         "lengthPx", "checkpoints", "bolts", "gear", "obstacles",
         "intendedBuilds"]


def main():
    for i, c in COURSES.items():
        d = {"id": f"w1_c{i:02d}", "world": 1, "index": i,
             "hintKey": f"hintCourse{i}", **c}
        d = {k: d[k] for k in ORDER if k in d}
        (OUT / f"course_{i:02d}.json").write_text(
            json.dumps(d, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
