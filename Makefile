.PHONY: all

all: .merlin

.merlin: pds.conf
	touch dune dune-project dune-workspace
	pds -f | merlin-of-pds > .merlin

pds.mk: pds.conf $(wildcard src/*/*) $(wildcard tests/*/*)
	pds

-include pds.mk
