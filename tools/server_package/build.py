"""Build the item-5 Windows server ZIP; no publication or workflow changes.

python tools/server_package/build.py --godot /path/to/godot --output /tmp/server.zip
Requires the pinned 4.7.2 Windows export templates. Output must be outside source.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
ASSET = "Shipping-Lanes-Server-Windows-x64.zip"


def package(export_dir, output, version):
    if not re.fullmatch(r"v\d+\.\d+\.\d+", version):
        raise ValueError("Expected stable tag vMAJOR.MINOR.PATCH")
    files = sorted(p for p in export_dir.rglob("*") if p.is_file())
    allowed = {".exe", ".pck", ".dll", ".dat"}
    if not {"ShippingLanesServer.exe", "ShippingLanesServer.pck"} <= {p.name for p in files}:
        raise ValueError("Missing dedicated Windows executable/PCK")
    if any(p.suffix.lower() not in allowed for p in files):
        raise ValueError("Unexpected export content; refusing to package operator data")
    payload = {p.relative_to(export_dir).as_posix(): p.read_bytes() for p in files}
    for name in ("ServerCore.ps1", "ServerLauncher.ps1"):
        payload[name] = (Path(__file__).parent / name).read_bytes()
    manifest = {"version": version, "engine": "4.7.2", "files": {
        name: hashlib.sha256(data).hexdigest() for name, data in payload.items()}}
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.write(Path(__file__).parent / "LaunchServer.cmd", "LaunchServer.cmd")
        archive.write(Path(__file__).parent / "Bootstrap.ps1", "Bootstrap.ps1")
        archive.writestr("current.json", json.dumps({"version": version}))
        archive.writestr("server-config.json", json.dumps({"port": 24565, "bind": "0.0.0.0", "public_address": ""}, indent=2))
        for name, data in payload.items():
            archive.writestr(f"versions/{version}/{name}", data)
        archive.writestr(f"versions/{version}/package.json", json.dumps(manifest, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if ROOT in output.parents and ROOT / "exports" not in output.parents:
        parser.error("Use exports/ or a directory outside the repository")
    engine = subprocess.check_output([args.godot, "--version"], text=True).strip()
    if not engine.startswith("4.7.2."):
        parser.error(f"Godot 4.7.2 required; found {engine}")
    version_match = re.search(r'const VERSION: String = "([0-9.]+)"', (ROOT / "features/network/play_connection.gd").read_text())
    version = "v" + version_match[1]
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="shipping-server-export-") as temporary:
        export_dir = Path(temporary)
        subprocess.run([args.godot, "--headless", "--path", str(ROOT), "--export-release",
                        "Dedicated Server Windows", str(export_dir / "ShippingLanesServer.exe")], check=True)
        package(export_dir, output, version)
    print(f"SERVER_PACKAGE_PASS {output.name} {version}")


if __name__ == "__main__":
    main()
