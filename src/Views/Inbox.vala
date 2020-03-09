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

public class Views.Inbox : Gtk.EventBox {
    private int64 project_id;
    private int is_todoist = 0;

    private Gtk.Box top_box;
    private Gtk.Revealer motion_revealer;

    private Gtk.ListBox listbox;
    private Gtk.ListBox section_listbox;
    private Gtk.ListBox completed_listbox;
    private Gtk.Revealer completed_revealer;
    private Gtk.ModelButton show_completed_button;
    private Gtk.Stack main_stack;

    private Gtk.Entry section_name_entry;
    private Gtk.ToggleButton section_button;
    private Gtk.Popover new_section_popover = null;
    private Gtk.Popover popover = null;
    private Gtk.ToggleButton settings_button;
    private Gtk.Switch show_completed_switch;

    private uint timeout = 0;
    public Gee.ArrayList<Widgets.ItemRow?> items_list;
    public Gee.ArrayList<Widgets.ItemRow?> items_opened;

    public int64 temp_id_mapping { get; set; default = 0; }

    private const Gtk.TargetEntry[] TARGET_ENTRIES = {
        {"ITEMROW", Gtk.TargetFlags.SAME_APP, 0}
    };

    private const Gtk.TargetEntry[] TARGET_ENTRIES_SECTION = {
        {"SECTIONROW", Gtk.TargetFlags.SAME_APP, 0}
    };

