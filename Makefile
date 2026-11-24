.DEFAULT_GOAL := help

RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
CYAN := \033[0;36m
DIM := \033[2m
NC := \033[0m

SHELL := bash
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

.PHONY: help doctor install uninstall

help:
	@printf "\n$(CYAN)statuslines$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  Status lines para $(BLUE)Cursor$(NC) y $(BLUE)agy$(NC). Se instalan bajo \$$HOME.\n\n"
	@printf "$(YELLOW)Acciones$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • ver este menú:        $(BLUE)make$(NC)\n"
	@printf "  • revisar el entorno:   $(BLUE)make doctor$(NC)\n"
	@printf "  • instalar:             $(BLUE)make install$(NC)\n"
	@printf "  • quitar:               $(BLUE)make uninstall$(NC)\n\n"

doctor:
	@bash "$(ROOT)/scripts/install.sh" doctor

install:
	@bash "$(ROOT)/scripts/install.sh" install

uninstall:
	@bash "$(ROOT)/scripts/install.sh" uninstall
