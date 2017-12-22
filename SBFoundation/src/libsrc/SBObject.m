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
#import "SBEnumerator.h"
#import "SBArray.h"
#import "SBDictionary.h"
#import "SBValue.h"
#import "SBAutoreleasePool.h"
#import "SBLock.h"

//

SBRange SBEmptyRange = { SBUIntegerMax, 0 };

//

@interface __SBClassEnumerator : SBEnumerator
{
  struct objc_class*    _siblingChain;
}

- (id) initWithClassPtr:(struct objc_class*)classPtr;

@end

@implementation __SBClassEnumerator

  - (id) initWithClassPtr:(struct objc_class*)classPtr
  {
    if ( (self = [super init]) ) {
      _siblingChain = classPtr;
    }
    return self;
  }

//

  - (id) nextObject
  {
    id      classPtr = (id)_siblingChain;
    
    if ( classPtr )
      _siblingChain = _siblingChain->sibling_class;
    return classPtr;
  }

@end


//

@interface SBObject(SBObjectPrivate)

- (void) setReferences:(SBUInteger)refCount;

@end

@implementation SBObject(SBObjectPrivate)

  - (void) setReferences:(SBUInteger)refCount
  {
    _references = refCount;
  }

@end

//

static SBUInteger   __SBObjectAllocCount = 0;
static FILE*        __SBFoundationErrorLog = NULL;

void
__SBFoundationErrorLogOpen(void)
{
  if ( ! __SBFoundationErrorLog ) {
    __SBFoundationErrorLog = fopen("/tmp/SBFoundationError.log", "a");
  }
}

#include <ucontext.h>

BOOL
__SBFoundationErrorHandler(
  id          object,
  int         code,
  const char* format,
  va_list     vargs
)
{
  if ( __SBFoundationErrorLog ) {
    fprintf(__SBFoundationErrorLog, "ERROR ENCOUNTERED WITH OBJECT %p (code=%d):\n", object, code);
    vfprintf(__SBFoundationErrorLog, format, vargs);
    printstack(fileno(__SBFoundationErrorLog));
    fflush(__SBFoundationErrorLog);
  } else {
    printf("ERROR ENCOUNTERED WITH OBJECT %p (code=%d):\n", object, code);
    vprintf(format, vargs);
    printstack(STDOUT_FILENO);
    fflush(stdout);
  }
  return NO;
}

