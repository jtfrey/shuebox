#
# Import SHUEBoxKit stuff:
#
include /opt/local/SHUEBox/SHUEBoxKit/lib/SHUEBoxKit.make.inc

PREFIX          = /opt/local/SHUEBox/cgi
BIN_DIR         = $(PREFIX)/bin
LOG_DIR         = $(PREFIX)/var/log

TARGETS         = userdata \
                  login \
                  collab_metadata \
                  demo

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


