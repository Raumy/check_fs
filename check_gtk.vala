using Gtk;


class TestApp   {
	protected Builder             builder;
	Window		window;
	TreeView treeview;
	ListStore store;
	
	public TestApp() {
		this.builder = new Builder ();
		try {
		        this.builder.add_from_file ("check_test.ui");
		} catch (Error err) {
			stdout.printf("Error : %s\n", err.message);
		}
		
		window = builder.get_object("main_window") as Window;
		init_treeview();

		window.destroy.connect(Gtk.main_quit);
	}

	void init_treeview() {
		// treeview =  builder.get_object("tv_configuration") as TreeView;
		store = builder.get_object("ls_configuration") as ListStore;
	}
	public void show_all() {
		window.show_all();
	}

	
}

void main(string[] args) {
    Gtk.init (ref args);

	TestApp h = new TestApp();
    h.show_all();
    Gtk.main();	
}

