/*
* Copyright (c) 2011-2018 elementary LLC (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Richard Fairthorne <richard.fairthorne@gmail.com>
*/

[DBus (name = "org.gnome.SessionManager")]
public interface SessionManager : Object {
    public abstract uint32 inhibit (string app_id, uint32 toplevel_xid, string reason, uint32 flags) throws GLib.Error;
    public abstract void uninhibit (uint32 inhibit_cookie) throws GLib.Error;
    public abstract void reboot () throws GLib.Error;
}

public class SuspendControl {

    SessionManager sm;
    bool inhibited = false;
    uint32 inhibit_cookie = 0;
    bool supported = true;

    private static SuspendControl? sc = null;

    public SuspendControl () {
        try {
            sm = Bus.get_proxy_sync (BusType.SESSION, "org.gnome.SessionManager", "/org/gnome/SessionManager");
        } catch (GLib.Error e) {
            supported = false;
            critical (e.message);
        }
    }

    public static unowned SuspendControl get_default () {
        if (sc == null) {
            sc = new SuspendControl ();
        }

        return sc;
    }

    public bool inhibit () {
        if (inhibited == false && supported) {
            try {
                inhibit_cookie = sm.inhibit ("io.elementary.appcenter", 0, "Inhibit suspend during package operations", 4);
                inhibited = true;
            } catch (GLib.Error e) {
                critical (e.message);
            }
        }

        return inhibited;
    }

    public bool uninhibit () {
        try {
            if (inhibited == true && supported) {
                sm.uninhibit (inhibit_cookie);
                inhibited = false;
            }
        } catch (GLib.Error e) {
            critical (e.message);
        }

        return !inhibited;
    }

    public void reboot () throws GLib.Error {
        try {
            sm.reboot ();
        } catch (GLib.Error e) {
            critical ("failed to request a reboot from GNOME: %s\n", e.message);
            throw e;
        }
    }

}
