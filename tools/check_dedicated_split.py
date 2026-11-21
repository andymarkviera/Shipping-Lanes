"""Isolated Godot 4.7.2 server + two clients; UDP loopback only, isolated saves.

Usage: python3 tools/check_dedicated_split.py --godot /path/to/godot
"""
import argparse
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--replication", action="store_true", help="check docking, cranes, cargo and payouts")
    parser.add_argument("--families", action="store_true", help="check bulk and physical heavy jobs")
    parser.add_argument("--prediction", action="store_true", help="check own-hull prediction, ping and live rename (Patch 3.0.1)")
    parser.add_argument("--flight", action="store_true", help="check other captains' planes, gear, Jetty hover and blaster (Patch 4.0.4)")
    parser.add_argument("--errors", action="store_true", help="check client error reports reach the server's rotating log, scrubbed and rate limited (Patch 4.0.5)")
    args = parser.parse_args()
    version = subprocess.check_output([args.godot, "--version"], text=True).strip()
    if not version.startswith("4.7.2."):
        raise SystemExit(f"Godot 4.7.2 required; found {version}")
    root = Path(__file__).resolve().parents[1]
    probe = "dedicated_replication_check.gd" if args.replication or args.families else "dedicated_split_check.gd"
    marker = "DEDICATED_REPLICATION_PASS" if args.replication or args.families else "DEDICATED_SPLIT_PASS"
    if args.prediction:
        probe, marker = "dedicated_prediction_check.gd", "DEDICATED_PREDICTION_PASS"
    if args.flight:
        probe, marker = "dedicated_flight_check.gd", "DEDICATED_FLIGHT_PASS"
    if args.errors:
        probe, marker = "dedicated_errors_check.gd", "DEDICATED_ERRORS_PASS"
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    with tempfile.TemporaryDirectory(prefix="shipping-split-") as temporary:
        folder = Path(temporary)
        processes = []
        files = []
        try:
            for role in ("server", "client1", "client2"):
                data = folder / role
                env = dict(os.environ, APPDATA=str(data / "data"), XDG_DATA_HOME=str(data / "data"),
                           XDG_CONFIG_HOME=str(data / "config"), XDG_CACHE_HOME=str(data / "cache"))
                log = (folder / f"{role}.log").open("w+")
                files.append(log)
                command = [args.godot, "--headless", "--path", str(root), "--script",
                           "res://tools/" + probe, "--",
                           "--server" if role == "server" else "--connect", f"--port={port}", f"--captain=Probe-{role}", f"--saves-dir={folder / 'saves'}"]
                if args.families:
                    command.append("--families")
                processes.append(subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT))
                if role == "server":
                    deadline = time.monotonic() + 30
                    while time.monotonic() < deadline:
                        log.seek(0)
                        if "DEDICATED_SERVER_READY" in log.read():
                            break
                        if processes[0].poll() is not None:
                            raise RuntimeError("server exited before readiness")
                        time.sleep(0.1)
                    else:
                        raise RuntimeError("server readiness timed out")
            codes = [process.wait(timeout=75) for process in processes]
            outputs = []
            for log in files:
                log.seek(0)
                outputs.append(log.read())
            for output in outputs:
                print(output)
            if any(codes) or any(marker not in output or "SCRIPT ERROR" in output or "ERROR:" in output for output in outputs):
                raise RuntimeError(f"loopback check failed: exits={codes}")
            if list(folder.rglob("*.db")) or list(folder.rglob("*.sqlite*")):
                raise RuntimeError("network runtime unexpectedly created a database")
            print("DEDICATED_LOOPBACK_PASS server+2 clients; no databases")
        finally:
            for process in processes:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
            for log in files:
                log.seek(0)
                if any(process.returncode not in (None, 0) for process in processes):
                    print(log.read())
                log.close()


if __name__ == "__main__":
    main()
