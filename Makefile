EXTENSION  = pg_dbms_metadata
EXTVERSION = $(shell grep default_version $(EXTENSION).control | \
		sed -e "s/default_version[[:space:]]*=[[:space:]]*'\([^']*\)'/\1/")

PGFILEDESC = "pg_dbms_metadata - Propose Oracle DBMS_METADATA compatibility for PostgreSQL"

PG_CONFIG = pg_config
PG91 = $(shell $(PG_CONFIG) --version | egrep " 8\.| 9\.0" > /dev/null && echo no || echo yes)

ifeq ($(PG91),yes)
DOCS = $(wildcard README*)

DATA = $(wildcard updates/*--*.sql) sql/$(EXTENSION)--$(EXTVERSION).sql
else
$(error Minimum version of PostgreSQL required is 9.1.0)
endif

PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

installcheck:
	$(PROVE)
