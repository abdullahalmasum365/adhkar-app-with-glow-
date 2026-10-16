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
KNOWN_LEGITIMATE_GROUPS = [
    ({"evening_e_ayatulkursi.mp3", "morning_m_ayatulkursi.mp3", "protection_5.mp3", "salah_ayatul_kursi.mp3", "sleep_ayatul_kursi.mp3"}, "Ayatul Kursi (Shared across Morning, Evening, Protection, Salah, Sleep)"),
    ({"evening_e_falaq.mp3", "morning_m_falaq.mp3", "protection_2.mp3", "salah_falaq.mp3", "sleep_falaq.mp3"}, "Surah Al-Falaq (Shared across Morning, Evening, Protection, Salah, Sleep)"),
    ({"evening_e_nas.mp3", "morning_m_nas.mp3", "protection_3.mp3", "salah_nas.mp3", "sleep_nas.mp3"}, "Surah An-Nas (Shared across Morning, Evening, Protection, Salah, Sleep)"),
    ({"evening_e_ikhlas.mp3", "morning_m_ikhlas.mp3", "salah_ikhlas.mp3", "sleep_ikhlas.mp3"}, "Surah Al-Ikhlas (Shared across Morning, Evening, Salah, Sleep)"),
    ({"evening_e_alhamdulillah.mp3", "focus_5.mp3", "morning_m_alhamdulillah.mp3"}, "Alhamdulillah (Shared across Morning, Evening, Focus)"),
    ({"evening_e_allahumma_fatir.mp3", "morning_m_allahumma_fatir.mp3", "sleep_allahumma_alimal_ghaybi.mp3"}, "Allahumma Fatiras-Samawati (Morning, Evening, Sleep)"),
    ({"evening_e_bismillah_la_yadurr.mp3", "morning_m_bismillah_la_yadurr.mp3", "protection_1.mp3"}, "Bismillahilladhi la yadurru (Morning, Evening, Protection)"),
    ({"evening_e_la_ilaha_illa_allah_10.mp3", "focus_7.mp3", "morning_m_la_ilaha_illa_allah_10.mp3"}, "La ilaha illallahu wahdahu la sharika lah (Morning, Evening, Focus)"),
    ({"evening_e_salawat_alan_nabi.mp3", "focus_8.mp3", "morning_m_salawat_alan_nabi.mp3"}, "Salawat alan-Nabi (Morning, Evening, Focus)"),
    ({"evening_e_subhanallah.mp3", "focus_4.mp3", "morning_m_subhanallah.mp3"}, "SubhanAllah (Morning, Evening, Focus)"),
    ({"evening_e_afwa_wal_afiyah.mp3", "morning_m_afwa_wal_afiyah.mp3"}, "Allahumma inni as'alukal-afwa wal-afiyah (Morning & Evening)"),
    ({"evening_e_allahu_akbar.mp3", "morning_m_allahu_akbar.mp3"}, "Allahu Akbar (Morning & Evening)"),
    ({"evening_e_allahumma_afini.mp3", "morning_m_allahumma_afini.mp3"}, "Allahumma afini fi badani (Morning & Evening)"),
    ({"evening_e_allahumma_ajirni_min_nar.mp3", "morning_m_allahumma_ajirni_min_nar.mp3"}, "Allahumma ajirni minan-nar (Morning & Evening)"),
    ({"evening_e_astaghfirullah.mp3", "morning_m_astaghfirullah.mp3"}, "Astaghfirullah (Morning & Evening)"),
    ({"evening_e_audhu_bikalimatillah.mp3", "protection_4.mp3"}, "Audhu bikalimatillahit-tammati (Evening & Protection)"),
    ({"evening_e_hasbiyallah.mp3", "morning_m_hasbiyallah.mp3"}, "Hasbiyallah (Morning & Evening)"),
    ({"evening_e_radhitu_billah.mp3", "morning_m_radhitu_billah.mp3"}, "Radhitu Billahi Rabba (Morning & Evening)"),
    ({"evening_e_sayyidul_istighfar.mp3", "morning_m_sayyidul_istighfar.mp3"}, "Sayyidul Istighfar (Morning & Evening)"),
    ({"evening_e_subhanallah_bihamdihi_100.mp3", "morning_m_subhanallah_bihamdihi_100.mp3"}, "SubhanAllahi wa biHamdihi 100x (Morning & Evening)"),
    ({"evening_e_ya_hayyu_ya_qayyum.mp3", "morning_m_ya_hayyu_ya_qayyum.mp3"}, "Ya Hayyu Ya Qayyum (Morning & Evening)"),
    ({"focus_6.mp3", "sleep_tasbih_fatimi.mp3"}, "Tasbih Fatimi (Focus & Sleep)"),
    ({"morning_m_allahumma_ilman_nafian.mp3", "salah_ilman_nafian.mp3"}, "Allahumma inni as'aluka ilman nafian (Morning & Salah)"),
]

