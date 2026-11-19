"""Godot 4.7.2: frozen 3.x fixtures, isolated UDP disconnect and server restart."""
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
    parser.add_argument("--generate-fixtures", action="store_true", help="maintainer only: create initial synthetic 3.0 fixtures")
    args = parser.parse_args()
    if not subprocess.check_output([args.godot, "--version"], text=True).strip().startswith("4.7.2."):
        raise SystemExit("Godot 4.7.2 required")
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="shipping-save-check-") as temporary:
        folder = Path(temporary)
        for phase in ("seed", "reload", "shutdown", "after-shutdown"):
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
                sock.bind(("127.0.0.1", 0))
                port = sock.getsockname()[1]
            processes = []
            logs = []
            try:
                for role in ("server", "client"):
                    data = folder / role
                    env = dict(os.environ, APPDATA=str(data / "data"), XDG_DATA_HOME=str(data / "data"),
                               XDG_CONFIG_HOME=str(data / "config"), XDG_CACHE_HOME=str(data / "cache"))
                    log = (folder / f"{phase}-{role}.log").open("w+")
                    logs.append(log)
                    command = [args.godot, "--headless", "--path", str(root), "--script",
                               "res://tools/server_saves_network_check.gd", "--",
                               "--server" if role == "server" else "--connect", f"--port={port}",
                               f"--saves-dir={folder / 'saves'}", "--captain=Synthetic"]
                    if phase != "seed":
                        command.append("--reload-save")
                    if phase == "shutdown":
                        command.append("--shutdown-live")
                    if phase == "after-shutdown":
                        command.append("--after-shutdown")
                    if phase == "seed" and args.generate_fixtures:
                        command.append("--generate-fixtures")
                    processes.append(subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT))
                    if role == "server":
                        deadline = time.monotonic() + 20
                        while time.monotonic() < deadline:
                            log.seek(0)
                            if "DEDICATED_SERVER_READY" in log.read():
                                break
                            if processes[0].poll() is not None:
                                raise RuntimeError("server exited before ready")
                            time.sleep(0.1)
                        else:
                            raise RuntimeError("server readiness timed out")
                codes = [process.wait(timeout=30) for process in processes]
                for log in logs:
                    log.seek(0)
                    output = log.read()
                    print(output)
                    if "SERVER_SAVES_NETWORK_PASS" not in output or "ERROR:" in output:
                        raise RuntimeError(f"{phase} failed")
                if any(codes):
                    raise RuntimeError(f"{phase} exits={codes}")
            finally:
                for process in processes:
                    if process.poll() is None:
                        process.terminate()
                        try:
                            process.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            process.kill()
                            process.wait()
                for log in logs:
                    log.seek(0)
                    if any(process.returncode for process in processes):
                        print(log.read())
                    log.close()
        result = subprocess.run([args.godot, "--headless", "--path", str(root), "--script",
                                 "res://tools/server_saves_check.gd"], env=env, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
        print(result.stdout)
        if result.returncode or "SERVER_SAVES_PASS" not in result.stdout or "ERROR:" in result.stdout:
            raise SystemExit("save fixture checks failed")
        print("PERSISTENT_SAVES_PASS fixtures, migration, backups, disconnect, restart")


if __name__ == "__main__":
    main()
