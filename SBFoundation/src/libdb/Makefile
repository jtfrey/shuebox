#
# $Id$
#

CPPFLAGS+=$(EXTRA_CPPFLAGS) -I$(SRC_DIR)/libsrc -I$(POSTGRES_PREFIX)/include
CFLAGS+=$(EXTRA_CFLAGS) 

INSTALL_LDFLAGS=-L$(LIB_DIR) -R$(LIB_DIR) -Bdynamic -L$(POSTGRES_PREFIX)/lib -R$(POSTGRES_PREFIX)/lib
INSTALL_LIBS=-lobjc -lSBFoundation $(POSTGRES_LIBS)

BUILD_LDFLAGS=$(LDFLAGS) -L$(SRC_DIR)/libsrc $(EXTRA_LDFLAGS) -L$(POSTGRES_PREFIX)/lib -R$(POSTGRES_PREFIX)/lib
BUILD_LIBS=$(LIBS) -lSBFoundation $(POSTGRES_LIBS)

#

LIBTARGET   = libSBDatabaseKit.so.1

LIBOBJECTS  = SBPostgres.o \
              SBPostgresAdditions.o \
              SBDatabaseObject.o
              
LIBHEADERS  = SBPostgres.h \
              SBDatabaseAccess.h \
              SBPostgresAdditions.h \
              SBDatabaseObject.h

##

default:: $(LIBTARGET)

clean::
	@rm -rf $(LIBTARGET) $(LIBOBJECTS)

install: default headers $(LIB_DIR)/$(LIBTARGET)
	@echo 'LDFLAGS := $$(LDFLAGS) -L$(POSTGRES_PREFIX)/lib -R$(POSTGRES_PREFIX)/lib' > $(LIB_DIR)/SBDatabaseKit.make.inc
	@echo 'LIBS    := $$(LIBS) -lSBDatabaseKit $(POSTGRES_LIBS)' >> $(LIB_DIR)/SBDatabaseKit.make.inc
	@echo 'CPPFLAGS:= $$(CPPFLAGS) -I$(POSTGRES_PREFIX)/include' >> $(LIB_DIR)/SBDatabaseKit.make.inc

headers: $(patsubst %.h,$(INCLUDE_DIR)/%.h,$(LIBHEADERS))

##

$(LIBTARGET): $(LIBHEADERS) $(LIBOBJECTS)
	$(CC) -o $(LIBTARGET) -shared -Wl,-h -Wl,$(LIBTARGET) $(LIBOBJECTS) $(BUILD_LDFLAGS) $(BUILD_LIBS)
	@rm -f libSBDatabaseKit.so
	@ln -s $(LIBTARGET) libSBDatabaseKit.so

$(LIB_DIR)/$(LIBTARGET): $(LIBTARGET)
	$(CC) -o $(LIB_DIR)/$(LIBTARGET) -shared -Wl,-h -Wl,$(LIBTARGET) $(LIBOBJECTS) $(INSTALL_LDFLAGS) $(INSTALL_LIBS)
	@rm -rf $(LIB_DIR)/libSBDatabaseKit.so
	@ln -s $(LIBTARGET) $(LIB_DIR)/libSBDatabaseKit.so

##

$(INCLUDE_DIR)/%.h: %.h
	@cp $< $@

##

SBPostgres.o: SBDatabaseAccess.h SBPostgresPrivate.h SBPostgres.h SBPostgres.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBPostgres.m

SBPostgresAdditions.o: SBPostgresPrivate.h SBPostgresAdditions.h SBPostgresAdditions.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBPostgresAdditions.m

SBDatabaseObject.o: SBDatabaseAccess.h SBDatabaseObject.h SBDatabaseObject.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBDatabaseObject.m

