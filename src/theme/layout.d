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
import deimos.X11.X;
import deimos.X11.Xlib;
import deimos.X11.keysymdef;
import deimos.X11.Xutil;
import deimos.X11.Xatom;
import std.stdio;
import std.string;


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
