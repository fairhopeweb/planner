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

public class Widgets.SectionRow : Gtk.ListBoxRow {
    public Objects.Section section { get; construct; }

    private Gtk.Button hidden_button;
    private Gtk.Label name_label;
    private Gtk.Entry name_entry;
    private Gtk.Stack name_stack;
    private Gtk.Revealer main_revealer;
    private Gtk.Revealer action_revealer;
    private Gtk.EventBox top_eventbox;
    private Gtk.Separator separator;
    private Gtk.Revealer motion_revealer;
    private Gtk.Revealer motion_section_revealer;

    private Gtk.ListBox listbox;
    private Gtk.Revealer listbox_revealer;
    private Gtk.Menu projects_menu;
    private Gtk.Menu menu = null;

    private uint timeout;
    public Gee.ArrayList<Widgets.ItemRow?> items_list;

    private const Gtk.TargetEntry[] TARGET_ENTRIES = {
        {"ITEMROW", Gtk.TargetFlags.SAME_APP, 0}
    };

    private const Gtk.TargetEntry[] TARGET_ENTRIES_MAGIC_BUTTON = {
        {"MAGICBUTTON", Gtk.TargetFlags.SAME_APP, 0}
    };

    private const Gtk.TargetEntry[] TARGET_ENTRIES_SECTION = {
        {"SECTIONROW", Gtk.TargetFlags.SAME_APP, 0}
    };

    public SectionRow (Objects.Section section) {
        Object (
            section: section
        );
    }

