"""
Export a Chinese sentiment model to TFLite for Senti.

Recommended source model:
    techthiyanes/chinese_sentiment

Usage:
    python tool/export_sentiment_tflite.py --output-dir assets/models

This script requires:
    pip install optimum[exporters-tf] transformers huggingface_hub
"""

from __future__ import annotations

import argparse
import pathlib
import shutil
import subprocess
import sys


MODEL_ID = "techthiyanes/chinese_sentiment"


def run(command: list[str]) -> None:
    print(">", " ".join(command))
    subprocess.run(command, check=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", default="assets/models")
    parser.add_argument("--sequence-length", type=int, default=128)
    args = parser.parse_args()

    output_dir = pathlib.Path(args.output_dir)
    temp_dir = output_dir / "_export_tmp"
    output_dir.mkdir(parents=True, exist_ok=True)

    run(
        [
            sys.executable,
            "-m",
            "optimum.exporters.tflite",
            "--model",
            MODEL_ID,
            "--task",
            "text-classification",
            "--sequence_length",
            str(args.sequence_length),
            str(temp_dir),
        ]
    )

    model_path = temp_dir / "model.tflite"
    if not model_path.exists():
        raise FileNotFoundError("Export succeeded but model.tflite was not found.")

    shutil.copy2(model_path, output_dir / "feeling_model.tflite")
    print(f"Exported TFLite model to: {output_dir / 'feeling_model.tflite'}")
    print("Keep sentiment_vocab.txt and sentiment_model_config.json in the same folder.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
