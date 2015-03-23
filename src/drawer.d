module drawer;
//
//import core.memory;
//import std.c.stdlib;
//import std.c.stdio;
//import std.c.string;
//
//import std.algorithm;
//import std.exception;
//import std.string;
//
//import deimos.X11.X;
//import deimos.X11.Xlib;
//
//import cursorfont;
//import ddwmtypes;
//import ddwmutil;
//
//alias DGC = core.memory.GC;
//alias XGC = deimos.X11.Xlib.GC;
//
///**
// * Drw provides an interface for working with drawable surfaces.
// */
//class Drawer 
//{
//    uint w, h; /// The width and height of the drawable area
//    Display *dpy; /// The X display
//    int screen; /// The X screen ID
//    Window root; /// The root window for this drawable
//    Drawable drawable; /// The X drawable encapsulated by this.
//    XGC gc; /// The X graphic context
//    ClrScheme *scheme; /// The colour scheme to use
//    Fnt *font; /// The X font to use for rendering text.
//
//    /**
//     * Ctor to initialise the draw object
//     * Params:
//     *  dpy=        X display to render with.
//     *  screen=     X screen id
//     *  root=       Root X window for this drawable
//     *  w=          Width of the drawable
//     *  h=          Height of the drawable
//     * Example:
//     * ---
//     * drw = new Drw(dpy, screen, root, sw, sh);
//     * ---
//     */
//    this(Display* dpy, int screen, Window root, uint w, uint h) 
//    {
//        this.dpy = dpy;
//        this.screen = screen;
//        this.root = root;
//        this.w = w;
//        this.h = h;
//        this.drawable = XCreatePixmap(dpy, root, w, h, DefaultDepth(dpy, screen));
//        this.gc = XCreateGC(dpy, root, 0, null);
//        XSetLineAttributes(dpy, this.gc, 1, LineSolid, CapButt, JoinMiter);
//
//    }
//
//    /**
//     * Resize the drawable to a new width and height
//     * Params:
//     *  w=      Width
//     *  h=      Height
//     * Example:
//     * ---
//     * drw.resize(100, 100);
//     * ---
//     */
//    void resize(uint w, uint h) 
//    {
//        this.w = w;
//        this.h = h;
//        if(this.drawable != 0) {
//            XFreePixmap(this.dpy, this.drawable);
//        }
//        this.drawable = XCreatePixmap(this.dpy, this.root, w, h, DefaultDepth(this.dpy, this.screen));
//    }
//
//    /**
//     * Destroy the X resources used by this drawable.
//     */
//    void destroy() 
//    {
//        XFreePixmap(this.dpy, this.drawable);
//        XFreeGC(this.dpy, this.gc);
//    }
//
//    /**
//     * Set the font to use for rendering.
//     * Params:
//     *  font=       Pointer to the font to use.
//     */
//    void setfont(Fnt *font) {
//        this.font = font;
//    }
//    /**
//     * Set the scheme for this drawable
//     * Params:
//     *  scheme=     Pointer to the scheme to use
//     */
//    void setscheme(ClrScheme *scheme) 
//    {
//        if(scheme)
//            this.scheme = scheme;
//    }
//
//    /**
//     * Draw a rectangle to the X display using the current settings. Note that
//     * filled and empty are not mutually exclusive.
//     * Params:
//     *  x=      Left edge of the rect
//     *  y=      Top edge of the rect
//     *  w=      Width of the rect
//     *  h=      Height of the rect
//     *  filled= If true the rect will be filled
//     *  empty=  If true the rect will be empty
//     *  invert= If true the colours will be inverted.
//     * Example:
//     * ---
//     * drw.rect(10, 10, 90, 90, true, false, false);
//     * ---
//     */
//    void rect(int x, int y, uint w, uint h, int filled, int empty, int invert)
//    {
//        int dx;
//
//        if(!this.font || !this.scheme)
//            return;
//        XSetForeground(this.dpy, this.gc, invert ? this.scheme.bg.rgb : this.scheme.fg.rgb);
//        dx = (this.font.ascent + this.font.descent + 2) / 4;
//        if(filled)
//            XFillRectangle(this.dpy, this.drawable, this.gc, x+1, y+1, dx+1, dx+1);
//        else if(empty)
//            XDrawRectangle(this.dpy, this.drawable, this.gc, x+1, y+1, dx, dx);
//    }
//
//    /**
//     * Render some text to the display using the current font.
//     * Params:
//     *  x=      Left edge of the text area
//     *  y=      Top of the text area
//     *  w=      Width of the text area
//     *  h=      Height of the text area
//     *  text=   Text to write
//     *  invert= true the text bg/fg coluors will be inverted
//     * Example:
//     * ---
//     * drw.text(10, 10, 100, 100, "this is a test", false);
//     * ---
//     */
//    void text(int x, int y, uint w, uint h, in string text, int invert) {
//        char[256] buf;
//        Extnts tex;
//
//        if(!this.scheme) {
//            return;
//        }
//        XSetForeground(this.dpy, this.gc, invert ? this.scheme.fg.rgb : this.scheme.bg.rgb);
//        XFillRectangle(this.dpy, this.drawable, this.gc, x, y, w, h);
//        if(!text || !this.font) {
//            return;
//        }
//        this.font.getexts(text, &tex);
//        auto th = this.font.ascent + this.font.descent;
//        auto ty = y + (h / 2) - (th / 2) + this.font.ascent;
//        auto tx = x + (h / 2);
//        /* shorten text if necessary */
//        auto len = min(text.length, buf.sizeof);        
//        for(; len && (tex.w > w - tex.h || w < tex.h); len--) {
//            this.font.getexts(text[0..len], &tex);
//        }
//        if(!len) {
//            return;
//        }
//        memcpy(buf.ptr, text.ptr, len);
//
//        XSetForeground(this.dpy, this.gc, invert ? this.scheme.bg.rgb : this.scheme.fg.rgb);
//        if(this.font.set)
//            XmbDrawString(this.dpy, this.drawable, this.font.set, this.gc, tx, ty, buf.ptr, cast(uint)(len));
//        else
//            XDrawString(this.dpy, this.drawable, this.gc, tx, ty, buf.ptr, cast(int)len);
//    }
//
//    /**
//     * Copy the drawable area to a window.
//     * Params:
//     *  win= Destination to copy to.
//     *  x=      Left edge of area to copy
//     *  y=      Top of area to copy
//     *  w=      Width of area to copy
//     *  h=      Height of area to copy
//     * Example:
//     * ---
//     * drw.map(win, 10, 10, 100, 100);
//     * ---
//     */
//    void map(Window win, int x, int y, uint w, uint h) {
//        XCopyArea(this.dpy, this.drawable, win, this.gc, x, y, w, h, x, y);
//        XSync(this.dpy, false);
//    }
//
//    /**
//     * Release the GC memory used for the Drw object
//     * Params:
//     *  drw=        Drw object to release
//     */
//    static void free(Drw* drw) {
//        drw.destroy;
//        DGC.free(drw);
//    }
//
//}
//
///**
// * Font object to encapsulate the X font.
// */
//class Fnt 
//{    
//    int ascent; /// Ascent of the font
//    int descent;/// Descent of the font
//    uint h; /// Height of the font. This equates to ascent + descent.
//    XFontSet set; // Font set to use
//    XFontStruct *xfont; /// The X font we're covering.
//    Display* dpy;
//
//    /**
//     * Ctor. Creates a Fnt object wrapping the specified font for a given display.
//     * Params:
//     *  dpy=        X display
//     *  fontname=   Name of the font to wrap (X font name)
//     * Example:
//     * ---
//     * auto f = Fnt(display, "-*-terminus-medium-r-*-*-16-*-*-*-*-*-*-*");
//     * ---
//     */
//    this(Display *dpy, in string fontname) {
//        if(dpy is null) {
//            lout(__FUNCTION__~"\n\t--> NULL dpy parm"); 
//            exit(EXIT_FAILURE);
//        }
//        this,dpy = dpy;
//        char *def;
//        char **missing;
//        int n;
//        this.set = XCreateFontSet(dpy, cast(char*)fontname.toStringz, &missing, &n, &def);
//        if(missing) {
//            while(n--) {
//                lout("drw: missing fontset: %s", missing[n].fromStringz);
//            }
//            XFreeStringList(missing);
//        }
//        if(this.set) {
//            XFontStruct **xfonts;
//            char **font_names;
//            XExtentsOfFontSet(this.set);
//            n = XFontsOfFontSet(this.set, &xfonts, &font_names);
//            while(n--) {
//                this.ascent = max(this.ascent, (*xfonts).ascent);
//                this.descent = max(this.descent,(*xfonts).descent);
//                xfonts++;
//            }
//        }
//        else {
//            this.xfont = XLoadQueryFont(dpy, cast(char*)(fontname.toStringz));
//            if(this.xfont is null) {
//                this.xfont = XLoadQueryFont(dpy, cast(char*)("fixed".toStringz));
//                if(this.xfont is null) {
//                    lout("error, cannot load font: %s", fontname);
//                    exit(EXIT_FAILURE);
//                }
//            }
//            this.ascent = this.xfont.ascent;
//            this.descent = this.xfont.descent;
//        }
//        this.h = this.ascent + this.descent;
//    }
//
//    /**
//     * Destroy the X resources for this font.
//     */
//    private void destroy(Display* dpy) {
//        if(this.set) {
//            XFreeFontSet(dpy, this.set);
//        }
//        else if(this.xfont) {
//            XFreeFont(dpy, this.xfont);
//        }
//        this.set = null;
//        this.xfont = null;
//    }
//
//    /**
//     * Free the given font object associated with a display. This will release
//     * the GC allocated memory.
//     * Params:
//     *  fnt=        Pointer to the font to destroy.
//     *  dpy=        Display associated with the font to destroy
//     * Example:
//     * ---
//     * auto f = Fnt(display, "-*-terminus-medium-r-*-*-16-*-*-*-*-*-*-*");
//     *
//     * // work with the font object
//     *
//     * Fnt.free(f)
//     * ---
//     */
//    static void free(Display* dpy, Fnt* fnt) {
//        fnt.destroy(dpy);
//        DGC.free(fnt);
//    }
//
//    /**
//     * Get the font extents for a given string.
//     * Params:
//     *  text=   Text to get the extents
//     *  tex=    Extents struct to fill in with the font information
//     */
//    void getexts(in string text, Extnts *tex) {
//        XRectangle r;
//
//        if(text.length == 0) {
//            return;
//        }
//        if(this.set) {
//            XmbTextExtents(this.set, cast(char*)text.ptr, cast(int)text.length, null, &r);
//            tex.w = r.width;
//            tex.h = r.height;
//        }
//        else {
//            tex.h = this.ascent + this.descent;
//            tex.w = XTextWidth(this.xfont, cast(char*)text.ptr, cast(int)text.length);
//        }
//    }
//
//    /**
//     * Get the rendered width of a string for the wrapped font.
//     * Params:
//     *  text=       Text to get the width for
//     * Returns:
//     *  Width of the text for the wrapped font.
//     */
//    uint getexts_width(in string text) {
//        Extnts tex;
//
//        this.getexts(text, &tex);
//        return tex.w;
//    }
//
//}
//
//struct Clr 
//{
//    ulong rgb;
//
//    this(Drw* drw, in string clrname) {
//        if(drw is null) {
//            lout(__FUNCTION__~"\n\t--> NULL Drw* parm");
//            exit(EXIT_FAILURE);
//        }
//        Colormap cmap;
//        XColor color;
//
//        cmap = DefaultColormap(drw.dpy, drw.screen);
//        if(!XAllocNamedColor(drw.dpy, cmap, cast(char*)clrname.toStringz, &color, &color)) {
//            lout("error, cannot allocate color '%s'", clrname);
//            exit(EXIT_FAILURE);
//        }
//        this.rgb = color.pixel;
//    }
//
//    static void free(Clr *clr) {
//        if(clr) {
//            DGC.free(clr);
//        }
//    }
//}
//
//struct ClrScheme 
//{
//	Clr *fg;
//	Clr *bg;
//	Clr *border;
//}
//
///**
// * Wraps a X cursor.
// */
//struct Cur 
//{
//    Cursor cursor;
//    Display* dpy;
//
//    /**
//     * Ctor constructing a Cursor with a given display object.
//     * Params:
//     *  dpy=        Display object
//     *  shape=      X cursor shape
//     */
//    this(Display* dpy, CursorFont shape) {
//        if(dpy is null) {
//            lout(__FUNCTION__~"\n\t--> NULL Display* parm");
//            exit(EXIT_FAILURE);
//        }
//        this.dpy = dpy;
//        this.cursor = XCreateFontCursor(this.dpy, shape);
//    }
//
//    private void destroy() {
//        XFreeCursor(this.dpy, this.cursor);
//    }
//
//    static void free(Cur* c) {
//        if(c is null) {
//            lout(__FUNCTION__~"\n\t--> NULL Cur* parm");
//            exit(EXIT_FAILURE);
//        }
//        c.destroy();
//        DGC.free(c);
//    }
//}


