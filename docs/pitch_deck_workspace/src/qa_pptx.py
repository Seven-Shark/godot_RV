import json
import re
import sys
import zipfile
from pathlib import Path


PLACEHOLDER_PATTERN = re.compile(r"\b(Slide Number|Click to add|Lorem ipsum|Replace with|TODO|TBD|Creating image)\b", re.I)


def main() -> int:
    pptx_path = Path(sys.argv[1])
    report_path = Path(sys.argv[2])
    report = {
        "pptx": str(pptx_path),
        "slide_count": 0,
        "media_count": 0,
        "placeholder_hits": [],
        "zero_byte_entries": [],
        "failures": [],
    }
    if not pptx_path.exists():
        report["failures"].append(f"Missing PPTX: {pptx_path}")
    else:
        with zipfile.ZipFile(pptx_path, "r") as zf:
            names = zf.namelist()
            slides = sorted([name for name in names if re.match(r"ppt/slides/slide\d+\.xml$", name)])
            media = [name for name in names if name.startswith("ppt/media/")]
            report["slide_count"] = len(slides)
            report["media_count"] = len(media)
            for info in zf.infolist():
                if info.file_size == 0 and not info.is_dir():
                    report["zero_byte_entries"].append(info.filename)
            for idx, slide_name in enumerate(slides, start=1):
                xml = zf.read(slide_name).decode("utf-8", errors="ignore")
                if PLACEHOLDER_PATTERN.search(xml):
                    report["placeholder_hits"].append({"slide": idx, "entry": slide_name})
            if not slides:
                report["failures"].append("No slide XML found.")
            if report["zero_byte_entries"]:
                report["failures"].append("PPTX contains zero-byte entries.")
            if report["placeholder_hits"]:
                report["failures"].append("PPTX contains placeholder text candidates.")
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(report_path)
    return 1 if report["failures"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
