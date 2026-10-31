import importlib.util
import pathlib
import unittest

SCRIPT = pathlib.Path(__file__).with_name("sync_merged_prs_to_trello.py")
spec = importlib.util.spec_from_file_location("sync_merged_prs_to_trello", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class SyncRulesTests(unittest.TestCase):
    def test_matches_real_repository_pr_links(self):
        text = ("PR: https://github.com/iosdevbyul/WakTrainerApp/pull/131 "
                "and https://github.com/iosdevbyul/Coufunch/pull/111")
        self.assertEqual(module.linked_prs(text), {("WakTrainerApp", 131), ("Coufunch", 111)})

    def test_other_owners_and_issue_links_do_not_match(self):
        text = ("https://github.com/another-owner/WakTrainerApp/pull/131 "
                "https://github.com/iosdevbyul/Coufunch/issues/111")
        self.assertEqual(module.linked_prs(text), set())

    def test_all_linked_prs_must_be_merged(self):
        self.assertFalse(module.is_complete([]))
        self.assertFalse(module.is_complete([True, False]))
        self.assertTrue(module.is_complete([True, True]))

    def test_plain_pr_number_is_not_sufficient(self):
        self.assertEqual(module.linked_prs("[WakTrainerApp][PR #131]"), set())


if __name__ == "__main__":
    unittest.main()
