"""Talk to Roblox StudioMCP over stdio JSON-RPC — batch mode, single process.
Usage: python mcp_driver.py batch <steps.json>
steps.json = [{"tool": "...", "args": {...}} | {"tool": "execute_luau", "luau_file": "path"}]
First step retries up to 60s (waits for Studio plugin to reconnect to new WS host).
"""
import json, subprocess, sys, threading, queue, time

EXE = r"C:\Users\khunb\AppData\Local\Roblox\Versions\version-ed7d8193e8564b1f\StudioMCP.exe"

proc = subprocess.Popen([EXE], stdin=subprocess.PIPE,
                        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
q = queue.Queue()
def reader():
    for line in proc.stdout:
        line = line.strip()
        if line:
            q.put(line)
threading.Thread(target=reader, daemon=True).start()

def send(obj):
    proc.stdin.write((json.dumps(obj) + "\n").encode())
    proc.stdin.flush()

def recv(want_id, timeout=180):
    while True:
        msg = json.loads(q.get(timeout=timeout))
        if msg.get("id") == want_id:
            return msg

def call(rid, tool, args, timeout=180):
    send({"jsonrpc": "2.0", "id": rid, "method": "tools/call",
          "params": {"name": tool, "arguments": args}})
    msg = recv(rid, timeout)
    if "error" in msg:
        return True, json.dumps(msg["error"])
    content = msg["result"].get("content", [])
    text = "\n".join(c.get("text", "") for c in content if c.get("text")) \
        or json.dumps(msg["result"], ensure_ascii=False)[:4000]
    return bool(msg["result"].get("isError")), text

try:
    send({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
        "protocolVersion": "2024-11-05", "capabilities": {},
        "clientInfo": {"name": "claude-driver", "version": "2.0"}}})
    recv(1)
    send({"jsonrpc": "2.0", "method": "notifications/initialized"})

    steps = json.load(open(sys.argv[1], encoding="utf-8"))
    rid = 10
    failed = False
    for i, step in enumerate(steps):
        tool = step["tool"]
        args = step.get("args", {})
        if "luau_file" in step:
            args = {"code": open(step["luau_file"], encoding="utf-8").read()}
        deadline = time.time() + (60 if i == 0 else 0)
        while True:
            rid += 1
            err, text = call(rid, tool, args)
            if not err or time.time() >= deadline:
                break
            time.sleep(3)
        print(f"=== step {i + 1}: {tool} {'[ERROR]' if err else '[OK]'} ===")
        print(text)
        if err:
            failed = True
            break
    sys.exit(1 if failed else 0)
finally:
    proc.kill()
