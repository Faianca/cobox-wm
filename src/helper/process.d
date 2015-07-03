module helper.process;

import std.conv;
import std.process;
import std.string;
import std.stdio;
import types;
import config;
import utils;

/**
* Runs command
**/
void spawn(const Arg *arg) 
{
    import std.variant;
    Variant v = arg.val;
    const(string[]) args = arg.s;
  
    if(args[0] == dmenucmd[0]) {
        dmenumon[0] = cast(char)('0' + selmon.num);
    }

    try {
        auto pid = spawnProcess(args);
    } catch {
        die("Failed to spawn '%s'", args);
    }
}


