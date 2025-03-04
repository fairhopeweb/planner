public class Widgets.ProjectButton : Gtk.Button {
    public Objects.Item item { get; construct; }

    private Gtk.Label name_label;
    private Widgets.IconColorProject icon_project;
    
    public signal void changed (int64 project_id, int64 section_id);
    public signal void dialog_open (bool value);

    public ProjectButton (Objects.Item item) {
        Object (
            item: item,
            can_focus: false
        );
    }

    construct {
        get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        icon_project = new Widgets.IconColorProject (12);
        icon_project.project = item.project;

        name_label = new Gtk.Label (null) {
            margin_start = 6
        };

        var forward_image = new Widgets.DynamicIcon () {
            margin_start = 3
        };
        forward_image.size = 16;
        forward_image.update_icon_name ("chevron-right");

        var projectbutton_grid = new Gtk.Grid () {
            valign = Gtk.Align.CENTER
        };
        projectbutton_grid.add (icon_project);
        projectbutton_grid.add (name_label);
        projectbutton_grid.add (forward_image);

        add (projectbutton_grid);
        update_request ();

        item.project.updated.connect (() => {
            update_request ();
        });

        clicked.connect (() => {
            var picker = new Dialogs.ProjectPicker.ProjectPicker ();
            
            if (item.has_section) {
                picker.section = item.section;
            } else {
                picker.project = item.project;
            }
            
            dialog_open (true);
            picker.popup ();

            picker.changed.connect ((project_id, section_id) => {
                changed (project_id, section_id);
            });

            picker.destroy.connect (() => {
                dialog_open (false);
            });
        });
    }

    public void update_request () {
        string section_name = "";
        if (item.has_section) {
            section_name = "/ %s".printf (item.section.short_name);
        }

        name_label.label = "%s %s".printf (item.project.short_name, section_name);
        icon_project.update_request ();
    }
}
