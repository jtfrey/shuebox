#!/usr/bin/perl

while ( <> ) {
  if ( /^XXXXXXXXXX$/ ) {
    if ( $ENV{OS} ) {
      printf("#define OS %s\n", $ENV{OS});
    }
    if ( $ENV{PREFIX} ) {
      printf("#define PREFIX %s\n", $ENV{PREFIX});
    }
    if ( $ENV{BINDIR} ) {
      printf("#define BINDIR %s\n", $ENV{BINDIR});
    }
    if ( $ENV{NEED_STRDUP} ) {
      printf("#define NEED_STRDUP\n");
    }
    if ( $ENV{NEED_STRSEP} ) {
      printf("#define NEED_STRSEP\n");
    }
    if ( $ENV{NEED_FGETLN} ) {
      printf("#define NEED_FGETLN\n");
    }
  } else {
    print $_;
  }
}

