# var
MODULE = $(notdir $(CURDIR))

# src
C += $(wildcard src/*.c*)
H += $(wildcard src/*.h*)
F += lib/$(MODULE).ini $(wildcard src/*.m)

# all
.PHONY: all
all:

# format
.PHONY: format
format: tmp/format_cpp
tmp/format_cpp: $(C) $(H)
	$(CF) $? && touch $@
