"""
Map extracted Arabic segments to app audio file names.

Strategy:
1. Load all app duas with their Arabic texts and TTS durations
2. Transcribe each extracted segment with Whisper (cached to transcripts.json)
3. Match by word overlap between transcript and known Arabic text
4. Duration-based confidence check (human vs TTS speed ratio)
5. Copy HIGH matches to assets/audio/; handle morning/evening pairs sharing text
"""
import json, os, re, shutil, subprocess

EXTRACTED_DIR  = r"C:\Users\UNSTOPPABLE\Music\apps\New folder\dhikr365\assets\audio\extracted"
APP_AUDIO_DIR  = r"C:\Users\UNSTOPPABLE\Music\apps\New folder\dhikr365\assets\audio"
TRANS_ROOT     = r"C:\Users\UNSTOPPABLE\Music\apps\New folder\dhikr365\assets\translations"
TRANSCRIPT_CACHE = os.path.join(EXTRACTED_DIR, "transcripts.json")
FFPROBE        = (r"C:\Users\UNSTOPPABLE\AppData\Local\Microsoft\WinGet\Packages"
                  r"\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe"
                  r"\ffmpeg-8.1.1-full_build\bin\ffprobe.exe")
CATEGORIES     = ["morning", "evening", "food", "graveyard", "parents", "protection"]

# ── helpers ───────────────────────────────────────────────────────────────────

def get_duration(path):
    r = subprocess.run([FFPROBE, "-v", "quiet", "-show_entries",
                        "format=duration", "-of",
                        "default=noprint_wrappers=1:nokey=1", path],
                       capture_output=True, text=True)
    try:
        return float(r.stdout.strip())
    except ValueError:
        return 0.0

# Build regex patterns using chr() to avoid Unicode range ambiguity.
# Arabic letters are U+0621-U+063A and U+0641-U+064A -- must NOT be removed.
# Diacritics/combining marks to remove:
#   U+0610-U+061A: Arabic combining marks (before letters start at U+0621)
#   U+064B-U+065F: Arabic diacritics/tashkeel (fathatan through wavy hamza)
#   U+0670:        Arabic superscript alef (combining)
#   U+06D6-U+06ED: Arabic small high combining marks (Indopak style)
_AR_DIAC = re.compile(
    "[" + chr(0x0610) + "-" + chr(0x061A)
    + chr(0x064B) + "-" + chr(0x065F)
    + chr(0x0670)
    + chr(0x06D6) + "-" + chr(0x06ED)
    + "]"
)
# Keep only Arabic letters U+0621-U+064A and whitespace
_AR_KEEP = re.compile("[^" + chr(0x0621) + "-" + chr(0x064A) + r"\s]")

def normalize_ar(text):
    text = _AR_DIAC.sub("", text)
    # Normalize alef variants: madda(622) hamzaAbove(623) hamzaBelow(625) wasla(671-675) -> alef(627)
    text = re.sub(
        "[" + chr(0x0622) + chr(0x0623) + chr(0x0625)
        + chr(0x0671) + "-" + chr(0x0675) + "]",
        chr(0x0627), text
    )
    # Normalize alef maqsura(649), Farsi yeh(06CC), Uzbek(06D0), Uyghur(06D2) -> ya(064A)
    text = re.sub(
        "[" + chr(0x0649) + chr(0x06CC) + chr(0x06D0) + chr(0x06D2) + "]",
        chr(0x064A), text
    )
    # Normalize ta marbuta(629) -> ha(647)
    text = re.sub(chr(0x0629), chr(0x0647), text)
    # Normalize kaf variants Keheh(06A9) Swash(06AA) -> kaf(643)
    text = re.sub("[" + chr(0x06A9) + chr(0x06AA) + "]", chr(0x0643), text)
    # Strip tatweel, punctuation, digits, Latin -- keep only Arabic letters + whitespace
    text = _AR_KEEP.sub(" ", text)
    return re.sub(r"\s+", " ", text).strip()

