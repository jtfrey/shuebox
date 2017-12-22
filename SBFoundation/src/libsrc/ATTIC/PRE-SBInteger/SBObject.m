//
// SBFoundation : ObjC Class Library for Solaris
// SBObject.m
//
// Base class for the package.  We augment Object, we don't replace
// it.
//
// $Id$
//

#import "SBObject.h"
#import "SBArray.h"
#import "SBDictionary.h"
#import "SBValue.h"
#import "SBAutoreleasePool.h"
#import "SBLock.h"

//

SBRange SBEmptyRange = { -1 , 0 };

//

@interface SBObject(SBObjectPrivate)

- (void) setReferences:(unsigned int)refCount;

@end

@implementation SBObject(SBObjectPrivate)

  - (void) setReferences:(unsigned int)refCount
  {
    _references = refCount;
  }

@end

//

static unsigned int   __SBObjectAllocCount = 0;

@implementation SBObject

  + (id) initialize
  {
    if ( self == [SBObject class] ) {
      SBGlobalLock = [[SBLock alloc] init];
    }
  }

#ifdef SB_DEBUG
  + (id) alloc
  {
    id      newObj = [super alloc];
    
    fprintf(stderr, "DEBUG:  [%05u] ALLOC    %s@%p\n", ++__SBObjectAllocCount, [self name], newObj);
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
    fprintf(stderr, "DEBUG:  [%05u] DEALLOC  %s@%p\n", --__SBObjectAllocCount, [self name], self);
#endif
    [super free];
  }

//

  - (unsigned int) referenceCount
  {
    return _references;
  }
  
//

  - (id) copy
  {
    return [self retain];
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
    [SBAutoreleasePool addObject:self];
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

//

  - (id) copy
  {
    return self;
  }
  - (void) dealloc
  {
    return;
    
    [super dealloc];
  }
  - (id) retain
  {
    return self;
  }
  - (void) release
  {
  }
  - (id) autorelease
  {
    return self;
  }

@end

@implementation SBObject(SBNullObject)

  - (BOOL) isNull
  {
    return ( [self isKindOf:[SBNull class]] );
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
      char*     buffer = ( fgetln_buffer ? objc_realloc(fgetln_buffer, fgetln_buffer_size + 64) : objc_malloc(64) );
      
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

BOOL
fileExists(
  const char* path
)
{
  struct stat   metaData;
  
  if ( stat(path, &metaData) == 0 )
    return YES;
  return NO;
}

BOOL
directoryExists(
  const char* path
)
{
  struct stat   metaData;
  
  if ( stat(path, &metaData) == 0 )
    return ( ((metaData.st_mode & S_IFDIR) != 0) ? YES : NO);
  return NO;
}

//
#pragma mark -
//


void
SBByteSwap(
  void*     src,
  size_t    length,
  void*     dst
)
{
  if ( src == dst ) {
    SBInSituByteSwap(src, length);
  } else {
    unsigned char*  s = (unsigned char*)src;
    unsigned char*  e = s + length - 1;
    unsigned char*  d = (unsigned char*)dst;
  
    switch ( length ) {
    
      case 0:
      case 1:
        break;
      
      case 2:
        *d++ = *e--;
        *d++ = *e--;
        break;
      
      case 3:
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        break;
      
      case 4:
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        break;
      
      case 5:
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        break;
      
      case 6:
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        break;
      
      case 7:
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        break;
      
      case 8:
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        break;
      
      case 9:
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        *d++ = *e--;
        break;
      
    default:
      while ( s < e ) {
        *d++ = *e--;
      }
      break;
    }
  }
}

//

void
SBInSituByteSwap(
  void*     ptr,
  size_t    length
)
{
  unsigned char*  s = (unsigned char*)ptr;
  unsigned char*  e = s + length - 1;
  unsigned char   c;
  
  switch ( length ) {
    
    case 0:
    case 1:
      break;
      
    case 2:
    case 3:
      c = *s;
      *s = *e;
      *e = c;
      break;
    
    case 4:
    case 5:
      c = *s;
      *s = *e;
      *e = c;
      s++; e--;
      c = *s;
      *s = *e;
      *e = c;
      break;
    
    case 6:
    case 7:
      c = *s;
      *s = *e;
      *e = c;
      s++; e--;
      c = *s;
      *s = *e;
      *e = c;
      s++; e--;
      c = *s;
      *s = *e;
      *e = c;
      break;
    
    case 8:
    case 9:
      c = *s;
      *s = *e;
      *e = c;
      s++; e--;
      c = *s;
      *s = *e;
      *e = c;
      s++; e--;
      c = *s;
      *s = *e;
      *e = c;
      s++; e--;
      c = *s;
      *s = *e;
      *e = c;
      break;
      
    default:
      while ( s < e ) {
        c = *s;
        *s = *e;
        *e = c;
        s++;
        e--;
      }
      break;
    
  }
}

//

const char* SBBase64CharSet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";

//

static uint32_t __SBByteOrderAsInt32 = 0xFEEDFACE;
static unsigned char __SBByteOrderAsChar[4] = { 0xFE , 0xED , 0xFA , 0xCE };

//

void
SBInSituByteSwapToNetwork(void* ptr, size_t length)
{
  if ( __SBByteOrderAsInt32 != *((uint32_t*)__SBByteOrderAsChar) )
    SBInSituByteSwap(ptr, length);
}

//

void
SBByteSwapToNetwork(void* src, size_t length, void* dst)
{
  if ( __SBByteOrderAsInt32 != *((uint32_t*)__SBByteOrderAsChar) )
    SBByteSwap(src, length, dst);
}

//

void
SBInSituByteSwapFromNetwork(void* ptr, size_t length)
{
  if ( __SBByteOrderAsInt32 != *((uint32_t*)__SBByteOrderAsChar) )
    SBInSituByteSwap(ptr, length);
}

//

void
SBByteSwapFromNetwork(void* src, size_t length, void* dst)
{
  if ( __SBByteOrderAsInt32 != *((uint32_t*)__SBByteOrderAsChar) )
    SBByteSwap(src, length, dst);
}

//
#pragma mark -
//

SBLock* SBGlobalLock = nil;
