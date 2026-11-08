"""Builds every audio clip the game plays into assets/audio (AUD-01 to
AUD-05).

1. synth.py makes the sound effects and music loops.
2. voice.ps1 speaks every voiced line from the ARB file (placeholder TTS).
3. ffmpeg normalises loudness (AUD-05) and encodes mono AAC .m4a.

Usage, from the project root: python tool/audio/build_audio.py
Needs ffmpeg on the PATH and Windows PowerShell for the voice step.
"""

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOL = Path(__file__).resolve().parent
ASSETS = ROOT / "assets" / "audio"

# ARB keys a child hears (AUD-02). Grown-ups text is never voiced (PAR-10).
VOICED_PREFIXES = ("goodAt", "hint", "say", "stickerClue", "tutorial")
VOICED_KEYS = {
    "firstRunQuestion", "homeGreeting", "homeIdlePlay", "testTrackLocked",
    "testTrackHint", "needMoreBolts", "partFromCourse", "pitStopHint",
    "tryNewParts", "screenResult", "newPartTitle", "newStickerTitle",
    "restMessage",
}

# Target loudness in LUFS: voice and effects at one level, music under them.
LOUDNESS = {"voice": -16, "sfx": -18, "music": -22}


def voiced_lines():
    arb = json.loads((ROOT / "lib/core/l10n/app_en.arb").read_text("utf-8"))
    return {
        key: text for key, text in arb.items()
        if not key.startswith("@")
        and (key in VOICED_KEYS or key.startswith(VOICED_PREFIXES))
    }


def encode(src: Path, dst: Path, loudness: int):
    dst.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", str(src),
         "-af", f"loudnorm=I={loudness}:TP=-1.5:LRA=11",
         "-ar", "44100", "-ac", "1", "-c:a", "aac", "-b:a", "96k",
         str(dst)],
        check=True)


def main():
    if shutil.which("ffmpeg") is None:
        sys.exit("ffmpeg is needed on the PATH")
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        subprocess.run([sys.executable, "-I", str(TOOL / "synth.py"),
                        str(work)], check=True)

        lines = voiced_lines()
        lines_file = work / "lines.json"
        lines_file.write_text(json.dumps(lines), "utf-8")
        subprocess.run(
            ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
             "-File", str(TOOL / "voice.ps1"), str(lines_file),
             str(work / "voice")],
            check=True)

        for group, folder in (("sfx", "sfx"), ("music", "music"),
                              ("voice", "voice")):
            out = ASSETS / ("voice/en_GB" if group == "voice" else folder)
            for wav in sorted((work / folder).glob("*.wav")):
                encode(wav, out / f"{wav.stem}.m4a", LOUDNESS[group])
        print(f"Built {len(lines)} voice lines, effects and music in {ASSETS}")


if __name__ == "__main__":
    main()