    construct {
        project_id = Planner.settings.get_int64 ("inbox-project");
        items_list = new Gee.ArrayList<Widgets.ItemRow?> ();
        items_opened = new Gee.ArrayList<Widgets.ItemRow?> ();

        if (Planner.settings.get_boolean ("inbox-project-sync")) {
            is_todoist = 1;
        }

        var icon_image = new Gtk.Image ();
        icon_image.valign = Gtk.Align.CENTER;
        icon_image.gicon = new ThemedIcon ("mail-mailbox-symbolic");
        icon_image.get_style_context ().add_class ("inbox-icon");
        icon_image.pixel_size = 19;

        var title_label = new Gtk.Label ("<b>%s</b>".printf (_("Inbox")));
        title_label.get_style_context ().add_class ("title-label");
        title_label.use_markup = true;

        var section_image = new Gtk.Image ();
        section_image.gicon = new ThemedIcon ("go-jump-symbolic");
        section_image.pixel_size = 16;

        section_button = new Gtk.ToggleButton ();
        section_button.valign = Gtk.Align.CENTER;
        section_button.valign = Gtk.Align.CENTER;
        section_button.tooltip_markup = Granite.markup_accel_tooltip ({"<Ctrl><Shift>S"}, _("Add Section"));
        section_button.can_focus = false;
        section_button.get_style_context ().add_class ("flat");
        section_button.add (section_image);

        var comment_button = new Gtk.Button.from_icon_name ("internet-chat-symbolic", Gtk.IconSize.MENU);
        comment_button.valign = Gtk.Align.CENTER;
        comment_button.valign = Gtk.Align.CENTER;
        comment_button.can_focus = false;
        comment_button.tooltip_text = _("Inbox comments");
        comment_button.margin_start = 6;
        comment_button.get_style_context ().add_class ("flat");

        var search_button = new Gtk.Button.from_icon_name ("edit-find-symbolic", Gtk.IconSize.MENU);
        search_button.valign = Gtk.Align.CENTER;
        search_button.valign = Gtk.Align.CENTER;
        search_button.can_focus = false;
        search_button.tooltip_text = _("Search task");
        search_button.margin_start = 6;
        search_button.get_style_context ().add_class ("flat");

        settings_button = new Gtk.ToggleButton ();
        settings_button.valign = Gtk.Align.CENTER;
        settings_button.can_focus = false;
        settings_button.tooltip_text = _("Inbox Menu");
        settings_button.image = new Gtk.Image.from_icon_name ("view-more-symbolic", Gtk.IconSize.MENU);
        settings_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        top_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        top_box.hexpand = true;
        top_box.valign = Gtk.Align.START;
        top_box.margin_start = 24;
        top_box.margin_end = 16;

        top_box.pack_start (icon_image, false, false, 0);
        top_box.pack_start (title_label, false, false, 0);
        top_box.pack_end (settings_button, false, false, 0);
        //top_box.pack_end (search_button, false, false, 0);
        //top_box.pack_end (comment_button, false, false, 0);
        top_box.pack_end (section_button, false, false, 0);

        listbox = new Gtk.ListBox ();
        listbox.valign = Gtk.Align.START;
        listbox.margin_top = 6;
        listbox.margin_start = 12;
        listbox.get_style_context ().add_class ("listbox");
        listbox.activate_on_single_click = true;
        listbox.selection_mode = Gtk.SelectionMode.SINGLE;
        listbox.hexpand = true;

        completed_listbox = new Gtk.ListBox ();
        completed_listbox.valign = Gtk.Align.START;
        completed_listbox.get_style_context ().add_class ("listbox");
        completed_listbox.activate_on_single_click = true;
        completed_listbox.selection_mode = Gtk.SelectionMode.SINGLE;
        completed_listbox.hexpand = true;

        var completed_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        completed_box.hexpand = true;
        completed_box.pack_start (get_completed_header (), false, false, 0);
        completed_box.pack_start (completed_listbox, false, false, 0);

        completed_revealer = new Gtk.Revealer ();
        completed_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN;
        completed_revealer.add (completed_box);

        var placeholder_view = new Widgets.Placeholder (
            _("All clear"),
            _("Looks like everything's organized in the right place."),
            "mail-mailbox-symbolic"
        );
        placeholder_view.reveal_child = true;

        var motion_grid = new Gtk.Grid ();
        motion_grid.get_style_context ().add_class ("grid-motion");
        motion_grid.height_request = 24;
        motion_grid.margin_start = 24;
        motion_grid.margin_end = 16;
        motion_grid.margin_top = 12;

        motion_revealer = new Gtk.Revealer ();
        motion_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN;
        motion_revealer.add (motion_grid);

        section_listbox = new Gtk.ListBox ();
        section_listbox.valign = Gtk.Align.START;
        section_listbox.get_style_context ().add_class ("listbox");
        section_listbox.activate_on_single_click = true;
        section_listbox.selection_mode = Gtk.SelectionMode.SINGLE;
        section_listbox.hexpand = true;

        Gtk.drag_dest_set (section_listbox, Gtk.DestDefaults.ALL, TARGET_ENTRIES_SECTION, Gdk.DragAction.MOVE);
        section_listbox.drag_data_received.connect (on_drag_section_received);

        var motion_section_grid = new Gtk.Grid ();
        motion_section_grid.margin_start = 24;
        motion_section_grid.margin_end = 16;
        motion_section_grid.get_style_context ().add_class ("grid-motion");
        motion_section_grid.height_request = 24;

        var motion_section_revealer = new Gtk.Revealer ();
        motion_section_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_UP;
        motion_section_revealer.add (motion_section_grid);

        var drag_section_grid = new Gtk.Grid ();
        drag_section_grid.margin_start = 24;
        drag_section_grid.margin_end = 16;
        drag_section_grid.height_request = 16;

        Gtk.drag_dest_set (drag_section_grid, Gtk.DestDefaults.ALL, TARGET_ENTRIES_SECTION, Gdk.DragAction.MOVE);
        drag_section_grid.drag_data_received.connect ((context, x, y, selection_data, target_type, time) => {
            Widgets.SectionRow source;

            var row = ((Gtk.Widget[]) selection_data.get_data ())[0];
            source = (Widgets.SectionRow) row;

            source.get_parent ().remove (source);

            section_listbox.insert (source, (int32) section_listbox.get_children ().length ());
            section_listbox.show_all ();

            update_section_order ();
        });

        drag_section_grid.drag_motion.connect ((context, x, y, time) => {
            motion_section_revealer.reveal_child = true;
            return true;
        });

        drag_section_grid.drag_leave.connect ((context, time) => {
            motion_section_revealer.reveal_child = false;
        });

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        box.expand = true;
        box.pack_start (motion_revealer, false, false, 0);
        box.pack_start (listbox, false, false, 0);
        box.pack_start (section_listbox, false, false, 0);
        box.pack_start (drag_section_grid, false, false, 0);
        box.pack_start (motion_section_revealer, false, false, 0);
        box.pack_start (completed_revealer, false, false, 0);

        var main_scrolled = new Gtk.ScrolledWindow (null, null);
        main_scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
        main_scrolled.expand = true;
        main_scrolled.add (box);

        main_stack = new Gtk.Stack ();
        main_stack.hexpand = true;
        main_stack.transition_type = Gtk.StackTransitionType.CROSSFADE;

        main_stack.add_named (main_scrolled, "project");
        main_stack.add_named (placeholder_view, "placeholder");

        var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        main_box.expand = true;
        main_box.pack_start (top_box, false, false, 0);
        main_box.pack_start (main_scrolled, false, true, 0);
        main_box.pack_start (main_stack, false, true, 0);

        add (main_box);

        add_items (project_id);
        add_all_sections (project_id);
        build_drag_and_drop (false);
        show_all ();

        // Check Placeholder view
        Timeout.add (125, () => {
            check_placeholder_view ();

            return false;
        });

        listbox.row_activated.connect ((row) => {
            var item = (Widgets.ItemRow) row;
            item.reveal_child = true;
        });

        listbox.remove.connect ((row) => {
            check_placeholder_view ();
        });

        section_listbox.remove.connect ((row) => {
            check_placeholder_view ();
        });

        settings_button.toggled.connect (() => {
            if (settings_button.active) {
                if (popover == null) {
                    build_menu_popover ();
                }

                if (Planner.database.get_count_checked_items_by_project (project_id) > 0) {
                    show_completed_button.sensitive = true;
                } else {
                    show_completed_button.sensitive = false;
                    show_completed_switch.active = false;
                }

                popover.show_all ();
            }
        });

        section_button.toggled.connect (() => {
            open_new_section ();
        });

        completed_listbox.remove.connect (() => {
            check_task_complete_visible ();
        });

        Planner.database.section_added.connect ((section) => {
            if (project_id == section.project_id) {
                var row = new Widgets.SectionRow (section);
                section_listbox.insert (row, 0);
                section_listbox.show_all ();

                update_section_order ();
                main_stack.visible_child_name = "project";
            }
        });

        Planner.database.section_moved.connect ((section, id, old_project_id) => {
            Idle.add (() => {
                if (project_id == old_project_id) {
                    section_listbox.foreach ((widget) => {
                        var row = (Widgets.SectionRow) widget;

                        if (row.section.id == section.id) {
                            row.destroy ();
                        }
                    });

                    check_placeholder_view ();
                }

                if (project_id == id) {
                    section.project_id = id;

                    var row = new Widgets.SectionRow (section);
                    section_listbox.add (row);
                    section_listbox.show_all ();
                    check_placeholder_view ();
                }

                return false;
            });
        });

        Planner.database.item_moved.connect ((item, id, old_id) => {
            Idle.add (() => {
                if (project_id == old_id) {
                    items_list.foreach ((widget) => {
                        var row = (Widgets.ItemRow) widget;

                        if (row.item.id == item.id) {
                            row.destroy ();
                            items_list.remove (row);
                        }
                    });

                    check_placeholder_view ();
                }

                if (project_id == id) {
                    item.project_id = id;

                    var row = new Widgets.ItemRow (item);
                    row.destroy.connect (() => {
                        item_row_removed (row);
                    });

                    listbox.add (row);
                    items_list.add (row);

                    listbox.show_all ();
                    check_placeholder_view ();
                }

                return false;
            });
        });

        Planner.database.item_section_moved.connect ((i, section_id, old_section_id) => {
            Idle.add (() => {
                if (0 == old_section_id) {
                    items_list.foreach ((widget) => {
                        var row = (Widgets.ItemRow) widget;

                        if (row.item.id == i.id) {
                            row.destroy ();
                            items_list.remove (row);
                        }
                    });

                    check_placeholder_view ();
                }

                if (0 == section_id) {
                    i.section_id = 0;

                    var row = new Widgets.ItemRow (i);
                    listbox.add (row);
                    listbox.show_all ();
                    check_placeholder_view ();
                }

                return false;
            });
        });

        Planner.database.item_added.connect ((item) => {
            if (project_id == item.project_id && item.section_id == 0 && item.parent_id == 0) {
                var row = new Widgets.ItemRow (item);
                row.destroy.connect (() => {
                    item_row_removed (row);
                });

                listbox.add (row);
                items_list.add (row);

                listbox.show_all ();
                check_placeholder_view ();
            }
        });

        Planner.database.item_added_with_index.connect ((item, index) => {
            if (project_id == item.project_id && item.section_id == 0 && item.parent_id == 0) {
                var row = new Widgets.ItemRow (item);
                row.destroy.connect (() => {
                    item_row_removed (row);
                });

                listbox.insert (row, index);
                items_list.add (row);

                listbox.show_all ();
                check_placeholder_view ();
            }
        });

        Planner.database.item_completed.connect ((item) => {
            Idle.add (() => {
                if (project_id == item.project_id && item.section_id == 0 && item.parent_id == 0) {
                    if (item.checked == 1) {
                        if (completed_revealer.reveal_child) {
                            var row = new Widgets.ItemCompletedRow (item);
                            completed_listbox.add (row);
                            completed_listbox.show_all ();
                        }
                    } else {
                        var row = new Widgets.ItemRow (item);
                        row.destroy.connect (() => {
                            item_row_removed (row);
                        });

                        listbox.add (row);
                        items_list.add (row);

                        listbox.show_all ();
                    }

                    check_placeholder_view ();
                }

                return false;
            });
        });

        Planner.utils.magic_button_activated.connect ((id, section_id, is_todoist, last, index) => {
            if (project_id == id && section_id == 0) {
                var new_item = new Widgets.NewItem (
                    project_id,
                    section_id,
                    is_todoist
                );

                if (last) {
                    listbox.add (new_item);
                } else {
                    new_item.has_index = true;
                    new_item.index = index;
                    listbox.insert (new_item, index);
                }

                listbox.show_all ();
                main_stack.visible_child_name = "project";
            }
        });

        Planner.settings.changed.connect (key => {
            if (key == "inbox-project") {
                project_id = Planner.settings.get_int64 ("inbox-project");
            } else if (key == "inbox-project-sync") {
                if (Planner.settings.get_boolean ("inbox-project-sync")) {
                    is_todoist = 1;
                    add_items (project_id);
                }
            }
        });

        Planner.utils.add_item_show_queue.connect ((row) => {
            if (project_id == row.item.project_id) {
                items_opened.add (row);
            }
        });

        Planner.utils.remove_item_show_queue.connect ((row) => {
            if (project_id == row.item.project_id) {
                remove_item_show_queue (row);
            }
        });
    }

