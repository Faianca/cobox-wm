cbox:
		dub build --compiler=dmd --build=release-nobounds --force
all: cbox
	
clean:
		rm cobox-wm
