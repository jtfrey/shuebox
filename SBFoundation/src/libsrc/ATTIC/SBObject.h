//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBObject.h
//
// Base class for the package.  We augment Object, we don't replace
// it.
//
// $Id$
//

#import <objc/Object.h>

#include "config.h"

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <ctype.h>
#include <unistd.h>
#include <stdarg.h>
#include <math.h>
#include <errno.h>
#include <signal.h>
#include <fcntl.h>
#include <getopt.h>
#include <pwd.h>
#include <grp.h>

#ifdef SOLARIS
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <sys/stat.h>
#endif

#define SBNotFound ((unsigned int)-1)

typedef enum {
  SBOrderDescending = -1,
  SBOrderSame = 0,
  SBOrderAscending = 1
} SBComparisonResult;

typedef struct {
  unsigned int    start;
  unsigned int    length;
} SBRange;

extern SBRange SBEmptyRange;

static inline SBRange SBRangeCreate(
  unsigned int    start,
  unsigned int    length
)
{
  SBRange   newRange = { start , length };
  return newRange;
}

static inline unsigned int SBRangeMax(
  SBRange         aRange
)
{
  return ( aRange.start + aRange.length );
}

static inline SBRangeContains(
  SBRange         aRange,
  unsigned int    value
)
{
  return ( value - aRange.start < aRange.length );
}

static inline SBRangeEqual(
  SBRange         aRange1,
  SBRange         aRange2
)
{
  return ( (aRange1.start == aRange2.start) && (aRange1.length == aRange2.length) ); 
}

static inline SBRangeEmpty(
  SBRange         aRange
)
{
  return ( aRange.length == 0 );
}

//

@protocol SBMutableCopying

- (id) mutableCopy;

@end

@interface SBObject : Object
{
  unsigned int      _references;
}

+ (void) emptyAutoreleasePool;

- (id) init;
- (void) dealloc;

- (unsigned int) referenceCount;
- (id) retain;
- (void) release;
- (id) autorelease;

- (void) summarizeToStream:(FILE*)stream;

- (unsigned int) hashForData:(const void*)data byteLength:(size_t)byteLength;

@end

@interface SBNull : SBObject

+ (id) null;

@end

#ifdef NEED_STRDUP
char* strdup(const char* s1);
#endif

#ifdef NEED_FGETLN
char* fgetln(FILE* stream,size_t* len);
#endif

int fileExists(const char* path);
int directoryExists(const char* path);
