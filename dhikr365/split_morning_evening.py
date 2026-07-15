"""
Split combined morning+evening audio files into separate morning and evening files.
Uses faster-whisper word timestamps to find where the evening version starts.
"""
import os, re, subprocess, sys, io, shutil
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

FFMPEG = (r"C:\Users\UNSTOPPABLE\AppData\Local\Microsoft\WinGet\Packages"
          r"\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe"
          r"\ffmpeg-8.1.1-full_build\bin\ffmpeg.exe")

APP_AUDIO_DIR  = r"C:\Users\UNSTOPPABLE\Music\apps\New folder\dhikr365\assets\audio"
DOWNLOAD_DIR   = os.path.join(APP_AUDIO_DIR, "_downloads")

# Items to split: (item_id, morning_file, evening_file)
SPLIT_PAIRS = [
    (77, "morning_m_asbahna_wal_mulku.mp3",      "evening_e_amsayna_wal_mulku.mp3"),
    (78, "morning_m_allahumma_bika_asbahna.mp3", "evening_e_allahumma_bika_amsayna.mp3"),
    (80, "morning_m_allahumma_ashhaduka.mp3",     "evening_e_allahumma_inni_amsaytu.mp3"),
    (81, "morning_m_allahumma_ma_asbaha.mp3",     "evening_e_allahumma_ma_amsa.mp3"),
    (89, "morning_m_morning_blessings.mp3",       "evening_e_evening_prayer_good_night.mp3"),
    (90, "morning_m_asbahna_ala_fitrah.mp3",      "evening_e_amsayna_ala_fitrah.mp3"),
]

# Arabic normalizer (same as before)
_AR_DIAC = re.compile(
    "[" + chr(0x0610) + "-" + chr(0x061A)
    + chr(0x064B) + "-" + chr(0x065F)
    + chr(0x0670) + chr(0x06D6) + "-" + chr(0x06ED) + "]"
)
_AR_KEEP = re.compile("[^" + chr(0x0621) + "-" + chr(0x064A) + r"\s]")

def normalize_ar(text):
    text = _AR_DIAC.sub("", text)
    text = re.sub("[" + chr(0x0622) + chr(0x0623) + chr(0x0625) + chr(0x0671) + "-" + chr(0x0675) + "]", chr(0x0627), text)
    text = re.sub("[" + chr(0x0649) + chr(0x06CC) + chr(0x06D0) + chr(0x06D2) + "]", chr(0x064A), text)
    text = re.sub("[" + chr(0x0629) + chr(0x06C3) + "]", chr(0x0647), text)
    text = re.sub("[" + chr(0x06A9) + chr(0x06AA) + "]", chr(0x0643), text)
    text = _AR_KEEP.sub(" ", text)
    return re.sub(r"\s+", " ", text).strip()

# Evening trigger words (normalized)
EVENING_WORDS = {
    normalize_ar(chr(0x0623)+chr(0x0645)+chr(0x0633)+chr(0x064A)+chr(0x0646)+chr(0x0627)),  # امسينا
    normalize_ar(chr(0x0623)+chr(0x0645)+chr(0x0633)+chr(0x064A)+chr(0x0646)),               # امسين
    normalize_ar(chr(0x0648)+chr(0x0623)+chr(0x0645)+chr(0x0633)+chr(0x064A)+chr(0x0646)+chr(0x0627)),  # وامسينا
    normalize_ar(chr(0x0623)+chr(0x0645)+chr(0x0633)+chr(0x0649)),                           # امسى
}
print(f"Evening trigger words: {EVENING_WORDS}\n")

def get_duration(path):
    FFPROBE = FFMPEG.replace("ffmpeg.exe", "ffprobe.exe")
    r = subprocess.run([FFPROBE, "-v", "quiet", "-show_entries",
                        "format=duration", "-of",
                        "default=noprint_wrappers=1:nokey=1", path],
                       capture_output=True, text=True)
    try:
        return float(r.stdout.strip())
    except:
        return 0.0

