#
# $Id$
#

PREFIX=/opt/local/SHUEBox/SBFoundation
BIN_DIR=$(PREFIX)/bin
LIB_DIR=$(PREFIX)/lib
INCLUDE_DIR=$(PREFIX)/include
SRC_DIR=$(PREFIX)/src
export PREFIX
export BIN_DIR
export LIB_DIR
export INCLUDE_DIR
export SRC_DIR

# Currently:	(BSD|SOLARIS)
OS=SOLARIS
export OS

# Where is GCC 4?
GCC_PREFIX=/opt/local/gcc/4.1.2
export GCC_PREFIX

# Where is SQLite3?
SQLITE_PREFIX=/opt/local/sqlite/3
export SQLITE_PREFIX
SQLITE_LIBS=-lsqlite3
export SQLITE_LIBS

# Where is Postgres?
POSTGRES_PREFIX=/opt/local/postgres/9.3
export POSTGRES_PREFIX
POSTGRES_LIBS=-lpq
export POSTGRES_LIBS

# IBM ICU libraries:
ICU_PREFIX=/opt/local/icu/4.0
export ICU_PREFIX
ICU_LIBS=-licudata -licui18n -licuio -licutu -licuuc

#-licudata -licuio -licule -liculx -licutoolutil -licutu -licuuc
export ICU_LIBS

# libcURL:
CURL_PREFIX=/opt/local/curl/7.19.5
export CURL_PREFIX
CURL_LIBS=-lcurl
export CURL_LIBS

# LDAP:
LDAP_PREFIX=/opt/local/openldap/2.4
export LDAP_PREFIX
LDAP_LIBS=-lldap 
export LDAP_LIBS

# Expat:
EXPAT_PREFIX=/opt/local/expat/2.0.1-UTF16
export EXPAT_PREFIX
EXPAT_LIBS=-lexpat
export EXPAT_LIBS

ifeq ($(OS),SOLARIS)
  NEED_STRDUP=1
  NEED_STRSEP=1
  NEED_FGETLN=1
  
  CC=$(GCC_PREFIX)/bin/gcc -O3

  EXTRA_CPPFLAGS=-D_STRPTIME_DONTZERO -DSBMemoryPoolAlignedAlloc=8 -DICU_4
  export EXTRA_CPPFLAGS

  EXTRA_LDFLAGS=-R$(GCC_PREFIX)/lib -lm -luuid -lmd5 -lrt -pthread
  export EXTRA_LDFLAGS
else
  NEED_STRDUP=0
  NEED_STRSEP=0
  NEED_FGETLN=0
  
  CC=gcc
endif

export CC
export NEED_STRDUP NEED_STRSEP NEED_FGETLN

##

CPPFLAGS          = -DSBPREFIX=\"$(PREFIX)\" -D$(OS) \
                    -DWANT_EXTENDED_SBMACADDRESS \
                    -I$(ICU_PREFIX)/include \
                    -I$(SQLITE_PREFIX)/include \
                    -I$(CURL_PREFIX)/include \
                    -I$(EXPAT_PREFIX)/include
export CPPFLAGS

CFLAGS            = -g -fPIC
export CFLAGS

OBJCFLAGS	  = -fconstant-string-class=SBStringConst -gen-decls
export OBJCFLAGS

LIBS              = -L$(ICU_PREFIX)/lib $(ICU_LIBS) -R$(ICU_PREFIX)/lib \
                    -L$(SQLITE_PREFIX)/lib $(SQLITE_LIBS) -R$(SQLITE_PREFIX)/lib \
                    -L$(CURL_PREFIX)/lib $(CURL_LIBS) -R$(CURL_PREFIX)/lib \
                    -L$(EXPAT_PREFIX)/lib $(EXPAT_LIBS) -R$(EXPAT_PREFIX)/lib \
                    -lnsl -lsocket -lobjc
export LIBS

####

SUBPROJ=libsrc libdb libzfs libwww libldap libtest

default::$(SUBPROJ)
	
install:: default $(BIN_DIR) $(LIB_DIR) $(INCLUDE_DIR)
	@for proj in $(SUBPROJ); do \
		(cd $$proj; $(MAKE) install); \
	done

clean::
	@for proj in $(SUBPROJ); do \
		(cd $$proj; $(MAKE) clean); \
	done

libsrc::
	@(cd libsrc; $(MAKE))

libdb::
	@(cd libdb; $(MAKE))

libzfs::
	@(cd libzfs; $(MAKE))

libwww::
	@(cd libwww; $(MAKE))

libldap::
	@(cd libldap; $(MAKE))

libtest::
	@(cd libtest; $(MAKE))

$(BIN_DIR):
	@mkdir -p $(BIN_DIR)

$(LIB_DIR):
	@mkdir -p $(LIB_DIR)

$(INCLUDE_DIR):
	@mkdir -p $(INCLUDE_DIR)


