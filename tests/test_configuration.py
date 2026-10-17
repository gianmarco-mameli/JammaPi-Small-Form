import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class ConfigurationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.config = self.directory / "config.txt"
        self.config.write_text("")

    def configure(self, operation="boot", mode="CRT", model="Raspberry Pi 4 Model B"):
        subprocess.run(
            ["bash", str(ROOT / "script/configure.sh"), operation,
             str(self.config), mode, model],
            check=True, capture_output=True, text=True,
        )
        return self.config.read_text()

    def test_partial_install_is_repaired_and_repeated_run_is_unchanged(self):
        self.config.write_text("dtparam=i2c_vc=on\n# user comment\n")
        first = self.configure()
        self.assertIn("enable_dpi_lcd=1\n", first)
        self.assertIn("# user comment\n", first)
        self.assertEqual(first.count("dtparam=i2c_vc=on\n"), 1)
        modified = self.config.stat().st_mtime_ns
        self.assertEqual(first, self.configure())
        self.assertEqual(modified, self.config.stat().st_mtime_ns)

    def test_old_duplicates_and_conflicting_sections_are_cleaned(self):
        self.config.write_text(
            "#hdmi_force_hotplug=0\n[pi4]\n"
            "dtoverlay=vga666-6\n#*#*dtoverlay=vga666,mode6\n"
            "audio_pwm_mode=2\naudio_pwm_mode=3\n"
            "#*dpi_mode=9\ndpi_mode=87\n#*#*HDMI\n#CRT\n"
            "dtoverlay=audremap,pins_18_19\n"
            "dtoverlay=pwm-2chan,pin=18,func=2,pin2=19,func2=2\n"
            "dtoverlay=spi-display\n[pi3]\ngpu_mem=64\n"
        )
        result = self.configure()
        self.assertEqual(result.count("dtoverlay=vga666"), 1)
        self.assertEqual(result.count("audio_pwm_mode="), 1)
        self.assertEqual(result.count("dpi_mode="), 1)
        self.assertNotIn("pwm-2chan", result)
        self.assertNotIn("#HDMI", result)
        self.assertIn("dtoverlay=spi-display\n[pi3]\ngpu_mem=64\n[all]\n", result)
        self.assertEqual(result, self.configure())

    def test_hdmi_crt_round_trip_and_model_change(self):
        crt = self.configure()
        hdmi = self.configure(mode="HDMI")
        self.assertIn("#*dtoverlay=vga666,mode6\n", hdmi)
        self.assertIn("#*dtoverlay=audremap,pins_18_19\n", hdmi)
        self.assertIn("#HDMI\n", hdmi)
        self.assertNotIn("\ndpi_mode=", hdmi)
        self.assertEqual(hdmi, self.configure(mode="HDMI"))
        self.assertEqual(crt, self.configure())
        pi3 = self.configure(model="Raspberry Pi 3 Model B")
        self.assertNotIn("audremap", pi3)
        self.assertEqual(pi3.count("dtoverlay=pwm-2chan"), 1)

    def test_other_i2c_parameters_and_comments_are_preserved(self):
        self.config.write_text(
            "dtparam=audio=on,i2c_vc=off,spi=on\n"
            "#dtparam=i2c_arm=on,i2c_vc=off\n"
            "# Example: hdmi_timings=custom\n"
        )
        result = self.configure()
        self.assertIn("dtparam=audio=on,spi=on\n", result)
        self.assertIn("#dtparam=i2c_arm=on\n", result)
        self.assertIn("# Example: hdmi_timings=custom\n", result)
        self.assertEqual(result.count("i2c_vc="), 1)
        self.assertEqual(result, self.configure())

    def test_audio_selection_preserves_hdmi_video(self):
        self.configure(mode="HDMI")
        result = self.configure("audio")
        self.assertIn("#HDMI\n", result)
        self.assertIn("#*dtoverlay=vga666,mode6\n", result)
        self.assertIn("\ndtoverlay=audremap,pins_18_19\n", result)
        self.assertEqual(result.count("audio_pwm_mode="), 1)
        self.assertEqual(result, self.configure("audio"))

    def test_modules_and_retroarch_are_normalized(self):
        self.config.write_text("#i2c-dev\ni2c-dev\ni2c-dev\nspi-dev\n")
        result = self.configure("modules")
        self.assertEqual(result, "spi-dev\ni2c-dev\n")
        self.assertEqual(result, self.configure("modules"))
        self.config.write_text(
            '#crt_switch_resolution = "1"\ncrt_switch_resolution = "2"\n'
            'crt_switch_resolution_super = "1920"\nvideo_driver = "gl"\n'
        )
        for mode in ("0", "1", "2", "0"):
            result = self.configure("retroarch", mode)
            self.assertEqual(result.count("crt_switch_resolution ="), 1)
            self.assertEqual(result.count("crt_switch_resolution_super ="), 1)
            self.assertIn(f'crt_switch_resolution = "{mode}"\n', result)
            super_resolution = "0" if mode == "0" else "1920"
            self.assertIn(
                f'crt_switch_resolution_super = "{super_resolution}"\n', result
            )
            self.assertIn('video_driver = "gl"\n', result)
            self.assertEqual(result, self.configure("retroarch", mode))

    def test_symlink_and_permissions_are_preserved(self):
        target = self.directory / "real-config.txt"
        self.config.rename(target)
        target.chmod(0o640)
        self.config.symlink_to(target)
        self.configure()
        self.assertTrue(self.config.is_symlink())
        self.assertEqual(target.stat().st_mode & 0o777, 0o640)
        self.assertIn("#CRT\n", target.read_text())

    def test_invalid_arguments_and_missing_input_fail(self):
        for operation, mode in (("boot", "invalid"), ("retroarch", "3"),
                                ("invalid", "CRT")):
            result = subprocess.run(
                ["bash", str(ROOT / "script/configure.sh"), operation,
                 str(self.config), mode], capture_output=True, text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertTrue(result.stderr)
            self.assertEqual(self.config.read_text(), "")
        self.config.unlink()
        with self.assertRaises(subprocess.CalledProcessError):
            self.configure()
        self.assertFalse(self.config.exists())

    def test_video_selection_scripts_are_repeatable(self):
        scripts = self.directory / "script"
        scripts.mkdir()
        configs = self.directory / "retropie"
        configs.mkdir()
        model = self.directory / "model"
        model.write_text("Raspberry Pi 3 Model B")
        retroarch = configs / "retroarch.cfg"
        retroarch.write_text("")
        for name in ("runcommand-onend.sh", "runcommand-onstart.sh"):
            (configs / name).symlink_to(ROOT / "script" / name)
        for name in ("configure.sh", "interfaccia.sh", "pixelperfect.sh"):
            text = (ROOT / "script" / name).read_text()
            text = text.replace("/boot/config.txt", str(self.config))
            text = text.replace("/proc/device-tree/model", str(model))
            text = text.replace("/opt/retropie/configs/all", str(configs))
            (scripts / name).write_text(text)
        commands = self.directory / "bin"
        commands.mkdir()
        for name, body in (("sudo", 'exec "$@"'), ("sleep", ":")):
            command = commands / name
            command.write_text("#!/bin/bash\n" + body + "\n")
            command.chmod(0o755)
        environment = dict(os.environ, PATH=str(commands) + os.pathsep + os.environ["PATH"])

        def select(mode):
            subprocess.run(
                ["bash", str(scripts / "interfaccia.sh"), mode],
                check=True, env=environment, capture_output=True, text=True,
            )
            return self.config.read_text(), retroarch.read_text()

        for model_name in ("Raspberry Pi 3 Model B", "Raspberry Pi 4 Model B"):
            model.write_text(model_name)
            for mode, marker in (("-SCART", "#CRT"), ("-HDMI", "#HDMI"),
                                 ("-HDMI", "#HDMI"), ("-SCART", "#CRT")):
                first = select(mode)
                self.assertEqual(first, select(mode))
                self.assertIn(marker + "\n", first[0])
                for name in ("runcommand-onend.sh", "runcommand-onstart.sh"):
                    self.assertEqual((configs / name).is_symlink(), mode == "-SCART")
                    self.assertEqual((configs / (name + ".off")).is_symlink(), mode == "-HDMI")

        select("-HDMI")
        for name in ("runcommand-onend.sh", "runcommand-onstart.sh"):
            (configs / name).symlink_to(ROOT / "script" / name)
        select("-SCART")
        for name in ("runcommand-onend.sh", "runcommand-onstart.sh"):
            self.assertFalse((configs / (name + ".off")).is_symlink())

        (configs / "runcommand-onend.sh").unlink()
        failed = subprocess.run(
            ["bash", str(scripts / "interfaccia.sh"), "-HDMI"],
            env=environment, capture_output=True, text=True,
        )
        self.assertNotEqual(failed.returncode, 0)
        self.assertIn("Script mancante", failed.stderr)

    def test_installer_can_be_run_twice_without_changing_edited_files(self):
        system = self.directory / "system"
        repository = system / "home/pi/JammaPi-Small-Form"
        shutil.copytree(ROOT / "script", repository / "script")
        shutil.copytree(ROOT / "joypi", repository / "joypi")
        shutil.copytree(ROOT / "services", repository / "services")
        for name in ("vga666.dtbo", "dt-blob.bin"):
            (repository / name).write_text("fixture")
        for name in ("boot/overlays", "etc/systemd/system",
                     "etc/apt/sources.list.d",
                     "opt/retropie/configs/all/retroarch-joypads",
                     "opt/retropie/configs/all/emulationstation",
                     "home/pi/RetroPie/retropiemenu", "opt/.emulationstation",
                     "proc/device-tree"):
            (system / name).mkdir(parents=True, exist_ok=True)
        for name in ("boot/config.txt", "etc/modules",
                     "opt/retropie/configs/all/retroarch.cfg"):
            (system / name).write_text("")
        (system / "boot/overlays/vga666.dtbo").write_text("old overlay")
        (system / "boot/dt-blob.bin").write_text("old device tree")
        original = system / "opt/.emulationstation/es_input.cfg"
        (system / "etc/os-release").write_text(
            'ID=raspbian\nVERSION_ID="10"\nVERSION_CODENAME=buster\n'
        )
        sources = system / "etc/apt/sources.list"
        sources.write_text(
            "deb http://raspbian.raspberrypi.org/raspbian buster main contrib\n"
        )
        original.write_text("original joystick configuration")
        (system / "proc/device-tree/model").write_text("Raspberry Pi 4 Model B")
        # Only the installer's paths are redirected; no host system files are edited.
        text = (ROOT / "install.sh").read_text()
        for prefix in ("/boot/", "/etc/", "/opt/", "/home/", "/proc/"):
            text = text.replace(prefix, str(system) + prefix)
        installer = repository / "install.sh"
        installer.write_text(text)
        commands = self.directory / "bin"
        commands.mkdir()
        for name, body in (
            ("sudo", 'exec "$@"'), ("lsmod", "echo 'joypi 123 0'"),
            ("apt-get", ":"), ("systemctl", ":"), ("sleep", ":"),
            ("reboot", ":"),
            ("ln", 'for target in "$@"; do\n'
                   'case "$target" in\n'
                   f'"{system}/boot/"*) echo "Boot partition cannot use symlinks" >&2; exit 1 ;;\n'
                   'esac\ndone\n'
                   f'exec "{shutil.which("ln")}" "$@"'),
        ):
            command = commands / name
            command.write_text("#!/bin/bash\n" + body + "\n")
            command.chmod(0o755)
        # Do not enter the interactive menu (which can reboot the real machine).
        (repository / "script/switchvideo.sh").write_text("#!/bin/bash\nexit 0\n")
        dialog = commands / "dialog"
        dialog.write_text("#!/bin/bash\nexit 0\n")
        dialog.chmod(0o755)
        environment = dict(os.environ, PATH=str(commands) + os.pathsep + os.environ["PATH"])

        def install():
            subprocess.run(
                ["bash", str(installer)], cwd=self.directory,
                env=environment, check=True, capture_output=True, text=True,
            )
            return {
                path: path.read_bytes()
                for path in (system / "boot/config.txt", system / "etc/modules",
                             system / "boot/overlays/vga666.dtbo",
                             system / "boot/dt-blob.bin",
                             system / "opt/retropie/configs/all/retroarch.cfg",
                             sources, sources.with_name("sources.list.jammapi.bak"),
                             original.with_suffix(".cfg.bak"))
            }

        first = install()
        original.write_text("changed after first installation")
        self.assertEqual(first, install())
        self.assertEqual(original.with_suffix(".cfg.bak").read_text(),
                         "original joystick configuration")
        self.assertEqual(sources.read_text(),
                         "deb https://legacy.raspbian.org/raspbian/ buster main contrib\n")
        for target, source in (("boot/overlays/vga666.dtbo", "vga666.dtbo"),
                               ("boot/dt-blob.bin", "dt-blob.bin")):
            self.assertFalse((system / target).is_symlink())
            self.assertEqual((system / target).read_bytes(),
                             (repository / source).read_bytes())
        self.assertEqual((system / "etc/asound.conf").resolve(),
                         (repository / "script/asound.conf").resolve())
        for target, source in (
            ("etc/systemd/system/jammapi.service", "services/jammapi.service"),
            ("home/pi/RetroPie/retropiemenu/JammaPi.sh", "script/menu.sh"),
            ("opt/retropie/configs/all/runcommand-onstart.sh",
             "script/runcommand-onstart.sh"),
            ("opt/retropie/configs/all/emulationstation/es_input.cfg",
             "joypi/es_input.cfg"),
        ):
            self.assertEqual((system / target).resolve(),
                             (repository / source).resolve())

    def test_runtime_paths_use_home_installation(self):
        for path in [ROOT / "install.sh", *sorted((ROOT / "script").glob("*.sh")),
                     ROOT / "services/jammapi.service"]:
            with self.subTest(path=path.name):
                text = path.read_text()
                self.assertNotIn("/opt/JammaPi", text)
                self.assertNotIn("/home/pi/JammaPi/", text)
        service = (ROOT / "services/jammapi.service").read_text()
        self.assertIn(
            "ExecStart=/home/pi/JammaPi-Small-Form/script/jammapi.sh\n", service
        )


if __name__ == "__main__":
    unittest.main()
