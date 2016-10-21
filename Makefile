default: build

SRC = $(shell find src -name "*.ls" -type f | sort)
LIB = $(SRC:src/%.ls=lib/%.js)

lib:
	mkdir -p lib/

lib/%.js: src/%.ls lib
	lsc --output lib --compile "$<"

build: $(LIB)

clean:
	rm -rf lib

