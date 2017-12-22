#
# $Id$
#

CPPFLAGS+=-I$(SRC_DIR)/libsrc -I$(SRC_DIR)/libdb -I$(SRC_DIR)/libwww -I$(SRC_DIR)/libldap $(EXTRA_CPPFLAGS) -I$(POSTGRES_PREFIX)/include -I$(LDAP_PREFIX)
CFLAGS+=$(EXTRA_CFLAGS)

INSTALL_LDFLAGS=-L$(LIB_DIR) -R$(LIB_DIR) -Bdynamic -L$(POSTGRES_PREFIX)/lib -R$(POSTGRES_PREFIX)/lib -L$(LDAP_PREFIX)/lib -R$(LDAP_PREFIX)/lib
INSTALL_LIBS=-lobjc -lSBFoundation -lSBDatabaseKit -lSBWebComponents -lSBLDAPKit $(POSTGRES_LIBS) $(LDAP_LIBS)

BUILD_LDFLAGS=$(LDFLAGS) -L$(SRC_DIR)/libsrc -R$(SRC_DIR)/libsrc -L$(SRC_DIR)/libdb -R$(SRC_DIR)/libdb -L$(SRC_DIR)/libwww -R$(SRC_DIR)/libwww -L$(SRC_DIR)/libldap -R$(SRC_DIR)/libldap $(EXTRA_LDFLAGS) -Bdynamic -L$(POSTGRES_PREFIX)/lib -R$(POSTGRES_PREFIX)/lib -L$(LDAP_PREFIX)/lib -R$(LDAP_PREFIX)/lib
BUILD_LIBS=-lobjc -lSBFoundation -lSBDatabaseKit -lSBWebComponents -lSBLDAPKit $(POSTGRES_LIBS) $(LDAP_LIBS)

#

TARGET=libtest
OBJECTS=libtest.o
HEADERS=

#

default:: $(TARGET)

clean::
	@rm -rf $(OBJECTS) $(TARGET)
	
install:
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -o $(BIN_DIR)/$(TARGET) $(OBJECTS) $(INSTALL_LDFLAGS) $(INSTALL_LIBS)

#

$(TARGET): $(OBJECTS)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -o $(TARGET) $(OBJECTS) $(BUILD_LDFLAGS) $(BUILD_LIBS)

#

libtest.o: libtest.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c libtest.m

