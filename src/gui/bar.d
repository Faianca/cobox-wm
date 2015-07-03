module gui.bar;

import cboxapp;
import types;
import gui.cursor;
import window;
import old;
import legacy;
import utils;
import config;
import kernel;
import helper.x11;
import monitor;
import std.stdio;
import theme.manager;

import deimos.X11.X;
import deimos.X11.Xlib;
import deimos.X11.keysymdef;
import deimos.X11.Xutil;
import deimos.X11.Xatom;

void drawbar(Monitor *m) 
{
    uint occ = 0, urg = 0;

    foreach(c; m.clients.range!"next") {
        occ |= c.tags;
        if(c.isurgent) {
            urg |= c.tags;
        }
    }

    int x = 0, w;

    ClrScheme sel = ThemeManager.instance().getScheme(SchemeSel);
    ClrScheme norm = ThemeManager.instance().getScheme(SchemeNorm);
    
    foreach(i, tag; tags) {
        w = TEXTW(tag);
        drw.setscheme((m.tagset[m.seltags] & (1 << i)) 
            ? &sel
            : &norm);
        drw.text(x, 0, w, bh, tag, urg & 1 << i);
        drw.rect(x, 0, w, bh, m == selmon && selmon.sel && selmon.sel.tags & 1 << i,
                 occ & 1 << i, urg & 1 << i);
        x += w;
    }

    int xx = x;
    
    if(m == selmon) { /* status is only drawn on selected monitor */
        w = TEXTW(stext);
        x = m.mw - w;

        if(x < xx) {
            x = xx;
            w = m.mw - xx;
        }

        drw.setscheme(&norm);
        drw.text(x, 0, w, bh, stext, 0);
    } else {
        x = m.mw;
    }

    if((w = x - xx) > bh) {
        x = xx;
        if(m.sel) {
            drw.setscheme(m == selmon ? &sel : &norm);
            drw.text(x, 0, w, bh, m.sel.name, 0);
            drw.rect(x, 0, w, bh, m.sel.isfixed, m.sel.isfloating, 0);
        } else {
            drw.setscheme(&norm);
            drw.text(x, 0, w, bh, null, 0);
        }
    }

    drw.map(m.barwin, 0, 0, m.mw, bh);
}

void drawbars()
{
    foreach(m; mons.range) {
        drawbar(m);
    }
}

void updatebars()
{
    Client *c;
    XSetWindowAttributes wa = {
		override_redirect : True,
		background_pixmap : ParentRelative,
		event_mask :  ButtonPressMask|ExposureMask
    };

    foreach(m; mons.range) {
        if (m.barwin)
            continue;
        
        m.barwin = XCreateWindow(
        	AppDisplay.instance().dpy, 
        	rootWin, 
        	m.wx, 
        	m.by, 
        	m.ww, 
        	bh, 
        	0, 
        	DefaultDepth(AppDisplay.instance().dpy, screen),
            CopyFromParent, 
            DefaultVisual(AppDisplay.instance().dpy, screen),
            CWOverrideRedirect|CWBackPixmap|CWEventMask, 
            &wa
        );

        XDefineCursor(AppDisplay.instance().dpy, m.barwin, cursor[CurNormal].cursor);

        //sendevent(c, XInternAtom(AppDisplay.instance().dpy, cast(char*)("_NET_WM_STATE_ABOVE"), false));
        XMapRaised(AppDisplay.instance().dpy, m.barwin);
        //sendevent(c, XInternAtom(AppDisplay.instance().dpy, cast(char*)("_NET_WM_STATE_ABOVE"), false));
    }
}

void updatebarpos(Monitor *m) 
{
    
    m.wy = m.my;
    m.wh = m.mh;
    if(m.showbar) {
        m.wh -= bh;
        m.by = m.topbar ? m.wy : m.wy + m.wh;
        m.wy = m.topbar ? m.wy + bh : m.wy;
    } else
        m.by = -bh;
}

void togglebar(const Arg *arg) 
{
    selmon.showbar = !selmon.showbar;
    updatebarpos(selmon);
    XMoveResizeWindow(AppDisplay.instance().dpy, selmon.barwin, selmon.wx, selmon.by, selmon.ww, bh);
    arrange(selmon);
}

void updatestatus() 
{
    if(!X11Helper.gettextprop(rootWin, XA_WM_NAME, stext)) {
        stext = "ddwm-"~VERSION;
    }
    drawbar(selmon);
}


