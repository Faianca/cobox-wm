module monitor;

import std.stdio;
import std.string;
import std.algorithm;

import deimos.X11.X;

import cboxapp;
import window;
import theme.layout;
import config;
import types;
import kernel;
import theme.manager;
import old;
import utils;

struct Monitor 
{
  string ltsymbol;
  float mfact;
  int nmaster;
  int num;
  int by;               /* bar geometry */
  int mx, my, mw, mh;   /* screen size */
  int wx, wy, ww, wh;   /* window area  */
  uint seltags;
  uint sellt;
  uint[2] tagset;
  bool showbar;
  bool topbar;
  Client *clients;
  Client *sel;
  Client *stack;
  Monitor *next;
  Window barwin;
  const(Layout)*[2] lt;

    struct MonitorRange 
    {
        Monitor* monitor;

        @property empty() 
        {
            return monitor is null;
        }

        @property auto front() 
        {
            return monitor;
        }

        auto popFront() 
        {
            monitor = monitor.next;
        }

        int opApply(int delegate(Monitor*) dg)
        {
            int result = 0;
            while(!this.empty)
            {
                result = dg(this.front);
                if(result)
                {
                    break;
                }
                this.popFront;
            }
            return result;
        }

        int opApply(int delegate(size_t, Monitor*) dg) 
        {
            int result = 0;
            size_t ii = 0;
            while(!this.empty)
            {
                result = dg(ii++, this.front);
                if(result)
                {
                    break;
                }
                this.popFront;
            }
            return result;
        }
    }
}

Monitor* recttomon(int x, int y, int w, int h) 
{
    auto r = selmon;
    int a, area = 0;

    foreach(m; mons.range) {
        a = INTERSECT(x, y, w, h, m);
        if(a > area) {
            area = a;
            r = m;
        }
    }
    return r;
}

Monitor* wintomon(Window w) 
{
    int x, y;

    if(w == rootWin && getrootptr(&x, &y)) {
        return recttomon(x, y, 1, 1);
    }
    auto m = mons.range.find!(mon => mon.barwin == w).front;
    if(m) {
        return m;
    }

    auto c = wintoclient(w);
    if(c) {
        return c.mon;
    }
    return selmon;
}

Monitor* dirtomon(int dir) 
{
    Monitor *m = null;

    if(dir > 0) {
        m = selmon.next;
        if(m is null) {
            m = mons;
        }
    } else if(selmon == mons) {
        m = mons.range.find!"a.next is null".front;
    } else {
        m = mons.range.find!(a => a.next == selmon).front;
    }
    return m;
}

Monitor* createmon() 
{
    Monitor* m = new Monitor();

    if(m is null) {
        die("fatal: could not malloc() %s bytes\n", Monitor.sizeof);
    }

    m.tagset[0] = m.tagset[1] = 1;
    m.mfact = mfact;
    m.nmaster = nmaster;
    m.showbar = showbar;
    m.topbar = topbar;
    m.lt[0] = &layouts[0];
    m.lt[1] = &layouts[1 % LENGTH(layouts)];
    m.ltsymbol = layouts[0].symbol;

    return m;
}

void arrange(Monitor *m) 
{
    if(m) {
        windowManager.showhide(m.stack);
    } else foreach(m; mons.range) {
        windowManager.showhide(m.stack);
    }
    if(m) {
        arrangemon(m);
        restack(m);
    } else foreach(m; mons.range) {
        arrangemon(m);
    }
}

void arrangemon(Monitor *m) {
    
    m.ltsymbol = m.lt[m.sellt].symbol;

    if(m.lt[m.sellt].arrange)
        m.lt[m.sellt].arrange(m);
}

void attach(Client *c) {
    
    c.next = c.mon.clients;
    c.mon.clients = c;
}

void attachstack(Client *c) {
    
    c.snext = c.mon.stack;
    c.mon.stack = c;
}