#
# $Id$
#

CPPFLAGS+=$(EXTRA_CPPFLAGS) -I$(SRC_DIR)/libsrc
CFLAGS+=$(EXTRA_CFLAGS) 

INSTALL_LDFLAGS=-L$(LIB_DIR) -R$(LIB_DIR) -Bdynamic
INSTALL_LIBS=-lobjc -lSBFoundation

BUILD_LDFLAGS=$(LDFLAGS) -L$(SRC_DIR)/libsrc $(EXTRA_LDFLAGS)
BUILD_LIBS=$(LIBS) -lSBFoundation

#

LIBTARGET   = libSBWebComponents.so.1

LIBOBJECTS  = SBHTTP.o \
              SBHTTPCookie.o \
              SBCGI.o
              
LIBHEADERS  = SBHTTP.h \
              SBHTTPCookie.h \
              SBCGI.h

##

default:: $(LIBTARGET)

clean::
	@rm -rf $(LIBTARGET) $(LIBOBJECTS)

install: default headers $(LIB_DIR)/$(LIBTARGET)
	@echo 'LIBS    := $$(LIBS) -lSBWebComponents' > $(LIB_DIR)/SBWebComponents.make.inc

headers: $(patsubst %.h,$(INCLUDE_DIR)/%.h,$(LIBHEADERS))

##

$(LIBTARGET): $(LIBHEADERS) $(LIBOBJECTS)
	$(CC) -o $(LIBTARGET) -shared -Wl,-h -Wl,$(LIBTARGET) $(LIBOBJECTS) $(BUILD_LDFLAGS) $(BUILD_LIBS)
	@rm -f libSBWebComponents.so
	@ln -s $(LIBTARGET) libSBWebComponents.so

$(LIB_DIR)/$(LIBTARGET): $(LIBTARGET)
	$(CC) -o $(LIB_DIR)/$(LIBTARGET) -shared -Wl,-h -Wl,$(LIBTARGET) $(LIBOBJECTS) $(INSTALL_LDFLAGS) $(INSTALL_LIBS)
	@rm -rf $(LIB_DIR)/libSBWebComponents.so
	@ln -s $(LIBTARGET) $(LIB_DIR)/libSBWebComponents.so

##

$(INCLUDE_DIR)/%.h: %.h
	@cp $< $@

##

SBHTTP.o: SBHTTP.h SBHTTP.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBHTTP.m

SBHTTPCookie.o: SBHTTPCookie.h SBHTTPCookie.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBHTTPCookie.m

SBCGI.o: SBCGI.h SBCGI.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBCGI.m

