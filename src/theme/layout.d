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

void tile(Monitor *m) 
{
    uint i, n, h, mw, my, ty;
    Client *c;

    for(n = 0, c = nexttiled(m.clients); c; c = nexttiled(c.next), n++) {}
    if(n == 0) {
        return;
    }

    if(n > m.nmaster) {
        mw = cast(uint)(m.nmaster ? m.ww * m.mfact : 0);
    } else {
        mw = m.ww;
    }
    for(i = my = ty = 0, c = nexttiled(m.clients); c; c = nexttiled(c.next), i++) {
        if(i < m.nmaster) {
            h = (m.wh - my) / (min(n, m.nmaster) - i);
            resize(c, m.wx, m.wy + my, mw - (2*c.bw), h - (2*c.bw), false);
            my += HEIGHT(c);
        } else {
            h = (m.wh - ty) / (n - i);
            resize(c, m.wx + mw, m.wy + ty, m.ww - mw - (2*c.bw), h - (2*c.bw), false);
            ty += HEIGHT(c);
        }
    }
}

void monocle(Monitor *m) 
{
    uint n = 0;

    n = m.clients.range!"next".map!(a=>ISVISIBLE(a)).sum;
    if(n > 0) { /* override layout symbol */
        m.ltsymbol = format("[%d]", n);
    }
    for(auto c = nexttiled(m.clients); c; c = nexttiled(c.next)) {
        resize(c, m.wx, m.wy, m.ww - 2 * c.bw, m.wh - 2 * c.bw, false);
    }
}