"""
Download audio files from hisnmuslim.com and replace app TTS audio.

Steps:
1. Download husn_en.json from GitHub
2. Load all app duas from translation JSONs
3. Match each app dua to the best JSON item by Arabic text similarity
4. Download the matched audio files
5. Save to assets/audio/ with the app's expected filename
6. Handle morning/evening sibling pairs (same Arabic text -> same audio)
"""
import json, os, re, urllib.request, shutil, time, sys, io

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

APP_AUDIO_DIR = r"C:\Users\UNSTOPPABLE\Music\apps\New folder\dhikr365\assets\audio"
TRANS_ROOT    = r"C:\Users\UNSTOPPABLE\Music\apps\New folder\dhikr365\assets\translations"
JSON_URL      = "https://raw.githubusercontent.com/wafaaelmaandy/Hisn-Muslim-Json/master/husn_en.json"
CATEGORIES    = ["morning", "evening", "food", "graveyard", "parents", "protection"]

# ── normalize_ar (same as map_arabic.py) ─────────────────────────────────────

_AR_DIAC = re.compile(
    "[" + chr(0x0610) + "-" + chr(0x061A)
    + chr(0x064B) + "-" + chr(0x065F)
    + chr(0x0670)
    + chr(0x06D6) + "-" + chr(0x06ED)
    + "]"
)
_AR_KEEP = re.compile("[^" + chr(0x0621) + "-" + chr(0x064A) + r"\s]")

def normalize_ar(text):
    text = _AR_DIAC.sub("", text)
    text = re.sub(
        "[" + chr(0x0622) + chr(0x0623) + chr(0x0625)
        + chr(0x0671) + "-" + chr(0x0675) + "]",
        chr(0x0627), text
    )
    text = re.sub(
        "[" + chr(0x0649) + chr(0x06CC) + chr(0x06D0) + chr(0x06D2) + "]",
        chr(0x064A), text
    )
    # ta marbuta(629) AND ta marbuta goal(06C3) -> ha(647)
    text = re.sub("[" + chr(0x0629) + chr(0x06C3) + "]", chr(0x0647), text)
    text = re.sub("[" + chr(0x06A9) + chr(0x06AA) + "]", chr(0x0643), text)
    text = _AR_KEEP.sub(" ", text)
    return re.sub(r"\s+", " ", text).strip()

def word_overlap(trans_text, dua_text):
    wt = set(normalize_ar(trans_text).split())
    wd = set(normalize_ar(dua_text).split())
    if not wt:
        return 0.0
    return len(wt & wd) / len(wt)

# ── download JSON ─────────────────────────────────────────────────────────────

print("Downloading husn_en.json from GitHub...", flush=True)
with urllib.request.urlopen(JSON_URL) as r:
    raw_data = json.loads(r.read().decode("utf-8-sig"))
chapters = raw_data.get("English", raw_data) if isinstance(raw_data, dict) else raw_data
print(f"  {len(chapters)} chapters loaded.", flush=True)

# Build flat list of all JSON items with audio
json_items = []
for ch in chapters:
    for item in ch.get("TEXT", []):
        if item.get("AUDIO") and item.get("ARABIC_TEXT"):
            json_items.append({
                "id":          item["ID"],
                "audio_url":   item["AUDIO"],
                "arabic":      item["ARABIC_TEXT"],
                "norm_ar":     normalize_ar(item["ARABIC_TEXT"]),
                "chapter_id":  ch["ID"],
                "chapter":     ch["TITLE"],
                "translated":  item.get("TRANSLATED_TEXT", ""),
            })

print(f"  {len(json_items)} items with audio.", flush=True)

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
        app_duas.append({
            "id":         key,
            "category":   cat,
            "title":      d.get("title", ""),
            "arabic":     d.get("arabicText", ""),
            "audio_file": audio_file,
        })

print(f"\nLoaded {len(app_duas)} app duas.")

# Build sibling map (duas sharing same normalized Arabic text)
text_to_duas = {}
for d in app_duas:
    k = normalize_ar(d["arabic"])
    text_to_duas.setdefault(k, []).append(d)

# ── match app duas to JSON items ──────────────────────────────────────────────

print("\nMatching app duas to hisnmuslim items...\n", flush=True)

