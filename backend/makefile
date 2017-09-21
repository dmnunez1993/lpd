all: detection

detection:	detection.cpp
	g++ -lopencv_core -lopencv_highgui  `pkg-config --libs --cflags opencv` detection.cpp -o detection

clean:
	rm -f detection
