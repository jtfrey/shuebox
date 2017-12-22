#
# $Id$
#

CPPFLAGS+=$(EXTRA_CPPFLAGS)
CFLAGS+=$(EXTRA_CFLAGS) 
LDFLAGS+=$(EXTRA_LDFLAGS)

#

LIBTARGET   = libSBFoundation.so.1
LIBOBJECTS  = SBObject.o \
              SBAutoreleasePool.o \
              SBLock.o \
              SBThread.o \
              SBException.o \
              SBKeyValueCoding.o \
              SBMemoryPool.o \
              SBError.o \
              SBData.o \
              SBString.o \
              SBScanner.o \
              SBDate.o \
              SBCalendar.o \
              SBValue.o \
              SBDateFormatter.o \
              SBNumberFormatter.o \
              SBEnumerator.o \
              SBArray.o \
              SBDictionary.o \
              SBOrderedSet.o \
              SBNotification.o \
              SBLocale.o \
              SBTimeZone.o \
              SBRegularExpression.o \
              SBCharacterSet.o \
              SBInetAddress.o \
              SBHost.o \
              SBMACAddress.o \
              SBUUID.o \
              SBNotorization.o \
              SBMailer.o \
              SBURL.o \
              SBMD5Digest.o \
              SBFileManager.o \
              SBFileHandle.o \
              SBUser.o \
              SBObjectCache.o \
              SBStream.o \
              SBTimer.o \
              SBRunLoop.o \
              SBXMLNode.o \
              SBXMLElement.o \
              SBXMLDocument.o \
              SBXMLParser.o \
              SBXMLInternalParser.o \
              SBLogger.o \
              SBTask.o \
              SBPIDFile.o \
              SBPropertyList.o

              
LIBHEADERS  = config.h \
              SBFoundation.h \
              SBObject.h \
              SBAutoreleasePool.h \
              SBLock.h \
              SBThread.h \
              SBException.h \
              SBKeyValueCoding.h \
              SBMemoryPool.h \
              SBError.h \
              SBData.h \
              SBString.h \
              SBScanner.h \
              SBDate.h \
              SBCalendar.h \
              SBValue.h \
              SBDateFormatter.h \
              SBNumberFormatter.h \
              SBEnumerator.h \
              SBArray.h \
              SBDictionary.h \
              SBOrderedSet.h \
              SBNotification.h \
              SBLocale.h \
              SBTimeZone.h \
              SBRegularExpression.h \
              SBCharacterSet.h \
              SBInetAddress.h \
              SBHost.h \
              SBMACAddress.h \
              SBUUID.h \
              SBNotorization.h \
              SBMailer.h \
              SBURL.h \
              SBMD5Digest.h \
              SBFileManager.h \
              SBFileHandle.h \
              SBUser.h \
              SBObjectCache.h \
              SBStream.h \
              SBTimer.h \
              SBRunLoop.h \
              SBXMLNode.h \
              SBXMLElement.h \
              SBXMLDocument.h \
              SBXMLParser.h \
              SBLogger.h \
              SBTask.h \
              SBPIDFile.h \
              SBPropertyList.h

##

default:: $(LIBTARGET)

clean::
	@rm -rf $(LIBOBJECTS) $(LIBTARGET) config.h config.status

install: default headers $(LIB_DIR)/$(LIBTARGET)
	@echo "CC       = $(CC)" > $(LIB_DIR)/SBFoundation.make.inc
	@echo "CPPFLAGS = $(CPPFLAGS) -I$(INCLUDE_DIR)" >> $(LIB_DIR)/SBFoundation.make.inc
	@echo "CFLAGS   = $(CFLAGS)" >> $(LIB_DIR)/SBFoundation.make.inc
	@echo "OBJCFLAGS= $(OBJCFLAGS)" >> $(LIB_DIR)/SBFoundation.make.inc
	@echo "LDFLAGS  = $(LDFLAGS) -L$(LIB_DIR) -R$(LIB_DIR) -Bdynamic" >> $(LIB_DIR)/SBFoundation.make.inc
	@echo "LIBS     = $(LIBS) -lSBFoundation" >> $(LIB_DIR)/SBFoundation.make.inc

headers: $(patsubst %.h,$(INCLUDE_DIR)/%.h,$(LIBHEADERS))

##

$(LIBTARGET): $(LIBOBJECTS)
	$(CC) -o $(LIBTARGET) -shared -Wl,-h -Wl,$(LIBTARGET) $(LIBOBJECTS) $(LDFLAGS) $(LIBS)
	@rm -f libSBFoundation.so
	@ln -s $(LIBTARGET) libSBFoundation.so

$(LIB_DIR)/$(LIBTARGET): $(LIBTARGET)
	$(CC) -o $(LIB_DIR)/$(LIBTARGET) -shared -Wl,-h -Wl,$(LIBTARGET) $(LIBOBJECTS) $(LDFLAGS) $(LIBS)
	@rm -rf $(LIB_DIR)/libSBFoundation.so
	@ln -s $(LIBTARGET) $(LIB_DIR)/libSBFoundation.so

##

$(INCLUDE_DIR)/%.h: %.h
	@cp $< $@

##

config.h: config.h.in config.status
	@cat config.h.in | $(SRC_DIR)/utils/config.pl > config.h

config.status:
	@echo "Generating config.h..." > config.status

##

SBObject.o: config.h SBArray.h SBObject.h SBObject.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBObject.m

SBAutoreleasePool.o: config.h SBAutoreleasePool.h SBAutoreleasePool.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBAutoreleasePool.m

