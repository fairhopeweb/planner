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

public class Dialogs.QuickFind.QuickFind : Hdy.Window {
    private Gee.Map<E.Source, ECal.ClientView> views;
    private const string QUERY = "(contains? 'any' '')";

    private Gtk.SearchEntry search_entry;
    private Gtk.ListBox listbox;

    private Gee.ArrayList<Objects.Task> tasks_array;
    private Gee.ArrayList<Objects.SourceTaskList> sources_array;

    public QuickFind () {
        Object (
            transient_for: Planner.instance.main_window,
            deletable: false,
            destroy_with_parent: true,
            window_position: Gtk.WindowPosition.CENTER_ON_PARENT,
            title: _("Quick Find"),
            modal: true,
            width_request: 400,
            height_request: 300
        );
    }

    construct {
        Planner.event_bus.unselect_all ();
        views = new Gee.HashMap<E.Source, ECal.ClientView> ();
        
        unowned Gtk.StyleContext main_context = get_style_context ();
        main_context.add_class ("picker");
        transient_for = Planner.instance.main_window;

        BackendType backend_type = (BackendType) Planner.settings.get_enum ("backend-type");
        if (backend_type == BackendType.CALDAV) {
            try {
                var registry = Services.CalDAV.get_default ().get_registry_sync ();
                var sources = registry.list_sources (E.SOURCE_EXTENSION_TASK_LIST);
                sources.foreach ((source) => {
                    add_task_list (source);
                });
            } catch (Error e) {
                warning (e.message);
            }
        }

        var headerbar = new Hdy.HeaderBar ();
        headerbar.has_subtitle = false;
        headerbar.show_close_button = false;
        headerbar.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        search_entry = new Gtk.SearchEntry () {
            placeholder_text = _("Quick Find"),
            hexpand = true
        };

        search_entry.get_style_context ().add_class ("quick-find-entry");

        headerbar.custom_title = search_entry;

        listbox = new Gtk.ListBox ();
        listbox.expand = true;
        listbox.set_placeholder (get_placeholder ());
        listbox.set_header_func (header_function);

        unowned Gtk.StyleContext listbox_context = listbox.get_style_context ();
        listbox_context.add_class ("listbox-background");
        listbox_context.add_class ("listbox-separator-3");

        var listbox_grid = new Gtk.Grid () {
            margin = 6,
            margin_top = 0,
            margin_bottom = 12
        };
        listbox_grid.add (listbox);

        var listbox_scrolled = new Gtk.ScrolledWindow (null, null) {
            expand = true,
            hscrollbar_policy = Gtk.PolicyType.NEVER
        };
        listbox_scrolled.expand = true;
        listbox_scrolled.add (listbox_grid);

        var content_grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.VERTICAL
        };

        content_grid.add (headerbar);
        content_grid.add (listbox_scrolled);

        add (content_grid);

        search_entry.search_changed.connect (() => {
            search_changed ();
        });

        focus_out_event.connect (() => {
            hide_destroy ();
            return false;
        });

         key_release_event.connect ((key) => {
            if (key.keyval == 65307) {
                hide_destroy ();
            }

            return false;
        });

        key_press_event.connect ((event) => {
            var key = Gdk.keyval_name (event.keyval).replace ("KP_", "");

            if (key == "Up" || key == "Down") {
                return false;
            } else if (key == "Enter" || key == "Return" || key == "KP_Enter") {
                row_activated (listbox.get_selected_row ());
                return false;
            } else {
                if (!search_entry.has_focus) {
                    search_entry.grab_focus ();
                    search_entry.move_cursor (Gtk.MovementStep.BUFFER_ENDS, 0, false);
                }

                return false;
            }

            return true;
        });

