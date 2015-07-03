module cli.options;

import std.string;
import std.stdio;
import config;
import std.process;
import std.file;

struct CFInfo 
{
	bool create_file;
	immutable string default_name;
	immutable string filename;
	immutable string fullName;

	this(bool cf, string dn, string fn)
    {
        create_file = cf;
        default_name = dn;
        filename = fn;
        fullName = dn ~ fn;
    }
}

class CboxOptions
{
	string cboxhome = "/home/jmeireles/.cbox";
	CFInfo *keys;
	CFInfo *startup;

	this()
	{
		keys = new CFInfo(false, this.cboxhome, "/keys");
		startup = new CFInfo(false, this.cboxhome, "/startup2");
	}

	void update()
	{
	   if (exists(this.startup.fullName)) {
	   	 spawnProcess(this.startup.fullName);
	   }
	}

	/**
 	* setup the configutation files in
 	* home directory
	*/
	void setupConfigFiles()
	{

	}

	int parse(string[] args)
	{
		if (args.length > 1) {
			foreach(string arg; args) {
				if(arg == "-v" || arg == "-version") {
					return this.versions();
				} else if(arg == "-h" || arg == "-help") {
					return this.help();
				}
			}
		}
		
		return 1;
	}

private:
	int versions()
	{
		writeln(
		"Cobox-wm-"~VERSION~"\n"~
		"The Cteam Window Manager.\n"~
		"© 2015 Cbox\n"
		);
		return -1;
	}

	int help()
	{
		writeln(
			 "Cobox-wm "~VERSION~" : (c) Cobox Team\n" ~
               "Website: http://www.fluxbox.org/\n\n" ~
               "-display <string>\t\tuse display connection.\n" ~
               "-screen <all|int,int,int>\trun on specified screens only.\n" ~
               "-rc <string>\t\t\tuse alternate resource file.\n" ~
               "-no-slit\t\t\tdo not provide a slit.\n" ~
               "-no-toolbar\t\t\tdo not provide a toolbar.\n" ~
               "-version\t\t\tdisplay version and exit.\n" ~
               "-info\t\t\t\tdisplay some useful information.\n" ~
               "-list-commands\t\t\tlist all valid key commands.\n" ~
               "-sync\t\t\t\tsynchronize with X server for debugging.\n" ~
               "-log <filename>\t\t\tlog output to file.\n" ~
               "-help\t\t\t\tdisplay this help text and exit.\n\n" 
		);
		return -1;
	}

}