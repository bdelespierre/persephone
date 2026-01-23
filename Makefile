.PHONY: test install uninstall

PREFIX ?= /usr/local
BINDIR := $(PREFIX)/bin

test:
	@bash tests/test_utils.sh
	@bash tests/test_lock.sh
	@bash tests/test_unlock.sh

install:
	@mkdir -p $(BINDIR)
	@cp bin/lock $(BINDIR)/lock
	@cp bin/unlock $(BINDIR)/unlock
	@chmod +x $(BINDIR)/lock $(BINDIR)/unlock
	@echo "Installed lock and unlock to $(BINDIR)"

uninstall:
	@rm -f $(BINDIR)/lock $(BINDIR)/unlock
	@echo "Removed lock and unlock from $(BINDIR)"
