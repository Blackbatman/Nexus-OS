# NEXUS-OS Stage A payload — ps5-payload-sdk build
# Targets: ps5 (needs PS5Payload SDK) · host-syntax (gcc syntax check, no SDK)

# --- configuration ----------------------------------------------------------
PS5SDK ?= $(PS5_PAYLOAD_SDK)
CC_PS5  := $(PS5SDK)/bin/clang
SYSROOT := $(PS5SDK)/ps5/sdk
BUILD   := build
ELF     := $(BUILD)/nexus_boot.elf

.PHONY: all ps5 host-syntax clean deploy

all: host-syntax

# Cross-build for the PS5 (FW userland, deployed via elfldr :9021)
ps5:
ifndef PS5SDK
	$(error PS5_PAYLOAD_SDK not set. Install https://github.com/ps5-payload-dev/sdk and: export PS5_PAYLOAD_SDK=/path)
endif
	mkdir -p $(BUILD)
	$(CC_PS5) --sysroot=$(SYSROOT) -O2 -Wall -Wextra -o $(ELF) nexus_boot.c \
		-lSDL2 -lc -lm

# Host syntax gate — this is what the beta team runs (no SDK needed)
host-syntax:
	mkdir -p $(BUILD)
	gcc -fsyntax-only -DNEXUS_NO_SDL -Wall -Wextra nexus_boot.c
	@echo "host-syntax OK"

deploy: $(ELF)
ifndef PS5_HOST
	$(error set PS5_HOST=<ps5 ip> (and PS5_PORT, default 9021))
endif
	curl -T $(ELF) ftp://$(PS5_HOST):$(NEXUS_FTP_PORT)/data/homebrew/nexus_boot.elf || \
	cui_setup $(PS5_HOST) $$( [ -n "$(PS5_PORT)" ] && echo $(PS5_PORT) || echo 9021 ) && \
	socat - TCP:$(PS5_HOST):$$( [ -n "$(PS5_PORT)" ] && echo $(PS5_PORT) || echo 9021 ) < $(ELF) \
	|| { echo "deploy: use ps5-payload-dev/ftpsrv (port 2121) to upload, elfldr (9021) to run"; exit 1; }

clean:
	rm -rf $(BUILD)