SBLock.o: config.h SBLock.h SBLock.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBLock.m

SBThread.o: config.h SBThread.h SBThread.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBThread.m

SBException.o: config.h SBException.h SBException.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBException.m

SBKeyValueCoding.o: config.h SBObject.h SBKeyValueCoding.h SBKeyValueCoding.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBKeyValueCoding.m

SBMemoryPool.o: config.h SBObject.h SBMemoryPool.h SBMemoryPool.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBMemoryPool.m

SBError.o: SBError.h SBError.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBError.m

SBEnumerator.o: config.h SBArray.h SBEnumerator.h SBEnumerator.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBEnumerator.m

SBData.o: config.h SBObject.h SBData.h SBData.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBData.m

SBString.o: config.h SBObject.h SBString.h SBString.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBString.m

SBScanner.o: config.h SBObject.h SBString.h SBScanner.h SBScanner.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBScanner.m

SBValue.o: config.h SBObject.h SBValue.h SBValue.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBValue.m

SBDate.o: config.h SBObject.h SBDate.h SBDate.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBDate.m

SBCalendar.o: config.h SBObject.h SBDate.h SBCalendar.h SBCalendar.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBCalendar.m

SBDateFormatter.o: config.h SBObject.h SBString.h SBDate.h SBDateFormatter.h SBDateFormatter.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBDateFormatter.m

SBNumberFormatter.o: config.h SBObject.h SBString.h SBNumberFormatter.h SBNumberFormatter.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBNumberFormatter.m

SBArray.o: config.h SBObject.h SBArray.h SBArray.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBArray.m

SBDictionary.o: config.h SBObject.h SBDictionary.h SBDictionary.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBDictionary.m

SBOrderedSet.o: config.h SBObject.h SBArray.h SBOrderedSet.h SBOrderedSet.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBOrderedSet.m

SBNotification.o: config.h SBObject.h SBNotification.h SBNotification.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBNotification.m

SBRegularExpression.o: config.h SBObject.h SBString.h SBRegularExpression.h SBRegularExpression.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBRegularExpression.m

SBLocale.o: config.h SBObject.h SBLocale.h SBLocale.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBLocale.m

SBTimeZone.o: config.h SBObject.h SBTimeZone.h SBTimeZone.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBTimeZone.m

SBCharacterSet.o: config.h SBObject.h SBString.h SBCharacterSet.h SBCharacterSet.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBCharacterSet.m

SBInetAddress.o: config.h SBObject.h SBString.h SBInetAddress.h SBInetAddress.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBInetAddress.m

SBHost.o: config.h SBObject.h SBString.h SBInetAddress.h SBHost.h SBHost.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBHost.m

SBMACAddress.o: config.h SBObject.h SBString.h SBMACAddress.h SBMACAddress.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBMACAddress.m

SBUUID.o: config.h SBObject.h SBString.h SBUUID.h SBUUID.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBUUID.m

SBNotorization.o: config.h SBObject.h SBString.h SBHost.h SBDate.h SBNotorization.h SBNotorization.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBNotorization.m

SBMailer.o: config.h SBObject.h SBString.h SBHost.h SBMailer.h SBMailer.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBMailer.m

SBURL.o: config.h SBObject.h SBString.h SBData.h SBURL.h SBURL.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBURL.m

SBMD5Digest.o: config.h SBObject.h SBString.h SBData.h SBMD5Digest.h SBMD5Digest.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBMD5Digest.m

SBFileManager.o: config.h SBObject.h SBString.h SBData.h SBFileManager.h SBFileManager.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBFileManager.m

SBFileHandle.o: config.h SBObject.h SBString.h SBData.h SBFileHandle.h SBFileHandle.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBFileHandle.m

SBUser.o: config.h SBObject.h SBString.h SBDictionary.h SBUser.h SBUser.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBUser.m

SBObjectCache.o: config.h SBObject.h SBString.h SBDictionary.h SBObjectCache.h SBObjectCache.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBObjectCache.m

SBStream.o: config.h SBObject.h SBStream.h SBStream.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBStream.m

SBTimer.o: config.h SBObject.h SBTimer.h SBTimer.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBTimer.m

SBRunLoop.o: config.h SBObject.h SBThread.h SBTimer.h SBRunLoop.h SBRunLoop.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBRunLoop.m

SBXMLNode.o: config.h SBObject.h SBXMLNode.h SBXMLNodePrivate.h SBXMLNode.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBXMLNode.m

SBXMLElement.o: config.h SBObject.h SBXMLNode.h SBXMLNodePrivate.h SBXMLElement.h SBXMLElement.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBXMLElement.m

SBXMLDocument.o: config.h SBObject.h SBXMLNode.h SBXMLNodePrivate.h SBXMLElement.h \
                 SBXMLDocument.h SBXMLDocument.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBXMLDocument.m

SBXMLParser.o: config.h SBObject.h SBXMLParser.h SBXMLParser.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBXMLParser.m

SBXMLInternalParser.o: config.h SBObject.h SBXMLParser.h SBXMLNode.h SBXMLElement.h \
                       SBXMLDocument.h SBXMLInternalParser.h SBXMLInternalParser.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBXMLInternalParser.m

SBLogger.o: config.h SBObject.h SBString.h SBStream.h SBLogger.h SBLogger.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBLogger.m

SBPIDFile.o: config.h SBPIDFile.h SBPIDFile.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBPIDFile.m

SBTask.o: config.h SBTask.h SBTask.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBTask.m

SBPropertyList.o: config.h SBPropertyList.h SBPropertyList.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -c SBPropertyList.m