        listbox.row_activated.connect ((row) => {
            row_activated (row);
        });
    }

    private void search_changed () {
        if (search_entry.text.strip () != "") {
            clean_results ();

            BackendType backend_type = (BackendType) Planner.settings.get_enum ("backend-type");
            if (backend_type == BackendType.LOCAL || backend_type == BackendType.TODOIST) {
                search_local_todoist ();
            } else if (backend_type == BackendType.CALDAV) {
                search_caldav ();
            }
        } else {
            clean_results ();
        }
    }

    private void search_local_todoist () {
        Objects.BaseObject[] filters = {
            Objects.Today.get_default (),
            Objects.Scheduled.get_default (),
            Objects.Pinboard.get_default ()
        };

        foreach (Objects.BaseObject object in filters) {
            if (search_entry.text.down () in object.name.down ()) {
                listbox.add (new Dialogs.QuickFind.QuickFindItem (object, search_entry.text));
                listbox.show_all ();
            }
        }

        foreach (Objects.Project project in Planner.database.get_all_projects_by_search (search_entry.text)) {
            listbox.add (new Dialogs.QuickFind.QuickFindItem (project, search_entry.text));
            listbox.show_all ();
        }

        foreach (Objects.Item item in Planner.database.get_all_items_by_search (search_entry.text)) {
            listbox.add (new Dialogs.QuickFind.QuickFindItem (item, search_entry.text));
            listbox.show_all ();
        }

        foreach (Objects.Label label in Planner.database.get_all_labels_by_search (search_entry.text)) {
            listbox.add (new Dialogs.QuickFind.QuickFindItem (label, search_entry.text));
            listbox.show_all ();
        }
    }

    private void search_caldav () {
        Objects.BaseObject[] filters = {
            Objects.Today.get_default (),
            Objects.Scheduled.get_default (),
            Objects.Pinboard.get_default ()
        };

        foreach (Objects.BaseObject object in filters) {
            if (search_entry.text.down () in object.name.down ()) {
                listbox.add (new Dialogs.QuickFind.QuickFindItem (object, search_entry.text));
                listbox.show_all ();
            }
        }

        foreach (Objects.SourceTaskList source in sources_array) {
            if (search_entry.text.down () in source.display_name.down ()) {
                listbox.add (new Dialogs.QuickFind.QuickFindItem (source, search_entry.text));
                listbox.show_all ();
            }
        }

        foreach (Objects.Task task in tasks_array) {
            if (search_entry.text.down () in task.summary.down () && !task.completed) {
                listbox.add (new Dialogs.QuickFind.QuickFindItem (task, search_entry.text));
                listbox.show_all ();
            }
        }
    }

    private void add_task_list (E.Source task_list) {
        if (!task_list.has_extension (E.SOURCE_EXTENSION_TASK_LIST)) {
            return;
        }

        if (sources_array == null) {
            sources_array = new Gee.ArrayList<Objects.SourceTaskList> ();
        }

        E.SourceTaskList list = (E.SourceTaskList) task_list.get_extension (E.SOURCE_EXTENSION_TASK_LIST);

        if (list.selected == true && task_list.enabled == true && !task_list.has_extension (E.SOURCE_EXTENSION_COLLECTION)) {
            sources_array.add (new Objects.SourceTaskList (task_list));
            add_view (task_list, QUERY);
        }
    }

    private void add_view (E.Source source, string query) {
        try {
            var view = Services.CalDAV.get_default ().create_task_list_view (
                source,
                query,
                on_tasks_added,
                on_tasks_modified,
                on_tasks_removed
            );

            lock (views) {
                views.set (source, view);
            }

        } catch (Error e) {
            critical (e.message);
        }
    }

    private void on_tasks_added (Gee.Collection<ECal.Component> tasks, E.Source source) {
        if (tasks_array == null) {
            tasks_array = new Gee.ArrayList<Objects.Task> ();
        }

        foreach (ECal.Component task in tasks) {
            if (task != null) {
                tasks_array.add (new Objects.Task (task, source));
            }
        }
    }

    private void on_tasks_modified (Gee.Collection<ECal.Component> tasks) {

    }

    private void on_tasks_removed (SList<ECal.ComponentId?> cids) {

    }

    private Gtk.Widget get_placeholder () {
        var message_label = new Gtk.Label (_("Quickly switch projects and views, find tasks, search by labels.")) {
            wrap = true,
            justify = Gtk.Justification.CENTER,
            expand = true,
            margin = 6
        };
        
        unowned Gtk.StyleContext message_label_context = message_label.get_style_context ();
        message_label_context.add_class ("dim-label");
        message_label_context.add_class (Granite.STYLE_CLASS_SMALL_LABEL);

        var placeholder_grid = new Gtk.Grid () {
            margin = 6,
            margin_top = 0,
            expand = true
        };

        placeholder_grid.add (message_label);
        placeholder_grid.show_all ();

        return placeholder_grid;
    }

    private void row_activated (Gtk.ListBoxRow row) {
        var base_object = ((Dialogs.QuickFind.QuickFindItem) row).base_object;

        if (base_object.object_type == ObjectType.PROJECT) {
            Planner.event_bus.pane_selected (PaneType.PROJECT, base_object.id_string);
        } else if (base_object.object_type == ObjectType.ITEM) {
            Planner.event_bus.pane_selected (PaneType.PROJECT,
                ((Objects.Item) base_object).project_id.to_string ()
            );
        } else if (base_object.object_type == ObjectType.LABEL) {
            Planner.event_bus.pane_selected (PaneType.LABEL,
                ((Objects.Label) base_object).id_string
            );
        } else if (base_object.object_type == ObjectType.FILTER) {
            if (base_object is Objects.Today) {
                Planner.event_bus.pane_selected (PaneType.FILTER, FilterType.TODAY.to_string ()); 
            } else if (base_object is Objects.Scheduled) {
                Planner.event_bus.pane_selected (PaneType.FILTER, FilterType.SCHEDULED.to_string ()); 
            } else if (base_object is Objects.Pinboard) {
                Planner.event_bus.pane_selected (PaneType.FILTER, FilterType.PINBOARD.to_string ());
            }
        } else if (base_object.object_type == ObjectType.TASK) {
            Planner.event_bus.pane_selected (PaneType.TASKLIST,
                ((Objects.Task) base_object).source.uid
            );
        } else if (base_object.object_type == ObjectType.TASK_LIST) {
            Planner.event_bus.pane_selected (PaneType.TASKLIST,
                ((Objects.SourceTaskList) base_object).source.uid
            );
        }

        hide_destroy ();
    }

    private void hide_destroy () {
        hide ();

        Timeout.add (500, () => {
            destroy ();
            return GLib.Source.REMOVE;
        });
    }

    private void clean_results () {
        foreach (unowned Gtk.Widget child in listbox.get_children ()) {
            child.destroy ();
        }
    }

    private void header_function (Gtk.ListBoxRow lbrow, Gtk.ListBoxRow? lbbefore) {
        var row = (Dialogs.QuickFind.QuickFindItem) lbrow;

        if (lbbefore != null) {
            var before = (Dialogs.QuickFind.QuickFindItem) lbbefore;
            if (row.base_object.object_type == before.base_object.object_type) {
                return;
            }
        }

        var header_label = new Granite.HeaderLabel (row.base_object.object_type.get_header ());

        row.set_header (header_label);
    }
}
