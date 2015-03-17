DEIMOS-X11 = libX11

cbox:
		dmd -O -release -inline -boundscheck=off -I$(DEIMOS-X11) -L-L$(DEIMOS-X11)/lib -L-lDX11-dmd -L-lX11 main.d

all: cbox

clean:
		rm main.o