    construct {
        margin_top = 12;

        can_focus = false;
        get_style_context ().add_class ("area-row");
        items_list = new Gee.ArrayList<Widgets.ItemRow?> ();

        hidden_button = new Gtk.Button.from_icon_name ("pan-end-symbolic", Gtk.IconSize.MENU);
        hidden_button.can_focus = false;
        hidden_button.margin_start = 22;
        hidden_button.margin_end = 6;
        hidden_button.tooltip_text = _("Display Tasks");
        hidden_button.get_style_context ().remove_class ("button");
        hidden_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        hidden_button.get_style_context ().add_class ("hidden-button");
        hidden_button.get_style_context ().add_class ("no-padding");

        if (section.collapsed == 1) {
            hidden_button.get_style_context ().add_class ("opened");
            hidden_button.tooltip_text = _("Hiding Tasks");
        }

        name_label = new Gtk.Label (section.name);
        name_label.halign = Gtk.Align.START;
        name_label.get_style_context ().add_class ("font-bold");
        name_label.set_ellipsize (Pango.EllipsizeMode.END);

        name_entry = new Gtk.Entry ();
        name_entry.text = section.name;
        name_entry.hexpand = true;
        name_entry.placeholder_text = _("Section name");
        name_entry.get_style_context ().add_class ("font-bold");
        name_entry.get_style_context ().add_class ("flat");
        name_entry.get_style_context ().add_class ("project-name-entry");
        name_entry.get_style_context ().add_class ("no-padding");

        name_stack = new Gtk.Stack ();
        name_stack.hexpand = true;
        name_stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
        name_stack.add_named (name_label, "name_label");
        name_stack.add_named (name_entry, "name_entry");

        var settings_button = new Gtk.Button ();
        settings_button.can_focus = false;
        settings_button.valign = Gtk.Align.CENTER;
        settings_button.tooltip_text = _("Section Menu");
        settings_button.image = new Gtk.Image.from_icon_name ("view-more-symbolic", Gtk.IconSize.MENU);
        settings_button.get_style_context ().remove_class ("button");
        settings_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        settings_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        settings_button.get_style_context ().add_class ("hidden-button");

        var settings_revealer = new Gtk.Revealer ();
        settings_revealer.transition_type = Gtk.RevealerTransitionType.CROSSFADE;
        settings_revealer.add (settings_button);
        settings_revealer.reveal_child = false;

        var top_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        top_box.pack_start (hidden_button, false, false, 0);
        top_box.pack_start (name_stack, false, true, 0);
        top_box.pack_end (settings_revealer, false, true, 0);

        var submit_button = new Gtk.Button.with_label (_("Save"));
        submit_button.sensitive = false;
        submit_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        var cancel_button = new Gtk.Button.with_label (_("Cancel"));
        cancel_button.get_style_context ().add_class ("planner-button");

        var action_grid = new Gtk.Grid ();
        action_grid.halign = Gtk.Align.START;
        action_grid.column_homogeneous = true;
        action_grid.column_spacing = 6;
        action_grid.margin_start = 45;
        action_grid.margin_bottom = 6;
        action_grid.margin_top = 6;
        action_grid.add (cancel_button);
        action_grid.add (submit_button);

        action_revealer = new Gtk.Revealer ();
        action_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN;
        action_revealer.add (action_grid);

        top_eventbox = new Gtk.EventBox ();
        top_eventbox.margin_end = 16;
        top_eventbox.add_events (Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK);
        top_eventbox.add (top_box);

        separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        separator.margin_start = 47;
        separator.margin_end = 24;

        var motion_grid = new Gtk.Grid ();
        motion_grid.margin_start = 24;
        motion_grid.margin_end = 16;
        motion_grid.margin_top = 6;
        motion_grid.get_style_context ().add_class ("grid-motion");
        motion_grid.height_request = 24;

        motion_revealer = new Gtk.Revealer ();
        motion_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN;
        motion_revealer.add (motion_grid);

        var motion_section_grid = new Gtk.Grid ();
        motion_section_grid.margin_start = 24;
        motion_section_grid.margin_end = 16;
        motion_section_grid.margin_bottom = 6;
        motion_section_grid.get_style_context ().add_class ("grid-motion");
        motion_section_grid.height_request = 24;

        motion_section_revealer = new Gtk.Revealer ();
        motion_section_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN;
        motion_section_revealer.add (motion_section_grid);

        listbox = new Gtk.ListBox ();
        listbox.margin_start = 12;
        listbox.valign = Gtk.Align.START;
        listbox.get_style_context ().add_class ("listbox");
        listbox.activate_on_single_click = true;
        listbox.selection_mode = Gtk.SelectionMode.SINGLE;
        listbox.hexpand = true;

        Gtk.drag_dest_set (listbox, Gtk.DestDefaults.ALL, TARGET_ENTRIES, Gdk.DragAction.MOVE);
        listbox.drag_data_received.connect (on_drag_data_received);

        listbox_revealer = new Gtk.Revealer ();
        listbox_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN;
        listbox_revealer.add (listbox);

        var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        main_box.margin_top = 6;
        main_box.hexpand = true;
        main_box.pack_start (motion_section_revealer, false, false, 0);
        main_box.pack_start (top_eventbox, false, false, 0);
        main_box.pack_start (separator, false, false, 0);
        main_box.pack_start (action_revealer, false, false, 0);
        main_box.pack_start (motion_revealer, false, false, 0);
        main_box.pack_start (listbox_revealer, false, false, 0);

        main_revealer = new Gtk.Revealer ();
        main_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN;
        main_revealer.add (main_box);
        main_revealer.reveal_child = true;

        add (main_revealer);
        add_all_items ();

        if (section.collapsed == 1) {
            listbox_revealer.reveal_child = true;
        }

        build_defaul_drag_and_drop ();

        Planner.utils.magic_button_activated.connect ((project_id, section_id, is_todoist, last, index) => {
            if (section.project_id == project_id && section.id == section_id) {
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
            }
        });

        listbox.row_activated.connect ((row) => {
            var item = ((Widgets.ItemRow) row);
            item.reveal_child = true;
        });

        Planner.database.item_added.connect ((item) => {
            if (section.id == item.section_id && item.parent_id == 0) {
                var row = new Widgets.ItemRow (item);
                row.destroy.connect (() => {
                    item_row_removed (row);
                });

                listbox.add (row);
                items_list.add (row);

                listbox.show_all ();
            }
        });

        Planner.database.item_completed.connect ((item) => {
            Idle.add (() => {
                if (item.checked == 0 && section.id == item.section_id && item.parent_id == 0) {
                    var row = new Widgets.ItemRow (item);
                    row.destroy.connect (() => {
                        item_row_removed (row);
                    });

                    listbox.add (row);
                    items_list.add (row);

                    listbox.show_all ();
                }

                return false;
            });
        });

        Planner.database.item_added_with_index.connect ((item, index) => {
            if (section.id == item.section_id && item.parent_id == 0) {
                var row = new Widgets.ItemRow (item);
                row.destroy.connect (() => {
                    item_row_removed (row);
                });

                listbox.insert (row, index);
                items_list.insert (index, row);

                listbox.show_all ();
            }
        });

        Planner.utils.drag_magic_button_activated.connect ((value) => {
            build_magic_button_drag_and_drop (value);
        });

        Planner.utils.drag_item_activated.connect ((value) => {
            build_item_drag_and_drop (value);
        });

        hidden_button.clicked.connect (() => {
            toggle_hidden ();
        });

        top_eventbox.enter_notify_event.connect ((event) => {
            settings_revealer.reveal_child = true;

            return true;
        });

        top_eventbox.leave_notify_event.connect ((event) => {
            if (event.detail == Gdk.NotifyType.INFERIOR) {
                return false;
            }

            settings_revealer.reveal_child = false;
            return true;
        });

        top_eventbox.event.connect ((event) => {
            if (event.type == Gdk.EventType.@2BUTTON_PRESS) {
                action_revealer.reveal_child = true;
                name_stack.visible_child_name = "name_entry";

                separator.visible = false;

                name_entry.grab_focus_without_selecting ();
                if (name_entry.cursor_position < name_entry.text_length) {
                    name_entry.move_cursor (Gtk.MovementStep.BUFFER_ENDS, (int32) name_entry.text_length, false);
                }
            }

            return false;
        });

        top_eventbox.button_press_event.connect ((sender, evt) => {
            if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 3) {
                activate_menu ();
                return true;
            }

            return false;
        });

