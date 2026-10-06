#!/usr/bin/python3
"""Install or uninstall a package from the menu, on any Debian system.

Ageless Linux fork addition. Upstream mintmenu hands these jobs to Mint-only
tools: "Uninstall" runs mint-remove-application (mintcommon) and "Install
package" opens an apt:// URL (mintinstall/apturl). Neither exists on Debian,
so both menu entries silently did nothing.

    apt-helper.py install <package>
    apt-helper.py remove-desktop-file <path/to/app.desktop>

Shows what apt would do (from a simulation run as the user), asks for
confirmation, then runs apt-get through pkexec.
"""

import subprocess
import sys
import threading

import gi
gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk  # noqa: E402

# Removing these would take the desktop (or the distro identity) with them.
PROTECTED = {"mintmenu", "mate-panel", "mate-session-manager", "caja", "marco",
             "ageless-os-release", "ageless-desktop-mate", "apt", "dpkg", "sudo",
             "pkexec", "polkitd"}


def owning_package(path):
    """dpkg -S for one file; None if no package owns it (e.g. ~/.local)."""
    res = subprocess.run(["dpkg-query", "-S", path], capture_output=True, text=True)
    if res.returncode != 0:
        return None
    # "pkg[:arch]: /path" (diversions print a different first line; skip them)
    for line in res.stdout.splitlines():
        if line.startswith("diversion by"):
            continue
        return line.split(":", 1)[0].split(",")[0].strip()
    return None


def simulate(action, package):
    """Return (ok, packages-installed, packages-removed, message)."""
    res = subprocess.run(["apt-get", "-s", "-q", action, package],
                         capture_output=True, text=True,
                         env={"LC_ALL": "C.UTF-8", "PATH": "/usr/bin:/bin"})
    if res.returncode != 0:
        return False, [], [], (res.stderr or res.stdout).strip()
    inst = [l.split()[1] for l in res.stdout.splitlines() if l.startswith("Inst ")]
    rem = [l.split()[1] for l in res.stdout.splitlines() if l.startswith("Remv ")]
    return True, inst, rem, ""


class Runner:
    def __init__(self, action, package):
        self.action, self.package = action, package
        self.rc = 1

    def confirm(self, title, body):
        dlg = Gtk.MessageDialog(message_type=Gtk.MessageType.QUESTION,
                                buttons=Gtk.ButtonsType.OK_CANCEL, text=title)
        dlg.format_secondary_markup(body)
        dlg.set_title("Software")
        ok = dlg.run() == Gtk.ResponseType.OK
        dlg.destroy()
        return ok

    def message(self, kind, title, body=""):
        dlg = Gtk.MessageDialog(message_type=kind, buttons=Gtk.ButtonsType.CLOSE, text=title)
        if body:
            dlg.format_secondary_text(body)
        dlg.set_title("Software")
        dlg.run()
        dlg.destroy()

    def run(self):
        ok, inst, rem, err = simulate(self.action, self.package)
        if not ok:
            self.message(Gtk.MessageType.ERROR, f"Cannot {self.action} {self.package}", err)
            return 1
        hit = PROTECTED.intersection(rem)
        if hit:
            self.message(Gtk.MessageType.ERROR, f"Not removing {self.package}",
                         "That would also remove " + ", ".join(sorted(hit)) +
                         ", which the desktop needs.")
            return 1
        lines = []
        if inst:
            lines.append(f"<b>Install ({len(inst)}):</b> " + GLib.markup_escape_text(" ".join(inst)))
        if rem:
            lines.append(f"<b>Remove ({len(rem)}):</b> " + GLib.markup_escape_text(" ".join(rem)))
        if not lines:
            self.message(Gtk.MessageType.INFO, f"Nothing to do for {self.package}")
            return 0
        verb = "Install" if self.action == "install" else "Uninstall"
        if not self.confirm(f"{verb} {self.package}?", "\n\n".join(lines)):
            return 1
        return self.apply(verb)

    def apply(self, verb):
        win = Gtk.Window(title="Software")
        win.set_default_size(360, -1)
        win.set_position(Gtk.WindowPosition.CENTER)
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12, border_width=18)
        spinner = Gtk.Spinner()
        spinner.start()
        box.pack_start(spinner, False, False, 0)
        box.pack_start(Gtk.Label(label=f"{verb}ing {self.package}…"), False, False, 0)
        win.add(box)
        win.show_all()
        result = {}

        def work():
            cmd = ["pkexec", "/usr/bin/apt-get", "-y", "-q", self.action, self.package]
            res = subprocess.run(cmd, capture_output=True, text=True,
                                 env={"DEBIAN_FRONTEND": "noninteractive", "LC_ALL": "C.UTF-8",
                                      "PATH": "/usr/sbin:/usr/bin:/sbin:/bin"})
            result["rc"], result["out"] = res.returncode, (res.stderr or res.stdout)
            GLib.idle_add(Gtk.main_quit)

        threading.Thread(target=work, daemon=True).start()
        Gtk.main()
        win.destroy()
        self.rc = result["rc"]
        if self.rc in (126, 127):  # pkexec: dismissed / not authorized
            return self.rc
        if self.rc != 0:
            self.message(Gtk.MessageType.ERROR, f"{verb} failed", result["out"].strip()[-1500:])
        else:
            self.message(Gtk.MessageType.INFO, f"{verb}ed {self.package}")
        return self.rc


def main(argv):
    if len(argv) != 3 or argv[1] not in ("install", "remove-desktop-file"):
        print(__doc__, file=sys.stderr)
        return 2
    if argv[1] == "install":
        return Runner("install", argv[2]).run()
    package = owning_package(argv[2])
    if package is None:
        r = Runner("remove", "")
        r.message(Gtk.MessageType.INFO, "This launcher is not part of a package",
                  argv[2] + "\n\nUse “Delete from menu” instead.")
        return 1
    return Runner("remove", package).run()


if __name__ == "__main__":
    sys.exit(main(sys.argv))
