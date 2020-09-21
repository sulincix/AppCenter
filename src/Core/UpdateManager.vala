// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Adam Bieńkowski <donadigos159@gmail.com>
 */

public class AppCenterCore.UpdateManager : Object {
    public bool restart_required { public get; private set; default = false; }
    
    private const string RESTART_REQUIRED_FILE = "/var/run/reboot-required";

    private File restart_file;

    construct {
        restart_file = File.new_for_path (RESTART_REQUIRED_FILE);

        var icon = new AppStream.Icon ();
        icon.set_name ("distributor-logo");
        icon.set_kind (AppStream.IconKind.STOCK);

    }

    public async uint get_updates (Cancellable? cancellable = null) {
        var apps_with_updates = new Gee.TreeSet<Package> ();
        uint count = 0;

        unowned FlatpakBackend fp_client = FlatpakBackend.get_default ();
        var flatpak_updates = yield fp_client.get_updates ();
        debug ("Flatpak backend reports %d updates", flatpak_updates.size);

        foreach (var flatpak_update in flatpak_updates) {
            var appcenter_package = fp_client.lookup_package_by_id (flatpak_update);
            if (appcenter_package != null) {
                debug ("Added %s to app updates", flatpak_update);
                apps_with_updates.add (appcenter_package);
                appcenter_package.change_information.updatable_packages.@set (fp_client, flatpak_update);
                appcenter_package.update_state ();
                try {
                    appcenter_package.change_information.size = yield fp_client.get_download_size (appcenter_package, null, true);
                } catch (Error e) {
                    warning ("Unable to get flatpak download size: %s", e.message);
                }
            }
        }


        count = apps_with_updates.size;
        debug ("%u app updates found", count);

        return count;
    }

    public void update_restart_state () {
        if (restart_file.query_exists ()) {
            if (!restart_required) {
                string title = _("Restart Required");
                string body = _("Please restart your system to finalize updates");
                var notification = new Notification (title);
                notification.set_body (body);
                notification.set_icon (new ThemedIcon ("system-software-install"));
                notification.set_priority (NotificationPriority.URGENT);
                notification.set_default_action ("app.open-application");
                Application.get_default ().send_notification ("restart", notification);
            }

            restart_required = true;
        } else if (restart_required) {
            restart_required = false;
        }
    }

    private static GLib.Once<UpdateManager> instance;
    public static unowned UpdateManager get_default () {
        return instance.once (() => { return new UpdateManager (); });
    }
}
