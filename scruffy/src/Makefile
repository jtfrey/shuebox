#
# Import SBFoundation stuff:
#
include /opt/local/SHUEBox/SBFoundation/lib/SBFoundation.make.inc
include /opt/local/SHUEBox/SBFoundation/lib/SBDatabaseKit.make.inc
include /opt/local/SHUEBox/SBFoundation/lib/SBZFSFilesystem.make.inc
include /opt/local/SHUEBox/SHUEBoxKit/lib/SHUEBoxKit.make.inc

PREFIX        = /opt/local/SHUEBox/scruffy
BIN_DIR       = $(PREFIX)/bin
LOG_DIR       = $(PREFIX)/var/log
RUN_DIR       = $(PREFIX)/var/run
WWW_DIR       = $(PREFIX)/www
SRC_DIR       = $(PREFIX)/src

export CC CPPFLAGS CFLAGS LD LDFLAGS LIBS OBJCFLAGS
export PREFIX BIN_DIR LOG_DIR RUN_DIR WWW_DIR SRC_DIR

CPPFLAGS      += -DLOG_DIR="\"$(LOG_DIR)\"" -DRUN_DIR="\"$(RUN_DIR)\""

TARGET        = scruffy
OBJECTS       = SBMaintenancePeriods.o \
                SBMaintenanceTask.o \
                  SBCollaborationMaintenanceTask.o \
                  SBRepositoryMaintenanceTask.o \
                  SBUsersMaintenanceTask.o \
                SBMaintenanceTaskManager.o \
                scruffy.o

default: $(TARGET)

clean:
	$(RM) $(OBJECTS) *.decl $(TARGET)

install: $(BIN_DIR)/$(TARGET) www_install

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(LOG_DIR):
	mkdir -p $(LOG_DIR)

$(RUN_DIR):
	mkdir -p $(RUN_DIR)

$(WWW_DIR):
	mkdir -p $(WWW_DIR)

$(BIN_DIR)/$(TARGET): $(BIN_DIR) $(LOG_DIR) $(RUN_DIR) $(TARGET)
	cp $(TARGET) $(BIN_DIR)/$(TARGET)

www_install:: $(WWW_DIR)
	$(MAKE) -C www install

##

$(TARGET): $(OBJECTS)
	$(CC) -o $(TARGET) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) $(OBJECTS) $(LDFLAGS) $(LIBS)

%.o: %.m
	$(CC) -c $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) $<

