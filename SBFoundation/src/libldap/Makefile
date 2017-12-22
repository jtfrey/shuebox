#
# $Id$
#

CPPFLAGS+=$(EXTRA_CPPFLAGS) -I$(SRC_DIR)/libsrc -I$(LDAP_PREFIX)/include
CFLAGS+=$(EXTRA_CFLAGS) 

INSTALL_LDFLAGS=-L$(LIB_DIR) -R$(LIB_DIR) -Bdynamic -L$(LDAP_PREFIX)/lib -R$(LDAP_PREFIX)/lib
INSTALL_LIBS=-lobjc -lSBFoundation $(LDAP_LIBS)

BUILD_LDFLAGS=$(LDFLAGS) -L$(SRC_DIR)/libsrc $(EXTRA_LDFLAGS) -L$(LDAP_PREFIX)/lib -R$(LDAP_PREFIX)/lib
BUILD_LIBS=$(LIBS) -lSBFoundation $(LDAP_LIBS)

#

LIBTARGET   = libSBLDAPKit.so.1

LIBOBJECTS  = SBLDAP.o \
              SBUDUser.o
              
LIBHEADERS  = SBLDAP.h \
              SBUDUser.h

##

default:: $(LIBTARGET)

clean::
	@rm -rf $(LIBTARGET) $(LIBOBJECTS)

install: default headers $(LIB_DIR)/$(LIBTARGET)
	@echo 'LDFLAGS := $$(LDFLAGS) -L$(LDAP_PREFIX)/lib -R$(LDAP_PREFIX)/lib' > $(LIB_DIR)/SBLDAPKit.make.inc
	@echo 'LIBS    := $$(LIBS) -lSBLDAPKit $(LDAP_LIBS)' >> $(LIB_DIR)/SBLDAPKit.make.inc
	@echo 'CPPFLAGS:= $$(CPPFLAGS) -I$(LDAP_PREFIX)/include' >> $(LIB_DIR)/SBLDAPKit.make.inc

headers: $(patsubst %.h,$(INCLUDE_DIR)/%.h,$(LIBHEADERS))

##

$(LIBTARGET): $(LIBHEADERS) $(LIBOBJECTS)
	$(CC) -o $(LIBTARGET) -shared -Wl,-h -Wl,$(LIBTARGET) $(LIBOBJECTS) $(BUILD_LDFLAGS) $(BUILD_LIBS)
	@rm -f libSBLDAPKit.so
	@ln -s $(LIBTARGET) libSBLDAPKit.so

$(LIB_DIR)/$(LIBTARGET): $(LIBTARGET)
	$(CC) -o $(LIB_DIR)/$(LIBTARGET) -shared -Wl,-h -Wl,$(LIBTARGET) $(LIBOBJECTS) $(INSTALL_LDFLAGS) $(INSTALL_LIBS)
	@rm -rf $(LIB_DIR)/libSBLDAPKit.so
	@ln -s $(LIBTARGET) $(LIB_DIR)/libSBLDAPKit.so

##

$(INCLUDE_DIR)/%.h: %.h
	@cp $< $@

##

SBLDAP.o: SBLDAP.h SBLDAP.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBLDAP.m

SBUDUser.o: SBLDAP.h SBUDUser.h SBUDUser.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBUDUser.m

