# SPDX-FileCopyrightText: 2018 Frank Hunleth, Mark Sebald
#
# SPDX-License-Identifier: Apache-2.0

# Makefile for building the NIF
#
# Makefile targets:
#
# all/install   build and install the NIF
# clean         clean build products and intermediates
#
# Variables to override:
#
# MIX_APP_PATH  path to the build directory
#
# CC            C compiler
# CROSSCOMPILE	crosscompiler prefix, if any
# CFLAGS	compiler flags for compiling all C files
# ERL_CFLAGS	additional compiler flags for files using Erlang header files
# ERL_EI_INCLUDE_DIR include path to ei.h (Required for crosscompile)
# ERL_EI_LIBDIR path to libei.a (Required for crosscompile)
# LDFLAGS	linker flags for linking all binaries
# ERL_LDFLAGS	additional linker flags for projects referencing Erlang libraries
#
# Requirements:
# - libcryptoauth.so must be available on the target system
# - cryptoauthlib headers must be available during compilation

PREFIX = $(MIX_APP_PATH)/priv
BUILD  = $(MIX_APP_PATH)/obj

NIF = $(PREFIX)/cryptoauthlib_nif.so

LDFLAGS += -lcryptoauth

# Add RPATH for runtime library search
LDFLAGS += -Wl,-rpath,/usr/lib -Wl,-rpath,/usr/local/lib

CFLAGS ?= -O2 -Wall -Wextra -Wno-unused-parameter -pedantic

# Check that we're on a supported build platform
ifeq ($(CROSSCOMPILE),)
# Not crosscompiling, so check that we're on Linux for whether to compile the NIF.
ifeq ($(shell uname -s),Linux)
CFLAGS += -fPIC
LDFLAGS += -fPIC -shared
else
LDFLAGS += -undefined dynamic_lookup -dynamiclib
endif
else
# Crosscompiled build
LDFLAGS += -fPIC -shared
CFLAGS += -fPIC
endif

# Set Erlang-specific compile and linker flags
ERL_CFLAGS ?= -I$(ERL_EI_INCLUDE_DIR)
ERL_LDFLAGS ?= -L$(ERL_EI_LIBDIR) -lei

SRC = c_src/cryptoauthlib_nif.c
HEADERS =$(wildcard c_src/*.h)
CRYPTOAUTHLIB_DIR =$(wildcard $(NERVES_SYSTEM)/staging/usr/include/cryptoauthlib)
CRYPTOAUTHLIB_HEADERS = cryptoauthlib.h atca_basic.h atca_device.h atca_iface.h
HEADERS += $(CRYPTOAUTHLIB_HEADERS)
OBJ = $(SRC:c_src/%.c=$(BUILD)/%.o)

calling_from_make:
	mix compile

all: install

install: $(PREFIX) $(BUILD) $(NIF)

#$(OBJ): $(HEADERS) Makefile

$(BUILD)/%.o: c_src/%.c
	@echo " CC $(notdir $@)"
	$(CC) -I$(CRYPTOAUTHLIB_DIR) -lcryptoauthlib -c $(ERL_CFLAGS) $(CFLAGS) -o $@ $<

$(NIF): $(OBJ)
	@echo " LD $(notdir $@)"
	$(CC) -o $@ $(ERL_LDFLAGS) $(LDFLAGS) $^

$(PREFIX) $(BUILD):
	mkdir -p $@

clean:
	$(RM) $(NIF) $(OBJ)

.PHONY: all clean calling_from_make install

# Don't echo commands unless the caller exports "V=1"
${V}.SILENT:
