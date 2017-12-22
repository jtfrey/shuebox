#
# Resource installer scripts should source this file before
# executing, e.g.
#
#   source ../install-inc
#
# $Id: install.inc,v 1.1 2009/09/01 14:32:07 frey Exp $
#

INSTALL_PREFIX=$1/$2

source ../base.inc

install_cleanup()
{
  if [ -d "$INSTALL_PREFIX" ]; then
    $CHOWN -hR webservd:webservd $INSTALL_PREFIX
    exit $?
  fi
}

# Initial setup -- make sure the target exists:
if [ ! -d "$INSTALL_PREFIX" ]; then
  $MKDIR -p $INSTALL_PREFIX &> /dev/null
  if [ $? -ne 0 ]; then
    exit $?
  fi
  $CHMOD 770 $INSTALL_PREFIX &> /dev/null
  $CHMOD g+s $INSTALL_PREFIX &> /dev/null
fi

