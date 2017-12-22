APACHE2=/opt/local/apache2/2.2

default::
	${APACHE2}/bin/apxs -c mod_authnz_shuebox.c

install::
	${APACHE2}/bin/apxs -i -a -c mod_authnz_shuebox.c

clean::
	rm -rf .libs/ *.la *.o *.lo *.slo *~

