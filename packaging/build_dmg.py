#!/usr/bin/env python3
"""Build a universal macOS app and a drag-to-Applications disk image.

Install packaging/requirements.txt in the Python environment used to run this file.
The default build uses an ad-hoc signature. For public distribution, pass a
Developer ID Application identity and a notarytool Keychain profile to sign,
notarize and staple both the app and disk image.
"""
import argparse
import json
import re
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

import dmgbuild

ROOT = Path(__file__).resolve().parent.parent

def run(*args, **kwargs):
    subprocess.run([str(arg) for arg in args], check=True, **kwargs)

def make_app(work):
    architecture_apps = []
    for architecture in ("arm64", "x86_64"):
        build_directory = work / architecture
        environment = dict(os.environ)
        environment["NYXWATCH_BUILD_DIR"] = str(build_directory)
        environment["NYXWATCH_TARGET"] = f"{architecture}-apple-macosx13.0"
        run("bash", ROOT / "build.sh", env=environment)
        architecture_apps.append(build_directory / "NyxWatch.app")

    app = work / "NyxWatch.app"
    shutil.copytree(architecture_apps[0], app)
    binary = Path("Contents/MacOS/NyxWatch")
    run("lipo", "-create", *(path / binary for path in architecture_apps),
        "-output", app / binary)
    return app

def developer_id_identity(requested):
    result = subprocess.run(
        ["security", "find-identity", "-v", "-p", "codesigning"],
        capture_output=True, text=True, check=True,
    )
    identities = re.findall(r'([0-9A-F]{40}) "([^"]+)"', result.stdout)
    for fingerprint, name in identities:
        if requested in (fingerprint, name) and name.startswith("Developer ID Application:"):
            return fingerprint
    raise ValueError("A valid Developer ID Application identity with its private key is required.")


def sign_app(app, identity):
    if identity:
        run("codesign", "--force", "--sign", identity, "--options", "runtime",
            "--timestamp", "--entitlements", ROOT / "packaging/entitlements.plist", app)
    else:
        run("codesign", "--force", "--sign", "-", app)
    run("codesign", "--verify", "--deep", "--strict", app)


def notarize(file, profile, report_prefix):
    result = subprocess.run(
        ["xcrun", "notarytool", "submit", str(file), "--keychain-profile", profile,
         "--wait", "--timeout", "10m", "--output-format", "json"],
        capture_output=True, text=True,
    )
    report_path = Path(str(report_prefix) + ".submission.json")
    report_path.write_text(result.stdout)
    try:
        submission = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError("Notarization did not return a submission report. "
                           + result.stderr.strip()) from error
    submission_id = submission.get("id")
    if submission_id:
        print("Apple submission", submission_id, submission.get("status"), flush=True)
        log_path = Path(str(report_prefix) + ".log.json")
        run("xcrun", "notarytool", "log", submission_id,
            "--keychain-profile", profile, log_path)
    if result.returncode or submission.get("status") != "Accepted":
        raise RuntimeError("Apple has not accepted the submission. See " + str(report_path))
    if file.suffix != ".zip":
        run("xcrun", "stapler", "staple", file)
        run("xcrun", "stapler", "validate", file)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "build/NyxWatch.dmg")
    parser.add_argument("--arm-app", type=Path, help="Reuse a compiled arm64 app.")
    parser.add_argument("--intel-app", type=Path, help="Reuse a compiled Intel app.")
    parser.add_argument("--signing-identity", help="Developer ID Application name or fingerprint.")
    parser.add_argument("--notary-profile", help="Existing notarytool Keychain profile.")
    args = parser.parse_args()
    if args.notary_profile and not args.signing_identity:
        parser.error("--notary-profile requires --signing-identity")
    try:
        identity = developer_id_identity(args.signing_identity) if args.signing_identity else None
    except ValueError as error:
        parser.error(str(error))
    if args.notary_profile:
        subprocess.run(
            ["xcrun", "notarytool", "history", "--keychain-profile",
             args.notary_profile, "--output-format", "json"],
            check=True, stdout=subprocess.DEVNULL,
        )
    if bool(args.arm_app) != bool(args.intel_app):
        parser.error("--arm-app and --intel-app must be used together")
    destination = args.output.resolve()
    destination.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="nyxwatch-dmg-") as directory:
        work = Path(directory)
        if args.arm_app:
            app = work / "NyxWatch.app"
            shutil.copytree(args.arm_app, app)
            run("lipo", "-create", args.arm_app / "Contents/MacOS/NyxWatch",
                args.intel_app / "Contents/MacOS/NyxWatch",
                "-output", app / "Contents/MacOS/NyxWatch")
        else:
            app = make_app(work)
        sign_app(app, identity)
        run("lipo", app / "Contents/MacOS/NyxWatch",
            "-verify_arch", "arm64", "x86_64")
        if args.notary_profile:
            archive = work / "NyxWatch.zip"
            run("ditto", "-c", "-k", "--keepParent", app, archive)
            notarize(archive, args.notary_profile, destination.with_suffix(".app-notary"))
            run("xcrun", "stapler", "staple", app)
            run("xcrun", "stapler", "validate", app)
            run("spctl", "--assess", "--type", "execute", "--verbose=2", app)

        image = work / "NyxWatch.dmg"
        dmgbuild.build_dmg(
            str(image),
            "NyxWatch",
            settings={
                "format": "UDZO",
                "filesystem": "HFS+",
                "files": [str(app)],
                "symlinks": {"Applications": "/Applications"},
                "icon": str(app / "Contents/Resources/AppIcon.icns"),
                "background": str(ROOT / "packaging/dmg-background.png"),
                "window_rect": ((160, 140), (720, 440)),
                "icon_locations": {"NyxWatch.app": (180, 235), "Applications": (540, 235)},
                "icon_size": 104,
                "text_size": 15,
                "show_toolbar": False,
                "show_sidebar": False,
                "show_status_bar": False,
                "default_view": "icon-view",
            },
        )
        if identity:
            run("codesign", "--force", "--sign", identity, "--timestamp", image)
            run("codesign", "--verify", "--strict", image)
        if args.notary_profile:
            notarize(image, args.notary_profile, destination.with_suffix(".dmg-notary"))
            run("spctl", "--assess", "--type", "open",
                "--context", "context:primary-signature", "--verbose=2", image)
        run("hdiutil", "verify", image)
        image.replace(destination)
    print(destination)

if __name__ == "__main__":
    main()