        name_entry.changed.connect (() => {
            if (name_entry.text.strip () != "" && section.name != name_entry.text) {
                submit_button.sensitive = true;
            } else {
                submit_button.sensitive = false;
            }
        });

        name_entry.activate.connect (() =>{
            save_section ();
        });

        name_entry.key_release_event.connect ((key) => {
            if (key.keyval == 65307) {
                action_revealer.reveal_child = false;
                name_stack.visible_child_name = "name_label";
                name_entry.text = section.name;

                separator.visible = true;
            }

            return false;
        });

        submit_button.clicked.connect (() => {
            save_section ();
        });

        cancel_button.clicked.connect (() => {
            action_revealer.reveal_child = false;
            name_stack.visible_child_name = "name_label";
            name_entry.text = section.name;

            separator.visible = true;
        });

        settings_button.clicked.connect (() => {
            activate_menu ();
        });

        Planner.database.section_deleted.connect ((s) => {
            if (section.id == s.id) {
                main_revealer.reveal_child = false;

                Timeout.add (500, () => {
                    destroy ();
                    return false;
                });
            }
        });

        Planner.todoist.section_deleted_started.connect ((id) => {
            if (section.id == id) {
                sensitive = false;
            }
        });

        Planner.todoist.section_deleted_error.connect ((id, http_code, error_message) => {
            if (section.id == id) {
                sensitive = true;
            }
        });

        Planner.todoist.section_moved_started.connect ((id) => {
            if (section.id == id) {
                sensitive = false;
            }
        });

        Planner.todoist.section_moved_completed.connect ((id) => {
            if (section.id == id) {
                main_revealer.reveal_child = false;

                Timeout.add (500, () => {
                    destroy ();
                    return false;
                });
            }
        });

        Planner.todoist.section_moved_error.connect ((id, http_code, error_message) => {
            if (section.id == id) {
                sensitive = true;
            }
        });

        Planner.database.section_updated.connect ((s) => {
            Idle.add (() => {
                if (section.id == s.id) {
                    section.name = s.name;

                    name_entry.text = s.name;
                    name_label.label = s.name;
                }

                return false;
            });
        });

        Planner.database.item_moved.connect ((item, project_id, old_project_id) => {
            Idle.add (() => {
                if (section.id == item.section_id) {
                    items_list.foreach ((widget) => {
                        var row = (Widgets.ItemRow) widget;

                        if (row.item.id == item.id) {
                            row.destroy ();
                            items_list.remove (row);
                        }
                    });
                }

                return false;
            });
        });

        Planner.database.item_section_moved.connect ((i, section_id, old_section_id) => {
            Idle.add (() => {
                if (section.id == old_section_id) {
                    listbox.foreach ((widget) => {
                        var row = (Widgets.ItemRow) widget;

                        if (row.item.id == i.id) {
                            row.destroy ();
                        }
                    });
                }

                if (section.id == section_id) {
                    i.section_id = section_id;

                    var row = new Widgets.ItemRow (i);
                    row.destroy.connect (() => {
                        item_row_removed (row);
                    });

                    listbox.add (row);
                    items_list.add (row);

                    listbox.show_all ();
                }

                return false;
            });
        });

        Planner.database.section_id_updated.connect ((current_id, new_id) => {
            Idle.add (() => {
                if (section.id == current_id) {
                    section.id = new_id;
                }

                return false;
            });
        });