    private void remove_item_show_queue (Widgets.ItemRow row) {
        items_opened.remove (row);
    }

    public void hide_last_item () {
        if (items_opened.size > 0) {
            var last = items_opened [items_opened.size - 1];
            remove_item_show_queue (last);
            last.hide_item ();

            if (items_opened.size > 0) {
                var focus = items_opened [items_opened.size - 1];
                focus.grab_focus ();
                focus.content_entry_focus ();
            }
        }
    }

    public void open_new_section () {
        if (new_section_popover == null) {
            build_new_section_popover ();
        }

        new_section_popover.show_all ();
        section_name_entry.grab_focus ();
    }

    private void add_items (int64 id) {
        foreach (var child in listbox.get_children ()) {
            child.destroy ();
        }

        foreach (var item in Planner.database.get_all_items_by_project_no_section_no_parent (id)) {
            var row = new Widgets.ItemRow (item);
            row.destroy.connect (() => {
                item_row_removed (row);
            });

            listbox.add (row);
            items_list.add (row);

            listbox.show_all ();
        }

        check_placeholder_view ();
    }

    private void add_all_sections (int64 id) {
        foreach (var section in Planner.database.get_all_sections_by_project (id)) {
            var row = new Widgets.SectionRow (section);
            section_listbox.add (row);
            section_listbox.show_all ();
        }
    }

