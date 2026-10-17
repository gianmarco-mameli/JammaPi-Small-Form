import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class AudioTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.cards = self.directory / "cards"
        self.cards.write_text(
            " 0 [b1             ]: bcm2835_hdmi - bcm2835 HDMI 1\n"
            "                      bcm2835 HDMI 1\n"
            " 1 [Headphones     ]: bcm2835_headpho - bcm2835 Headphones\n"
            "                      bcm2835 Headphones\n"
        )
        self.config = self.directory / "asound.conf"
        self.config.write_text((ROOT / "script/asound.conf").read_text())
        self.log = self.directory / "amixer.log"
        mixer = self.directory / "amixer"
        mixer.write_text(
            '#!/bin/bash\nprintf "%s\\n" "$*" >> "$MIXER_LOG"\n'
            'if [ "$3" = controls ]; then\n'
            '  echo "numid=8,iface=MIXER,name=\'PCM Playback Route\'"\n'
            'fi\n'
        )
        mixer.chmod(0o755)
        self.environment = dict(
            os.environ, PATH=str(self.directory) + os.pathsep + os.environ["PATH"],
            MIXER_LOG=str(self.log),
        )

    def select(self, output, check=True):
        return subprocess.run(
            ["bash", str(ROOT / "script/select-audio.sh"), output,
             str(self.config), str(self.cards)],
            check=check, capture_output=True, text=True, env=self.environment,
        )

    def test_split_cards_are_selected_idempotently_without_mixer_route(self):
        for output, card in (("HDMI", "b1"), ("JAMMA", "Headphones"),
                             ("HDMI", "b1")):
            self.select(output)
            first = self.config.read_text()
            self.assertIn(f'slave.pcm "plughw:CARD={card},DEV=0"', first)
            self.assertIn(f'ctl.!default {{ type hw card "{card}" }}', first)
            self.assertIn("1.0 0", first)
            modified = self.config.stat().st_mtime_ns
            self.select(output)
            self.assertEqual(first, self.config.read_text())
            self.assertEqual(modified, self.config.stat().st_mtime_ns)
        self.assertFalse(self.log.exists())

    def test_card_indices_do_not_matter_and_mono_is_preserved(self):
        self.cards.write_text(" 4 [Headphones ]: bcm2835_headpho - bcm2835 Headphones\n")
        self.config.write_text(self.config.read_text().replace("1.0 0", "1.0 1"))
        self.select("JAMMA")
        self.assertIn("plughw:CARD=Headphones,DEV=0", self.config.read_text())
        self.assertIn("1.0 1", self.config.read_text())

    def test_missing_output_fails_without_modifying_configuration(self):
        original = self.config.read_bytes()
        self.cards.write_text(" 1 [Headphones ]: bcm2835_headpho - bcm2835 Headphones\n")
        result = self.select("HDMI", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("non disponibile", result.stderr)
        self.assertEqual(self.config.read_bytes(), original)

    def test_legacy_card_uses_named_control_on_explicit_card(self):
        self.cards.write_text(" 0 [ALSA ]: bcm2835 - bcm2835 ALSA\n")
        for output, route in (("HDMI", "2"), ("JAMMA", "1")):
            self.select(output)
            self.assertIn(f"-c ALSA cset name=PCM Playback Route {route}",
                          self.log.read_text())
            self.assertIn("plughw:CARD=ALSA,DEV=0", self.config.read_text())

    def test_invalid_config_fails_without_overwriting(self):
        self.config.write_text("invalid config\n")
        result = self.select("HDMI", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.config.read_text(), "invalid config\n")


if __name__ == "__main__":
    unittest.main()