def word_overlap(trans_text, dua_text):
    wt = set(normalize_ar(trans_text).split())
    wd = set(normalize_ar(dua_text).split())
    if not wt:
        return 0.0
    return len(wt & wd) / len(wt)

# ── load app duas ─────────────────────────────────────────────────────────────

app_duas = []
for cat in CATEGORIES:
    p = os.path.join(TRANS_ROOT, cat, "en.json")
    if not os.path.exists(p):
        continue
    with open(p, encoding="utf-8") as f:
        j = json.load(f)
    for key, d in j["dhikrs"].items():
        if "audioPath" in d and d["audioPath"]:
            audio_file = os.path.basename(d["audioPath"])
        else:
            audio_file = f"{cat}_{key}.mp3"
        tts_path = os.path.join(APP_AUDIO_DIR, audio_file)
        tts_dur  = get_duration(tts_path) if os.path.exists(tts_path) else 0.0
        app_duas.append({
            "id":         key,
            "category":   cat,
            "no":         d.get("dhikr_no", 0),
            "title":      d.get("title", ""),
            "arabic":     d.get("arabicText", ""),
            "norm_ar":    normalize_ar(d.get("arabicText", "")),
            "audio_file": audio_file,
            "tts_dur":    tts_dur,
        })

print(f"Loaded {len(app_duas)} app duas.")

# Build sibling pairs map: duas sharing the same Arabic text (morning/evening)
text_to_duas = {}
for d in app_duas:
    k = d["norm_ar"]
    text_to_duas.setdefault(k, []).append(d)
shared_pairs = {k: v for k, v in text_to_duas.items() if len(v) > 1}
print(f"  {len(shared_pairs)} groups sharing the same Arabic text.\n")

# ── load manifest ─────────────────────────────────────────────────────────────

manifest_path = os.path.join(EXTRACTED_DIR, "arabic_manifest.json")
if not os.path.exists(manifest_path):
    print("ERROR: arabic_manifest.json not found. Run extract_arabic.py first.")
    exit(1)

with open(manifest_path, encoding="utf-8") as f:
    arabic_segs = json.load(f)

print(f"Loaded {len(arabic_segs)} extracted Arabic segments.\n")

# ── transcribe (with cache) ───────────────────────────────────────────────────

if os.path.exists(TRANSCRIPT_CACHE):
    print(f"Loading transcripts from cache: {TRANSCRIPT_CACHE}", flush=True)
    with open(TRANSCRIPT_CACHE, encoding="utf-8") as f:
        transcript_cache = json.load(f)
    print(f"  Loaded {len(transcript_cache)} cached transcripts.\n", flush=True)
else:
    transcript_cache = {}

need_transcribe = [seg for seg in arabic_segs if seg["file"] not in transcript_cache]

if need_transcribe:
    print(f"Transcribing {len(need_transcribe)} segments (loading Whisper)...", flush=True)
    from faster_whisper import WhisperModel
    model = WhisperModel("tiny", device="cpu", compute_type="int8")
    print("Model ready.\n", flush=True)

    for seg in need_transcribe:
        seg_path = os.path.join(EXTRACTED_DIR, seg["file"])
        if not os.path.exists(seg_path):
            transcript_cache[seg["file"]] = ""
            continue
        try:
            result, _ = model.transcribe(
                seg_path, language="ar",
                condition_on_previous_text=False,
                beam_size=2, best_of=2,
            )
            text = " ".join(s.text for s in result).strip()
        except Exception:
            text = ""
        transcript_cache[seg["file"]] = text
        word_count = len(text.split()) if text else 0
        seg_dur = get_duration(seg_path)
        print(f"  ar_{seg['seq']:03d} ({seg_dur:5.1f}s): {word_count} words", flush=True)

    with open(TRANSCRIPT_CACHE, "w", encoding="utf-8") as f:
        json.dump(transcript_cache, f, indent=2, ensure_ascii=False)
    print(f"\nTranscripts cached: {TRANSCRIPT_CACHE}\n", flush=True)
