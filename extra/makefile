all: circulos	features matcher template

circulos:	circulos.cpp
	g++ `pkg-config --libs --cflags opencv` circulos.cpp -o circulos

features:	features.cpp
	g++ `pkg-config --libs --cflags opencv` features.cpp -o features
matcher:	matcher.cpp
	g++ `pkg-config --libs --cflags opencv` matcher.cpp -o matcher

template:	template.cpp
	g++ `pkg-config --libs --cflags opencv` template.cpp -o template
clean:
	rm -f circulos features matcher template
