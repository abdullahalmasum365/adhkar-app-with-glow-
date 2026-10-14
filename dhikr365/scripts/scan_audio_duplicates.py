#!/usr/bin/env python3
"""
scripts/scan_audio_duplicates.py
--------------------------------
Scans all .mp3 files in assets/audio/, calculates MD5 and SHA-256 hashes,
detects duplicate recitations, highlights erroneous duplicate bindings,
and identifies embedded artwork (PNG/JPG IDAT chunks) bloating the APK size.
"""

import os
import hashlib
import json
import sys

AUDIO_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")

# Known legitimate duplicates (e.g. Quran Surahs or generic tasbih shared across morning/evening/sleep/salah)
KNOWN_LEGITIMATE_DUPLICATES = {
    # Ayatul Kursi
    "91e75163557bf5bae861628334b04b37": "Ayatul Kursi (Shared across Morning, Evening, Protection, Salah, Sleep)",
    # Al-Falaq
    "b10d56f493f814a4100b1cd8c23fb0a8": "Surah Al-Falaq (Shared across Morning, Evening, Protection, Salah, Sleep)",
    # An-Nas
    "a421ab49f436fb324b5de725a75a2cb8": "Surah An-Nas (Shared across Morning, Evening, Protection, Salah, Sleep)",
    # Al-Ikhlas
    "a4bc855e9291b9f572e20d4a258cddfa": "Surah Al-Ikhlas (Shared across Morning, Evening, Salah, Sleep)",
    # Alhamdulillah
    "22bed34ee7314a8f6fea3481973de230": "Alhamdulillah (Shared across Morning, Evening, Focus)",
    # SubhanAllah
    "8280e3eba91050784ed2249622f2b83b": "SubhanAllah (Shared across Morning, Evening)",
    # Subhanallahi wa bihamdihi 100x
    "09eb52f8bf58f9a5d159b0a5ded3185d": "SubhanAllahi wa biHamdihi 100x (Morning & Evening)",
    # Astaghfirullah
    "fd7622fd3140a72de0f7f0b97847a2f1": "Astaghfirullah (Morning & Evening)",
    # Allahu Akbar
    "2f74ba7f2e16460a82909c60f29c5ece": "Allahu Akbar (Morning & Evening)",
    # Hasbiyallah
    "70c29b8191289eec720b63006f4ab7b5": "Hasbiyallah (Morning & Evening)",
    # Radhitu Billah
    "5a9f3ffe07d1100a217308c24fb21400": "Radhitu Billahi Rabba (Morning & Evening)",
    # Sayyidul Istighfar
    "7a942c5160b7cfed3736d7c2ac3f0ed1": "Sayyidul Istighfar (Morning & Evening)",
    # Ya Hayyu Ya Qayyum
    "f27b2b5382bbb88b49cf55e78358006b": "Ya Hayyu Ya Qayyum (Morning & Evening)",
    # Afwa wal Afiyah
    "41469c50810e24f7016ea7961c64ec1e": "Allahumma inni as'alukal-afwa wal-afiyah (Morning & Evening)",
    # Allahumma Fatir
    "4c7ebfda41165d384536b55c78b1d1f5": "Allahumma Fatiras-Samawati (Morning, Evening, Sleep)",
    # Bismillahilladhi la yadurr
    "845f77f76dc4604db3623475d1fc2f53": "Bismillahilladhi la yadurru (Morning, Evening, Protection)",
    # Audhu bikalimatillah
    "8be9abbd2508d300e3229dcdda9e3dba": "Audhu bikalimatillahit-tammati (Evening & Protection)",
    # Allahumma ajirni minan-nar
    "5974175eeed4fc311b3952af86f68971": "Allahumma ajirni minan-nar (Morning & Evening)",
    # Salawat alan-Nabi
    "1cc525b27d6c8e281100ecbfa4d3f6cc": "Salawat alan-Nabi (Morning, Evening, Focus)",
    # La ilaha illallahu wahdahu 10x
    "ce4c0132cc2b3d19f56b10233b2f4623": "La ilaha illallahu wahdahu la sharika lah (Morning, Evening, Focus)",
    # Ilman Nafian
    "1159e61f9b54bb582e8bc8693ece9680": "Allahumma inni as'aluka ilman nafian (Morning & Salah)",
    # Tasbih Fatimi
    "d87c921a1f2f4495337e11480cef5ea7": "Tasbih Fatimi (Focus & Sleep)",
}

