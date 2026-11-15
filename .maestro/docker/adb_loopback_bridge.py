#!/usr/bin/env python3
"""Minimal TCP loopback bridge inside finazaap-maestro container for ADB/Maestro ports."""
import socket
import sys
import threading


def pipe(src: socket.socket, dst: socket.socket, done: threading.Event) -> None:
    try:
        while True:
            data = src.recv(65536)
            if not data:
                try:
                    dst.shutdown(socket.SHUT_WR)
                except OSError:
                    pass
                break
            dst.sendall(data)
    except OSError:
        pass
    finally:
        done.set()


def handle_client(client: socket.socket, remote_host: str, remote_port: int) -> None:
    try:
        remote = socket.create_connection((remote_host, remote_port), timeout=5)
        remote.settimeout(None)
    except OSError:
        client.close()
        return
    done1 = threading.Event()
    done2 = threading.Event()
    threading.Thread(target=pipe, args=(client, remote, done1), daemon=True).start()
    threading.Thread(target=pipe, args=(remote, client, done2), daemon=True).start()
    done1.wait()
    done2.wait()
    for sock in (client, remote):
        try:
            sock.close()
        except OSError:
            pass


def forward(local_port: int, remote_host: str, remote_port: int) -> None:
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", local_port))
    srv.listen(32)
    while True:
        client, _ = srv.accept()
        threading.Thread(
            target=handle_client, args=(client, remote_host, remote_port), daemon=True
        ).start()


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(1)
    host_ip = sys.argv[1]
    for port in (5037, 7001):
        threading.Thread(target=forward, args=(port, host_ip, port), daemon=True).start()
    threading.Event().wait()


if __name__ == "__main__":
    main()
