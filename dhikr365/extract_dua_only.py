"""
Extract only the dua recitation from each hisnmuslim audio file,
removing intro speech. Uses Whisper word timestamps + app Arabic text matching.
"""
import json, os, re, subprocess, sys, io, shutil
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

FFMPEG       = (r"C:\Users\UNSTOPPABLE\AppData\Local\Microsoft\WinGet\Packages"
                r"\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe"
                r"\ffmpeg-8.1.1-full_build\bin\ffmpeg.exe")
APP_AUDIO    = r"C:\Users\UNSTOPPABLE\Music\apps\New folder\dhikr365\assets\audio"
TRANS_ROOT   = r"C:\Users\UNSTOPPABLE\Music\apps\New folder\dhikr365\assets\translations"
DOWNLOAD_DIR = os.path.join(APP_AUDIO, "_downloads")
CATEGORIES   = ["morning", "evening", "food", "graveyard", "parents", "protection"]

# ── Arabic normalizer ──────────────────────────────────────────────────────────
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

# ── helpers ────────────────────────────────────────────────────────────────────
def get_duration(path):
    r = subprocess.run(
        [FFMPEG.replace("ffmpeg.exe","ffprobe.exe"), "-v", "quiet",
         "-show_entries", "format=duration",
         "-of", "default=noprint_wrappers=1:nokey=1", path],
        capture_output=True, text=True)
    try: return float(r.stdout.strip())
    except: return 0.0

def trim_audio(src, dst, start, end=None, pad_start=0.1, pad_end=0.3):
    t0 = max(0, start - pad_start)
    cmd = [FFMPEG, "-y", "-i", src, "-ss", f"{t0:.3f}"]
    if end is not None:
        cmd += ["-to", f"{end + pad_end:.3f}"]
    cmd += ["-af", f"afade=t=in:st=0:d=0.05,afade=t=out:st={((end or get_duration(src))+pad_end - t0 - 0.1):.2f}:d=0.1",
            dst]
    r = subprocess.run(cmd, capture_output=True)
    return r.returncode == 0

def find_dua_span(words, dua_norm_words):
    """
    Find the best contiguous window of Whisper words that covers the most dua words.
    Returns (start_time, end_time, coverage_score).
    words = [(start, end, word_norm), ...]
    """
    if not dua_norm_words or not words:
        return None, None, 0.0

    dua_set = set(dua_norm_words)
    n = len(words)

    best_score = 0.0
    best_span  = (None, None)

    # Sliding window: try all windows, score = overlap with dua words
    # Use a window that covers at most 3x the dua word count
    max_win = min(n, len(dua_norm_words) * 4)

    for start_i in range(n):
        covered = set()
        for end_i in range(start_i, min(start_i + max_win, n)):
            w_norm = words[end_i][2]
            if w_norm in dua_set:
                covered.add(w_norm)
            score = len(covered) / len(dua_set)
            if score > best_score:
                best_score = score
                best_span  = (words[start_i][0], words[end_i][1])
            if score >= 0.95:
                break
        if best_score >= 0.95:
            break

    return best_span[0], best_span[1], best_score

# ── load all app duas ──────────────────────────────────────────────────────────
app_duas = {}  # audio_file -> (arabic_text, norm_words)
for cat in CATEGORIES:
    p = os.path.join(TRANS_ROOT, cat, "en.json")
    if not os.path.exists(p):
        continue
    with open(p, encoding="utf-8") as f:
        j = json.load(f)
    for key, d in j["dhikrs"].items():
        if "audioPath" in d and d["audioPath"]:
            fname = os.path.basename(d["audioPath"])
        else:
            fname = f"{cat}_{key}.mp3"
        ar = d.get("arabicText", "")
        norm = normalize_ar(ar)
        app_duas[fname] = norm.split() if norm else []

print(f"Loaded {len(app_duas)} app duas.\n")

# ── build: which download file serves which app audio files ───────────────────
# From download_hisnmuslim_audio.py: assignments map (recompute quickly)
import urllib.request
JSON_URL = "https://raw.githubusercontent.com/wafaaelmaandy/Hisn-Muslim-Json/master/husn_en.json"
print("Fetching husn_en.json...", flush=True)
with urllib.request.urlopen(JSON_URL) as r:
    raw_data = json.loads(r.read().decode("utf-8-sig"))
