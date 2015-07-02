module gui.font;

import deimos.X11.X;
import deimos.X11.Xlib;
import deimos.X11.Xutil;
import std.c.stdlib;
import std.string;
import std.algorithm;

import cboxapp;
import types;

/**
 * Font object to encapsulate the X font.
 */
struct Fnt 
{
    int ascent; /// Ascent of the font
    int descent;/// Descent of the font
    uint h; /// Height of the font. This equates to ascent + descent.
    XFontSet set; // Font set to use
    XFontStruct *xfont; /// The X font we're covering.
    Display* dpy;

    /**
     * Ctor. Creates a Fnt object wrapping the specified font for a given display.
     * Params:
     *  dpy=        X display
     *  fontname=   Name of the font to wrap (X font name)
     * Example:
     * ---
     * auto f = Fnt(display, "-*-terminus-medium-r-*-*-16-*-*-*-*-*-*-*");
     * ---
     */
    this(Display *dpy, in string fontname) 
    {
        if(AppDisplay.instance().dpy is null) {
            exit(EXIT_FAILURE);
        }

        this.dpy = dpy;
        char *def;
        char **missing;
        int n;

        this.set = XCreateFontSet(AppDisplay.instance().dpy, cast(char*)fontname.toStringz, &missing, &n, &def);

        if(missing) {
            while(n--) {
                //lout("drw: missing fontset: %s", missing[n].fromStringz);
            }
            XFreeStringList(missing);
        }

        if(this.set) {
            XFontStruct **xfonts;
            char **font_names;
            XExtentsOfFontSet(this.set);
            n = XFontsOfFontSet(this.set, &xfonts, &font_names);
            while(n--) {
                this.ascent = max(this.ascent, (*xfonts).ascent);
                this.descent = max(this.descent,(*xfonts).descent);
                xfonts++;
            }
        }

        else {
            this.xfont = XLoadQueryFont(AppDisplay.instance().dpy, cast(char*)(fontname.toStringz));
            if(this.xfont is null) {
                this.xfont = XLoadQueryFont(AppDisplay.instance().dpy, cast(char*)("fixed".toStringz));
                if(this.xfont is null) {
                    //lout("error, cannot load font: %s", fontname);
                    exit(EXIT_FAILURE);
                }
            }
            this.ascent = this.xfont.ascent;
            this.descent = this.xfont.descent;
        }

        this.h = this.ascent + this.descent;
    }

    /**
     * Destroy the X resources for this font.
     */
    private void destroy(Display* dpy) 
    {
        if(this.set) {
            XFreeFontSet(dpy, this.set);
        }
        else if(this.xfont) {
            XFreeFont(dpy, this.xfont);
        }
        this.set = null;
        this.xfont = null;
    }

    /**
     * Free the given font object associated with a display. This will release
     * the GC allocated memory.
     * Params:
     *  fnt=        Pointer to the font to destroy.
     *  dpy=        Display associated with the font to destroy
     * Example:
     * ---
     * auto f = Fnt(display, "-*-terminus-medium-r-*-*-16-*-*-*-*-*-*-*");
     *
     * Fnt.free(f)
     * ---
     */
    static void free(Display* dpy, Fnt* fnt) 
    {
        fnt.destroy(AppDisplay.instance().dpy);
        DGC.free(fnt);
    }

    /**
     * Get the font extents for a given string.
     * Params:
     *  text=   Text to get the extents
     *  tex=    Extents struct to fill in with the font information
     */
    void getexts(in string text, Extnts *tex) 
    {
        XRectangle r;

        if(text.length == 0) {
            return;
        }
        if(this.set) {
            XmbTextExtents(this.set, cast(char*)text.ptr, cast(int)text.length, null, &r);
            tex.w = r.width;
            tex.h = r.height;
        }
        else {
            tex.h = this.ascent + this.descent;
            tex.w = XTextWidth(this.xfont, cast(char*)text.ptr, cast(int)text.length);
        }
    }

    /**
     * Get the rendered width of a string for the wrapped font.
     * Params:
     *  text=       Text to get the width for
     * Returns:
     *  Width of the text for the wrapped font.
     */
    uint getexts_width(in string text) 
    {
        Extnts tex;

        this.getexts(text, &tex);
        return tex.w;
    }
}