# Cache: audio_file -> (json_item, score)
assignments = {}

for dua in app_duas:
    if not dua["arabic"]:
        continue
    norm = normalize_ar(dua["arabic"])
    # Find best matching JSON item
    best_score = 0.0
    best_item  = None
    for jitem in json_items:
        # Score: overlap of dua words in json item (how much of the dua is covered)
        dua_words  = set(norm.split())
        json_words = set(jitem["norm_ar"].split())
        if not dua_words:
            continue
        overlap = len(dua_words & json_words) / len(dua_words)
        if overlap > best_score:
            best_score = overlap
            best_item  = jitem

    # Apply to all siblings sharing this Arabic text
    siblings = text_to_duas.get(norm, [dua])
    for sib in siblings:
        fname = sib["audio_file"]
        if fname not in assignments or best_score > assignments[fname][1]:
            assignments[fname] = (best_item, best_score)

# ── print matching table ──────────────────────────────────────────────────────

print(f"{'App audio file':<45} {'Score':>6}  {'JSON item ID':>10}  Chapter")
print("-" * 110)
for dua in app_duas:
    fname = dua["audio_file"]
    item, score = assignments.get(fname, (None, 0.0))
    if item:
        print(f"{fname:<45} {score:>6.3f}  item={item['id']:>5}      {item['chapter'][:40]}")
    else:
        print(f"{fname:<45}  NO MATCH")

high  = [(f, i, s) for f, (i, s) in assignments.items() if s >= 0.5 and i]
med   = [(f, i, s) for f, (i, s) in assignments.items() if 0.3 <= s < 0.5 and i]
low   = [(f, i, s) for f, (i, s) in assignments.items() if s < 0.3 or not i]
print(f"\nScore >=0.5 (HIGH): {len(high)}  0.3-0.5 (MED): {len(med)}  <0.3 (LOW): {len(low)}")

# ── download and save ─────────────────────────────────────────────────────────

print("\nDownloading and saving audio files...\n", flush=True)

downloaded_cache = {}   # url -> local_path (avoid re-downloading same file)
download_dir = os.path.join(APP_AUDIO_DIR, "_downloads")
os.makedirs(download_dir, exist_ok=True)

results = []
seen_urls = {}   # audio_url -> temp_path (cache)

# Sort by score descending so we process best matches first
sorted_assignments = sorted(assignments.items(), key=lambda x: -x[1][1])

for fname, (item, score) in sorted_assignments:
    if item is None or score < 0.3:
        results.append(f"  SKIP (no match)          {fname}")
        continue

    audio_url = item["audio_url"]
    dest = os.path.join(APP_AUDIO_DIR, fname)

    # Download (or reuse cached)
    if audio_url not in seen_urls:
        tmp_path = os.path.join(download_dir, f"item_{item['id']}.mp3")
        try:
            req = urllib.request.Request(audio_url, headers={
                "User-Agent": (
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/124.0.0.0 Safari/537.36"
                ),
                "Referer": "http://www.hisnmuslim.com/",
                "Accept": "audio/mpeg,audio/*;q=0.9,*/*;q=0.8",
            })
            with urllib.request.urlopen(req) as resp, open(tmp_path, "wb") as f:
                f.write(resp.read())
            seen_urls[audio_url] = tmp_path
            print(f"  DL  item_{item['id']:03d} ({score:.2f}) -> {fname}", flush=True)
        except Exception as e:
            results.append(f"  ERR item_{item['id']:03d}  {e}  -> {fname}")
            continue
        time.sleep(0.15)   # be polite to the server
    else:
        tmp_path = seen_urls[audio_url]
        print(f"  CPY item_{item['id']:03d} ({score:.2f}) -> {fname}", flush=True)

    shutil.copy2(tmp_path, dest)
    results.append(f"  OK  item_{item['id']:03d} ({score:.2f}) -> {fname}")

print(f"\n{'='*60}")
print(f"Done.  {sum(1 for r in results if r.startswith('  OK'))} files saved.")
print(f"       {sum(1 for r in results if r.startswith('  ERR'))} errors.")
print(f"       {sum(1 for r in results if r.startswith('  SKIP'))} skipped (no match).")
print()

# Show skipped / errors
for r in results:
    if not r.startswith("  OK"):
        print(r)
