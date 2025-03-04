/*
* Copyright © 2019 Alain M. (https://github.com/alainm23/planner)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
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
* Authored by: Alain M. <alainmh23@gmail.com>
*/

public class Services.Notification : GLib.Object {
    private static Notification? _instance;
    public static Notification get_default () {
        if (_instance == null) {
            _instance = new Notification ();
        }

        return _instance;
    }

    private Gee.HashMap<string, string> reminders;

    construct {
        regresh ();
    }

    public void regresh () {
        if (reminders == null) {
            reminders = new Gee.HashMap<string, string> ();
        } else {
            reminders.clear ();
        }

        foreach (var reminder in Planner.database.reminders) {
            reminder_added (reminder);
        }

        Planner.database.reminder_added.connect ((reminder) => {
            reminder_added (reminder);
        });

        Planner.database.reminder_deleted.connect ((reminder) => {
            if (reminders.has_key (reminder.id_string)) {
                reminders.unset (reminder.id_string);
            }
        });
    }

    private void reminder_added (Objects.Reminder reminder) {
        if (reminder.due.datetime.compare (new GLib.DateTime.now_local ()) <= 0) {
            var notification = new GLib.Notification (reminder.item.project.short_name);
            notification.set_body (reminder.item.content);
            notification.set_icon (new ThemedIcon ("com.github.alainm23.planner"));
            notification.set_priority (GLib.NotificationPriority.URGENT);

            notification.set_default_action_and_target_value (
                "app.show-item",
                new Variant.int64 (reminder.item_id)
            );

            Planner.instance.send_notification (reminder.id_string, notification);
            Planner.database.delete_reminder (reminder);
        } else if (Granite.DateTime.is_same_day (reminder.due.datetime, new GLib.DateTime.now_local ())) {
            var interval = (uint) time_until_now (reminder.due.datetime);
            var uid = "%u-%u".printf (interval, GLib.Random.next_int ());
            reminders.set (reminder.id_string, uid);
            
            Timeout.add_seconds (interval, () => {
                queue_reminder_notification (reminder.id, uid);
                return GLib.Source.REMOVE;
            });
        }
    }

    private TimeSpan time_until_now (GLib.DateTime dt) {
        var now = new DateTime.now_local ();
        return dt.difference (now) / TimeSpan.SECOND;
    }

    private TimeSpan time_until_tomorrow () {
        var now = new DateTime.now_local ();
        var tomorrow = new DateTime.local (
            now.add_days (1).get_year (),
            now.add_days (1).get_month (),
            now.add_days (1).get_day_of_month (),
            0,
            0,
            0
        );

        return tomorrow.difference (now) / TimeSpan.SECOND;
    }

    public void queue_reminder_notification (int64 reminder_id, string uid) {
        if (reminders.values.contains (uid) == false) {
            return;
        }

        var reminder = Planner.database.get_reminder (reminder_id);
        var notification = new GLib.Notification (reminder.item.project.short_name);
        notification.set_body (reminder.item.content);
        notification.set_icon (new ThemedIcon ("com.github.alainm23.planner"));
        notification.set_priority (GLib.NotificationPriority.URGENT);

        notification.set_default_action_and_target_value (
            "app.show-item",
            new Variant.int64 (reminder.item_id)
        );

        Planner.instance.send_notification (uid, notification);
        Planner.database.delete_reminder (reminder);
    }
}