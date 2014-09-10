using Gee;

int nb_threads = 4;

public enum eIdType { tFile, tDir, tLoad }
public enum eStatus { tBuild, tDisplay, tCompare}
public enum eCompInfos { None, Identical, Deleted, Added, Modified }

public class MD5Info {
	string _name;
	string _digest;
	eIdType _idType;
	int64 _size;
	uint64 _ftc; // creation
	uint64 _ftm; // modification
	uint _attributs;

	public eCompInfos compare = eCompInfos.None;
	public sCompare diff = null;
	
	public string name { get { return _name; } }
	public string digest { get { return _digest; } }
	public eIdType idType { get { return _idType; } }
	public int64 size { get { return _size; } }
	public uint64 ftc { get { return _ftc; } }
	public uint64 ftm { get { return _ftm; } }
	public uint attributs { get { return _attributs; } }

	public MD5Info.from_md5info(MD5Info from) {
		this._name = from.name;
		this._digest = from.digest;
		this._idType = from.idType;
		this._size = from.size;
		this._ftc = from.ftc;
		this._ftm = from.ftm;
		this._idType = from.idType;
		this._attributs = from.attributs;		
	}
	
		
	public MD5Info(File file) {
		FileInfo info = file.query_info ("*", FileQueryInfoFlags.NONE);
		uint8[] contents;

		this._name = file.get_path();			 

		if (info.get_file_type () == FileType.DIRECTORY) {
			this._idType = eIdType.tDir;
			this._size = 0;
			this._digest = "################";
		} else {
			this._idType = eIdType.tFile;
			this._size = info.get_size();
			this._ftc = info.get_attribute_uint64(FileAttribute.TIME_CHANGED);
			this._ftm = info.get_attribute_uint64(FileAttribute.TIME_MODIFIED);
			
			try {
				FileUtils.get_data(file.get_path(), out contents);
			} catch (FileError e) {
				stdout.printf("%s\n", e.message);
			}
			this._digest = Checksum.compute_for_data(ChecksumType.MD5, contents);
			
		}
	}
	
	public  MD5Info.InputStream(DataInputStream dis) {
		this._name = dis.read_upto ("\0", 1, null);
		dis.read_byte ();
		this._digest = dis.read_upto ("\0", 1, null);
		dis.read_byte ();
		uint16 a = dis.read_uint16();
		this._idType = (eIdType) a;
		this._ftc = dis.read_uint64();
		this._ftm = dis.read_uint64();
		this._size = dis.read_int64();		
	}

	public MD5Info dup() {
		return new MD5Info.from_md5info(this);
	}
	
	public void OutputStream(DataOutputStream dos) {
		dos.put_string(this._name);
		dos.put_byte ('\0');
		dos.put_string(this._digest);
		dos.put_byte ('\0');
		dos.put_uint16((uint16) this._idType);
		dos.put_uint64(this._ftc);
		dos.put_uint64(this._ftm);
		dos.put_int64(this._size);
	}
		
	public bool is_dir() { return _idType == eIdType.tDir; }
	public bool is_file() { return _idType == eIdType.tFile; }	
	public bool has_prefix(string s) { return _name.has_prefix (s); }
	
	public void set_digest(string digest) { this._digest = digest; }
	
	public string diff_to_string() {
		if (diff != null) return diff.to_string();
		
		return "";
	}
	public string to_string() {
		return "*" + _digest + "  :: " + _name;
	}
}

public class sCompare
{
	public bool ok;
	public bool nok;
	public bool digest;
	public bool filesize;
	public bool ftc;
	public bool ftm;
	public bool fta;
	public bool lm;
	public bool attributs;

	public sCompare() {
		ok = false;
		nok = false;
		digest = false;
		filesize = false;
		ftc = false;
		ftm = false;
		fta = false;
		attributs = false;
	}

	public uint value() {
		uint tmp = 0;
		if (ok) tmp = tmp | 0x01;
		if (nok) tmp = tmp | 0x02;
		if (digest) tmp = tmp | 0x04;
		if (filesize) tmp = tmp | 0x08;
		if (ftc) tmp = tmp | 0x10;
		if (ftm) tmp = tmp | 0x20;
		if (fta) tmp = tmp | 0x40;
		if (attributs) tmp = tmp | 0x80;

		return tmp;
	}

	public string to_string() {
		string buff = "";
		
		if (digest) { buff += "digest,"; }
		if (filesize) { buff += "filesize,"; }
		if (ftc) { buff += "ftc,"; }
		if (ftm) { buff += "ftm,"; }
		if (attributs) { buff += "attributs,"; }
		
		return buff;
	}
}

sCompare compare_attributes(MD5Info o1, MD5Info o2)
{
	sCompare compare = new sCompare();

	if (!Globals.dont_calculate_md5 && (strcmp(o1.digest, o2.digest) != 0)) compare.digest = true;
	if (o1.size != o2.size) compare.filesize = true;
	if (o1.ftc != o2.ftc) compare.ftc = true;
	if (o1.ftm != o2.ftm) compare.ftm = true;
	if (o1.attributs != o2.attributs) compare.attributs = true;

	return compare;
}