else:
    print("All transcripts loaded from cache.\n", flush=True)

# ── build seg_data ────────────────────────────────────────────────────────────

seg_data = []
for seg in arabic_segs:
    seg_path = os.path.join(EXTRACTED_DIR, seg["file"])
    text     = transcript_cache.get(seg["file"], "")
    seg_dur  = get_duration(seg_path) if os.path.exists(seg_path) else 0.0
    seg_data.append({**seg, "transcript": text, "seg_dur": round(seg_dur, 2)})

# ── match ─────────────────────────────────────────────────────────────────────

print("Matching...\n", flush=True)
mapping = []

for sd in seg_data:
    candidates = []
    for dua in app_duas:
        if not dua["arabic"]:
            continue
        score = word_overlap(sd["transcript"], dua["arabic"])
        if score > 0:
            candidates.append((score, dua))
    candidates.sort(key=lambda x: x[0], reverse=True)

    best_score = candidates[0][0] if candidates else 0.0
    best_dua   = candidates[0][1] if candidates else None

    dur_ok = False
    if best_dua and best_dua["tts_dur"] > 0 and sd["seg_dur"] > 0:
        ratio = sd["seg_dur"] / best_dua["tts_dur"]
        dur_ok = 0.25 <= ratio <= 3.0

    if best_score >= 0.4 and dur_ok:
        conf = "HIGH"
    elif best_score >= 0.25:
        conf = "MED"
    else:
        conf = "LOW"

    siblings = []
    if best_dua:
        norm     = best_dua["norm_ar"]
        siblings = text_to_duas.get(norm, [best_dua])

    mapping.append({
        "seq":        sd["seq"],
        "seg_file":   sd["file"],
        "seg_dur":    sd["seg_dur"],
        "transcript": sd["transcript"][:200],
        "txt_score":  round(best_score, 3),
        "confidence": conf,
        "best_dua":   best_dua["id"]   if best_dua else None,
        "best_title": best_dua["title"] if best_dua else "",
        "siblings":   [s["audio_file"] for s in siblings],
        "tts_dur":    best_dua["tts_dur"] if best_dua else 0,
    })

# ── print summary ─────────────────────────────────────────────────────────────

print(f"\n{'#':<4} {'Dur':>6}  {'Score':>6}  {'Conf':<5}  Audio files")
print("-" * 100)
for m in mapping:
    files = ", ".join(m["siblings"]) if m["siblings"] else "---"
    print(f"{m['seq']:<4} {m['seg_dur']:>6.1f}s {m['txt_score']:>6.3f}  {m['confidence']:<5}  {files}")

high = [m for m in mapping if m["confidence"] == "HIGH"]
med  = [m for m in mapping if m["confidence"] == "MED"]
print(f"\nHIGH={len(high)}  MED={len(med)}  LOW/unmatched={len(mapping)-len(high)-len(med)}")

# ── copy ──────────────────────────────────────────────────────────────────────

print("\nCopying HIGH-confidence matches to assets/audio/ ...")
copied = []
seen_dst = set()
for m in sorted(high, key=lambda x: -x["txt_score"]):
    src = os.path.join(EXTRACTED_DIR, m["seg_file"])
    if not os.path.exists(src):
        continue
    for fname in m["siblings"]:
        if fname in seen_dst:
            continue
        seen_dst.add(fname)
        dst = os.path.join(APP_AUDIO_DIR, fname)
        shutil.copy2(src, dst)
        copied.append(f"  ar_{m['seq']:03d} ({m['seg_dur']:.1f}s, score={m['txt_score']:.3f}) -> {fname}")

for line in copied:
    print(line)
print(f"\nReplaced {len(copied)} audio files.")

out = os.path.join(EXTRACTED_DIR, "mapping.json")
with open(out, "w", encoding="utf-8") as f:
    json.dump(mapping, f, indent=2, ensure_ascii=False)
print(f"Mapping saved: {out}")
