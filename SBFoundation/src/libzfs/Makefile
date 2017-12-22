#
# $Id$
#

CPPFLAGS+=$(EXTRA_CPPFLAGS) -I$(SRC_DIR)/libsrc
CFLAGS+=$(EXTRA_CFLAGS) 

INSTALL_LDFLAGS=-L$(LIB_DIR) -R$(LIB_DIR) -Bdynamic
INSTALL_LIBS=-lobjc -lzfs -lnvpair -lSBFoundation

BUILD_LDFLAGS=$(LDFLAGS) -L$(SRC_DIR)/libsrc $(EXTRA_LDFLAGS)
BUILD_LIBS=$(LIBS) -lzfs -lnvpair -lSBFoundation

#

LIBTARGET   = libSBZFSFilesystem.so.1

LIBOBJECTS  = SBZFSFilesystem.o
              
LIBHEADERS  = SBZFSFilesystem.h

##

default:: $(LIBTARGET)

clean::
	@rm -rf $(LIBTARGET) $(LIBOBJECTS)

install: default headers $(LIB_DIR)/$(LIBTARGET)
	@echo 'LIBS    := $$(LIBS) -lSBZFSFilesystem -lzfs -lnvpair' > $(LIB_DIR)/SBZFSFilesystem.make.inc

headers: $(patsubst %.h,$(INCLUDE_DIR)/%.h,$(LIBHEADERS))

##

$(LIBTARGET): $(LIBHEADERS) $(LIBOBJECTS)
	$(CC) -o $(LIBTARGET) -shared -Wl,-h -Wl,$(LIBTARGET) $(LIBOBJECTS) $(BUILD_LDFLAGS) $(BUILD_LIBS)
	@rm -f libSBZFSFilesystem.so
	@ln -s $(LIBTARGET) libSBZFSFilesystem.so

$(LIB_DIR)/$(LIBTARGET): $(LIBTARGET)
	$(CC) -o $(LIB_DIR)/$(LIBTARGET) -shared -Wl,-h -Wl,$(LIBTARGET) $(LIBOBJECTS) $(INSTALL_LDFLAGS) $(INSTALL_LIBS)
	@rm -rf $(LIB_DIR)/libSBZFSFilesystem.so
	@ln -s $(LIBTARGET) $(LIB_DIR)/libSBZFSFilesystem.so

##

$(INCLUDE_DIR)/%.h: %.h
	@cp $< $@

##

SBZFSFilesystem.o: SBZFSFilesystem.h SBZFSFilesystem.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBZFSFilesystem.m

