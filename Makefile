# var
MODULE = $(notdir $(CURDIR))

# dir
CWD  = $(CURDIR)
ROOT = $(CWD)/root

# cross
APP ?= $(MODULE)
HW  ?= qemu386
include  any/any.mk
include   hw/$(HW).mk
include  cpu/$(CPU).mk
include arch/$(ARCH).mk
include  app/$(APP).mk

# tool
CURL = curl -L -o
CF   = clang-format -style=file -i

# src
C += $(wildcard src/*.c*)
H += $(wildcard inc/*.h*)
F += lib/$(MODULE).ini $(wildcard src/*.m)
CP = tmp/$(MODULE).parser.cpp tmp/$(MODULE).lexer.cpp
HP = tmp/$(MODULE).parser.hpp

# cfg
CFLAGS += -Iinc -Itmp

# all
.PHONY: all
all: bin/$(MODULE) $(F)
	$^

# format
.PHONY: format
format: tmp/format_cpp
tmp/format_cpp: $(C) $(H)
	$(CF) $? && touch $@

# rule
bin/$(MODULE): $(C) $(H) $(CP) $(HP)
	$(CXX) $(CFLAGS) -o $@ $(C) $(CP) $(L)

tmp/$(MODULE).lexer.cpp: src/$(MODULE).lex
	flex -o $@ $<
tmp/$(MODULE).parser.cpp: src/$(MODULE).yacc
	bison -o $@ $<

# install
.PHONY: install update ref gz
install: ref gz
	$(MAKE) update
update:
	sudo apt update
	sudo apt install -uy `cat apt.txt`
ref:
gz:

# debstrap

MM_OPTS  += --aptopt=etc/apt/apt.conf.d/99proxy

.PHONY: deb
deb:
	rm -rf $(ROOT) ; git checkout $(ROOT)
