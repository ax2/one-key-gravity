#!/usr/bin/env python3
"""Export and inspect a test APK using signing material stored outside the project."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import zipfile

project = Path(__file__).resolve().parents[1]
toolchain = Path(os.environ.get("GODOT_TOOLCHAIN_ROOT", project.parent / ".godot-toolchain"))
credential_file = Path(os.environ.get("GODOT_TEST_CREDENTIALS", toolchain / "private/android-test-signing.json")).resolve()
if credential_file.is_relative_to(project):
    raise SystemExit("Signing material must remain outside the source project")
if not credential_file.exists():
    raise SystemExit("No test signing credentials found. Configure a test key outside the project first.")
credentials = json.loads(credential_file.read_text())
env = os.environ.copy()
env.update({
    "XDG_DATA_HOME": str(toolchain / "data"),
    "XDG_CONFIG_HOME": str(toolchain / "config"),
    "XDG_CACHE_HOME": str(toolchain / "cache"),
    "JAVA_HOME": "/usr/lib/jvm/java-21-openjdk-amd64",
    "ANDROID_USER_HOME": str(toolchain / "android-user-home"),
    "GODOT_ANDROID_KEYSTORE_DEBUG_PATH": credentials["keystore"],
    "GODOT_ANDROID_KEYSTORE_DEBUG_USER": credentials["alias"],
    "GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD": credentials["password"],
})
apk = project / "build/android/OneKeyGravity-test.apk"
apk.parent.mkdir(parents=True, exist_ok=True)
build_tools = toolchain / "android-sdk/build-tools/36.0.0"
log_parts = []
source_sha256 = hashlib.sha256((project / "main.gd").read_bytes()).hexdigest()

def run(command):
    result = subprocess.run(command, env=env, cwd=project, capture_output=True, text=True)
    output = result.stdout + result.stderr
    for sensitive in (credentials["password"], credentials["keystore"], credentials["alias"]):
        output = output.replace(sensitive, "<REDACTED>")
    log_parts.append(output)
    print(output, end="")
    if result.returncode:
        (project / "tests/android-export.log").write_text("\n".join(log_parts))
        raise SystemExit(result.returncode)
    return output

godot = os.environ.get("GODOT", "godot")
run([godot, "--headless", "--path", str(project), "--import", "--quit"])
run([godot, "--headless", "--path", str(project), "--export-debug", "Android", str(apk)])
run([str(build_tools / "apksigner"), "verify", "--verbose", "--print-certs", str(apk)])
manifest = run([str(build_tools / "aapt"), "dump", "badging", str(apk)])
assert "package: name='org.ax2.onekeygravity'" in manifest, "Unexpected Android package"
assert "sdkVersion:'24'" in manifest, "Unexpected minimum Android SDK"
assert "targetSdkVersion:'36'" in manifest, "Unexpected target Android SDK"
assert "native-code: 'arm64-v8a'" in manifest, "Unexpected Android architectures"
assert "android.permission.INTERNET" not in manifest, "Unexpected network permission"
manifest_tree = run([str(build_tools / "aapt"), "dump", "xmltree", str(apk), "AndroidManifest.xml"])
assert '"android.intent.category.LAUNCHER"' in manifest_tree, "Missing launcher intent"
assert '"android.intent.action.MAIN"' in manifest_tree, "Missing main activity intent"
with zipfile.ZipFile(apk) as archive:
    names = archive.namelist()
    assert "assets/assets/FONT-LICENSE.txt" in names, "Font license missing from APK"
    assert "assets/assets/GODOT-LICENSE.txt" in names, "Godot license missing from APK"
    assert not any("keystore" in name.lower() or "android-test-signing" in name.lower() for name in names), "Signing material must never be packaged"
run([str(build_tools / "zipalign"), "-c", "-P", "16", "4", str(apk)])
assert source_sha256 == hashlib.sha256((project / "main.gd").read_bytes()).hexdigest(), "Game changed during export; rerun to build latest source"
summary = {
    "artifact": str(apk.relative_to(project)),
    "sha256": hashlib.sha256(apk.read_bytes()).hexdigest(),
    "size_bytes": apk.stat().st_size,
    "source_sha256": source_sha256,
    "signing": "test-only",
    "verification": ["APK signature", "Android manifest", "16 KiB ZIP alignment"],
    "not_verified": ["Installation and gameplay on a physical Android device"],
}
(project / "tests/android-export.log").write_text("\n".join(log_parts))
(project / "build/android/build-info.json").write_text(json.dumps(summary, indent=2) + "\n")
print(json.dumps(summary, indent=2))
