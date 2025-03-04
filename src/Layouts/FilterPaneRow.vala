public class Layouts.FilterPaneRow : Gtk.FlowBoxChild {
    public FilterType filter_type { get; construct; }

    public string title;
    public string icon_name;

    private Widgets.DynamicIcon title_image;
    private Gtk.Label title_label;
    private Gtk.Label count_label;
    private Gtk.EventBox content_eventbox;

    public Gee.HashMap<string, ECal.Component> items_added;

    public FilterPaneRow (FilterType filter_type) {
        Object (
            filter_type: filter_type,
            can_focus: false
        );
    }
    
    construct {
        get_style_context ().add_class ("filter-pane-row-%s".printf (filter_type.to_string ()));

        title_image = new Widgets.DynamicIcon () {
            hexpand = true,
            halign = Gtk.Align.END
        };
        title_image.size = 19;

        title_label = new Gtk.Label (null) {
            hexpand = true,
            halign = Gtk.Align.START,
            margin_start = 3
        };

        title_label.get_style_context ().add_class ("font-bold");

        count_label = new Gtk.Label (null) {
            hexpand = true,
            halign = Gtk.Align.START,
            margin_start = 3
        };

        var main_grid = new Gtk.Grid () {
            column_spacing = 6,
            margin = 3
        };
        main_grid.attach (title_label, 0, 0, 1, 1);
        main_grid.attach (title_image, 1, 0, 1, 1);
        main_grid.attach (count_label, 0, 1, 2, 2);

        content_eventbox = new Gtk.EventBox ();
        content_eventbox.get_style_context ().add_class ("transition");
        content_eventbox.add (main_grid);

        add (content_eventbox);

        build_filter_data ();

        content_eventbox.button_press_event.connect ((sender, evt) => {
            if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 1) {
                Planner.event_bus.pane_selected (PaneType.FILTER, filter_type.to_string ());
            } else if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 3) {
                // activate_menu ();
            }

            return false;
        });

        Planner.event_bus.pane_selected.connect ((pane_type, id) => {
            if (pane_type == PaneType.FILTER && filter_type.to_string () == id) {
                get_style_context ().add_class (
                    "filter-pane-row-%s-selected".printf (filter_type.to_string ())
                );
            } else {
                get_style_context ().remove_class (
                    "filter-pane-row-%s-selected".printf (filter_type.to_string ())
                );
            }
        });
    }

    private void build_filter_data () {
        if (filter_type == FilterType.TODAY) {
            title_label.label = _("Today");
            title_image.update_icon_name ("planner-today");
        } else if (filter_type == FilterType.INBOX) {
            title_label.label = _("Inbox");
            title_image.update_icon_name ("planner-inbox");
        } else if (filter_type == FilterType.SCHEDULED) {
            title_label.label = _("Scheduled");
            title_image.update_icon_name ("planner-scheduled");
        } else if (filter_type == FilterType.PINBOARD) {
            title_label.label = _("Pinboard");
            title_image.update_icon_name ("planner-pin-tack");
        }
    }

    private void update_count_label (int count) {
        count_label.label = count.to_string ();
    }

    public void init () {
        if (filter_type == FilterType.TODAY) {
            update_count_label (Objects.Today.get_default ().today_count);
            Objects.Today.get_default ().today_count_updated.connect (() => {
                update_count_label (Objects.Today.get_default ().today_count);
            });
        } else if (filter_type == FilterType.INBOX) {
            init_inbox_count ();            
        } else if (filter_type == FilterType.SCHEDULED) {
            update_count_label (Objects.Scheduled.get_default ().scheduled_count);
            Objects.Scheduled.get_default ().scheduled_count_updated.connect (() => {
                update_count_label (Objects.Scheduled.get_default ().scheduled_count);
            });
        } else if (filter_type == FilterType.PINBOARD) {
            update_count_label (Objects.Pinboard.get_default ().pinboard_count);
            Objects.Pinboard.get_default ().pinboard_count_updated.connect (() => {
                update_count_label (Objects.Pinboard.get_default ().pinboard_count);
            });
        }
    }

    private void init_inbox_count () {
        BackendType backend_type = (BackendType) Planner.settings.get_enum ("backend-type");

        if (backend_type == BackendType.LOCAL || backend_type == BackendType.TODOIST) {
            Objects.Project inbox_project = Planner.database.get_project (Planner.settings.get_int64 ("inbox-project-id"));
            update_count_label (inbox_project.project_count);

            inbox_project.project_count_updated.connect (() => {
                update_count_label (inbox_project.project_count);
            });
        } else if (backend_type == BackendType.CALDAV) {
            try {
                var registry = Services.CalDAV.get_default ().get_registry_sync ();

                Services.CalDAV.get_default ().create_task_list_view (
                    registry.default_task_list,
                    "(contains? 'any' '')",
                    on_tasks_added,
                    on_tasks_modified,
                    on_tasks_removed
                );
            } catch (Error e) {
                warning (e.message);
            }
        }
    }

    private void on_tasks_added (Gee.Collection<ECal.Component> tasks) {
        if (items_added == null) {
            items_added = new Gee.HashMap<string, ECal.Component> ();
        }

        int task_completed = 0;
        foreach (ECal.Component task in tasks) {
            if (!items_added.has_key (task.get_icalcomponent ().get_uid ())) {
                unowned ICal.Component ical_task = task.get_icalcomponent ();
                if (ical_task.get_status () == ICal.PropertyStatus.COMPLETED) {
                    task_completed++;
                }

                items_added[task.get_icalcomponent ().get_uid ()] = task;
            }
        }

        update_count_label (items_added.size - task_completed);
    }

    private void on_tasks_modified (Gee.Collection<ECal.Component> tasks) {
        foreach (ECal.Component task in tasks) {
            items_added[task.get_icalcomponent ().get_uid ()] = task;
        }

        int task_completed = 0;
        foreach (var task in items_added.values) {
            unowned ICal.Component ical_task = task.get_icalcomponent ();
            if (ical_task.get_status () == ICal.PropertyStatus.COMPLETED) {
                task_completed++;
            }
        }

        update_count_label (items_added.size - task_completed);
    }

    private void on_tasks_removed (SList<ECal.ComponentId?> cids) {
        foreach (unowned ECal.ComponentId cid in cids) {
            if (cid == null) {
                continue;
            } else {
                items_added.unset (cid.get_uid ());
            }
        }

        int task_completed = 0;
        foreach (var task in items_added.values) {
            unowned ICal.Component ical_task = task.get_icalcomponent ();
            if (ical_task.get_status () == ICal.PropertyStatus.COMPLETED) {
                task_completed++;
            }
        }

        update_count_label (items_added.size - task_completed);
    }
}