    private void add_completed_items (int64 id) {
        foreach (var child in completed_listbox.get_children ()) {
            child.destroy ();
        }

        foreach (var item in Planner.database.get_all_completed_items_by_inbox (id)) {
            var row = new Widgets.ItemCompletedRow (item);
            completed_listbox.add (row);
            completed_listbox.show_all ();
        }

        completed_revealer.reveal_child = true;
    }

    private void build_drag_and_drop (bool is_magic_button_active) {
        Gtk.drag_dest_set (listbox, Gtk.DestDefaults.ALL, TARGET_ENTRIES, Gdk.DragAction.MOVE);
        listbox.drag_data_received.connect (on_drag_data_received);

        Gtk.drag_dest_set (top_box, Gtk.DestDefaults.ALL, TARGET_ENTRIES, Gdk.DragAction.MOVE);
        top_box.drag_data_received.connect (on_drag_item_received);
        top_box.drag_motion.connect (on_drag_motion);
        top_box.drag_leave.connect (on_drag_leave);
    }

    private void on_drag_data_received (Gdk.DragContext context, int x, int y,
        Gtk.SelectionData selection_data, uint target_type, uint time) {
        Widgets.ItemRow target;
        Widgets.ItemRow source;
        Gtk.Allocation alloc;

        target = (Widgets.ItemRow) listbox.get_row_at_y (y);
        target.get_allocation (out alloc);

        var row = ((Gtk.Widget[]) selection_data.get_data ())[0];
        source = (Widgets.ItemRow) row;

        if (target != null) {
            if (source.item.section_id != 0) {
                source.item.section_id = 0;

                if (source.item.is_todoist == 1) {
                    Planner.todoist.move_item_to_section (source.item, 0);
                }
            }

            source.get_parent ().remove (source);
            items_list.remove (source);

            listbox.insert (source, target.get_index () + 1);
            items_list.insert (target.get_index () + 1, source);

            listbox.show_all ();
            update_item_order ();
        }
    }