class MD5Calculation {
	public ArrayList<string> files_list = null;
	public ArrayList<MD5Info> result = null;
	int id_thread = -1;

	public MD5Calculation (int p_id_thread) {
		this.files_list = new ArrayList<string>();
		this.result = new ArrayList<MD5Info>();
		this.id_thread = p_id_thread;
	}

	public void add(string path) {
		files_list.add(path);
	}

	public void run () {
		foreach (string file in files_list) {
			MD5Info md5_file = new MD5Info(File.new_for_path (file));
			result.add(md5_file);
		}
	}
}

public class MD5db : ArrayList<MD5Info> {
	public void save() {
		try {
			var file = File.new_for_path (Globals.db_name);
			if (file.query_exists ()) file.delete ();

			var local_fstream = file.create (FileCreateFlags.REPLACE_DESTINATION);
			var dos = new DataOutputStream (local_fstream);

			foreach (MD5Info md5_info in this) {
				md5_info.OutputStream(dos);	
			}
		} catch (Error e) {
			stderr.printf ("Error saving database: %s\n", e.message);
		}
	}

	public void  load() {
		MD5Info md5_info;

		clear();

		try {
			var file = File.new_for_path (Globals.db_name);
			var file_info = file.query_info ("*", FileQueryInfoFlags.NONE);
			var dis = new DataInputStream (file.read ());


			while (dis.tell() != file_info.get_size()) {
				md5_info = new MD5Info.InputStream(dis);
				add(md5_info);
			}

		} catch (Error e) {
			stderr.printf ("Error loading database : %s\n", e.message);
		}
	}

	ArrayList<string> parse_directory (File file) {
		ArrayList<string> list = new ArrayList<string>();

		FileEnumerator enumerator = file.enumerate_children ("*", 0);

		FileInfo info = file.query_info ("*", FileQueryInfoFlags.NONE);;
		list.add(file.get_path());

		while ((info = enumerator.next_file ()) != null) {
			if (info.get_file_type () == FileType.DIRECTORY) {
				string s = file.get_path() + Path.DIR_SEPARATOR_S + info.get_name();
					
				if (!Globals.exclude_dir.contains(s)) {
					// stdout.printf ("include %s\n", s);
					list.add_all(parse_directory (File.new_for_path (s)));
				} // else
					// stdout.printf ("exclude %s\n", s);

			} else {
				list.add(file.get_path() + Path.DIR_SEPARATOR_S + info.get_name());
			}
		}

		return list;
	}

	public void create() {
		// on commence par construire la liste en parcourant les
		// répertoire
		ArrayList<string> list = new ArrayList<string>();

		foreach (string path in Globals.include_dir)
			list.add_all(parse_directory(File.new_for_path (path)));

		if (Globals.dont_calculate_md5 == true) {
			stdout.printf ("Pas de calcul MD5\n");
			add_all(list);
			sort_database();
			return;
		}

		// on initliase les tâches
		ArrayList<MD5Calculation> threads = new ArrayList<MD5Calculation>();

		for (int i = 0; i < nb_threads; i++)
			threads.add(new MD5Calculation(i));

		// on associe à chaque tâche une liste de fichiers à traiter
		int index = 0;

		foreach (string path in list) {
			MD5Calculation thread = threads[index];
			thread.add(path);
			index++;
			if (index >= nb_threads) index = 0;
		}

		// et on lance les tâches
		try {
			ThreadPool<MD5Calculation> pool = new ThreadPool<MD5Calculation>.with_owned_data ((worker) => {
			                                                                                          worker.run ();
													  }, nb_threads, false);

			for (int i = 0; i < nb_threads; i++)
				pool.add (threads[i]);

		} catch (ThreadError e) {
			stdout.printf ("ThreadError: %s\n", e.message);
		}

		// puis on reconstruit la liste avec les données de hashage
		list.clear();
		ArrayList<MD5Info> result = new ArrayList<MD5Info>();
		
		for (int i = 0; i < nb_threads; i++)
			result.add_all(threads[i].result);

		 ArrayList<MD5Info> directories = new  ArrayList<MD5Info>();
		 ArrayList<MD5Info> files = new  ArrayList<MD5Info>();

		foreach (MD5Info md5_info in result) {
			if (md5_info.is_dir())
				directories.add(md5_info);
			else {
				files.add(md5_info);
				add(md5_info);
			}
		}

		foreach (MD5Info dir in directories) {
			string md5 = "";

			foreach (MD5Info file in files) {
				if (file.has_prefix (dir.name))
					md5 = md5 + file.digest;
			}
			dir.set_digest(Checksum.compute_for_data(ChecksumType.MD5, md5.data));
			add(dir);
		}

		sort_database();

	}

