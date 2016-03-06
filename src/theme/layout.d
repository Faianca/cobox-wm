module theme.layout;

import kernel;
import cboxapp;
import old;
import types;
import utils;
import theme.manager;
import window;
import monitor;

import std.c.stdlib;
import x11.X;
import x11.Xlib;
import x11.keysymdef;
import x11.Xutil;
import x11.Xatom;
import std.stdio;
import std.string;
import std.algorithm;


struct Layout 
{
    const string symbol;
    void function(Monitor* m) arrange;
}

struct Clr 
{
    ulong rgb;

    this(Drw* drw, in string clrname) 
    {
        if(drw is null) {
           // lout(__FUNCTION__~"\n\t--> NULL Drw* parm");
            exit(EXIT_FAILURE);
        }

        Colormap cmap;
        XColor color;

        cmap = DefaultColormap(drw.dpy, drw.screen);
        if(!XAllocNamedColor(drw.dpy, cmap, cast(char*)clrname.toStringz, &color, &color)) {
           // lout("error, cannot allocate color '%s'", clrname);
            exit(EXIT_FAILURE);
        }
        this.rgb = color.pixel;
    }

    static void free(Clr *clr) 
    {
        if(clr) {
            DGC.free(clr);
        }
    }
}
