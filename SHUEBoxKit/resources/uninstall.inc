#
# Resource uninstaller scripts should source this file before
# executing, e.g.
#
#   source ../uninstall-inc
#
# $Id: uninstall.inc,v 1.1 2009/09/01 14:32:10 frey Exp $
#

INSTALL_PREFIX=$1/$2

source ../base.inc

uninstall_cleanup()
{
  if [ -d "$INSTALL_PREFIX" ]; then
    $RM -rf $INSTALL_PREFIX/*
    exit $?
  fi
}

# Initial setup -- make sure the target exists:
if [ ! -d "$INSTALL_PREFIX" ]; then
  exit 1 
fi