chapters = raw_data.get("English", raw_data) if isinstance(raw_data, dict) else raw_data
json_items = {}
for ch in chapters:
    for item in ch.get("TEXT", []):
        if item.get("AUDIO") and item.get("ARABIC_TEXT"):
            json_items[item["ID"]] = {
                "norm_ar": normalize_ar(item["ARABIC_TEXT"]),
                "audio_url": item["AUDIO"],
            }

# Match each app dua to best JSON item
def match_item(dua_norm_words):
    dua_set = set(dua_norm_words)
    if not dua_set:
        return None, 0.0
    best_score, best_id = 0.0, None
    for iid, jitem in json_items.items():
        jwords = set(jitem["norm_ar"].split())
        score = len(dua_set & jwords) / len(dua_set)
        if score > best_score:
            best_score = score
            best_id = iid
    return best_id, best_score

# Build: download_file -> list of app_audio_files using it
dl_to_app = {}  # item_id -> [app_audio_file, ...]
for fname, norm_words in app_duas.items():
    item_id, score = match_item(norm_words)
    if item_id and score >= 0.3:
        dl_to_app.setdefault(item_id, []).append(fname)

print(f"Matched to {len(dl_to_app)} unique download items.\n")

# ── load whisper ───────────────────────────────────────────────────────────────
print("Loading Whisper (small model)...", flush=True)
from faster_whisper import WhisperModel
model = WhisperModel("small", device="cpu", compute_type="int8")
print("Ready.\n", flush=True)

# ── process each download file ─────────────────────────────────────────────────
results = []

for item_id, app_files in sorted(dl_to_app.items()):
    dl_path = os.path.join(DOWNLOAD_DIR, f"item_{item_id}.mp3")
    if not os.path.exists(dl_path):
        for f in app_files:
            results.append(f"  SKIP item_{item_id} (no download file) -> {f}")
        continue

    total_dur = get_duration(dl_path)
    print(f"item_{item_id:03d} ({total_dur:.1f}s)  serves: {', '.join(app_files)}", flush=True)

    # For morning/evening split files, determine which portion to use
    # Items 77,78,80,81,89,90 have separate morning and evening files
    SPLIT_ITEMS = {77, 78, 80, 81, 89, 90}
    is_split = item_id in SPLIT_ITEMS and len(app_files) >= 2

    # Transcribe with word timestamps
    segments, _ = model.transcribe(
        dl_path, language="ar",
        word_timestamps=True,
        condition_on_previous_text=False,
        beam_size=3,
    )
    all_words = []
    for seg in segments:
        if seg.words:
            for w in seg.words:
                norm_w = normalize_ar(w.word)
                if norm_w:
                    all_words.append((w.start, w.end, norm_w))

    print(f"  Transcribed: {len(all_words)} words (0-{total_dur:.1f}s)", flush=True)

    # For each app file, find the dua span in the audio
    for fname in app_files:
        dua_words = app_duas.get(fname, [])
        if not dua_words:
            results.append(f"  SKIP {fname} (no Arabic text)")
            continue

        t_start, t_end, score = find_dua_span(all_words, dua_words)

        if score < 0.25 or t_start is None:
            # Fallback: use whole file
            t_start, t_end = 0, None
            print(f"  {fname}: score={score:.2f} LOW - using full audio", flush=True)
        else:
            print(f"  {fname}: score={score:.2f}  span={t_start:.1f}s-{t_end:.1f}s", flush=True)

        dst = os.path.join(APP_AUDIO, fname)
        ok = trim_audio(dl_path, dst, t_start, t_end)
        dur = get_duration(dst)
        status = "OK" if ok else "ERR"
        end_str = f"{t_end:.1f}" if t_end is not None else "end"
        results.append(f"  {status}  item_{item_id:03d} ({score:.2f}) span={t_start:.1f}-{end_str}s dur={dur:.1f}s -> {fname}")

    print(flush=True)

# ── summary ────────────────────────────────────────────────────────────────────
print("=" * 70)
ok_count  = sum(1 for r in results if r.strip().startswith("OK"))
err_count = sum(1 for r in results if r.strip().startswith("ERR"))
print(f"Done.  OK={ok_count}  ERR/SKIP={err_count + len([r for r in results if 'SKIP' in r])}")
print()
for r in results:
    print(r)
