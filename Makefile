default: build

SRC = $(shell find src -name "*.ls" -type f | sort)
LIB = $(SRC:src/%.ls=lib/%.js)

lib:
	mkdir -p lib/

lib/%.js: src/%.ls lib node_modules
	node node_modules/livescript/bin/lsc --output lib --compile "$<"

node_modules:
	npm install

build: $(LIB)

SPEC_SRC = $(shell find spec -name "*.ls" -type f | sort)
SPEC_LIB = $(SPEC_SRC:spec/src/%.ls=spec/%.js)

spec/%.js: spec/src/*.ls node_modules
	node node_modules/livescript/bin/lsc --output spec --map linked-src --compile "$<"

build-tests: $(SPEC_LIB)

test: build build-tests
	node node_modules/jasmine/bin/jasmine.js

clean:
	rm -rf lib
	rm spec/*.js