    private void on_drag_item_received (Gdk.DragContext context, int x, int y,
        Gtk.SelectionData selection_data, uint target_type, uint time) {
        Widgets.ItemRow source;
        var row = ((Gtk.Widget[]) selection_data.get_data ())[0];
        source = (Widgets.ItemRow) row;

        if (source.item.section_id != 0) {
            source.item.section_id = 0;

            if (source.item.is_todoist == 1) {
                Planner.todoist.move_item_to_section (source.item, 0);
            }
        }

        source.get_parent ().remove (source);
        items_list.remove (source);

        listbox.insert (source, 0);
        items_list.insert (0, source);

        listbox.show_all ();
        update_item_order ();
    }

    public bool on_drag_motion (Gdk.DragContext context, int x, int y, uint time) {
        motion_revealer.reveal_child = true;
        return true;
    }

    public void on_drag_leave (Gdk.DragContext context, uint time) {
        motion_revealer.reveal_child = false;
    }

    private void check_task_complete_visible () {
        int count = 0;
        completed_listbox.foreach ((widget) => {
            count++;
        });

        if (count <= 0) {
            completed_revealer.reveal_child = false;
        }
    }

    private void update_item_order () {
        timeout = Timeout.add (250, () => {
            new Thread<void*> ("update_item_order", () => {
                for (int index = 0; index < items_list.size; index++) {
                    Planner.database.update_item_order (items_list [index].item, 0, index);
                }

                return null;
            });

            return false;
        });
    }

