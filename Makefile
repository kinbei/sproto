.PHONY : all win clean

LUA_INC_DIR ?= /usr/local/include
LUA_LIB_DIR ?= /usr/local/bin
LUA_LIB ?= lua53

all : linux
win : sproto.dll

# For Linux
linux:
	make sproto.so "DLLFLAGS = -shared -fPIC"
# For Mac OS
macosx:
	make sproto.so "DLLFLAGS = -bundle -undefined dynamic_lookup"

sproto.so : sproto.c lsproto.c
	env gcc -O2 -Wall $(DLLFLAGS) -o $@ $^ -I$(LUA_INC_DIR) -L$(LUA_LIB_DIR) -l$(LUA_LIB)

sproto.dll : sproto.c lsproto.c
	gcc -O2 -Wall --shared -o $@ $^ -I$(LUA_INC_DIR) -L$(LUA_LIB_DIR) -l$(LUA_LIB)

clean :
	rm -f sproto.so sproto.dll
