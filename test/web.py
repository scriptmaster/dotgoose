#!/usr/bin/env python3
"""Build, verify, and optionally measure the six paired HTTP examples on Linux."""
import argparse
from dataclasses import dataclass
import http.client
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import statistics
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "samples" / "web"
SHARED = WEB / "shared"
GOOSE = os.environ.get("GOOSE", "goose")
JSON = "application/json"
TEXT = "text/plain"
HTML = "text/html"
ENV = {
    **os.environ,
    "LC_ALL": "C",
    "DOTNET_NOLOGO": "1",
    "DOTNET_SYSTEM_GLOBALIZATION_INVARIANT": "1",
    "ASPNETCORE_ENVIRONMENT": "Production",
}

@dataclass(frozen=True)
class Case:
    method: str
    path: str
    status: int
    body: str = ""
    mime: str = ""
    send: tuple = ()
    expect: tuple = ()
    payload: str | None = None

CASES = {
    "01-health": (
        Case("GET", "/healthz", 200, '{"status":"ok"}', JSON),
        Case("GET", "/missing", 404),
    ),
    "02-routing": (
        Case("GET", "/api/items/42?includeDetails=true", 200, '{"id":42,"details":"starter"}', JSON),
        Case("GET", "/api/items/7?includeDetails=false", 200, '{"id":7}', JSON),
        Case("GET", "/api/items/42", 200, '{"id":42}', JSON),
        Case("GET", "/api/items/42?includeDetails=maybe", 400),
        Case("GET", "/api/items/abc", 404),
        Case("GET", "/api/items/0", 404),
    ),
    "03-middleware": (
        Case("GET", "/api/ping", 200, "pong", TEXT, (("X-Request-Id", "demo-42"),),
             (("X-Request-Id", "demo-42"), ("X-Stages", "id,endpoint"))),
        Case("GET", "/api/ping", 400, expect=(("X-Stages", "id"),)),
        Case("GET", "/api/ping", 400, send=(("X-Request-Id", "bad id"),), expect=(("X-Stages", "id"),)),
    ),
    "04-json": (
        Case("POST", "/api/items", 201, '{"name":"Gear","quantity":2}', JSON, (("Content-Type", JSON),),
             (("Location", "/api/items/42"),), '{"name":"Gear","quantity":2}'),
        Case("POST", "/api/items", 400, send=(("Content-Type", JSON),),
             payload='{"name":"Gear","quantity":0}'),
        Case("POST", "/api/items", 400, send=(("Content-Type", JSON),), payload='{"name":'),
        Case("POST", "/api/items", 400, send=(("Content-Type", TEXT),),
             payload='{"name":"Gear","quantity":2}'),
    ),
    "05-scope": (
        Case("GET", "/api/visit", 200, '{"step":2}', JSON),
        Case("GET", "/missing", 404),
        Case("GET", "/api/visit", 200, '{"step":2}', JSON),
    ),
    "06-mvc": (
        Case("GET", "/catalog/42", 200,
             '<!doctype html>\n<html lang="en">\n<title>Catalog</title>\n<h1>Goose</h1>\n<p>Item 42</p>\n</html>\n', HTML),
        Case("GET", "/catalog/999", 404),
    ),
}

@dataclass(frozen=True)
class Variant:
    name: str
    executable: Path
    dotnet: bool = False
    managed: bool = False

    def command(self, port):
        command = ["dotnet", str(self.executable)] if self.managed else [str(self.executable)]
        return [*command, "--urls", f"http://127.0.0.1:{port}"] if self.dotnet else [*command, str(port)]

def run(command, directory):
    result = subprocess.run(command, cwd=directory, env=ENV, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=240)
    if result.returncode:
        raise RuntimeError(f"{' '.join(map(str, command))}\n{result.stdout}")
    return result.stdout

def code_lines(path):
    return sum(bool(line.strip()) and not line.lstrip().startswith(("//", "/*"))
               for line in path.read_text().splitlines())

def build(name, work, benchmark):
    source = WEB / name
    src = work / "src"
    shutil.copytree(source, src)
    shutil.copy2(SHARED / "Web.csproj", src)
    shutil.copy2(SHARED / "http.goose", src)
    shutil.copy2(ROOT / "lib" / "dotgoose.goose", src)

    c_file = work / "generated.c"
    run([GOOSE, "--standalone", "--include", str(SHARED / "transport.h"), "-o", c_file, "main.goose"], src)
    gcc = ["gcc", "-O2", "-s", "-Wno-attributes", c_file]
    goose = work / "goose"
    run([*gcc, "-o", goose, "-lm", "-pthread"], work)
    variants = [Variant("goose", goose)]

    if not benchmark:
        managed = work / "managed"
        run(["dotnet", "build", "-c", "Release", "-o", managed, "-v:q"], src)
        return [*variants, Variant("dotnet-jit", managed / "WebSample.dll", True, True)]

    static = work / "goose-static"
    run([*gcc, "-static", "-o", static, "-lm", "-pthread"], work)
    assert "NEEDED" not in run(["readelf", "-d", static], work)
    assert "INTERP" not in run(["readelf", "-l", static], work)
    variants.append(Variant("goose-static", static))

    publish = ["dotnet", "publish", "-c", "Release", "-r", "linux-x64",
               "-p:InvariantGlobalization=true", "-v:q"]
    if name != "06-mvc":
        aot = work / "aot"
        output = run([*publish, "-p:PublishAot=true", "-p:OptimizationPreference=Size",
                      "-p:StripSymbols=true", "-o", aot], src)
        if any("warning IL" in line or "warning RDG" in line for line in output.splitlines()):
            raise RuntimeError(output)
        executable = aot / "WebSample"
        run(["strip", "--strip-all", executable], work)
        variants.append(Variant("dotnet-aot", executable, True))

    single = work / "single"
    run([*publish, "--self-contained", "true", "-p:PublishSingleFile=true",
         "-p:IncludeNativeLibrariesForSelfExtract=true", "-p:EnableCompressionInSingleFile=true",
         "-p:DebugType=None", "-o", single], src)
    variants.append(Variant("dotnet-single", single / "WebSample", True))
    return variants

