using Gtk;


class TestApp   {
	protected Builder             builder;
	Window		window;
	TreeView treeview;
	ListStore store;
	Gdk.Pixbuf pxb_folder;
	Gdk.Pixbuf pxb_file;
	Gdk.Pixbuf pxb_file_add;
	Gdk.Pixbuf pxb_file_del;
	Gdk.Pixbuf pxb_file_mod;
	Gdk.Pixbuf pxb_folder_add;
	Gdk.Pixbuf pxb_folder_del;
	Gdk.Pixbuf pxb_folder_mod;
	
	Resource res;
	
	public TestApp() {
		this.builder = new Builder ();
		try {
		        this.builder.add_from_file ("check.ui");
		} catch (Error err) {
			stdout.printf("Error : %s\n", err.message);
		}
		

		((Button) builder.get_object("bt_build")).clicked.connect(bt_build);
		((Button) builder.get_object("bt_display")).clicked.connect(bt_display);
		((Button) builder.get_object("bt_compare")).clicked.connect(bt_compare);
		
		window = builder.get_object("main_window") as Window;
		init_treeview();

		try {
			pxb_folder = new Gdk.Pixbuf.from_file_at_scale ("folder.png", 20, 20, true);
			pxb_file = new Gdk.Pixbuf.from_file_at_scale ("file.png", 20, 20, true);
			pxb_folder_add = new Gdk.Pixbuf.from_file_at_scale ("folder_add.png", 20, 20, true);
			pxb_folder_del = new Gdk.Pixbuf.from_file_at_scale ("folder_del.png", 20, 20, true);
			pxb_folder_mod = new Gdk.Pixbuf.from_file_at_scale ("folder_mod.png", 20, 20, true);
			pxb_file_add = new Gdk.Pixbuf.from_file_at_scale ("file_add.png", 20, 20, true);
			pxb_file_del = new Gdk.Pixbuf.from_file_at_scale ("file_del.png", 20, 20, true);
			pxb_file_mod = new Gdk.Pixbuf.from_file_at_scale ("file_mod.png", 20, 20, true);
		} catch (Error e) {
		}

		window.destroy.connect(Gtk.main_quit);
	}

	void init_treeview() {
		treeview =  builder.get_object("treeview") as TreeView;
		store = builder.get_object("liststore") as ListStore;
	}
	
	public void bt_build(Button source) {
		/*
		TreeIter root;

		store.append (out root);
		store.set (root, 1, "test1", 1, "test2", -1);
		*/
	}

	public void bt_compare(Button source) {
		MD5db referentiel = new MD5db();
		MD5db db = new MD5db();
		MD5db diff = null;
		referentiel.load();

		db.create();
		referentiel.load();

		diff = db.compare(referentiel);
		store.clear();
		TreeIter root;
		
		foreach (MD5Info md5_info in diff) {
			store.append (out root);
			store.set (root,1, md5_info.name, 
							2, md5_info.diff_to_string(), -1);
							
			if (md5_info.is_dir()) {
				switch (md5_info.compare) {
					case eCompInfos.Deleted: 
					store.set (root, 0, pxb_folder_del, -1);
						break;
					case eCompInfos.Added: 
					store.set (root, 0, pxb_folder_add, -1);
						break;
					case eCompInfos.Modified: 
					store.set (root, 0, pxb_folder_mod, -1);
						break;
					default: 
					store.set (root, 0, pxb_folder, -1);
						break;
				}
			} else {
				stdout.printf ("file %s\n", md5_info.name);
				switch (md5_info.compare) {
					case eCompInfos.Deleted: 
					store.set (root, 0, pxb_file_del, -1);
						break;
					case eCompInfos.Added: 
					store.set (root, 0, pxb_file_add, -1);
						break;
					case eCompInfos.Modified: 
					store.set (root, 0, pxb_file_mod, -1);
						break;
					default: 
					store.set (root, 0, pxb_file, -1);
						break;
				}
			}
		}
	}
	
	public void bt_display() {
		MD5db referentiel = new MD5db();		
		referentiel.load();
		referentiel.display();
		
		store.clear();
		TreeIter root;

		
		foreach (MD5Info md5_info in referentiel) {
			store.append (out root);
			store.set (root,1, md5_info.name, 
							2, md5_info.diff_to_string(), -1);
			
			if (md5_info.is_dir())
				store.set (root, 0, pxb_folder, -1);
			else
				store.set (root, 0, pxb_file, -1);
		}
		
	}
	
	public void show_all() {
		window.show_all();
	}

	
}

void main(string[] args) {
	check_init(args[0]);
    Gtk.init (ref args);
    /*
	CssProvider	css = new Gtk.CssProvider();

css.load_from_path ("theme/Evolve/gtk-3.0/gtk.css");



Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), css,
       Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
       */
	TestApp h = new TestApp();
    h.show_all();
    Gtk.main();	
}

