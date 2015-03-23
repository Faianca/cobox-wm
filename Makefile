DEIMOS-X11 = libX11

cbox:
		rdmd -O -release -inline -boundscheck=off -I$(DEIMOS-X11) -L-L$(DEIMOS-X11)/lib -L-lX11  src/main.d -of cbox

all: cbox

clean:
		rm main.o
