#!/usr/bin/env python3
"""Adds a Wi-Fi network to wpa_supplicant and joins it, for Network.qml:

    wifi-join.py <interface>          with one line of JSON on stdin:
    {"ssid": "<hex>", "kind": "open" | "psk" | "sae", "password": "...", "hidden": false}

Prints the new network's id. On a value wpa_supplicant refuses (a password of the wrong length, say)
the half-added network is removed again and it exits with 1.

The password comes in on stdin and goes straight to wpa_supplicant's control socket (the one wpa_cli
uses; group `wheel`, no root). It's never an argument of any command, so it doesn't show up in the
process list, where every user on the computer could read it.
"""
import json, os, socket, sys, tempfile


class Wpa:
    def __init__(self, interface):
        for folder in ("/run/wpa_supplicant", "/var/run/wpa_supplicant"):
            path = os.path.join(folder, interface)
            if os.path.exists(path):
                break
        else:
            raise OSError("wpa_supplicant isn't running on " + interface)
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        # wpa_supplicant answers to the address this socket is bound to
        self.local = os.path.join(tempfile.gettempdir(), "wpa_ctrl_%d-%s" % (os.getpid(), os.urandom(4).hex()))
        self.sock.bind(self.local)
        self.sock.settimeout(5)
        self.sock.connect(path)

    def close(self):
        self.sock.close()
        try:
            os.unlink(self.local)
        except OSError:
            pass

    def request(self, command):
        self.sock.send(command.encode())
        while True:
            reply = self.sock.recv(4096).decode(errors="replace")
            if not reply.startswith("<"):  # "<3>CTRL-EVENT-...": an event, not the answer
                return reply.strip()


def quoted(value):
    # wpa_supplicant takes a quoted string as it is, up to the last quote
    return '"' + value + '"'


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    request = json.loads(sys.stdin.readline())
    ssid = request.get("ssid", "")
    password = request.get("password", "")
    if not ssid or any(c not in "0123456789abcdef" for c in ssid) or "\n" in password or "\r" in password:
        sys.exit("Invalid network")

    wpa = Wpa(sys.argv[1])
    try:
        network = wpa.request("ADD_NETWORK")
        if not network.isdigit():
            sys.exit("add_network failed")
        values = [("ssid", ssid)]
        if request.get("kind") == "open":
            values.append(("key_mgmt", "NONE"))
        elif request.get("kind") == "sae":
            values += [("key_mgmt", "SAE"), ("ieee80211w", "2"), ("sae_password", quoted(password))]
        else:
            values.append(("psk", quoted(password)))
        if request.get("hidden"):
            values.append(("scan_ssid", "1"))
        for key, value in values:
            if wpa.request("SET_NETWORK %s %s %s" % (network, key, value)) != "OK":
                wpa.request("REMOVE_NETWORK " + network)
                sys.exit("Invalid " + key)
        wpa.request("SELECT_NETWORK " + network)
        print(network)
    finally:
        wpa.close()


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as error:
        sys.exit(str(error))
