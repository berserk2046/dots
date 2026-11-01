#!/usr/bin/env python3
"""BlueZ pairing agent for the menu bar's Bluetooth panel and System Settings → Bluetooth
(BluetoothPairing.qml runs it).

Registers as the default agent while one of them is open (it exits when stdin closes) and passes
each request to it as a JSON line on stdout:
    {"id": 1, "type": "confirm", "device": "Name", "passkey": "123456"}
types: confirm, pin (asks for a PIN), passkey (asks for a number), displayPasskey, displayPin,
authorize, cancel. Requests that need one are answered with a line on stdin:
    {"id": 1, "ok": true, "value": "0000"}
"""
import json, sys

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

AGENT_PATH = "/org/systemsettings/agent"


class Rejected(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Rejected"


class Canceled(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Canceled"


bus = None
pending = {}  # id -> (reply, error, kind)
next_id = 0


def emit(message):
    print(json.dumps(message), flush=True)


def device_name(path):
    try:
        props = dbus.Interface(bus.get_object("org.bluez", path), "org.freedesktop.DBus.Properties")
        return str(props.Get("org.bluez.Device1", "Alias"))
    except dbus.DBusException:
        return str(path).split("/")[-1].replace("dev_", "").replace("_", ":")


def ask(kind, device, reply, error, **extra):
    global next_id
    next_id += 1
    pending[next_id] = (reply, error, kind)
    emit(dict(id=next_id, type=kind, device=device_name(device), **extra))


def set_trusted(path):
    try:
        props = dbus.Interface(bus.get_object("org.bluez", path), "org.freedesktop.DBus.Properties")
        props.Set("org.bluez.Device1", "Trusted", dbus.Boolean(True))
    except dbus.DBusException:
        pass


class Agent(dbus.service.Object):
    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Release(self):
        loop.quit()

    @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        # Services of a device that's being paired or already paired are fine.
        return

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="s",
                         async_callbacks=("reply", "error"))
    def RequestPinCode(self, device, reply, error):
        ask("pin", device, reply, error)

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="u",
                         async_callbacks=("reply", "error"))
    def RequestPasskey(self, device, reply, error):
        ask("passkey", device, reply, error)

    @dbus.service.method("org.bluez.Agent1", in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        emit(dict(id=0, type="displayPasskey", device=device_name(device), passkey="%06d" % passkey, entered=int(entered)))

    @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        emit(dict(id=0, type="displayPin", device=device_name(device), passkey=str(pincode)))

    @dbus.service.method("org.bluez.Agent1", in_signature="ou", out_signature="",
                         async_callbacks=("reply", "error"))
    def RequestConfirmation(self, device, passkey, reply, error):
        set_trusted(device)
        ask("confirm", device, reply, error, passkey="%06d" % passkey)

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="",
                         async_callbacks=("reply", "error"))
    def RequestAuthorization(self, device, reply, error):
        ask("authorize", device, reply, error)

    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Cancel(self):
        for reply, error, kind in pending.values():
            error(Canceled("Canceled"))
        pending.clear()
        emit(dict(id=0, type="cancel"))


def on_stdin(source, condition):
    line = sys.stdin.readline()
    if not line:  # the pane closed
        loop.quit()
        return False
    try:
        answer = json.loads(line)
    except ValueError:
        return True
    entry = pending.pop(answer.get("id"), None)
    if not entry:
        return True
    reply, error, kind = entry
    if not answer.get("ok"):
        error(Rejected("Rejected by user"))
    elif kind == "pin":
        reply(dbus.String(str(answer.get("value", ""))))
    elif kind == "passkey":
        try:
            reply(dbus.UInt32(int(answer.get("value", 0))))
        except ValueError:
            error(Rejected("Not a number"))
    else:
        reply()
    return True


dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SystemBus()
agent = Agent(bus, AGENT_PATH)
manager = dbus.Interface(bus.get_object("org.bluez", "/org/bluez"), "org.bluez.AgentManager1")
manager.RegisterAgent(AGENT_PATH, "KeyboardDisplay")
manager.RequestDefaultAgent(AGENT_PATH)
emit(dict(id=0, type="ready"))

loop = GLib.MainLoop()
GLib.io_add_watch(sys.stdin, GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP, on_stdin)
try:
    loop.run()
finally:
    try:
        manager.UnregisterAgent(AGENT_PATH)
    except dbus.DBusException:
        pass