@implementation SBObject

  + (id) initialize
  {
    if ( self == [SBObject class] ) {
      SBGlobalLock = [[SBLock alloc] init];
      __SBFoundationErrorLogOpen();
      objc_set_error_handler(__SBFoundationErrorHandler);
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
    fprintf(stderr, "DEBUG:  [%05" SBUIntegerFormat "] DEALLOC  %s@%p\n", --__SBObjectAllocCount, [self name], self);
#endif
    [super free];
  }

//

  - (SBUInteger) referenceCount
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
        "%s@%p[" SBUIntegerFormat "]",
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
 *   http://burtleburtle.net/bob/hash/evahash.html
 *
 */

#if SB64BitIntegers

#  define SBOBJECT_HASH_MIX64(a,b,c) \
    { \
      a -= b; a -= c; a ^= (c>>43); \
      b -= c; b -= a; b ^= (a<<9); \
      c -= a; c -= b; c ^= (b>>8); \
      a -= b; a -= c; a ^= (c>>38); \
      b -= c; b -= a; b ^= (a<<23); \
      c -= a; c -= b; c ^= (b>>5); \
      a -= b; a -= c; a ^= (c>>35); \
      b -= c; b -= a; b ^= (a<<49); \
      c -= a; c -= b; c ^= (b>>11); \
      a -= b; a -= c; a ^= (c>>12); \
      b -= c; b -= a; b ^= (a<<18); \
      c -= a; c -= b; c ^= (b>>22); \
    }

  - (SBUInteger) hashForData:(const void*)data
    byteLength:(SBUInteger)byteLength
  {
    char*                 k = (void*)data;
    register SBUInteger   a, b, c, len;
    
    len = byteLength;
    a = b = byteLength;
    c = 0x9e3779b97f4a7c13LL;

    /*---------------------------------------- handle most of the key */
    while (len >= 24)
    {
      a += (k[0]        +(SBUIntegerk[ 1]<< 8)+(SBUIntegerk[ 2]<<16)+(SBUIntegerk[ 3]<<24)
       +(SBUIntegerk[4 ]<<32)+(SBUIntegerk[ 5]<<40)+(SBUIntegerk[ 6]<<48)+(SBUIntegerk[ 7]<<56));
      b += (k[8]        +(SBUIntegerk[ 9]<< 8)+(SBUIntegerk[10]<<16)+(SBUIntegerk[11]<<24)
       +(SBUIntegerk[12]<<32)+(SBUIntegerk[13]<<40)+(SBUIntegerk[14]<<48)+(SBUIntegerk[15]<<56));
      c += (k[16]       +(SBUIntegerk[17]<< 8)+(SBUIntegerk[18]<<16)+(SBUIntegerk[19]<<24)
       +(SBUIntegerk[20]<<32)+(SBUIntegerk[21]<<40)+(SBUIntegerk[22]<<48)+(SBUIntegerk[23]<<56));
      SBOBJECT_HASH_MIX64(a,b,c);
      k += 24; len -= 24;
    }

    /*------------------------------------- handle the last 23 bytes */
    c += byteLength;
    switch(len)              /* all the case statements fall through */
    {
    case 23: c+=(SBUInteger)k[22]<<56);
    case 22: c+=(SBUInteger)k[21]<<48);
    case 21: c+=(SBUInteger)k[20]<<40);
    case 20: c+=(SBUInteger)k[19]<<32);
    case 19: c+=(SBUInteger)k[18]<<24);
    case 18: c+=(SBUInteger)k[17]<<16);
    case 17: c+=(SBUInteger)k[16]<<8);
      /* the first byte of c is reserved for the length */
    case 16: b+=(SBUInteger)k[15]<<56);
    case 15: b+=(SBUInteger)k[14]<<48);
    case 14: b+=(SBUInteger)k[13]<<40);
    case 13: b+=(SBUInteger)k[12]<<32);
    case 12: b+=(SBUInteger)k[11]<<24);
    case 11: b+=(SBUInteger)k[10]<<16);
    case 10: b+=(SBUInteger)k[ 9]<<8);
    case  9: b+=(SBUInteger)k[ 8]);
    case  8: a+=(SBUInteger)k[ 7]<<56);
    case  7: a+=(SBUInteger)k[ 6]<<48);
    case  6: a+=(SBUInteger)k[ 5]<<40);
    case  5: a+=(SBUInteger)k[ 4]<<32);
    case  4: a+=(SBUInteger)k[ 3]<<24);
    case  3: a+=(SBUInteger)k[ 2]<<16);
    case  2: a+=(SBUInteger)k[ 1]<<8);
    case  1: a+=(SBUInteger)k[ 0]);
      /* case 0: nothing left to add */
    }
    SBOBJECT_HASH_MIX64(a,b,c);
    /*-------------------------------------------- report the result */
    return c;
  }

#else

#  undef SBOBJECT_HASH_PTR_TO_UINT16
#  define SBOBJECT_HASH_PTR_TO_UINT16(d) (*((const uint16_t *) (d)))

  - (SBUInteger) hashForData:(const void*)data
    byteLength:(SBUInteger)byteLength
  {
    SBUInteger      hash = 0x9e3779b9, tmp;
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
  
#endif
  
//

  - (SBUInteger) hash
  {
    return (SBUInteger)self;
  }

//

  + (SBEnumerator*) subclassEnumerator
  {
    return [[[__SBClassEnumerator alloc] initWithClassPtr:[self class]->subclass_list] autorelease];
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
    SBUInteger    slen = strlen(s1);
    
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
  FILE*       stream,
  SBUInteger* len
)
{
  static char*  fgetln_buffer = NULL;
  static SBUInteger fgetln_buffer_size= 0;
  
  char*         p = fgetln_buffer;
  int           c;
  SBUInteger        count = 0;
  
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
  void*         src,
  SBUInteger    length,
  void*         dst
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
  void*         ptr,
  SBUInteger    length
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
SBInSituByteSwapToNetwork(void* ptr, SBUInteger length)
{
  if ( __SBByteOrderAsInt32 != *((uint32_t*)__SBByteOrderAsChar) )
    SBInSituByteSwap(ptr, length);
}

//

void
SBByteSwapToNetwork(void* src, SBUInteger length, void* dst)
{
  if ( __SBByteOrderAsInt32 != *((uint32_t*)__SBByteOrderAsChar) )
    SBByteSwap(src, length, dst);
  else
    memcpy(dst, src, length);
}

//

void
SBInSituByteSwapFromNetwork(void* ptr, SBUInteger length)
{
  if ( __SBByteOrderAsInt32 != *((uint32_t*)__SBByteOrderAsChar) )
    SBInSituByteSwap(ptr, length);
}

//

void
SBByteSwapFromNetwork(void* src, SBUInteger length, void* dst)
{
  if ( __SBByteOrderAsInt32 != *((uint32_t*)__SBByteOrderAsChar) )
    SBByteSwap(src, length, dst);
  else
    memcpy(dst, src, length);
}

//
#pragma mark -
//

SBLock* SBGlobalLock = nil;
