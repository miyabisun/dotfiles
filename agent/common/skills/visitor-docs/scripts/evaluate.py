#!/usr/bin/env python3
"""Record a visitor document's Jev scores; never declare the document complete."""
import argparse
import json
import math
import os
from pathlib import Path
import urllib.request


def make_request(document, context, questions):
    if not document.strip() or not isinstance(context, dict):
        raise ValueError("document and context are required")
    for key in ("reader", "purpose", "exposure", "evidence"):
        if not isinstance(context.get(key), str) or not context[key].strip():
            raise ValueError(f"context.{key} requires actual text")
    return {"model": "jev-latest", "state": {"document": document, "context": context},
            "questions": questions}


def summarize(response, questions):
    if not isinstance(response, dict) or not isinstance(response.get("model"), str) or not response["model"]:
        raise ValueError("missing model")
    answers = response.get("answers")
    if not isinstance(answers, dict):
        raise ValueError("missing answers")
    scores, review = {}, []
    for name, question in questions.items():
        answer = answers.get(name)
        if not isinstance(answer, dict) or answer.get("type") != "score":
            raise ValueError(f"missing Score answer: {name}")
        for field, maximum in (("score", len(question["criteria"]) - 1), ("confidence", 1)):
            value = answer.get(field)
            if type(value) not in (int, float) or not math.isfinite(value) or not 0 <= value <= maximum:
                raise ValueError(f"invalid {name}.{field}")
        scores[name] = {key: answer[key] for key in ("score", "confidence")}
        # Review routing only, not a calibrated quality or completion threshold.
        if answer["score"] < 2.5 or answer["confidence"] < 0.5:
            review.append(name)
    return {"model": response["model"], "status": "review" if review else "scored",
            "scores": scores, "review_items": review}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--context", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True, help="new evidence directory outside the repo")
    parser.add_argument("document", type=Path)
    args = parser.parse_args(argv)
    args.output.mkdir(parents=True, exist_ok=False)
    try:
        questions = json.loads(Path(__file__).with_name("questions.json").read_text())
        request = make_request(args.document.read_text(), json.loads(args.context.read_text()), questions)
        key = os.environ.get("TYPESAFE_API_KEY", "").strip()
        if not key:
            raise ValueError("TYPESAFE_API_KEY is not set")
        (args.output / "request.json").write_text(json.dumps(request, ensure_ascii=False, indent=2))
        http = urllib.request.Request("https://api.typesafe.ai/v1/systemone",
            data=json.dumps(request).encode(),
            headers={"Content-Type": "application/json", "Authorization": f"Bearer {key}"})
        with urllib.request.urlopen(http, timeout=60) as connection:
            raw = connection.read().decode()
        (args.output / "response.json").write_text(raw)
        summary = summarize(json.loads(raw), questions)
        code = 1 if summary["status"] == "review" else 0
    except (OSError, ValueError, TimeoutError) as error:
        # Do not serialize exception text: a network error can contain credentials.
        summary = {"status": "unconfirmed", "error_type": type(error).__name__}
        code = 2
    (args.output / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2))
    print(json.dumps(summary, ensure_ascii=False))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