	public void sort_database() {
		CompareFunc<MD5Info> compare_func = (a, b) => {
			return strcmp(a.name, b.name);
		};

		sort(compare_func);
	}

	public MD5db compare(MD5db referentiel) {
		uint max = 0;
		MD5Info o1;
		MD5Info o2;
		MD5db new_db = new MD5db();

		sCompare compare;
		string buff = "";

		if (size != referentiel.size) {
			// stdout.printf ("Nombre d'objets differents : %d dans la bd et %d maintenant\n", referentiel.size, size);
			max = (referentiel.size < size) ? size : referentiel.size;
		}

		int i1 = 0, i2 = 0, diff = 0;
		int last = 0;

		while ((i1 < referentiel.size) && (i2 < size)) {
			o1 = referentiel[i1];
			o2 = this[i2];
	
			if (strcmp(o1.name,o2.name) == 0) {

				compare = compare_attributes(o1, o2);

				if (compare.value() != 0) {
					MD5Info dup = o1.dup();
					dup.compare = eCompInfos.Modified;
					dup.diff = compare;
					new_db.add(dup);
				} else {
					MD5Info dup = o1.dup();
					dup.compare = eCompInfos.Identical;
					new_db.add(dup);
				}
				
				i2++;
				i1++;
			} else {
				if (strcmp(o1.name, o2.name) > 0) {
					o2 = this[i2];
					while (strcmp(o1.name, o2.name) > 0) {
						MD5Info dup = o2.dup();
						dup.compare = eCompInfos.Added;						
						new_db.add(dup);
						i2++;
						o2 = this[i2];
					}
				} else {
					o1 = referentiel[i1];
					while ((strcmp(o1.name, o2.name) < 0) && (i1 < referentiel.size)) {
						MD5Info dup = o1.dup();
						dup.compare = eCompInfos.Deleted;						
						new_db.add(dup);
						
						i1++;
						if (i1 < referentiel.size)
							o1 = referentiel[i1];
					}
				}
			}
		}

		while (i2 < size) {
			o2 = this[i2];
			MD5Info dup = o2.dup();
			dup.compare = eCompInfos.Added;						
			new_db.add(dup);
			i2++;
		}

		while (i1 < referentiel.size) {
			o1 = referentiel[i1];
			MD5Info dup = o1.dup();
			dup.compare = eCompInfos.Deleted;						
			new_db.add(dup);
			i1++;
		}
		
		return new_db;
	}

	public void display() {
		foreach (MD5Info md5_info in this) {
			switch (md5_info.compare) {
				case eCompInfos.Deleted: 
					stdout.printf ("-- ");
					break;
				case eCompInfos.Added: 
					stdout.printf ("++ ");
					break;
				case eCompInfos.Modified: 
					stdout.printf ("** ");
					break;
				default: 
					stdout.printf ("   ");
					break;
			}
			stdout.printf ("%s\n", md5_info.to_string());
		}
	}

}

struct Globals {
	static string db_name;
	static string conf_name;
	static string prog_name;

	static bool dont_calculate_md5;
	static bool delete_new_files;
	static ArrayList<string> include_dir;
	static ArrayList<string> exclude_dir;
	static File parent;

	public static const OptionEntry[] options = {
		{ "no-md5", 'n', 0, OptionArg.NONE, ref Globals.dont_calculate_md5, "Don't calculate MD5", null },
		{"database", 'b', 0, OptionArg.STRING, ref Globals.db_name, "DB Filename", null},
		{ "conf", 'c', 0, OptionArg.STRING, ref Globals.conf_name, "", null },
		{ "delete", 'd', 0, OptionArg.NONE, ref Globals.delete_new_files, "Delete all added files from previous DB", null },
		{ null }
	};
}

void check_init(string prog_name) {
	Globals.db_name = "check.db";
	Globals.dont_calculate_md5 = false;
	Globals.include_dir = new ArrayList<string>();
	Globals.exclude_dir = new ArrayList<string>();
	Globals.parent  = File.new_for_path (".");
	Globals.prog_name = prog_name;
	
	try {
		var file = File.new_for_path ("check_db.conf");
		var dis = new DataInputStream (file.read ());
		string line;

		while ((line = dis.read_line (null)) != null) {
			line = line.replace("\r", "").replace("\n", "");

			string directory = line.substring(2, -1);

			if (line.has_prefix("+A"))  Globals.include_dir.add(directory);
			if (line.has_prefix("-A"))  Globals.exclude_dir.add(directory);
	
			if (line.has_prefix("+R"))  Globals.include_dir.add(Globals.parent.get_path() + Path.DIR_SEPARATOR_S + directory);
			if (line.has_prefix("-R"))  Globals.exclude_dir.add(Globals.parent.get_path() + Path.DIR_SEPARATOR_S + directory);

		}
	} catch (Error e) {
		error ("%s", e.message);
	}
}
