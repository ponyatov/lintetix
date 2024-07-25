# var
MODULE   = $(notdir $(CURDIR))
SQUIPORT = 13128

# cross
APP ?= $(MODULE)
HW  ?= qemu386
include  any/any.mk
include   hw/$(HW).mk
include  cpu/$(CPU).mk
include arch/$(ARCH).mk
include  app/$(APP).mk

# dir
CWD     = $(CURDIR)
ROOT    = $(CWD)/root
SQUIDIR = $(HOME)/tmp/squid

# tool
CURL  = curl -L -o
CF    = clang-format -style=file -i
SQUID = /usr/sbin/squid

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
	sudo systemctl disable squid
	sudo systemctl stop    squid
update:
	sudo apt update
	sudo apt install -uy `cat apt.txt`
ref:
gz:

# debstrap

MM_SUITE  = bookworm
MM_MIRROR = etc/apt/sources.list
MM_OPTS  += --aptopt=etc/apt/apt.conf.d/99proxy
MM_OPTS  += --architectures=$(ARCH)
MM_OPTS  += --variant=custom
MM_OPTS  += --setup-hook='mkdir -p "$$1"'
MM_OPTS  += --customize-hook='git checkout "$$1"'
MM_OPTS  += --customize-hook='sync-in etc /etc'
# MM_OPTS  += --customize-hook='copy-in etc/network  /etc/network'
# MM_OPTS  += --customize-hook='copy-in etc/wpa_supplicant /etc/wpa_supplicant'
MM_OPTS  += --aptopt='Acquire::http { Proxy "http://localhost:13128"; }'

.PHONY: deb
deb:
	sudo rm -rf $(ROOT)
#  ; git checkout $(ROOT)
	sudo mmdebstrap $(MM_OPTS) $(MM_SUITE) $(ROOT) $(MM_MIRROR)

.PHONY: squid
squid: etc/squid/squid.conf $(SQUIDIR)/00/00
	$(SQUID) -N -f $<
$(SQUIDIR)/00/00: etc/squid/squid.conf
	mkdir -p $(SQUIDIR) && $(SQUID) -N -f $< -z
etc/squid/squid.conf: etc/squid/squid.in Makefile
	cat $< > $@
	echo "pid_filename $(SQUIDIR)/pid" >> $@
	echo "cache_log    $(SQUIDIR)/cache.log" >> $@
	echo "access_log   $(SQUIDIR)/access.log" >> $@
	echo >> $@
	echo "cache_dir aufs $(SQUIDIR) 40960 16 256" >> $@
	echo >> $@
	echo "http_port $(SQUIPORT)" >> $@