    private void on_drag_section_received (Gdk.DragContext context, int x, int y,
        Gtk.SelectionData selection_data, uint target_type, uint time) {
        Widgets.SectionRow target;
        Widgets.SectionRow source;
        Gtk.Allocation alloc;

        target = (Widgets.SectionRow) section_listbox.get_row_at_y (y);
        target.get_allocation (out alloc);

        var row = ((Gtk.Widget[]) selection_data.get_data ())[0];
        source = (Widgets.SectionRow) row;

        if (target != null) {
            source.get_parent ().remove (source);

            section_listbox.insert (source, target.get_index ());
            section_listbox.show_all ();

            update_section_order ();
        }
    }

    private void update_section_order () {
        timeout = Timeout.add (150, () => {
            new Thread<void*> ("update_section_order", () => {
                section_listbox.foreach ((widget) => {
                    var row = (Gtk.ListBoxRow) widget;
                    int index = row.get_index ();

                    var section = ((Widgets.SectionRow) row).section;

                    new Thread<void*> ("update_section_order", () => {
                        Planner.database.update_section_item_order (section.id, index);
                        return null;
                    });
                });

                return null;
            });

            Source.remove (timeout);
            timeout = 0;

            return false;
        });
    }

    private void build_menu_popover () {
        popover = new Gtk.Popover (settings_button);
        popover.position = Gtk.PositionType.BOTTOM;

        var show_completed_image = new Gtk.Image ();
        show_completed_image.gicon = new ThemedIcon ("emblem-default-symbolic");
        show_completed_image.valign = Gtk.Align.START;
        show_completed_image.pixel_size = 16;

        var show_completed_label = new Gtk.Label (_("Show Completed"));
        show_completed_label.hexpand = true;
        show_completed_label.valign = Gtk.Align.START;
        show_completed_label.xalign = 0;
        show_completed_label.margin_start = 9;

        show_completed_switch = new Gtk.Switch ();
        show_completed_switch.margin_start = 12;
        show_completed_switch.get_style_context ().add_class ("planner-switch");

        var show_completed_grid = new Gtk.Grid ();
        show_completed_grid.add (show_completed_image);
        show_completed_grid.add (show_completed_label);
        show_completed_grid.add (show_completed_switch);

        show_completed_button = new Gtk.ModelButton ();
        show_completed_button.get_style_context ().add_class ("popover-model-button");
        show_completed_button.get_child ().destroy ();
        show_completed_button.add (show_completed_grid);

        var popover_grid = new Gtk.Grid ();
        popover_grid.width_request = 200;
        popover_grid.orientation = Gtk.Orientation.VERTICAL;
        popover_grid.margin_top = 3;
        popover_grid.margin_bottom = 3;
        popover_grid.add (show_completed_button);

        popover.add (popover_grid);

        popover.closed.connect (() => {
            settings_button.active = false;
        });

        show_completed_button.button_release_event.connect (() => {
            show_completed_switch.activate ();

            if (show_completed_switch.active) {
                completed_revealer.reveal_child = false;
                check_placeholder_view ();
            } else {
                add_completed_items (project_id);
                main_stack.visible_child_name = "project";
            }

            return Gdk.EVENT_STOP;
        });
    }

