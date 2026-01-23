.PHONY: test install uninstall

PREFIX ?= /usr/local
BINDIR := $(PREFIX)/bin
LIBDIR := $(PREFIX)/lib

test:
	@bash tests/test_utils.sh
	@bash tests/test_lock.sh
	@bash tests/test_unlock.sh

install:
	@mkdir -p $(BINDIR)
	@mkdir -p $(LIBDIR)/lockbox
	@cp bin/lock $(BINDIR)/lock
	@cp bin/unlock $(BINDIR)/unlock
	@cp lib/lockbox/utils.sh $(LIBDIR)/lockbox/utils.sh
	@chmod +x $(BINDIR)/lock $(BINDIR)/unlock
	@echo "Installed lock and unlock to $(BINDIR)"
	@echo "Installed utils.sh to $(LIBDIR)/lockbox"

uninstall:
	@rm -f $(BINDIR)/lock $(BINDIR)/unlock
	@rm -rf $(LIBDIR)/lockbox
	@echo "Removed lock and unlock from $(BINDIR)"
	@echo "Removed $(LIBDIR)/lockbox"
