.PHONY: test install uninstall

PREFIX ?= $(HOME)/.local
BINDIR := $(PREFIX)/bin
LIBDIR := $(PREFIX)/lib

test:
	@bats tests/

install:
	@mkdir -p $(BINDIR)
	@mkdir -p $(LIBDIR)/persephone
	@cp bin/crypt $(BINDIR)/crypt
	@cp lib/persephone/utils.bash $(LIBDIR)/persephone/utils.bash
	@cp lib/persephone/crypt.bash $(LIBDIR)/persephone/crypt.bash
	@chmod +x $(BINDIR)/crypt
	@echo "Installed crypt to $(BINDIR)"
	@echo "Installed libs to $(LIBDIR)/persephone"

uninstall:
	@rm -f $(BINDIR)/crypt
	@rm -rf $(LIBDIR)/persephone
	@echo "Removed crypt from $(BINDIR)"
	@echo "Removed $(LIBDIR)/persephone"
