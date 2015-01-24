VPATH=src
BUILDDIR=lib

BEANDIR=.
JSONDIR=.

COFFEE_SOURCES= $(wildcard $(VPATH)/*.coffee)
COFFEE_OBJECTS=$(patsubst $(VPATH)/%.coffee, $(BUILDDIR)/%.js, $(COFFEE_SOURCES))

BEAN_FILES=$(wildcard $(BEANDIR)/*.yml)
JSON_FILES=$(patsubst $(BEANDIR)/%.yml, $(JSONDIR)/%.json, $(BEAN_FILES))

GRAMMAR_DIR=src
GRAMMAR_BUILD_DIR=lib

GRAMMAR_SOURCES= $(wildcard $(GRAMMAR_DIR)/*.pegjs)
GRAMMAR_TEMP_OBJECTS = $(patsubst $(GRAMMAR_DIR)/%.pegjs, $(GRAMMAR_DIR)/%.js, $(GRAMMAR_SOURCES))
GRAMMAR_OBJECTS= $(patsubst $(GRAMMAR_DIR)/%.pegjs, $(GRAMMAR_BUILD_DIR)/%.js, $(GRAMMAR_SOURCES))

all: build

.PHONY: build
build: node_modules objects

.PHONY: objects
objects: $(COFFEE_OBJECTS) $(JSON_FILES) $(GRAMMAR_OBJECTS) $(GRAMMAR_TEMP_OBJECTS)

$(JSONDIR)/%.json: $(BEANDIR)/%.yml
	./node_modules/.bin/bean --source $<

.PHONY: test
test: build
	./node_modules/.bin/testlet

.PHONY: clean
clean:
	rm -f $(COFFEE_OBJECTS)

.PHONE: pristine
pristine: clean
	rm -rf node_modules

node_modules:
	npm install -d

$(BUILDDIR)/%.js: $(VPATH)/%.coffee
	coffee -o $(BUILDDIR) -c $<

$(GRAMMAR_BUILD_DIR)/%.js: $(GRAMMAR_DIR)/%.pegjs
	./node_modules/.bin/pegjs $< $@

$(GRAMMAR_DIR)/%.js: $(GRAMMAR_DIR)/%.pegjs
	./node_modules/.bin/pegjs $< $@