    private void build_new_section_popover () {
        new_section_popover = new Gtk.Popover (section_button);
        new_section_popover.position = Gtk.PositionType.BOTTOM;

        var name_label = new Granite.HeaderLabel (_("Name:"));

        section_name_entry = new Gtk.Entry ();
        section_name_entry.hexpand = true;

        var submit_button = new Gtk.Button ();
        submit_button.sensitive = false;
        submit_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        var submit_spinner = new Gtk.Spinner ();
        submit_spinner.start ();

        var submit_stack = new Gtk.Stack ();
        submit_stack.expand = true;
        submit_stack.transition_type = Gtk.StackTransitionType.CROSSFADE;

        submit_stack.add_named (new Gtk.Label (_("Add")), "label");
        submit_stack.add_named (submit_spinner, "spinner");

        submit_button.add (submit_stack);

        var cancel_button = new Gtk.Button.with_label (_("Cancel"));
        cancel_button.get_style_context ().add_class ("planner-button");

        var action_grid = new Gtk.Grid ();
        action_grid.expand = false;
        action_grid.halign = Gtk.Align.START;
        action_grid.column_homogeneous = true;
        action_grid.column_spacing = 9;
        action_grid.margin_top = 12;
        action_grid.add (cancel_button);
        action_grid.add (submit_button);

        var popover_grid = new Gtk.Grid ();
        popover_grid.width_request = 250;
        popover_grid.orientation = Gtk.Orientation.VERTICAL;
        popover_grid.margin_top = 3;
        popover_grid.margin_bottom = 9;
        popover_grid.margin_start = 9;
        popover_grid.margin_end = 9;
        popover_grid.add (name_label);
        popover_grid.add (section_name_entry);
        popover_grid.add (action_grid);

        new_section_popover.add (popover_grid);

        new_section_popover.closed.connect (() => {
            section_button.active = false;
        });

        submit_button.clicked.connect (insert_section);

        section_name_entry.activate.connect (() => {
            insert_section ();
        });

        section_name_entry.key_release_event.connect ((key) => {
            if (key.keyval == 65307) {
                section_name_entry.text = "";
                new_section_popover.popdown ();
            }

            return false;
        });

        section_name_entry.changed.connect (() => {
            if (section_name_entry.text != "") {
                submit_button.sensitive = true;
            } else {
                submit_button.sensitive = false;
            }
        });

        cancel_button.clicked.connect (() => {
            section_name_entry.text = "";
            new_section_popover.popdown ();
        });

        Planner.todoist.section_added_started.connect ((id) => {
            if (temp_id_mapping == id) {
                submit_stack.visible_child_name = "spinner";
                popover_grid.sensitive = false;
            }
        });

        Planner.todoist.section_added_completed.connect ((id) => {
            if (temp_id_mapping == id) {
                submit_stack.visible_child_name = "label";
                temp_id_mapping = 0;

                popover_grid.sensitive = true;

                section_name_entry.text = "";
                new_section_popover.popdown ();
            }
        });

        Planner.todoist.section_added_error.connect ((id) => {
            if (temp_id_mapping == id) {
                submit_stack.visible_child_name = "label";
                temp_id_mapping = 0;

                popover_grid.sensitive = true;

                section_name_entry.text = "";
                new_section_popover.popdown ();
            }
        });
    }

    private Gtk.Widget get_completed_header () {
        var name_label = new Gtk.Label (_("Task completed"));
        name_label.halign = Gtk.Align.START;
        name_label.get_style_context ().add_class ("font-bold");
        name_label.valign = Gtk.Align.CENTER;
        name_label.set_ellipsize (Pango.EllipsizeMode.END);

        var separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        separator.margin_top = 3;

        var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        main_box.margin_top = 12;
        main_box.margin_start = 24;
        main_box.margin_bottom = 6;
        main_box.margin_end = 16;
        main_box.hexpand = true;
        main_box.pack_start (name_label, false, false, 0);
        main_box.pack_start (separator, false, false, 0);
        main_box.show_all ();

        return main_box;
    }

    private void insert_section () {
        if (section_name_entry.text != "") {
            var section = new Objects.Section ();
            section.name = section_name_entry.text;
            section.project_id = project_id;
            section.is_todoist = is_todoist;

            if (is_todoist == 0) {
                section.id = Planner.utils.generate_id ();
                Planner.database.insert_section (section);

                section_name_entry.text = "";
                new_section_popover.popdown ();
            } else {
                temp_id_mapping = Planner.utils.generate_id ();
                section.is_todoist = 1;

                Planner.todoist.add_section (section, temp_id_mapping);
            }
        }
    }

    private void check_placeholder_view () {
        if (Planner.database.get_count_items_by_project (project_id) > 0 ||
            Planner.database.get_count_sections_by_project (project_id) > 0) {
            main_stack.visible_child_name = "project";
        } else {
            main_stack.visible_child_name = "placeholder";
        }
    }

    private void item_row_removed (Widgets.ItemRow row) {
        items_list.remove (row);
    }
}
