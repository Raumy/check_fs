# Makefile
# vala project
#
 
# name of your project/program
PROGRAM = check
 
 
# for most cases the following two are the only you'll need to change
# add your source files here
SRC = main_gtk.vala check.vala
 
# add your used packges here
PKGS = --pkg gee-1.0 --pkg gio-2.0  --pkg gtk+-3.0
 
# vala compiler
VALAC = valac
 
# compiler options for a debug build
#VALACOPTS = -g --save-temps -X -w  -D NO_SERVER --disable-warnings
VALACOPTS = -X -w  -D NO_SERVER -D REF_TRACKING --disable-warnings
 
# set this as root makefile for Valencia
BUILD_ROOT = 1
 
# the 'all' target build a debug build
all:
	@$(VALAC) $(VALACOPTS) $(SRC) -o $(PROGRAM) $(PKGS)
 
# the 'release' target builds a release build
# you might want to disabled asserts also
release: clean
	@$(VALAC) -X -O2 $(SRC) -o main_release $(PKGS)
 
# clean all built files
clean:
	@rm -v -fr *~ *.c $(PROGRAM)