KNOWN_LEGITIMATE_DUPLICATES = {
    # Current 64kbps CBR hashes
    "24be0a12a95a338d53de85a701b08ad9": "Ayatul Kursi (Shared across Morning, Evening, Protection, Salah, Sleep)",
    "8e56a11fe2f79ee9c20554b9f8d1f30f": "Surah Al-Falaq (Shared across Morning, Evening, Protection, Salah, Sleep)",
    "5e40c4a233d7f27df6f09655c675ee0c": "Surah An-Nas (Shared across Morning, Evening, Protection, Salah, Sleep)",
    "85639cbf711ffa95b1256f63a3c82661": "Surah Al-Ikhlas (Shared across Morning, Evening, Salah, Sleep)",
    "bfbcf5bffd29fd53a944a21248e3f744": "Alhamdulillah (Shared across Morning, Evening, Focus)",
    "c2eacd1af29a29bff6f8810c18ca23ab": "SubhanAllah (Morning, Evening, Focus)",
    "bcaf8277151973a16aad62baf057bf83": "SubhanAllahi wa biHamdihi 100x (Morning & Evening)",
    "4ae5b9af5e28b962bd30e16728862fcc": "Astaghfirullah (Morning & Evening)",
    "4db5609e41c5fe182fb685444f60f818": "Allahu Akbar (Morning & Evening)",
    "74a3d8c572af2a61daa11da2d72e532c": "Hasbiyallah (Morning & Evening)",
    "3823376537a68493373785c6d4757b0a": "Radhitu Billahi Rabba (Morning & Evening)",
    "dcc7c56daeb3511191f53fb43a7052f4": "Sayyidul Istighfar (Morning & Evening)",
    "4711761f8ae1ff9617b1e50b3ec939b7": "Ya Hayyu Ya Qayyum (Morning & Evening)",
    "9e6041d7492f9b7acbf801907893b6e4": "Allahumma inni as'alukal-afwa wal-afiyah (Morning & Evening)",
    "6c58d14b07b5fad132cad3a5a2a4b7d4": "Allahumma Fatiras-Samawati (Morning, Evening, Sleep)",
    "97d5c292ffec562cd28f735d7e0b7b31": "Bismillahilladhi la yadurru (Morning, Evening, Protection)",
    "a365ca9f8b9c6bcf4baae8f303a15fcb": "Audhu bikalimatillahit-tammati (Evening & Protection)",
    "82fa2d0b0a380eaa9fb112c2b9217be3": "Allahumma ajirni minan-nar (Morning & Evening)",
    "3e7df9f8fd971e09e16818b62778cad5": "Salawat alan-Nabi (Morning, Evening, Focus)",
    "f42dce1a7709aa7abb08ea4e18360e07": "La ilaha illallahu wahdahu la sharika lah (Morning, Evening, Focus)",
    "547c057fb4b234446debd4c6993cdf85": "Allahumma inni as'aluka ilman nafian (Morning & Salah)",
    "c6b1b6289f737e917dd83b33c079fba0": "Tasbih Fatimi (Focus & Sleep)",
    "65eea32a86a9fe68ce2fcfda8b589d58": "Allahumma afini fi badani (Morning & Evening)",
    # Legacy uncompressed hashes (historical reference)
    "91e75163557bf5bae861628334b04b37": "Ayatul Kursi (Shared across Morning, Evening, Protection, Salah, Sleep)",
    "b10d56f493f814a4100b1cd8c23fb0a8": "Surah Al-Falaq (Shared across Morning, Evening, Protection, Salah, Sleep)",
    "a421ab49f436fb324b5de725a75a2cb8": "Surah An-Nas (Shared across Morning, Evening, Protection, Salah, Sleep)",
    "a4bc855e9291b9f572e20d4a258cddfa": "Surah Al-Ikhlas (Shared across Morning, Evening, Salah, Sleep)",
    "22bed34ee7314a8f6fea3481973de230": "Alhamdulillah (Shared across Morning, Evening, Focus)",
    "8280e3eba91050784ed2249622f2b83b": "SubhanAllah (Shared across Morning, Evening)",
    "09eb52f8bf58f9a5d159b0a5ded3185d": "SubhanAllahi wa biHamdihi 100x (Morning & Evening)",
    "fd7622fd3140a72de0f7f0b97847a2f1": "Astaghfirullah (Morning & Evening)",
    "2f74ba7f2e16460a82909c60f29c5ece": "Allahu Akbar (Morning & Evening)",
    "70c29b8191289eec720b63006f4ab7b5": "Hasbiyallah (Morning & Evening)",
    "5a9f3ffe07d1100a217308c24fb21400": "Radhitu Billahi Rabba (Morning & Evening)",
    "7a942c5160b7cfed3736d7c2ac3f0ed1": "Sayyidul Istighfar (Morning & Evening)",
    "f27b2b5382bbb88b49cf55e78358006b": "Ya Hayyu Ya Qayyum (Morning & Evening)",
    "41469c50810e24f7016ea7961c64ec1e": "Allahumma inni as'alukal-afwa wal-afiyah (Morning & Evening)",
    "4c7ebfda41165d384536b55c78b1d1f5": "Allahumma Fatiras-Samawati (Morning, Evening, Sleep)",
    "845f77f76dc4604db3623475d1fc2f53": "Bismillahilladhi la yadurru (Morning, Evening, Protection)",
    "8be9abbd2508d300e3229dcdda9e3dba": "Audhu bikalimatillahit-tammati (Evening & Protection)",
    "5974175eeed4fc311b3952af86f68971": "Allahumma ajirni minan-nar (Morning & Evening)",
    "1cc525b27d6c8e281100ecbfa4d3f6cc": "Salawat alan-Nabi (Morning, Evening, Focus)",
    "ce4c0132cc2b3d19f56b10233b2f4623": "La ilaha illallahu wahdahu la sharika lah (Morning, Evening, Focus)",
    "1159e61f9b54bb582e8bc8693ece9680": "Allahumma inni as'aluka ilman nafian (Morning & Salah)",
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

                # Detect embedded PNG / JPEG cover art in ID3 metadata (APIC frame)
                has_apic = b"APIC" in content
                has_png = (b"\x89PNG\r\n\x1a\n" in content) and has_apic
                has_jpg = (b"\xff\xd8\xff" in content) and has_apic
                
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
        desc = KNOWN_LEGITIMATE_DUPLICATES.get(h)
        if not desc:
            fset = set(flist)
            for s_files, d in KNOWN_LEGITIMATE_GROUPS:
                if fset == s_files:
                    desc = d
                    break
        if desc:
            legitimate.append((h, flist, desc))
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
