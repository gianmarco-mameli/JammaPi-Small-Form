from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class AptSourcesTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.os_release = self.directory / "os-release"
        self.os_release.write_text(
            'ID=raspbian\nVERSION_ID="10"\nVERSION_CODENAME=buster\n'
        )
        self.apt = self.directory / "apt"
        (self.apt / "sources.list.d").mkdir(parents=True)
        self.sources = self.apt / "sources.list"

    def prepare(self):
        return subprocess.run(
            ["bash", str(ROOT / "script/prepare-apt.sh"),
             str(self.os_release), str(self.apt)],
            check=True, capture_output=True, text=True,
        )

    def test_old_buster_mirrors_are_replaced_and_backup_is_preserved(self):
        original = (
            "deb http://raspbian.raspberrypi.org/raspbian buster main contrib non-free rpi\n"
            "deb-src [signed-by=/usr/share/keyrings/raspbian.gpg] "
            "https://mirrordirector.raspbian.org/raspbian/ buster main\n"
        )
        self.sources.write_text(original)
        extra = self.apt / "sources.list.d/old.list"
        extra.write_text("deb http://archive.raspbian.org/raspbian buster main\n")
        self.prepare()
        expected = original.replace(
            "http://raspbian.raspberrypi.org/raspbian",
            "https://legacy.raspbian.org/raspbian/",
        ).replace("https://mirrordirector.raspbian.org/raspbian/",
                  "https://legacy.raspbian.org/raspbian/")
        self.assertEqual(self.sources.read_text(), expected)
        self.assertEqual(extra.read_text(),
                         "deb https://legacy.raspbian.org/raspbian/ buster main\n")
        backup = self.apt / "sources.list.jammapi.bak"
        self.assertEqual(backup.read_text(), original)
        modified = self.sources.stat().st_mtime_ns
        self.assertEqual(self.prepare().stdout, "")
        self.assertEqual(self.sources.stat().st_mtime_ns, modified)
        self.assertEqual(backup.read_text(), original)

    def test_unrelated_repositories_options_and_comments_are_preserved(self):
        original = (
            "# deb http://raspbian.raspberrypi.org/raspbian buster main\n"
            "deb http://archive.raspberrypi.org/debian buster main\n"
            "deb http://raspbian.raspberrypi.org/raspbian bullseye main\n"
            "deb https://example.org/raspbian buster main\n"
            "deb https://legacy.raspbian.org/raspbian/ buster main\n"
        )
        self.sources.write_text(original)
        self.prepare()
        self.assertEqual(self.sources.read_text(), original)
        self.assertFalse((self.apt / "sources.list.jammapi.bak").exists())

    def test_other_operating_systems_are_not_modified(self):
        original = "deb http://raspbian.raspberrypi.org/raspbian buster main\n"
        self.sources.write_text(original)
        for release in (
            'ID=raspbian\nVERSION_ID="11"\nVERSION_CODENAME=bullseye\n',
            'ID=debian\nVERSION_ID="10"\nVERSION_CODENAME=buster\n',
        ):
            self.os_release.write_text(release)
            self.prepare()
            self.assertEqual(self.sources.read_text(), original)

    def test_version_id_detection_and_missing_sources_list(self):
        self.os_release.write_text('ID=raspbian\nVERSION_ID="10"\n')
        extra = self.apt / "sources.list.d/raspbian.list"
        extra.write_text("deb http://raspbian.raspberrypi.org/raspbian buster main\n")
        self.prepare()
        self.assertIn("https://legacy.raspbian.org/raspbian/", extra.read_text())
        self.assertFalse(self.sources.exists())

    def test_missing_os_release_fails_explicitly(self):
        self.os_release.unlink()
        with self.assertRaises(subprocess.CalledProcessError):
            self.prepare()


if __name__ == "__main__":
    unittest.main()
