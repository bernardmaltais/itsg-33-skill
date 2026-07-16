import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parent / "merge-file-roles.py"
HASH_A = "a" * 64
HASH_B = "b" * 64


class MergeFileRolesTest(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmpdir.cleanup)
        self.input_path = Path(self.tmpdir.name) / "in.json"
        self.old_path = Path(self.tmpdir.name) / "old.yaml"
        self.new_path = Path(self.tmpdir.name) / "new.yaml"

    def run_script(self, payload, old_data=None):
        self.input_path.write_text(json.dumps(payload))
        if old_data is not None:
            self.old_path.write_text(json.dumps(old_data))
        return subprocess.run(
            [sys.executable, str(SCRIPT), str(self.input_path), str(self.old_path), str(self.new_path)],
            capture_output=True,
            text=True,
        )

    def test_valid_classification_writes_merged_output(self):
        payload = {"classifications": {
            "main.tf": {"roles": ["iac"], "content_hash": HASH_A},
        }}
        result = self.run_script(payload)
        self.assertEqual(result.returncode, 0, result.stderr)
        written = json.loads(self.new_path.read_text())
        self.assertEqual(written["main.tf"], {"roles": ["iac"], "content_hash": HASH_A})

    def test_zero_roles_is_valid(self):
        payload = {"classifications": {
            "README.md": {"roles": [], "content_hash": HASH_A},
        }}
        result = self.run_script(payload)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_cold_start_no_old_file(self):
        payload = {"classifications": {"main.tf": {"roles": ["iac"], "content_hash": HASH_A}}}
        result = self.run_script(payload)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(json.loads(self.new_path.read_text())), 1)

    def test_untouched_paths_pass_through(self):
        old_data = {"Chart.yaml": {"roles": ["iac", "dependency-manifest"], "content_hash": HASH_B}}
        payload = {"classifications": {"main.tf": {"roles": ["iac"], "content_hash": HASH_A}}}
        result = self.run_script(payload, old_data=old_data)
        self.assertEqual(result.returncode, 0, result.stderr)
        written = json.loads(self.new_path.read_text())
        self.assertEqual(written["Chart.yaml"], old_data["Chart.yaml"])
        self.assertEqual(written["main.tf"]["roles"], ["iac"])

    def test_reclassified_path_overwrites_old_entry(self):
        old_data = {"main.tf": {"roles": ["app-source"], "content_hash": HASH_B}}
        payload = {"classifications": {"main.tf": {"roles": ["iac"], "content_hash": HASH_A}}}
        result = self.run_script(payload, old_data=old_data)
        self.assertEqual(result.returncode, 0, result.stderr)
        written = json.loads(self.new_path.read_text())
        self.assertEqual(written["main.tf"], {"roles": ["iac"], "content_hash": HASH_A})

    def test_invalid_content_hash_fails(self):
        payload = {"classifications": {"main.tf": {"roles": ["iac"], "content_hash": "not-a-hash"}}}
        result = self.run_script(payload)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("content_hash", result.stderr.lower())

    def test_non_list_roles_fails(self):
        payload = {"classifications": {"main.tf": {"roles": "iac", "content_hash": HASH_A}}}
        result = self.run_script(payload)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("roles", result.stderr.lower())

    def test_malformed_json_input_fails(self):
        self.input_path.write_text("{not valid json")
        result = subprocess.run(
            [sys.executable, str(SCRIPT), str(self.input_path), str(self.old_path), str(self.new_path)],
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("json", result.stderr.lower())

    def test_malformed_old_roles_file_fails(self):
        self.old_path.write_text("{not valid json")
        payload = {"classifications": {"main.tf": {"roles": ["iac"], "content_hash": HASH_A}}}
        self.input_path.write_text(json.dumps(payload))
        result = subprocess.run(
            [sys.executable, str(SCRIPT), str(self.input_path), str(self.old_path), str(self.new_path)],
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("json", result.stderr.lower())


if __name__ == "__main__":
    unittest.main()
