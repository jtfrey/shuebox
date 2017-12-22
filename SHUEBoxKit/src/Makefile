#
# Import SBFoundation stuff:
#
include /opt/local/SHUEBox/SBFoundation/lib/SBFoundation.make.inc
include /opt/local/SHUEBox/SBFoundation/lib/SBDatabaseKit.make.inc
include /opt/local/SHUEBox/SBFoundation/lib/SBZFSFilesystem.make.inc
include /opt/local/SHUEBox/SBFoundation/lib/SBLDAPKit.make.inc
include /opt/local/SHUEBox/SBFoundation/lib/SBWebComponents.make.inc

PREFIX=/opt/local/SHUEBox/SHUEBoxKit
BIN_DIR=$(PREFIX)/bin
ETC_DIR=$(PREFIX)/etc
LIB_DIR=$(PREFIX)/lib
INCLUDE_DIR=$(PREFIX)/include
SRC_DIR=$(PREFIX)/src
export PREFIX
export BIN_DIR
export ETC_DIR
export LIB_DIR
export INCLUDE_DIR
export SRC_DIR

TARGET       = libSHUEBoxKit.so.1
OBJECTS      = SHUEBox.o \
               SHUEBoxPathManager.o \
               SHUEBoxApacheManager.o \
               SHUEBoxAuthCookie.o \
               SHUEBoxRole.o \
               SHUEBoxUser.o \
               SHUEBoxCollaboration.o \
               SHUEBoxRepository.o \
               SHUEBoxWebRepository.o \
               SHUEBoxDAVRepository.o \
               SHUEBoxSVNRepository.o \
               SHUEBoxGITRepository.o \
               SHUEBoxDictionary.o \
               SHUEBoxCGI.o

HEADERS      = SHUEBox.h \
               SHUEBoxPathManager.h \
               SHUEBoxApacheManager.h \
               SHUEBoxAuthCookie.h \
               SHUEBoxCollaboration.h \
               SHUEBoxRepository.h \
               SHUEBoxWebRepository.h \
               SHUEBoxDAVRepository.h \
               SHUEBoxSVNRepository.h \
               SHUEBoxGITRepository.h \
               SHUEBoxUser.h \
               SHUEBoxRole.h \
               SHUEBoxDictionary.h \
               SHUEBoxCGI.h

CPPFLAGS    += -DSHUEBOXKIT_PATHMAP='@"'$(ETC_DIR)/paths.strpairs'"'

##

default:: $(TARGET)

clean:
	@rm -rf $(OBJECTS) $(TARGET) libSHUEBoxKit.so *.decl

install: default $(BIN_DIR) $(ETC_DIR) $(LIB_DIR) $(INCLUDE_DIR) headers $(LIB_DIR)/$(TARGET)
	@cp -f paths.strpairs $(ETC_DIR)
	@echo "CC        := $(CC)" > $(LIB_DIR)/SHUEBoxKit.make.inc
	@echo "CFLAGS    := $(CFLAGS)" >> $(LIB_DIR)/SHUEBoxKit.make.inc
	@echo "OBJCFLAGS := $(OBJCFLAGS)" >> $(LIB_DIR)/SHUEBoxKit.make.inc
	@echo "CPPFLAGS  := $(CPPFLAGS) -I$(INCLUDE_DIR)" >> $(LIB_DIR)/SHUEBoxKit.make.inc
	@echo "LDFLAGS   := $(LDFLAGS) -L$(LIB_DIR) -R$(LIB_DIR)" >> $(LIB_DIR)/SHUEBoxKit.make.inc
	@echo "LIBS      := $(LIBS) -lSHUEBoxKit" >> $(LIB_DIR)/SHUEBoxKit.make.inc

headers: $(patsubst %.h,$(INCLUDE_DIR)/%.h,$(HEADERS))

##

$(TARGET): $(OBJECTS)
	$(CC) -o $(TARGET) -shared -Wl,-h -Wl,$(TARGET) $(OBJECTS) $(LDFLAGS) $(LIBS)
	@rm -f libSHUEBoxKit.so
	@ln -s $(TARGET) libSHUEBoxKit.so

$(LIB_DIR)/$(TARGET): $(TARGET)
	$(CC) -o $(LIB_DIR)/$(TARGET) -shared -Wl,-h -Wl,$(TARGET) $(OBJECTS) $(LDFLAGS) $(LIBS)
	@rm -rf $(LIB_DIR)/libSHUEBoxKit.so
	@ln -s $(TARGET) $(LIB_DIR)/libSHUEBoxKit.so

##

%.o: %.m
	$(CC) -c $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) $<

##

$(INCLUDE_DIR)/%.h: %.h
	@cp $< $@

##

$(BIN_DIR):
	@mkdir -p $(BIN_DIR)

$(ETC_DIR):
	@mkdir -p $(ETC_DIR)

$(LIB_DIR):
	@mkdir -p $(LIB_DIR)

$(INCLUDE_DIR):
	@mkdir -p $(INCLUDE_DIR)

test: test.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -o test.exe test.m $(OBJECTS) $(LDFLAGS) $(LIBS)

