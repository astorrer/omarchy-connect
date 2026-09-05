#!/usr/bin/python3
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from connectlib.messages import chip_label, parse_attachment, parse_message

TINY_PNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="


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
        with tempfile.TemporaryDirectory() as tmp:
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
                [
                    (190, "image/png", TINY_PNG, "PART_1_pic.png"),
                    (191, "application/pdf", "", "scan.pdf"),
                ],
            )
            message = parse_message(raw, Path(tmp))
            self.assertEqual(message["addresses"], ["+1", "+2"])
            self.assertFalse(message["fromMe"])
            self.assertEqual(message["attachmentCount"], 2)
            self.assertEqual(message["id"], 12)
            self.assertEqual(message["attachments"][0]["kind"], "image")
            self.assertTrue(message["attachments"][0]["thumb"].startswith("file:"))
            self.assertEqual(message["attachments"][1]["kind"], "file")
            self.assertEqual(message["attachments"][1]["label"], "scan.pdf")

    def test_chip_label(self):
        self.assertEqual(chip_label("image/jpeg", "PART_123_cat.jpg"), "cat.jpg")
        self.assertEqual(chip_label("application/pdf", ""), "PDF")
        self.assertEqual(chip_label("audio/mpeg", "voicenote.m4a"), "voicenote.m4a")

    def test_parse_attachment_dict(self):
        parsed = parse_attachment(
            {"part_id": 3, "mime_type": "video/mp4", "unique_identifier": "clip.mp4"},
            Path("/tmp"),
        )
        self.assertEqual(parsed["kind"], "file")
        self.assertEqual(parsed["label"], "clip.mp4")

    def test_parse_rejects_junk(self):
        self.assertIsNone(parse_message(None))
        self.assertIsNone(parse_message([1, 2, 3]))


if __name__ == "__main__":
    unittest.main()
