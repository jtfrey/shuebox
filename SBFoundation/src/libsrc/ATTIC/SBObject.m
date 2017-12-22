//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBObject.m
//
// Base class for the package.  We augment Object, we don't replace
// it.
//
// $Id$
//

#import "SBObject.h"
#import "SBArray.h"
#import "SBArrayPrivate.h"

SBRange SBEmptyRange = { 0 , 0 };

static SBArray* __AutoreleasePool = nil;

//

@implementation SBObject

  + (void) emptyAutoreleasePool
  {
    if ( __AutoreleasePool ) {
#ifdef SB_DEBUG
      [__AutoreleasePool summarizeToStream:stderr];
#endif
      [__AutoreleasePool removeAllObjects];
    }
  }

//

#ifdef SB_DEBUG
  + (id) alloc
  {
    id      newObj = [super alloc];
    
    fprintf(stderr, "DEBUG:  ALLOC    %s@%p\n", [self name], newObj);
    return newObj;
  }
#endif

//

  - (id) init
  {
    if ( self = [super init] )
      _references = 1;
    return self;
  }
  
//

  - (void) dealloc
  {
#ifdef SB_DEBUG
    fprintf(stderr, "DEBUG:  DEALLOC  %s@%p\n", [self name], self);
#endif
    [super free];
  }

//

  - (unsigned int) referenceCount
  {
    return _references;
  }
  
//

  - (id) retain
  {
    _references++;
    return self;
  }

//

  - (void) release
  {
    if ( --_references == 0 )
      [self dealloc];
  }

//

  - (id) autorelease
  {
    if ( __AutoreleasePool == nil )
      __AutoreleasePool = [[SBArray alloc] init];
    if ( __AutoreleasePool ) {
      [__AutoreleasePool addUnretainedObject:self];
    } else {
      printf("NO AUTORELEASE POOL?!?!?\n");
    }
    return self;
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    fprintf(
        stream,
        "%s@%p[%u]",
        [self name],
        self,
        _references
      );
  }

//

/*
 * Adapted from
 *
 *   http://www.azillionmonkeys.com/qed/hash.html
 *
 */

#undef SBOBJECT_HASH_PTR_TO_UINT16
#define SBOBJECT_HASH_PTR_TO_UINT16(d) (*((const uint16_t *) (d)))

  - (unsigned int) hashForData:(const void*)data
    byteLength:(size_t)byteLength
  {
    unsigned int    hash = byteLength, tmp;
    int             remnant;

    if (byteLength <= 0 || data == NULL)
      return 0;

    remnant = byteLength & 3;
    byteLength >>= 2;

    /* Main loop */
    while ( byteLength-- > 0 ) {
      hash += SBOBJECT_HASH_PTR_TO_UINT16(data);
      data += 2;
      tmp = (SBOBJECT_HASH_PTR_TO_UINT16(data) << 11) ^ hash;
      data += 2;
      
      hash = (hash << 16) ^ tmp;
      hash += hash >> 11;
    }

    /* Handle end cases */
    switch (remnant) {
      case 3: hash += SBOBJECT_HASH_PTR_TO_UINT16(data);
              hash ^= hash << 16;
              hash ^= ((char*)data)[2] << 18;
              hash += hash >> 11;
              break;
      case 2: hash += SBOBJECT_HASH_PTR_TO_UINT16(data);
              hash ^= hash << 11;
              hash += hash >> 17;
              break;
      case 1: hash += *((char*)data);
              hash ^= hash << 10;
              hash += hash >> 1;
              break;
    }

    /* Force "avalanching" of final 127 bits */
    hash ^= hash << 3;
    hash += hash >> 5;
    hash ^= hash << 4;
    hash += hash >> 17;
    hash ^= hash << 25;
    hash += hash >> 6;

    return hash;
  }

@end

//
#pragma mark -
//

@implementation SBNull

  + (id) null
  {
    static SBNull* _sharedInstance = nil;
    
    if ( _sharedInstance == nil )
      _sharedInstance = [[SBNull alloc] init];
    return _sharedInstance;
  }

@end

//
#pragma mark -
//

#ifdef NEED_STRDUP

char*
strdup(
  const char* s1
)
{
  char*       r = NULL;
  
  if ( s1 ) {
    size_t    slen = strlen(s1);
    
    if ( (r = malloc(slen + 1)) ) {
      strcpy(r, s1);
    }
  }
  return r;
}

#endif

#ifdef NEED_FGETLN

char*
fgetln(
  FILE*   stream,
  size_t* len
)
{
  static char*  fgetln_buffer = NULL;
  static size_t fgetln_buffer_size= 0;
  
  char*         p = fgetln_buffer;
  int           c;
  size_t        count = 0;
  
  while ( ! feof(stream) && (c = fgetc(stream)) && (c != EOF) ) {
    if ( count == fgetln_buffer_size ) {
      char*     buffer = ( fgetln_buffer ? realloc(fgetln_buffer, fgetln_buffer_size + 64) : malloc(64) );
      
      if ( ! buffer )
        break;
      fgetln_buffer = buffer;
      p = buffer + count;
      fgetln_buffer_size += 64;
    }
    *p++ = (char)c;
    count++;
    
    if ( c == '\n' )
      break;
  }
  *len = count;
  return ( count ? fgetln_buffer : NULL );
}

#endif

int
fileExists(
  const char* path
)
{
  struct stat   metaData;
  
  if ( stat(path, &metaData) == 0 )
    return 1;
  return 0;
}

int
directoryExists(
  const char* path
)
{
  struct stat   metaData;
  
  if ( stat(path, &metaData) == 0 )
    return ((metaData.st_mode & S_IFDIR) != 0);
  return 0;
}