def trim_audio(src, dst, start, end=None):
    cmd = [FFMPEG, "-y", "-i", src, "-ss", str(start)]
    if end is not None:
        cmd += ["-to", str(end)]
    cmd += ["-c", "copy", dst]
    r = subprocess.run(cmd, capture_output=True)
    return r.returncode == 0

print("Loading faster-whisper model...", flush=True)
from faster_whisper import WhisperModel
model = WhisperModel("small", device="cpu", compute_type="int8")
print("Model ready.\n", flush=True)

results = []

for item_id, morning_file, evening_file in SPLIT_PAIRS:
    src = os.path.join(DOWNLOAD_DIR, f"item_{item_id}.mp3")
    if not os.path.exists(src):
        print(f"item_{item_id}: source not found, skipping")
        continue

    total_dur = get_duration(src)
    print(f"item_{item_id} ({total_dur:.1f}s) — transcribing with word timestamps...", flush=True)

    # Transcribe with word-level timestamps
    segments, _ = model.transcribe(
        src, language="ar",
        word_timestamps=True,
        condition_on_previous_text=False,
        beam_size=3,
    )

    # Collect all words with timestamps
    all_words = []
    for seg in segments:
        if seg.words:
            for w in seg.words:
                all_words.append((w.start, w.end, w.word.strip()))

    print(f"  {len(all_words)} words transcribed", flush=True)

    # Find the first evening-trigger word
    split_time = None
    for start, end, word in all_words:
        norm = normalize_ar(word)
        if norm in EVENING_WORDS:
            split_time = start
            print(f"  Evening trigger '{word}' at {start:.2f}s", flush=True)
            break

    if split_time is None:
        # Fallback: try silence-based split (find longest gap in middle 40-60% of audio)
        print(f"  No evening word found by Whisper — trying silence detection...", flush=True)
        FFPROBE = FFMPEG.replace("ffmpeg.exe", "ffprobe.exe")
        r = subprocess.run(
            [FFMPEG, "-i", src, "-af",
             "silencedetect=noise=-35dB:d=0.5",
             "-f", "null", "-"],
            capture_output=True, text=True
        )
        # parse silence_end times from middle 30-70% of audio
        midlo, midhi = total_dur * 0.30, total_dur * 0.70
        silence_ends = []
        for line in (r.stdout + r.stderr).splitlines():
            m = re.search(r"silence_end: ([\d.]+)", line)
            if m:
                t = float(m.group(1))
                if midlo <= t <= midhi:
                    silence_ends.append(t)
        if silence_ends:
            # pick the silence end that's closest to the midpoint
            mid = total_dur / 2
            split_time = min(silence_ends, key=lambda t: abs(t - mid))
            print(f"  Silence-based split at {split_time:.2f}s", flush=True)
        else:
            # Last resort: split at midpoint
            split_time = total_dur / 2
            print(f"  No silence found — splitting at midpoint {split_time:.2f}s", flush=True)

    # Trim morning and evening
    morning_dst = os.path.join(APP_AUDIO_DIR, morning_file)
    evening_dst = os.path.join(APP_AUDIO_DIR, evening_file)

    ok_m = trim_audio(src, morning_dst, 0, split_time)
    ok_e = trim_audio(src, evening_dst, split_time)

    m_dur = get_duration(morning_dst)
    e_dur = get_duration(evening_dst)

    status = "OK" if (ok_m and ok_e) else "ERR"
    print(f"  {status}  morning={m_dur:.1f}s  evening={e_dur:.1f}s\n", flush=True)
    results.append(f"  {status}  item_{item_id:03d}  split@{split_time:.1f}s  -> {morning_file} + {evening_file}")

print("="*60)
for r in results:
    print(r)
print(f"\nDone. {sum(1 for r in results if 'OK' in r)}/{len(results)} splits successful.")
