# var
MODULE   = $(notdir $(CURDIR))
SQUIPORT = 13128

# version
LINUX_VER = 6.1.0-23

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

# https://youtu.be/UrDlUWNNkDY?si=twzZmIEYHUyUlUEa&t=560

MM_SUITE  = bookworm
MM_MIRROR = etc/apt/sources.list
# MM_OPTS  += --aptopt=etc/apt/apt.conf.d/99proxy
MM_OPTS  += --aptopt='Acquire::http { Proxy "http://localhost:13128"; }'
MM_OPTS  += --dpkgopt='path-exclude=/usr/share/man/*'
MM_OPTS  += --dpkgopt='path-exclude=/usr/share/doc/*'
# MM_OPTS  += --dpkgopt='path-include=/usr/share/doc/*/copyright'
MM_OPTS  += --dpkgopt='path-exclude=/usr/share/info/*'
MM_OPTS  += --dpkgopt='path-exclude=/usr/share/locale/*'
MM_OPTS  += --architectures=$(ARCH)
MM_OPTS  += --variant=minbase
# required
# minbase
# custom
MM_OPTS  += --setup-hook='mkdir -p "$$1"'
MM_OPTS  += --setup-hook='git checkout "$$1/.gitignore"'
MM_OPTS  += --customize-hook='echo $(APP) > "$$1/etc/hostname"'
MM_OPTS  += --customize-hook='git checkout "$$1/isolinux"'
# MM_OPTS  += --customize-hook='sync-in etc /etc'
# MM_OPTS  += --customize-hook='copy-in etc/network  /etc/network'
# MM_OPTS  += --customize-hook='copy-in etc/wpa_supplicant /etc/wpa_supplicant'
# MM_OPTS  += --include=libc6,libc-bin,dpkg,dash,busybox,base-files,base-passwd,debianutils
# MM_OPTS  += --include=coreutils,diffutils,mawk
# MM_OPTS  += --include=libacl1,libgcc-s1
# MM_OPTS  += --include=libc6,dash,bash
# MM_OPTS  += --include=dpkg,apt,debconf,passwd,mount,libpam0g
MM_OPTS  += --include=git,make,curl,mc,vim,less
MM_OPTS  += --include=live-boot,init,openssh-server
MM_OPTS  += --include=linux-image-$(DEB_ARCH),isolinux,syslinux,syslinux-common
MM_OPTS  += --include=firmware-linux-free,firmware-linux-nonfree
# adduser,findutils,
# grep,gzip,hostname,login,passwd
# nginx,squid,python3

.PHONY: deb
deb:
	$(MAKE) unchroot ; sudo rm -rf $(ROOT)
	sudo mmdebstrap $(MM_OPTS) $(MM_SUITE) $(ROOT) $(MM_MIRROR)
	sudo rm -rf \
		$(ROOT)/etc/apt/apt.conf.d/99* \
		$(ROOT)/etc/dpkg/dpkg.conf.d/99*
# $(ROOT)/etc/apt/sources.list.d/0000*

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

.PHONY: chroot unchroot
chroot:
	sudo mount -t proc  none $(ROOT)/proc
	sudo mount -t sysfs none $(ROOT)/sys
	sudo mount -o bind  /dev $(ROOT)/dev
	sudo chroot $(ROOT)
	$(MAKE) unchroot
unchroot:
	-sudo umount              $(ROOT)/proc
	-sudo umount              $(ROOT)/sys
	-sudo umount              $(ROOT)/dev

ISO = fw/$(APP)$(HW).iso
.PHONY: iso
iso: syslinux
	$(MAKE) unchroot
	sudo xorriso -as mkisofs -r -R -J \
		-joliet-long -l -V "$(APP)$(HW)" \
		-b /usr/lib/ISOLINUX/isolinux.bin -c isolinux/boot.cat -iso-level 3 \
		-no-emul-boot -partition_offset 16 -boot-load-size 4 \
		-boot-info-table -isohybrid-mbr root/usr/lib/ISOLINUX/isohdpfx.bin \
		-o $(ISO) $(ROOT)
	sudo chown `whoami` $(ISO)

.PHONY: qemu
qemu: $(ISO)
	$(QEMU) -m 1G -boot d -cdrom $<

.PHONY: syslinux
syslinux: \
	root/isolinux/libcom32.c32 \
	root/isolinux/reboot.c32 root/isolinux/poweroff.c32 \
	root/isolinux/ldlinux.c32 root/isolinux/linux.c32
	$(MAKE) root/isolinux/isolinux.cfg
root/isolinux/%: root/usr/lib/syslinux/modules/bios/%
	sudo cp $< $@
root/isolinux/isolinux.cfg: Makefile
	echo "DEFAULT boot" | sudo tee $@
	echo "LABEL   boot" | sudo tee -a $@
	echo "LINUX   /boot/vmlinuz-$(LINUX_VER)-$(DEB_ARCH)" | sudo tee -a $@
	echo "INITRD  /boot/initrd.img-$(LINUX_VER)-$(DEB_ARCH)" | sudo tee -a $@
	echo "APPEND  vga=ask" | sudo tee -a $@
	
root/isolinux/%: root/usr/lib/syslinux/modules/bios/%
	sudo cp $< $@
