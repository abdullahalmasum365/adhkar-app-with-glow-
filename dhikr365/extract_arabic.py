"""
Extract Arabic-only dua segments from Hisnul Muslim CD recordings.
Uses ffmpeg silence detection + faster-whisper language ID to keep only Arabic.
"""
import subprocess, json, os, re, sys, tempfile

FF   = r"C:\Users\UNSTOPPABLE\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1.1-full_build\bin\ffmpeg.exe"
FFP  = FF.replace("ffmpeg.exe", "ffprobe.exe")
CD1  = r"C:\Users\UNSTOPPABLE\Downloads\any share\Hisnul-Muslim_CD_1_(www.TheChoice.one).mp3"
CD2  = r"C:\Users\UNSTOPPABLE\Downloads\any share\Hisnul-Muslim_CD_2_(www.TheChoice.one).mp3"
OUT  = r"C:\Users\UNSTOPPABLE\Music\apps\New folder\dhikr365\assets\audio\extracted"

os.makedirs(OUT, exist_ok=True)

# ── helpers ──────────────────────────────────────────────────────────────────

def get_duration(path):
    r = subprocess.run([FFP, "-v", "quiet", "-show_entries", "format=duration",
                        "-of", "default=noprint_wrappers=1:nokey=1", path],
                       capture_output=True, text=True)
    return float(r.stdout.strip())

def silence_boundaries(path, db=-35, min_dur=0.35):
    """Return list of (sil_start, sil_end) from silencedetect."""
    cmd = [FF, "-i", path, "-af", f"silencedetect=noise={db}dB:d={min_dur}",
           "-f", "null", "-"]
    r = subprocess.run(cmd, capture_output=True, text=True)
    starts = [float(x) for x in re.findall(r"silence_start: ([0-9.]+)", r.stderr)]
    ends   = [float(x) for x in re.findall(r"silence_end: ([0-9.]+) \|",  r.stderr)]
    return list(zip(starts, ends))

def build_speech_segs(silences, total_dur, min_speech=1.5):
    """Convert silence pairs → speech (start, end, dur) list."""
    segs, pos = [], 0.0
    for ss, se in silences:
        d = ss - pos
        if d >= min_speech:
            segs.append((pos, ss, d))
        pos = se
    d = total_dur - pos
    if d >= min_speech:
        segs.append((pos, total_dur, d))
    return segs

def extract_mp3(src, start, dur, dst):
    subprocess.run([FF, "-y", "-ss", str(start), "-i", src,
                    "-t", str(dur), "-acodec", "libmp3lame", "-ar", "44100",
                    "-b:a", "128k", dst], capture_output=True)

def split_long(src, start, dur, db=-35, min_sil=0.25, min_speech=1.5):
    """
    Sub-split a segment that is >30s using a tighter silence threshold.
    Returns list of (abs_start, dur) pairs, or original if no sub-splits found.
    """
    with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp:
        tmp_path = tmp.name
    extract_mp3(src, start, dur, tmp_path)
    sub_sils = silence_boundaries(tmp_path, db=db, min_dur=min_sil)
    sub_segs = build_speech_segs(sub_sils, dur, min_speech=min_speech)
    os.unlink(tmp_path)
    if len(sub_segs) <= 1:
        return [(start, dur)]
    return [(start + ss, d) for ss, _, d in sub_segs]

# ── load whisper ──────────────────────────────────────────────────────────────

print("Loading Whisper tiny model (downloads ~75 MB on first run)...", flush=True)
from faster_whisper import WhisperModel
model = WhisperModel("tiny", device="cpu", compute_type="int8")
print("Model ready.\n", flush=True)

# ── process CDs ──────────────────────────────────────────────────────────────

all_arabic = []
seq = 0

for cd_path, cd_label in [(CD1, "CD1"), (CD2, "CD2")]:
    if not os.path.exists(cd_path):
        print(f"SKIP {cd_label} — file not found: {cd_path}")
        continue

    print(f"{'='*60}")
    print(f"Processing {cd_label}: {cd_path}")
    total = get_duration(cd_path)
    print(f"  Duration: {total:.1f}s ({total/60:.1f} min)", flush=True)

    silences = silence_boundaries(cd_path, db=-35, min_dur=0.35)
    raw_segs = build_speech_segs(silences, total, min_speech=1.5)
    print(f"  Raw segments (0.35s threshold): {len(raw_segs)}", flush=True)

    # Expand long segments with tighter threshold
    final_segs = []
    for st, en, dur in raw_segs:
        if dur > 30.0:
            sub = split_long(cd_path, st, dur, db=-35, min_sil=0.25, min_speech=1.5)
            final_segs.extend(sub)
        else:
            final_segs.append((st, dur))

    print(f"  After sub-splitting long segs: {len(final_segs)} segments\n", flush=True)

    for idx, (st, dur) in enumerate(final_segs):
        with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp:
            tmp_path = tmp.name
        extract_mp3(cd_path, st, dur, tmp_path)

        try:
            _, info = model.transcribe(
                tmp_path, language=None,
                condition_on_previous_text=False,
                without_timestamps=True,
                beam_size=1, best_of=1,
            )
            lang = info.language
            prob = round(info.language_probability, 3)
        except Exception as e:
            lang, prob = "err", 0.0
        finally:
            os.unlink(tmp_path)

        flag = "ARABIC" if (lang == "ar" and prob >= 0.5) else lang
        print(f"  [{cd_label}] seg {idx+1:03d}/{len(final_segs)} "
              f"{st:8.1f}s  dur={dur:6.1f}s  -> {flag} ({prob})", flush=True)

        if lang == "ar" and prob >= 0.5:
            seq += 1
            fname = f"ar_{seq:03d}_{cd_label}_t{int(st)}s_d{int(dur)}s.mp3"
            fpath = os.path.join(OUT, fname)
            extract_mp3(cd_path, st, dur, fpath)
            all_arabic.append({
                "seq": seq, "file": fname, "cd": cd_label,
                "start": round(st, 2), "dur": round(dur, 2),
                "lang_prob": prob,
            })

print(f"\n{'='*60}")
print(f"Total Arabic segments saved: {len(all_arabic)}")
manifest = os.path.join(OUT, "arabic_manifest.json")
with open(manifest, "w", encoding="utf-8") as f:
    json.dump(all_arabic, f, indent=2, ensure_ascii=False)
print(f"Manifest: {manifest}")
