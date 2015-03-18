module utils;

import std.stdio;

class Utils
{
	immutable string debugLogFile = "cbox-wm.log";
	
	private File _logfile;

	this() {
		import std.file;
		if(std.file.exists(debugLogFile)) {
			std.file.remove(debugLogFile);
		}
	}

	auto die(F, A...)(lazy F fmt, lazy A args) nothrow
	{
		import std.c.stdlib;
		try {
			std.stdio.stderr.writefln("\n\n"~fmt~"\n\n", args);
		} catch {}
		exit(EXIT_FAILURE);
	}

	auto lout(string file = __FILE__,
		size_t line = __LINE__,
		F,
		A...)(lazy F fmt,
		lazy A args) nothrow @trusted
	{
		import std.datetime : Clock, DateTime;
		import std.process : thisProcessID;
		import std.string;
		import std.file;
		string txt, fmtTxt;
		try {
			try {
				fmtTxt = format(fmt, args);
				txt = format("[%s] [%s] [%s(%s)] %s", thisProcessID, cast(DateTime)(Clock.currTime), file, line, fmtTxt);
			} catch {
				die("Failed to format text '%s','%s'", fmt, args);
			}
			//     debug {
			try {
				_logfile = File(debugLogFile, "a");
				_logfile.writefln(txt);
				_logfile.close;
			} catch        { die("failed to log to file");}
			//}
			stderr.writeln(txt);
		} catch {
			die("Failed to log '%s' to stdout.", fmt, args);
		}
	}
	
	MaxType!(T1, T2, T3) clamp(T1, T2, T3)(T1 val, T2 lower, T3 upper)
	{
		return max(lower, min(upper,val));
	}

}