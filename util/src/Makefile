#
# Import SHUEBoxKit stuff:
#
include /opt/local/SHUEBox/SHUEBoxKit/lib/SHUEBoxKit.make.inc

PREFIX          = /opt/local/SHUEBox/util
BIN_DIR         = $(PREFIX)/bin
LOG_DIR         = $(PREFIX)/var/log

TARGETS         = useradd-native \
                  userlookup

CPPFLAGS        += -DLOG_DIR="\"$(LOG_DIR)\""

default:: $(TARGETS)

clean::
	$(RM) $(TARGETS)

install: $(TARGETS) $(BIN_DIR) $(LOG_DIR)
	cp -f $(TARGETS) $(BIN_DIR)

$(BIN_DIR)::
	mkdir -p $(BIN_DIR)

$(LOG_DIR)::
	mkdir -p $(LOG_DIR)

% : %.m
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) $^ -o $@ $(LDFLAGS) $(LIBS)


