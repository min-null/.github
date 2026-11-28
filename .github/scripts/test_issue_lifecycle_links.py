import unittest

from issue_lifecycle_links import extract_links, should_close_issue


class IssueLifecycleLinkTests(unittest.TestCase):
    def test_qualified_repo_reference(self):
        self.assertEqual(
            extract_links("Closes min-null/minchat-hq#122", "min-null/minchat-backend", ""),
            [("min-null/minchat-hq", 122, True)],
        )

    def test_github_issue_url_in_markdown(self):
        self.assertEqual(
            extract_links(
                "Refs [#122](https://github.com/min-null/minchat-hq/issues/122)",
                "min-null/minchat-backend",
                "develop",
            ),
            [("min-null/minchat-hq", 122, False)],
        )

    def test_plain_issue_number_stays_in_current_repo(self):
        self.assertEqual(
            extract_links("Fixes #42", "min-null/minchat-backend", ""),
            [("min-null/minchat-backend", 42, True)],
        )

    def test_branch_fallback_is_preserved(self):
        self.assertEqual(
            extract_links("No issue reference", "min-null/minchat-backend", "issues-83-cleanup"),
            [("min-null/minchat-backend", 83, True)],
        )

    def test_release_closes_cross_repo_reference_but_not_a_local_mention(self):
        self.assertTrue(should_close_issue(False, "min-null/minchat-backend", "min-null/minchat-hq", "main", True))
        self.assertFalse(should_close_issue(False, "min-null/minchat-backend", "min-null/minchat-hq", "develop", False))
        self.assertFalse(should_close_issue(False, "min-null/minchat-backend", "min-null/minchat-backend", "main", True))


if __name__ == "__main__":
    unittest.main()
