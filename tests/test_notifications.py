#!/usr/bin/python3
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from connectlib.notice import parse_notification


class NotificationsTest(unittest.TestCase):
    def test_parse_basic(self):
        item = parse_notification(
            "16",
            {
                "appName": "Wyze",
                "title": "Garage Door Is Closed",
                "text": "Garage Cam at 9:37 PM.",
                "ticker": "Garage Door Is Closed: Garage Cam at 9:37 PM.",
                "silent": True,
                "dismissable": True,
                "replyId": "",
                "isConversation": False,
                "hasIcon": True,
            },
        )
        self.assertEqual(item["id"], "16")
        self.assertEqual(item["appName"], "Wyze")
        self.assertEqual(item["title"], "Garage Door Is Closed")
        self.assertTrue(item["dismissable"])
        self.assertFalse(item["canReply"])

    def test_parse_replyable(self):
        item = parse_notification(
            "8",
            {
                "appName": "Messages",
                "title": "(707) 595-9859",
                "text": "Hello",
                "replyId": "a2555cb3-fbec-4634-a879-d8fb30044eb6",
                "isConversation": True,
                "dismissable": True,
            },
        )
        self.assertTrue(item["canReply"])
        self.assertTrue(item["isConversation"])
        self.assertEqual(item["replyId"], "a2555cb3-fbec-4634-a879-d8fb30044eb6")

    def test_parse_empty(self):
        item = parse_notification("1", {})
        self.assertEqual(item["id"], "1")
        self.assertEqual(item["title"], "")
        self.assertFalse(item["canReply"])


if __name__ == "__main__":
    unittest.main()
