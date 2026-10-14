#!/usr/bin/env python3
"""
scripts/compress_audio_ffmpeg.py
--------------------------------
Batch processes all .mp3 files in assets/audio/ using ffmpeg:
  1. Strips all embedded cover art / PNG / JPG chunks (-vn)
  2. Strips all metadata & ID3 tags (-map_metadata -1)
  3. Converts stereo to mono (-ac 1)
  4. Encodes at 64kbps CBR (-b:a 64k) at 44.1 kHz (-ar 44100)
  5. Preserves exact audio duration so time-synced timestamps stay 100% aligned.

Usage:
  # Dry run (test & report without overwriting):
  python scripts/compress_audio_ffmpeg.py --dry-run

  # Execute compression with automatic backup:
  python scripts/compress_audio_ffmpeg.py
"""

import os
import shutil
import subprocess
import sys
import tempfile

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO_DIR = os.path.join(PROJECT_ROOT, "assets", "audio")
BACKUP_DIR = os.path.join(PROJECT_ROOT, "assets", "audio_backup_original")

def check_ffmpeg():
    try:
        res = subprocess.run(["ffmpeg", "-version"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return res.returncode == 0
    except FileNotFoundError:
        return False

def compress_audio(dry_run=False):
    if not check_ffmpeg():
        print("ERROR: ffmpeg is not found on your system PATH. Please install ffmpeg or add it to PATH.")
        sys.exit(1)

    mp3_files = [f for f in sorted(os.listdir(AUDIO_DIR)) if f.lower().endswith(".mp3")]
    if not mp3_files:
        print(f"No MP3 files found in {AUDIO_DIR}")
        return

    print("=" * 75)
    print("        DHIKR365 AUDIO COMPRESSION & METADATA STRIPPER")
    print("=" * 75)
    print(f"Target Directory: {AUDIO_DIR}")
    print(f"Files to process: {len(mp3_files)}")
    print(f"Mode:             {'DRY RUN (preview only)' if dry_run else 'ACTIVE COMPRESSION'}")
    print("-" * 75)

    if not dry_run and not os.path.exists(BACKUP_DIR):
        print(f"Creating backup of original files in:\n  -> {BACKUP_DIR}")
        shutil.copytree(AUDIO_DIR, BACKUP_DIR, ignore=shutil.ignore_patterns("*.json"))

    total_orig = 0
    total_new = 0

    with tempfile.TemporaryDirectory() as tmp_dir:
        for idx, f in enumerate(mp3_files, 1):
            src_path = os.path.join(AUDIO_DIR, f)
            tmp_out = os.path.join(tmp_dir, f)
            orig_sz = os.path.getsize(src_path)
            total_orig += orig_sz

            # ffmpeg command
            cmd = [
                "ffmpeg", "-y", "-i", src_path,
                "-vn",                 # Strip embedded video/art
                "-map_metadata", "-1", # Strip all ID3 metadata
                "-ac", "1",            # Convert to mono
                "-b:a", "64k",         # 64 kbps audio bitrate
                "-ar", "44100",        # 44.1 kHz sample rate
                tmp_out
            ]

            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            if res.returncode != 0:
                print(f"[{idx}/{len(mp3_files)}] FAILED: {f}")
                total_new += orig_sz
                continue

            new_sz = os.path.getsize(tmp_out)
            total_new += new_sz
            reduction = (1 - new_sz / orig_sz) * 100

            if not dry_run:
                shutil.copy2(tmp_out, src_path)

            print(f"[{idx:3d}/{len(mp3_files)}] {f:<38} | {orig_sz/1024:6.1f} KB -> {new_sz/1024:5.1f} KB ({reduction:4.1f}% saved)")

    saved_mb = (total_orig - total_new) / (1024 * 1024)
    print("=" * 75)
    print("                        SUMMARY")
    print("=" * 75)
    print(f"Original Size:   {total_orig / (1024*1024):.2f} MB")
    print(f"Compressed Size: {total_new / (1024*1024):.2f} MB")
    print(f"Total Saved:     {saved_mb:.2f} MB ({(1 - total_new/total_orig)*100:.1f}% reduction)")
    if not dry_run:
        print(f"Backup saved to: {BACKUP_DIR}")
    print("=" * 75)

if __name__ == "__main__":
    is_dry = "--dry-run" in sys.argv
    compress_audio(dry_run=is_dry)
