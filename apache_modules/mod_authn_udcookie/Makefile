#
# mod_authn_udcookie
#
# Makefile which builds/installs the UDCookie Apache access and
# authentication module.  Simply change the path to APACHE2 and
# you should be all set.
#
# $Id: Makefile 261 2009-11-10 17:42:11Z frey $
#

APACHE2=/opt/local/apache2/2.2

default::
	${APACHE2}/bin/apxs -c mod_authn_udcookie.c

install::
	${APACHE2}/bin/apxs -i -a -c mod_authn_udcookie.c

clean::
	rm -rf .libs/ *.la *.o *.lo *.slo *~	

