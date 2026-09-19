import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import evaluate


class EvaluationTest(unittest.TestCase):
    questions = {name: {"type": "score", "criteria": ["absent", "broken", "partial", "usable"]}
                 for name in ("objectivity", "first_use")}
    context = {"reader": "CLI users", "purpose": "Install and use", "exposure": "public",
               "evidence": "The executable accepts --help and --version."}

    def response(self):
        return {"model": "jev-test", "answers": {
            name: {"type": "score", "score": 3.0, "confidence": 0.9}
            for name in self.questions}}

    def test_request_includes_actual_document_and_rejects_missing_context(self):
        request = evaluate.make_request("# Demo\nInstall the executable.", self.context, self.questions)
        self.assertEqual(request["state"]["document"], "# Demo\nInstall the executable.")
        self.assertEqual(request["state"]["context"], self.context)
        for document, context in [(" ", self.context), ("# Demo", {}),
                                  ("# Demo", {**self.context, "evidence": " "})]:
            with self.assertRaises(ValueError):
                evaluate.make_request(document, context, self.questions)

    def test_one_weak_dimension_cannot_be_averaged_away(self):
        response = self.response()
        self.assertEqual(evaluate.summarize(response, self.questions)["status"], "scored")
        response["answers"]["first_use"]["score"] = 1.0
        result = evaluate.summarize(response, self.questions)
        self.assertEqual(result["status"], "review")
        self.assertEqual(result["review_items"], ["first_use"])
        response["answers"]["first_use"].update(score=3, confidence=0.3)
        self.assertEqual(evaluate.summarize(response, self.questions)["status"], "review")

    def test_missing_or_invalid_answers_never_count_as_scored(self):
        response = self.response()
        del response["answers"]["first_use"]
        with self.assertRaises(ValueError):
            evaluate.summarize(response, self.questions)
        for field, value in [("type", "noul"), ("score", float("nan")), ("score", True),
                             ("score", 4), ("confidence", -1), ("confidence", "0.9")]:
            response = self.response()
            response["answers"]["first_use"][field] = value
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                evaluate.summarize(response, self.questions)

    def test_api_failure_leaves_unconfirmed_evidence_without_secret(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            (root / "context.json").write_text(json.dumps(self.context))
            (root / "README.md").write_text("# Demo\nRun demo --help.")
            output = root / "result"
            args = ["--context", str(root / "context.json"), "--output", str(output),
                    str(root / "README.md")]
            with patch.dict("os.environ", {"TYPESAFE_API_KEY": "test-secret"}), \
                 patch("evaluate.urllib.request.urlopen", side_effect=OSError("offline")), \
                 contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(evaluate.main(args), 2)
            self.assertEqual(json.loads((output / "summary.json").read_text())["status"], "unconfirmed")
            self.assertNotIn("test-secret", "".join(f.read_text() for f in output.iterdir()))
            with self.assertRaises(FileExistsError):
                evaluate.main(args)


if __name__ == "__main__":
    unittest.main()