def analyze_audio_directory(audio_dir):
    if not os.path.exists(audio_dir):
        print(f"Error: Directory not found: {audio_dir}")
        return

    mp3_files = {}
    for root, _, files in os.walk(audio_dir):
        for f in sorted(files):
            if f.lower().endswith(".mp3"):
                file_path = os.path.join(root, f)
                with open(file_path, "rb") as fp:
                    content = fp.read()
                
                md5 = hashlib.md5(content).hexdigest()
                sha256 = hashlib.sha256(content).hexdigest()
                size = len(content)

                # Detect embedded PNG / JPEG cover art
                has_png = b"\x89PNG\r\n\x1a\n" in content
                has_jpg = b"\xff\xd8\xff" in content
                
                art_bytes = 0
                if has_png:
                    p_start = content.find(b"\x89PNG\r\n\x1a\n")
                    p_end = content.find(b"IEND", p_start)
                    art_bytes = (p_end + 8 - p_start) if p_end != -1 else (size - p_start)
                elif has_jpg:
                    j_start = content.find(b"\xff\xd8\xff")
                    j_end = content.find(b"\xff\xd9", j_start)
                    art_bytes = (j_end + 2 - j_start) if j_end != -1 else (size - j_start)

                mp3_files[f] = {
                    "path": file_path,
                    "size": size,
                    "md5": md5,
                    "sha256": sha256,
                    "has_embedded_art": (has_png or has_jpg),
                    "art_bytes": art_bytes,
                }

    # Group by MD5
    grouped = {}
    for fname, meta in mp3_files.items():
        grouped.setdefault(meta["md5"], []).append(fname)

    duplicates = {h: flist for h, flist in grouped.items() if len(flist) > 1}
    
    total_size = sum(m["size"] for m in mp3_files.values())
    total_art = sum(m["art_bytes"] for m in mp3_files.values())

    print("\n" + "="*80)
    print("                    DHIKR365 AUDIO INTEGRITY AUDIT")
    print("="*80)
    print(f" Total MP3 Audio Files:      {len(mp3_files)}")
    print(f" Unique Audio Recitations:   {len(grouped)}")
    print(f" Duplicate Groups:           {len(duplicates)} (Total duplicate files: {sum(len(f) for f in duplicates.values())})")
    print(f" Total Audio Storage:        {total_size / (1024*1024):.2f} MB")
    print(f" Wasted on Embedded Art:     {total_art / (1024*1024):.2f} MB ({(total_art/total_size)*100:.1f}% of entire audio folder!)")
    print("="*80)

    # 1. Critical / Erroneous duplicates
    erroneous = []
    legitimate = []

    for h, flist in sorted(duplicates.items(), key=lambda x: len(x[1]), reverse=True):
        if h in KNOWN_LEGITIMATE_DUPLICATES:
            legitimate.append((h, flist, KNOWN_LEGITIMATE_DUPLICATES[h]))
        else:
            erroneous.append((h, flist))

    print("\n" + "!"*80)
    print(" [ACTION REQUIRED] ERRONEOUS DUPLICATES (Audio content mismatch with Dua text):")
    print("!"*80)
    for idx, (h, flist) in enumerate(erroneous, start=1):
        sz = mp3_files[flist[0]]["size"]
        sha = mp3_files[flist[0]]["sha256"]
        print(f"\n[{idx}] Duplicate Set — MD5: {h}")
        print(f"    SHA-256: {sha}")
        print(f"    File Size: {sz:,} bytes ({sz/1024:.1f} KB)")
        for f in flist:
            art_flag = " [!] HAS EMBEDDED PNG/JPG ART" if mp3_files[f]["has_embedded_art"] else ""
            print(f"    -> assets/audio/{f}{art_flag}")
        
        # Explain the known issue for key culprits
        if "evening_e_allahumma_ma_amsa.mp3" in flist and "morning_m_allahumma_ma_asbaha.mp3" in flist:
            print("    ISSUE: Evening dua text says 'Allahumma ma amsa bi...', but audio is copy of morning ('asbaha').")
        elif "evening_e_allahumma_inni_amsaytu.mp3" in flist and "morning_m_allahumma_ashhaduka.mp3" in flist:
            print("    ISSUE: Evening dua text says 'Allahumma inni amsaytu ushhiduka...', but audio says 'asbahtu'.")
        elif "grave_salaam_aisha.mp3" in flist and "grave_salaam_buraidah.mp3" in flist:
            print("    ISSUE: Two distinct graveyard greetings (Sahih Muslim 974 vs 975) pointing to identical audio.")
        elif "focus_2.mp3" in flist and "focus_4.mp3" in flist:
            print("    ISSUE: 'SubhanAllahi wa biHamdihi' (focus_2) duplicated onto 'SubhanAllah' (focus_4).")
        elif "distress.mp3" in flist and "distress_anxiety_grief.mp3" in flist:
            print("    ISSUE: Category audio 'distress.mp3' is duplicate of Dhikr #2 'distress_anxiety_grief.mp3'.")
        elif "shifa.mp3" in flist and "shifa_visiting_sick_1.mp3" in flist:
            print("    ISSUE: Category audio 'shifa.mp3' is duplicate of 'shifa_visiting_sick_1.mp3'.")
        elif "travel.mp3" in flist and "travel_riding_vehicle.mp3" in flist:
            print("    ISSUE: Category audio 'travel.mp3' is duplicate of 'travel_riding_vehicle.mp3'.")

    print("\n" + "-"*80)
    print(" [INFO] LEGITIMATE DUPLICATES (Identical Quranic or Tasbih text across categories):")
    print("-"*80)
    for idx, (h, flist, desc) in enumerate(legitimate, start=1):
        sz = mp3_files[flist[0]]["size"]
        print(f"\n({idx}) {desc} [MD5: {h[:12]}..., Size: {sz/1024:.1f} KB]:")
        for f in flist:
            art_flag = " [!] ART" if mp3_files[f]["has_embedded_art"] else ""
            print(f"    -> {f}{art_flag}")

    # Export report to JSON for tooling
    report_path = os.path.join(audio_dir, "duplicate_audio_report.json")
    with open(report_path, "w", encoding="utf-8") as fp:
        json.dump({
            "total_files": len(mp3_files),
            "unique_hashes": len(grouped),
            "erroneous_duplicate_groups": [
                {"md5": h, "sha256": mp3_files[flist[0]]["sha256"], "size_bytes": mp3_files[flist[0]]["size"], "files": flist}
                for h, flist in erroneous
            ],
            "legitimate_duplicate_groups": [
                {"description": desc, "md5": h, "sha256": mp3_files[flist[0]]["sha256"], "files": flist}
                for h, flist, desc in legitimate
            ],
            "embedded_art_files": [
                {"file": f, "file_size": m["size"], "art_bytes": m["art_bytes"]}
                for f, m in mp3_files.items() if m["has_embedded_art"]
            ]
        }, fp, indent=2)

    print("\n" + "="*80)
    print(f"Report exported to: {report_path}")
    print("="*80 + "\n")

if __name__ == "__main__":
    analyze_audio_directory(AUDIO_DIR)
