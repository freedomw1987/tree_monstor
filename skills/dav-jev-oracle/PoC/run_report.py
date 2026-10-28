"""
run_report.py — M4 對外 CLI 入口（薄殼，包 batch_report.main）
"""
from __future__ import annotations
import sys
from pathlib import Path

THIS_DIR = Path(__file__).parent
sys.path.insert(0, str(THIS_DIR))

from batch_report import main

if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
