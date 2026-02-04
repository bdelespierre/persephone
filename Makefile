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
	@mkdir -p $(LIBDIR)/persephone
	@cp bin/lock $(BINDIR)/lock
	@cp bin/unlock $(BINDIR)/unlock
	@cp lib/persephone/utils.sh $(LIBDIR)/persephone/utils.sh
	@chmod +x $(BINDIR)/lock $(BINDIR)/unlock
	@echo "Installed lock and unlock to $(BINDIR)"
	@echo "Installed utils.sh to $(LIBDIR)/persephone"

uninstall:
	@rm -f $(BINDIR)/lock $(BINDIR)/unlock
	@rm -rf $(LIBDIR)/persephone
	@echo "Removed lock and unlock from $(BINDIR)"
	@echo "Removed $(LIBDIR)/persephone"
