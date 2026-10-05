#!/usr/bin/env python3
# HTTP proxy in front of the codebase-memory-mcp graph UI.
#
# Two problems it solves (both verified against the real server):
#
# 1. The UI HTTP server binds 127.0.0.1 only and offers no bind-address
#    option, so neither Traefik nor a published Docker port can reach it.
#    This proxy listens on all interfaces and connects to the UI locally.
#
# 2. The UI answers 403 {"error":"forbidden host"} to requests carrying an
#    Origin header. Its own index.html marks the entry script and the
#    stylesheet as `crossorigin`, so a browser sends Origin even for
#    same-origin requests and every /assets/* fetch fails. Dropping Origin
#    (and Referer) here fixes it; the asset paths stay root-relative, so the
#    browser keeps resolving them against this proxy.
#
# Request headers are rewritten, then both directions are relayed as raw
# bytes: streaming responses, chunked bodies and upgrade handshakes pass
# through untouched. The UI serves its own HTML unchanged.
#
# stdlib only, no dependencies. Ports are overridable via environment.
import os
import re
import socket
import threading

LISTEN = ("0.0.0.0", int(os.environ.get("CBM_UI_LISTEN_PORT", "9748")))
TARGET_HOST = os.environ.get("CBM_UI_TARGET_HOST", "127.0.0.1")
TARGET_PORT = int(os.environ.get("CBM_UI_TARGET_PORT", "9749"))
BUFSIZE = 65536
HEADER_END = b"\r\n\r\n"

# Headers the UI rejects or that describe the previous hop.
DROP_HEADERS = re.compile(
    r"^(host|origin|referer|connection|keep-alive|proxy-.*|upgrade)$",
    re.IGNORECASE,
)


def read_headers(sock):
    """Read the request head (up to CRLFCRLF). Returns raw bytes or None."""
    buf = b""
    while HEADER_END not in buf:
        chunk = sock.recv(BUFSIZE)
        if not chunk:
            return None
        buf += chunk
        if len(buf) > 262144:
            return None
    return buf


def build_upstream_head(raw):
    """Rewrite the request head: drop rejected/hop headers, pin the Host."""
    lines = raw.split(b"\r\n")
    request_line = lines[0]
    kept = [request_line, b"Host: %s:%d" % (TARGET_HOST.encode(), TARGET_PORT)]
    for line in lines[1:]:
        # Only the empty line before the CRLFCRLF terminator is skipped.
        if not line:
            continue
        name = line.split(b":", 1)[0]
        if DROP_HEADERS.match(name.decode("latin-1")):
            continue
        kept.append(line)
    kept.append(b"Connection: close")
    return b"\r\n".join(kept) + HEADER_END


def pump(src, dst):
    try:
        while True:
            data = src.recv(BUFSIZE)
            if not data:
                break
            dst.sendall(data)
    except OSError:
        pass
    finally:
        for s in (src, dst):
            try:
                s.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            s.close()


def handle(client):
    try:
        raw = read_headers(client)
        if raw is None:
            client.close()
            return
        upstream = socket.create_connection((TARGET_HOST, TARGET_PORT), timeout=10)
    except OSError:
        client.close()
        return

    try:
        upstream.sendall(build_upstream_head(raw))
        # Relay whatever followed the request head (request body, upgrade
        # payload) and the response body in both directions.
        rest = raw.split(HEADER_END, 1)[1]
        if rest:
            upstream.sendall(rest)
    except OSError:
        upstream.close()
        client.close()
        return

    threading.Thread(target=pump, args=(client, upstream), daemon=True).start()
    pump(upstream, client)


def main():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(LISTEN)
    srv.listen(128)
    print(
        "forwarding %s:%d -> %s:%d (dropping Origin/Referer)"
        % (LISTEN[0], LISTEN[1], TARGET_HOST, TARGET_PORT),
        flush=True,
    )
    while True:
        client, _ = srv.accept()
        threading.Thread(target=handle, args=(client,), daemon=True).start()


if __name__ == "__main__":
    main()
