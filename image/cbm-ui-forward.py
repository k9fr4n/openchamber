#!/usr/bin/env python3
# Forwards 0.0.0.0:9748 to the codebase-memory-mcp graph UI on 127.0.0.1:9749.
#
# The UI HTTP server binds localhost only with no bind-address option, so
# neither Traefik nor a published Docker port can reach it directly. This
# tiny stdlib-only TCP proxy bridges that gap. Ports are overridable via
# environment for tests; defaults match the Compose wiring.
import os
import socket
import threading

LISTEN = ("0.0.0.0", int(os.environ.get("CBM_UI_LISTEN_PORT", "9748")))
TARGET = ("127.0.0.1", int(os.environ.get("CBM_UI_TARGET_PORT", "9749")))


def pipe(src, dst):
    try:
        while True:
            data = src.recv(65536)
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
        upstream = socket.create_connection(TARGET, timeout=5)
    except OSError:
        client.close()
        return
    threading.Thread(target=pipe, args=(client, upstream), daemon=True).start()
    pipe(upstream, client)


def main():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(LISTEN)
    srv.listen(128)
    print("forwarding %s:%d -> %s:%d" % (LISTEN[0], LISTEN[1], TARGET[0], TARGET[1]), flush=True)
    while True:
        client, _ = srv.accept()
        threading.Thread(target=handle, args=(client,), daemon=True).start()


if __name__ == "__main__":
    main()
