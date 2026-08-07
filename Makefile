# Astrolog (Version 8.00) File: Makefile (Unix version)
#
# IMPORTANT NOTICE: Astrolog and all chart display routines and anything
# not enumerated elsewhere in this program are Copyright (C) 1991-2026 by
# Walter D. Pullen (Astara@msn.com, http://www.astrolog.org/astrolog.htm).
# Permission is granted to freely use, modify, and distribute these
# routines provided these credits and notices remain unmodified with any
# altered or distributed versions of the program.
#
# First created 11/21/1991.
#
# This Makefile is included only for convenience. One could easily compile
# Astrolog on most Unix systems by hand with the command:
# % cc -c -O *.cpp; cc -o astrolog *.o -lm -lX11
# Generally, all that needs to be done to compile once astrolog.h has been
# edited, is compile each source file, and link them together with the math
# library, and if applicable, the main X library.
#
NAME = astrolog
OBJS = astrolog.o atlas.o calc.o charts0.o charts1.o charts2.o charts3.o\
 data.o express.o general.o intrpret.o io.o matrix.o placalc.o placalc2.o\
 xdata.o xgeneral.o xdevice.o xcharts0.o xcharts1.o xcharts2.o xscreen.o\
 swecl.o swedate.o swehouse.o swejpl.o swemmoon.o swemplan.o sweph.o\
 swephlib.o

# Native macOS command-line build. The graphics engine remains enabled for
# SVG, PNG, PostScript, and bitmap export; only the optional X11 window layer
# is disabled in astrolog.h.
CXX ?= c++
LIBS = -lm
CXXFLAGS ?= -O2
ARCHFLAGS ?=
CXXFLAGS += -Wno-write-strings -Wno-narrowing -Wno-comment \
 -Wno-deprecated-declarations $(ARCHFLAGS)
RM = rm -f

$(NAME): $(OBJS)
	$(CXX) $(ARCHFLAGS) -o $(NAME) $(OBJS) $(LIBS)

clean:
	$(RM) $(OBJS) $(NAME)
#