def request(port, case):
    conn = http.client.HTTPConnection("127.0.0.1", port, timeout=5)
    try:
        conn.request(case.method, case.path, body=case.payload, headers={"Connection": "close", **dict(case.send)})
        response = conn.getresponse()
        body = response.read()
        mime = response.getheader("Content-Type", "").split(";", 1)[0].strip().lower()
        selected = ("X-Request-Id", "X-Stages", "Location")
        actual = (response.status, mime, body, tuple((h, response.getheader(h)) for h in selected))
        expect = dict(case.expect)
        expected = (case.status, case.mime, case.body.encode(), tuple((h, expect.get(h)) for h in selected))
        if actual != expected:
            raise AssertionError(f"{case.method} {case.path}\nexpected {expected!r}\nreceived {actual!r}")
    finally:
        conn.close()

def drive(variant, cases, work, count, timed):
    with socket.socket() as reserve:
        reserve.bind(("127.0.0.1", 0))
        port = reserve.getsockname()[1]
    env = {**ENV, "DOTNET_BUNDLE_EXTRACT_BASE_DIR": str(work / "extract")}
    server_pid = work / "server.pid"
    timing = work / "time.tsv"
    server_pid.unlink(missing_ok=True)
    command = variant.command(port)
    if timed:
        command = ["/usr/bin/time", "-q", "-f", "%U\t%S\t%M", "-o", str(timing),
                   "/bin/sh", "-c", 'echo "$$" > "$1"; shift; exec "$@"', "sh", str(server_pid), *command]
    log_path = work / "server.log"
    with log_path.open("wb") as log:
        with subprocess.Popen(command, cwd=work, env=env, stdout=log, stderr=subprocess.STDOUT,
                              start_new_session=True) as process:
            try:
                for _ in range(500):
                    if process.poll() is not None:
                        raise RuntimeError(log_path.read_text(errors="replace"))
                    try:
                        with socket.create_connection(("127.0.0.1", port), timeout=.15):
                            break
                    except OSError:
                        time.sleep(.02)
                else:
                    raise TimeoutError(f"Server did not start: {variant.name}")
                for index in range(count):
                    request(port, cases[index % len(cases)])
            finally:
                if process.poll() is None:
                    pid = int(server_pid.read_text()) if timed and server_pid.is_file() else process.pid
                    try:
                        os.kill(pid, signal.SIGTERM)
                    except ProcessLookupError:
                        pass
                    try:
                        process.wait(timeout=8)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait()
    if timed:
        user, system, rss = timing.read_text().split()
        return round((float(user) + float(system)) * 1000), int(rss)
    return None

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--benchmark", type=Path, help="write release build sizes, source lines and measurements to JSON")
    parser.add_argument("--requests", type=int, default=2000, help="requests per measured run")
    parser.add_argument("--trials", type=int, default=3, help="measured runs per executable")
    parser.add_argument("--only", choices=CASES, help="run one example")
    args = parser.parse_args()
    if args.requests < 1 or args.trials < 1:
        parser.error("requests and trials must be positive")
    results = []
    with tempfile.TemporaryDirectory(prefix="dotgoose-web-") as temp:
        for name, cases in CASES.items():
            if args.only and name != args.only:
                continue
            work = Path(temp) / name
            work.mkdir()
            record = {
                "example": name,
                "dotnet_lines": sum(code_lines(path) for path in (WEB/name).rglob("*")
                                    if path.suffix in (".cs", ".cshtml")),
                "goose_lines": code_lines(WEB/name/"main.goose"),
                "variants": {},
            }
            for variant in build(name, work, args.benchmark is not None):
                variant_work = work / f"run-{variant.name}"
                variant_work.mkdir()
                drive(variant, cases, variant_work, len(cases), False)
                print(f"PASS {name} / {variant.name}: {len(cases)} HTTP cases", flush=True)
                if args.benchmark:
                    data = [drive(variant, cases, variant_work, args.requests, True) for _ in range(args.trials)]
                    record["variants"][variant.name] = {
                        "bytes": variant.executable.stat().st_size,
                        "cpu_ms": statistics.median(row[0] for row in data),
                        "peak_rss_kib": statistics.median(row[1] for row in data),
                        "trials": data,
                    }
                    print(f"MEASURE {name} / {variant.name}: {record['variants'][variant.name]}", flush=True)
            results.append(record)
    if args.benchmark:
        shared = sum(code_lines(SHARED/file) for file in ("http.goose", "transport.h"))
        result = {"requests":args.requests, "trials":args.trials, "shared_goose_lines":shared,
                  "add_library_lines":code_lines(ROOT/"lib"/"dotgoose.goose"), "examples":results}
        args.benchmark.write_text(json.dumps(result, indent=2)+"\n")

if __name__ == "__main__":
    main()
