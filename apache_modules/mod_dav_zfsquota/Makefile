APACHE2_HOME=/opt/local/apache2/2.2

shared:
	${APACHE2_HOME}/bin/apxs -i -a -c -lzfs mod_dav_zfsquota.c

clean:
	rm -rf .libs/ *.la *.o *.lo *.slo *~	
