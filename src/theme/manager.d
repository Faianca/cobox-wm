module theme.manager;

import theme.layout;
import gui.font;
import config;
import cboxapp;
import window;
import types;
import gui.bar;
import kernel;

import std.algorithm;
import std.c.string;
import deimos.X11.X;
import deimos.X11.Xlib;
import deimos.X11.keysymdef;
import deimos.X11.Xutil;
import deimos.X11.Xatom;

class ThemeManager
{
	
	this()
	{
		
	}

	void setlayout(const Arg *arg) 
	{
	    if(!arg || !arg.v || arg.v != selmon.lt[selmon.sellt])
	        selmon.sellt ^= 1;

	    if(arg && arg.v) {
	        selmon.lt[selmon.sellt] = cast(Layout *)arg.v;
	    }

	    selmon.ltsymbol = selmon.lt[selmon.sellt].symbol;

	    if(selmon.sel)
	        arrange(selmon);
	    else
	        drawbar(selmon);
	}

}

/**
 * Drw provides an interface for working with drawable surfaces.
 */
struct Drw 
{
    uint w, h; /// The width and height of the drawable area
    Display *dpy; /// The X display
    int screen; /// The X screen ID
    Window root; /// The root window for this drawable
    Drawable drawable; /// The X drawable encapsulated by this.
    XGC gc; /// The X graphic context
    ClrScheme *scheme; /// The colour scheme to use
    Fnt *font; /// The X font to use for rendering text.

    /**
     * Ctor to initialise the draw object
     * Params:
     *  dpy=        X display to render with.
     *  screen=     X screen id
     *  root=       Root X window for this drawable
     *  w=          Width of the drawable
     *  h=          Height of the drawable
     * Example:
     * ---
     * drw = new Drw(AppDisplay.instance().dpy, screen, root, sw, sh);
     * ---
     */
    this(Display* dpy, int screen, Window root, uint w, uint h) 
    {
        this.dpy = dpy;
        this.screen = screen;
        this.root = root;
        this.w = w;
        this.h = h;
        this.drawable = XCreatePixmap(dpy, root, w, h, DefaultDepth(dpy, screen));
        this.gc = XCreateGC(dpy, root, 0, null);
        XSetLineAttributes(dpy, this.gc, 1, LineSolid, CapButt, JoinMiter);

    }

    /**
     * Resize the drawable to a new width and height
     * Params:
     *  w=      Width
     *  h=      Height
     * Example:
     * ---
     * drw.resize(100, 100);
     * ---
     */
    void resize(uint w, uint h)
     {
        this.w = w;
        this.h = h;
        if(this.drawable != 0) {
            XFreePixmap(this.dpy, this.drawable);
        }
        this.drawable = XCreatePixmap(this.dpy, this.root, w, h, DefaultDepth(this.dpy, this.screen));
    }

    /**
     * Set the font to use for rendering.
     * Params:
     *  font=       Pointer to the font to use.
     */
    void setfont(Fnt *font) 
    {
        this.font = font;
    }

    /**
     * Set the scheme for this drawable
     * Params:
     *  scheme = Pointer to the scheme to use
     */
    void setscheme(ClrScheme *scheme)
    {
        if(scheme)
            this.scheme = scheme;
    }

    /**
     * Draw a rectangle to the X display using the current settings. Note that
     * filled and empty are not mutually exclusive.
     * Params:
     *  x=      Left edge of the rect
     *  y=      Top edge of the rect
     *  w=      Width of the rect
     *  h=      Height of the rect
     *  filled= If true the rect will be filled
     *  empty=  If true the rect will be empty
     *  invert= If true the colours will be inverted.
     * Example:
     * ---
     * drw.rect(10, 10, 90, 90, true, false, false);
     * ---
     */
    void rect(int x, int y, uint w, uint h, int filled, int empty, int invert) 
    {
        int dx;

        if(!this.font || !this.scheme)
            return;
        XSetForeground(this.dpy, this.gc, invert ? this.scheme.bg.rgb : this.scheme.fg.rgb);
        dx = (this.font.ascent + this.font.descent + 2) / 4;
        if(filled)
            XFillRectangle(this.dpy, this.drawable, this.gc, x+1, y+1, dx+1, dx+1);
        else if(empty)
            XDrawRectangle(this.dpy, this.drawable, this.gc, x+1, y+1, dx, dx);
    }

    /**
     * Render some text to the display using the current font.
     * Params:
     *  x=      Left edge of the text area
     *  y=      Top of the text area
     *  w=      Width of the text area
     *  h=      Height of the text area
     *  text=   Text to write
     *  invert= true the text bg/fg coluors will be inverted
     * Example:
     * ---
     * drw.text(10, 10, 100, 100, "this is a test", false);
     * ---
     */
    void text(int x, int y, uint w, uint h, in string text, int invert) 
    {
        char[256] buf;
        Extnts tex;

        if(!this.scheme) {
            return;
        }
        XSetForeground(this.dpy, this.gc, invert ? this.scheme.fg.rgb : this.scheme.bg.rgb);
        XFillRectangle(this.dpy, this.drawable, this.gc, x, y, w, h);
        if(!text || !this.font) {
            return;
        }
        this.font.getexts(text, &tex);
        auto th = this.font.ascent + this.font.descent;
        auto ty = y + (h / 2) - (th / 2) + this.font.ascent;
        auto tx = x + (h / 2);
        /* shorten text if necessary */
        auto len = min(text.length, buf.sizeof);        
        for(; len && (tex.w > w - tex.h || w < tex.h); len--) {
            this.font.getexts(text[0..len], &tex);
        }
        if(!len) {
            return;
        }
        memcpy(buf.ptr, text.ptr, len);

        XSetForeground(this.dpy, this.gc, invert ? this.scheme.bg.rgb : this.scheme.fg.rgb);
        if(this.font.set)
            XmbDrawString(this.dpy, this.drawable, this.font.set, this.gc, tx, ty, buf.ptr, cast(uint)(len));
        else
            XDrawString(this.dpy, this.drawable, this.gc, tx, ty, buf.ptr, cast(int)len);
    }

    /**
     * Copy the drawable area to a window.
     * Params:
     *  win= Destination to copy to.
     *  x=      Left edge of area to copy
     *  y=      Top of area to copy
     *  w=      Width of area to copy
     *  h=      Height of area to copy
     * Example:
     * ---
     * drw.map(win, 10, 10, 100, 100);
     * ---
     */
    void map(Window win, int x, int y, uint w, uint h) 
    {
        XCopyArea(this.dpy, this.drawable, win, this.gc, x, y, w, h, x, y);
        XSync(this.dpy, false);
    }

    /**
     * Release the GC memory used for the Drw object
     * Params:
     *  drw = Drw object to release
     */
    static void free(Drw* drw) 
    {
        drw.destroy;
        DGC.free(drw);
    }

    /**
     * Destroy the X resources used by this drawable.
     */
    void destroy() 
    {
        XFreePixmap(this.dpy, this.drawable);
        XFreeGC(this.dpy, this.gc);
    }

}