        Planner.database.project_id_updated.connect ((current_id, new_id) => {
            Idle.add (() => {
                if (section.project_id == current_id) {
                    section.project_id = new_id;
                }

                return false;
            });
        });
    }

    private void build_defaul_drag_and_drop () {
        name_stack.drag_data_received.disconnect (on_drag_item_received);
        name_stack.drag_data_received.disconnect (on_drag_magic_button_received);

        Gtk.drag_source_set (this, Gdk.ModifierType.BUTTON1_MASK, TARGET_ENTRIES_SECTION, Gdk.DragAction.MOVE);
        drag_begin.connect (on_drag_begin);
        drag_data_get.connect (on_drag_data_get);
        drag_end.connect (clear_indicator);

        Gtk.drag_dest_set (this, Gtk.DestDefaults.MOTION, TARGET_ENTRIES_SECTION, Gdk.DragAction.MOVE);
        drag_motion.connect (on_drag_motion);
        drag_leave.connect (on_drag_leave);
    }

    private void activate_menu () {
        if (menu == null) {
            build_context_menu (section);
        }

        foreach (var child in projects_menu.get_children ()) {
            child.destroy ();
        }

        Widgets.ImageMenuItem item_menu;
        int is_todoist = 0;
        if (Planner.settings.get_boolean ("inbox-project-sync")) {
            is_todoist = 1;
        }

        if (section.is_todoist == is_todoist) {
            item_menu = new Widgets.ImageMenuItem (_("Inbox"), "mail-mailbox-symbolic");
            item_menu.activate.connect (() => {
                Planner.database.move_section (section, Planner.settings.get_int64 ("inbox-project"));
                if (section.is_todoist == 1) {
                    Planner.todoist.move_section (section, Planner.settings.get_int64 ("inbox-project"));
                }

                string move_template = _("Section moved to <b>%s</b>");
                Planner.notifications.send_notification (
                    0,
                    move_template.printf (
                        section.name
                    )
                );
            });

            projects_menu.add (item_menu);
        }

        foreach (var project in Planner.database.get_all_projects ()) {
            if (project.inbox_project == 0 && section.project_id != project.id) {
                if (project.is_todoist == section.is_todoist) {
                    item_menu = new Widgets.ImageMenuItem (project.name, "planner-project-symbolic");
                    item_menu.activate.connect (() => {
                        Planner.database.move_section (section, project.id);
                        if (section.is_todoist == 1) {
                            Planner.todoist.move_section (section, project.id);
                        }

                        string move_template = _("Section moved to <b>%s</b>");
                        Planner.notifications.send_notification (
                            0,
                            move_template.printf (
                                section.name
                            )
                        );
                    });

                    projects_menu.add (item_menu);
                }
            }
        }

        projects_menu.show_all ();
        menu.popup_at_pointer (null);
    }

    private void build_context_menu (Objects.Section section) {
        menu = new Gtk.Menu ();
        menu.width_request = 200;

        var add_menu = new Widgets.ImageMenuItem (_("Add Task"), "list-add-symbolic");
        add_menu.get_style_context ().add_class ("add-button-menu");

        var edit_menu = new Widgets.ImageMenuItem (_("Rename"), "edit-symbolic");
        var note_menu = new Widgets.ImageMenuItem (_("Add Note"), "text-x-generic-symbolic");

        var move_project_menu = new Widgets.ImageMenuItem (_("Move to Project"), "planner-project-symbolic");
        projects_menu = new Gtk.Menu ();
        move_project_menu.set_submenu (projects_menu);

        var share_menu = new Widgets.ImageMenuItem (_("Share"), "emblem-shared-symbolic");
        var share_list_menu = new Gtk.Menu ();
        share_menu.set_submenu (share_list_menu);

        //var share_text_menu = new Widgets.ImageMenuItem (_("Text"), "text-x-generic-symbolic");
        var share_markdown_menu = new Widgets.ImageMenuItem (_("Markdown"), "planner-markdown-symbolic");

        //share_list_menu.add (share_text_menu);
        share_list_menu.add (share_markdown_menu);
        share_list_menu.show_all ();

        var delete_menu = new Widgets.ImageMenuItem (_("Delete"), "user-trash-symbolic");
        delete_menu.get_style_context ().add_class ("menu-danger");

        menu.add (add_menu);
        menu.add (new Gtk.SeparatorMenuItem ());
        menu.add (edit_menu);
        menu.add (note_menu);
        menu.add (move_project_menu);
        menu.add (share_menu);
        menu.add (new Gtk.SeparatorMenuItem ());
        menu.add (delete_menu);

        menu.show_all ();

        add_menu.activate.connect (() => {
            add_new_item (true);
        });

        edit_menu.activate.connect (() => {
            action_revealer.reveal_child = true;
            name_stack.visible_child_name = "name_entry";

            separator.visible = false;

            name_entry.grab_focus_without_selecting ();
            if (name_entry.cursor_position < name_entry.text_length) {
                name_entry.move_cursor (Gtk.MovementStep.BUFFER_ENDS, (int32) name_entry.text_length, false);
            }
        });

        delete_menu.activate.connect (() => {
            var message_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                _("Delete section"),
                _("Are you sure you want to delete <b>%s</b>?".printf (section.name)),
                "user-trash-full",
            Gtk.ButtonsType.CANCEL);

            var remove_button = new Gtk.Button.with_label (_("Delete"));
            remove_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
            message_dialog.add_action_widget (remove_button, Gtk.ResponseType.ACCEPT);

            message_dialog.show_all ();

            if (message_dialog.run () == Gtk.ResponseType.ACCEPT) {
                Planner.database.delete_section (section);
                if (section.is_todoist == 1) {
                    Planner.todoist.delete_section (section);
                }

                Planner.notifications.send_notification (
                    0,
                    _("Section deleted")
                );
            }

            message_dialog.destroy ();
        });

        share_markdown_menu.activate.connect (() => {
            section.share_markdown ();
        });
    }

    public void add_all_items () {
        foreach (Objects.Item item in Planner.database.get_all_items_by_section_no_parent (section)) {
            var row = new Widgets.ItemRow (item);
            row.destroy.connect (() => {
                item_row_removed (row);
            });

            listbox.add (row);
            items_list.add (row);

            items_list.add (row);
        }

        listbox.show_all ();
    }

    private void toggle_hidden () {
        if (listbox_revealer.reveal_child) {
            listbox_revealer.reveal_child = false;
            hidden_button.get_style_context ().remove_class ("opened");
            hidden_button.tooltip_text = _("Display Tasks");
            section.collapsed = 0;
        } else {
            listbox_revealer.reveal_child = true;
            hidden_button.get_style_context ().add_class ("opened");
            hidden_button.tooltip_text = _("Hiding Tasks");
            section.collapsed = 1;
        }

        section.save_local ();
    }

    public void save_section () {
        if (name_entry.text.strip () != "" && section.name != name_entry.text) {
            name_label.label = name_entry.text;
            section.name = name_entry.text;

            action_revealer.reveal_child = false;
            name_stack.visible_child_name = "name_label";
            separator.visible = true;

            section.save ();
        } else {
            action_revealer.reveal_child = false;
            name_stack.visible_child_name = "name_label";
            separator.visible = true;
        }
    }

    private void build_magic_button_drag_and_drop (bool value) {
        name_stack.drag_data_received.disconnect (on_drag_item_received);
        name_stack.drag_data_received.disconnect (on_drag_magic_button_received);

        if (value) {
            Gtk.drag_dest_set (name_stack, Gtk.DestDefaults.ALL, TARGET_ENTRIES_MAGIC_BUTTON, Gdk.DragAction.MOVE);
            name_stack.drag_data_received.connect (on_drag_magic_button_received);
            name_stack.drag_motion.connect (on_drag_magicbutton_motion);
            name_stack.drag_leave.connect (on_drag_magicbutton_leave);
        } else {
            build_defaul_drag_and_drop ();
        }
    }

    private void build_item_drag_and_drop (bool value) {
        name_stack.drag_data_received.disconnect (on_drag_item_received);
        name_stack.drag_data_received.disconnect (on_drag_magic_button_received);

        if (value) {
            Gtk.drag_dest_set (name_stack, Gtk.DestDefaults.ALL, TARGET_ENTRIES, Gdk.DragAction.MOVE);
            name_stack.drag_data_received.connect (on_drag_item_received);
            name_stack.drag_motion.connect (on_drag_magicbutton_motion);
            name_stack.drag_leave.connect (on_drag_magicbutton_leave);
        } else {
            build_defaul_drag_and_drop ();
        }
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
            if (source.item.section_id != section.id) {
                source.item.section_id = section.id;

                if (source.item.is_todoist == 1) {
                    Planner.todoist.move_item_to_section (source.item, section.id);
                }

                string move_template = _("Task moved to <b>%s</b>");
                Planner.notifications.send_notification (
                    0,
                    move_template.printf (
                        section.name
                    )
                );
            }

            source.get_parent ().remove (source);
            items_list.remove (source);

            listbox.insert (source, target.get_index () + 1);
            items_list.insert (target.get_index () + 1, source);

            listbox.show_all ();
            update_item_order ();
        }
    }

    private void on_drag_magic_button_received (Gdk.DragContext context, int x, int y,
        Gtk.SelectionData selection_data, uint target_type, uint time) {
        add_new_item ();
    }

    private void add_new_item (bool last=false) {
        var new_item = new Widgets.NewItem (
            section.project_id,
            section.id,
            section.is_todoist
        );

        if (last) {
            listbox.add (new_item);
        } else {
            new_item.has_index = true;
            new_item.index = 0;
            listbox.insert (new_item, 0);
        }

        listbox.show_all ();
        listbox_revealer.reveal_child = true;
    }

    private void on_drag_item_received (Gdk.DragContext context, int x, int y,
        Gtk.SelectionData selection_data, uint target_type) {
        Widgets.ItemRow source;
        var row = ((Gtk.Widget[]) selection_data.get_data ())[0];
        source = (Widgets.ItemRow) row;

        if (source.item.section_id != section.id) {
            source.item.section_id = section.id;

            if (source.item.is_todoist == 1) {
                Planner.todoist.move_item_to_section (source.item, section.id);
            }
        }

        source.get_parent ().remove (source);
        items_list.remove (source);

        listbox.insert (source, 0);
        items_list.insert (0, source);

        listbox.show_all ();
        update_item_order ();

        listbox_revealer.reveal_child = true;
        section.collapsed = 1;

        save_section ();
    }

    public bool on_drag_motion (Gdk.DragContext context, int x, int y, uint time) {
        motion_section_revealer.reveal_child = true;
        return true;
    }

    public void on_drag_leave (Gdk.DragContext context, uint time) {
        motion_section_revealer.reveal_child = false;
    }

    public bool on_drag_magicbutton_motion (Gdk.DragContext context, int x, int y, uint time) {
        separator.visible = false;
        motion_revealer.reveal_child = true;
        return true;
    }

    public void on_drag_magicbutton_leave (Gdk.DragContext context, uint time) {
        separator.visible = true;
        motion_revealer.reveal_child = false;
    }

    private void update_item_order () {
        timeout = Timeout.add (150, () => {
            new Thread<void*> ("update_item_order", () => {
                listbox.foreach ((widget) => {
                    var row = (Gtk.ListBoxRow) widget;
                    int index = row.get_index ();

                    var item = ((Widgets.ItemRow) row).item;
                    Planner.database.update_item_order (item, section.id, index);
                });

                return null;
            });

            Source.remove (timeout);
            timeout = 0;

            return false;
        });
    }

    private void on_drag_begin (Gtk.Widget widget, Gdk.DragContext context) {
        var row = ((Widgets.SectionRow) widget).top_eventbox;

        Gtk.Allocation alloc;
        row.get_allocation (out alloc);

        var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, alloc.width, alloc.height);
        var cr = new Cairo.Context (surface);
        cr.set_source_rgba (0, 0, 0, 0.5);
        cr.set_line_width (1);

        cr.move_to (0, 0);
        cr.line_to (alloc.width, 0);
        cr.line_to (alloc.width, alloc.height);
        cr.line_to (0, alloc.height);
        cr.line_to (0, 0);
        cr.stroke ();

        cr.set_source_rgba (255, 255, 255, 0);
        cr.rectangle (0, 0, alloc.width, alloc.height);
        cr.fill ();

        row.get_style_context ().add_class ("drag-begin");
        row.draw (cr);
        row.get_style_context ().remove_class ("drag-begin");

        Gtk.drag_set_icon_surface (context, surface);
        main_revealer.reveal_child = false;
    }

    private void on_drag_data_get (Gtk.Widget widget, Gdk.DragContext context,
        Gtk.SelectionData selection_data, uint target_type, uint time) {
        uchar[] data = new uchar[(sizeof (Widgets.SectionRow))];
        ((Gtk.Widget[])data)[0] = widget;

        selection_data.set (
            Gdk.Atom.intern_static_string ("SECTIONROW"), 32, data
        );
    }

    public void clear_indicator (Gdk.DragContext context) {
        main_revealer.reveal_child = true;
    }

    private void item_row_removed (Widgets.ItemRow row) {
        items_list.remove (row);
    }
}
