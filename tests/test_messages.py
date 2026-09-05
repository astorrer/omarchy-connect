#!/usr/bin/python3
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from connectlib.messages import parse_message


class MessagesTest(unittest.TestCase):
    def test_parse_dict(self):
        message = parse_message(
            {
                "event": 1,
                "body": "hello",
                "addresses": ["+18015550100"],
                "date": 10,
                "type": 2,
                "read": 1,
                "threadId": 7,
                "id": 9,
                "fromMe": True,
                "attachmentCount": 0,
            }
        )
        self.assertEqual(message["body"], "hello")
        self.assertEqual(message["addresses"], ["+18015550100"])
        self.assertTrue(message["fromMe"])
        self.assertEqual(message["threadId"], 7)

    def test_parse_tuple_and_attachments(self):
        raw = (
            0,
            "hi",
            [("+1",), ("+1",), "+2"],
            123,
            1,
            0,
            44,
            12,
            0,
            ["a", "b"],
        )
        message = parse_message(raw)
        self.assertEqual(message["addresses"], ["+1", "+2"])
        self.assertFalse(message["fromMe"])
        self.assertEqual(message["attachmentCount"], 2)
        self.assertEqual(message["id"], 12)

    def test_parse_rejects_junk(self):
        self.assertIsNone(parse_message(None))
        self.assertIsNone(parse_message([1, 2, 3]))


if __name__ == "__main__":
    unittest.main()
