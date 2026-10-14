#!/usr/bin/env python3
"""Parse the maintainer-provided judgment Markdown and replace the bundled bank."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path


CHAPTER_RE = re.compile(r"^##\s+第[^\s]+章\s+(.+?)（(\d+)[–—-](\d+)）\s*$")
QUESTION_RE = re.compile(r"^###\s+(\d+)\.\s+(.+?)\s*$")
ANSWER_RE = re.compile(r"^\*\*答案：(正确|错误)\*\*(.*)$")
EXPLANATION_RE = re.compile(r"^\*\*解析：\*\*\s*(.*)$")
RISK_ROW_RE = re.compile(
    r"^\|\s*(\d+)\s*\|\s*\*\*(正确|错误)\*\*\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*$"
)


def plain_text(value: str) -> str:
    value = value.replace("**", "").replace("`", "")
    value = re.sub(r"\[([^]]+)]\([^)]+\)", r"\1", value)
    value = re.sub(r"[ \t]+", " ", value)
    return value.strip()


def parse_risks(lines: list[str]) -> dict[int, dict[str, str]]:
    risks: dict[int, dict[str, str]] = {}
    for line in lines:
        match = RISK_ROW_RE.match(line)
        if not match:
            continue
        number = int(match.group(1))
        answer = match.group(2)
        note = plain_text(match.group(3))
        detail = plain_text(match.group(4))
        risks[number] = {
            "answerText": answer,
            "level": note,
            "issue": f"{note}；{detail}" if detail else note,
        }
    return risks


def parse_questions(source: Path) -> tuple[list[dict], list[tuple[str, int, int]], str]:
    raw = source.read_text(encoding="utf-8")
    lines = raw.splitlines()
    risks = parse_risks(lines)
    chapters: list[tuple[str, int, int]] = []
    rows: list[dict] = []
    category: str | None = None
    current: dict | None = None
    collecting_explanation = False

    def finish_current() -> None:
        nonlocal current, collecting_explanation
        if current is None:
            return
        explanation = "\n".join(
            line for line in current.pop("_explanation_lines") if line
        ).strip()
        if not current.get("answerText") or not explanation:
            raise ValueError(f"第 {current['sourceNo']} 题缺少答案或解析")
        current["explanation"] = explanation
        risk = risks.get(current["sourceNo"])
        if risk:
            if risk["answerText"] != current["answerText"]:
                raise ValueError(f"第 {current['sourceNo']} 题存疑表答案与题目答案不一致")
            current["risk"] = {
                "level": risk["level"],
                "issue": risk["issue"],
                "advice": (
                    f"练习和模拟考试按附件参考答案“{current['answerText']}”作答；"
                    "实际应用请结合现行法规、教材或技术资料核对。"
                ),
            }
        else:
            current["risk"] = None
        rows.append(current)
        current = None
        collecting_explanation = False

    for line in lines:
        chapter_match = CHAPTER_RE.match(line)
        if chapter_match:
            finish_current()
            category = plain_text(chapter_match.group(1))
            chapters.append((category, int(chapter_match.group(2)), int(chapter_match.group(3))))
            continue

        question_match = QUESTION_RE.match(line)
        if question_match:
            finish_current()
            if category is None:
                raise ValueError(f"第 {question_match.group(1)} 题前没有章节")
            number = int(question_match.group(1))
            current = {
                "id": f"J{number:03d}",
                "sourceNo": number,
                "q": plain_text(question_match.group(2)),
                "options": ["正确", "错误"],
                "answer": "",
                "answerText": "",
                "explanation": "",
                "pattern": "判断题辨析",
                "step": "先识别题干的核心概念和限定词，再结合题库解析核对判断",
                "category": category,
                "risk": None,
                "kind": "judge",
                "source": "维护者提供的判断题解析附件",
                "_explanation_lines": [],
            }
            collecting_explanation = False
            continue

        if current is not None and (line.strip() == "---" or line.startswith("## ")):
            finish_current()
            continue

        if current is None:
            continue
        answer_match = ANSWER_RE.match(line)
        if answer_match:
            current["answerText"] = answer_match.group(1)
            current["answer"] = "A" if answer_match.group(1) == "正确" else "B"
            continue
        explanation_match = EXPLANATION_RE.match(line)
        if explanation_match:
            collecting_explanation = True
            first = plain_text(explanation_match.group(1))
            if first:
                current["_explanation_lines"].append(first)
            continue
        if collecting_explanation and line.strip() != "---":
            cleaned = plain_text(line)
            if cleaned:
                current["_explanation_lines"].append(cleaned)

    finish_current()

    expected = list(range(1, 301))
    actual = [row["sourceNo"] for row in rows]
    if actual != expected:
        raise ValueError("题号必须是连续的 1–300")
    if len({row["q"] for row in rows}) != 300:
        raise ValueError("题干存在重复")
    if len(chapters) != 17:
        raise ValueError(f"应有 17 章，实际为 {len(chapters)} 章")
    if set(risks) != {2, 9, 19, 36, 58, 70, 125, 165, 203, 204, 256}:
        raise ValueError("存疑题清单与预期不一致")
    digest = hashlib.sha256(raw.encode("utf-8")).hexdigest()
    return rows, chapters, digest


def replace_bank(index_path: Path, rows: list[dict]) -> None:
    html = index_path.read_text(encoding="utf-8")
    payload = json.dumps(rows, ensure_ascii=False, separators=(",", ":"))
    updated, count = re.subn(
        r"let JUDGMENTS=\[.*?\];\nlet JUDGMENT_MAP=",
        lambda _match: f"let JUDGMENTS={payload};\nlet JUDGMENT_MAP=",
        html,
        count=1,
        flags=re.DOTALL,
    )
    if count != 1:
        raise ValueError("没有找到唯一的内置判断题数组")
    index_path.write_text(updated, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path, help="判断题 Markdown 文件")
    parser.add_argument(
        "--index",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "index.html",
        help="要更新的 index.html",
    )
    parser.add_argument("--check-only", action="store_true", help="只校验附件，不修改网页")
    args = parser.parse_args()
    rows, chapters, digest = parse_questions(args.source)
    if not args.check_only:
        replace_bank(args.index, rows)
    correct = sum(row["answer"] == "A" for row in rows)
    print(
        f"PASS: {len(rows)} 题；正确 {correct}，错误 {len(rows) - correct}；"
        f"{len(chapters)} 章；存疑 {sum(row['risk'] is not None for row in rows)}；SHA-256 {digest}"
    )


if __name__ == "__main__":
    main()
