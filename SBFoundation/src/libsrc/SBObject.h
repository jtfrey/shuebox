//
// SBFoundation : ObjC Class Library for Solaris
// SBObject.h
//
// Base class for the package.  We augment Object, we don't replace
// it.
//
// $Id$
//

#import <objc/objc-api.h>
#import <objc/Object.h>

#include "config.h"

#include <stdio.h>
#include <string.h>
#include <strings.h>
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
#include <limits.h>
#include <float.h>

#ifdef SOLARIS
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <sys/stat.h>
#endif

#if __LP64__ || SB_FORCE_64BIT_INTS
typedef long int SBInteger;
typedef unsigned long int SBUInteger;
#  define SBIntegerMax      LONG_MAX
#  define SBIntegerMin      LONG_MIN
#  define SBUIntegerMax     ULONG_MAX
#  define SBIntegerFormat   "%ld"
#  define SBUIntegerFormat  "%lu"
#  define SB64BitIntegers   1
#else
/*!
  @typedef SBInteger
  @discussion
    The type of signed integer values used throughout this library.
*/
typedef int SBInteger;
/*!
  @typedef SBUInteger
  @discussion
    The type of unsigned integer values used throughout this library.
*/
typedef unsigned int SBUInteger;
/*!
  @defined SBIntegerMax
  @discussion
    The maximum representable value of an SBInteger.
*/
#  define SBIntegerMax      INT_MAX
/*!
  @defined SBIntegerMin
  @discussion
    The minimum representable value of an SBInteger.
*/
#  define SBIntegerMin      INT_MIN
/*!
  @defined SBUIntegerMax
  @discussion
    The maximum representable value of an SBUInteger.
*/
#  define SBUIntegerMax     UINT_MAX
/*!
  @defined SBIntegerFormat
  @discussion
    The printf() format string corresponding to the SBInteger type.
*/
#  define SBIntegerFormat   "%d"
/*!
  @defined SBUIntegerFormat
  @discussion
    The printf() format string corresponding to the SBUInteger type.
*/
#  define SBUIntegerFormat  "%u"
/*!
  @defined SB64BitIntegers
  @discussion
    Non-zero if the API is compiled with 64-bit integers as the default.
*/
#  define SB64BitIntegers   0
#endif

/*!
  @defined SBNotFound
  @discussion
  For routines which return SBUInteger index values, the value of SBNotFound represents
  an invalid or unknown index.
*/
#define SBNotFound (SBUIntegerMax)

/*!
  @const SBBase64CharSet
  @discussion
  The base64 character set -- 65 characters, with the character at index 64 being the "="
  pad character.
*/
extern const char* SBBase64CharSet;

/*!
  @typedef SBComparisonResult
  @discussion
  An enumeration that represents the results of a comparison operation.  Comparisons always
  operate on two objects; typically, the receiver (object A) and another object (object B)
  @constant SBOrderDescending    A > B
  @constant SBOrderSame          A = B
  @constant SBOrderAscending     A < B
*/
typedef SBInteger SBComparisonResult;
enum {
  SBOrderDescending = -1,
  SBOrderSame = 0,
  SBOrderAscending = 1
} ;

/*!
  @typedef SBRange
  @discussion
  SBRange is used to represent a range of SBUInteger values.
*/
typedef struct {
  SBUInteger      start;
  SBUInteger      length;
} SBRange;

/*!
  @const SBEmptyRange
  @discussion
  An SBRange that represents zero SBUInteger values.
*/
extern SBRange SBEmptyRange;

/*!
  @function SBRangeCreate
  @discussion
  Initializes and returns an SBRange.
*/
static inline SBRange SBRangeCreate(
  SBUInteger    start,
  SBUInteger    length
)
{
  SBRange   newRange = { start , length };
  return newRange;
}

/*!
  @function SBRangeMax
  @discussion
  Returns the SBUInteger that is one past the final value in the range.  Useful
  as the terminating value of a loop over the range, e.g.
  <pre>
    SBRange       aRange = SBRangeCreate(0,15);
    SBUInteger    i = 0, iMax = SBRangeMax(aRange);
    
    while ( i < iMax ) {
       :
      i++;
    }
  </pre>
*/
static inline SBUInteger SBRangeMax(
  SBRange         aRange
)
{
  return ( aRange.start + aRange.length );
}

/*!
  @function SBRangeContains
  @discussion
  Returns boolean true if "value" lies within the given SBUInteger range (aRange).
*/
static inline SBRangeContains(
  SBRange         aRange,
  SBUInteger      value
)
{
  return ( value - aRange.start < aRange.length );
}

/*!
  @function SBRangeEqual
  @discussion
  Returns boolean true if the two ranges have the same origin and length.
*/
static inline SBRangeEqual(
  SBRange         aRange1,
  SBRange         aRange2
)
{
  return ( (aRange1.start == aRange2.start) && (aRange1.length == aRange2.length) ); 
}

/*!
  @function SBRangeEmpty
  @discussion
  Returns boolean true if aRange contains zero SBUInteger values (basically,
  length is equal to zero).
*/
static inline SBRangeEmpty(
  SBRange         aRange
)
{
  return ( aRange.length == 0 );
}

@class SBString, SBEnumerator;

/*!
  @protocol SBMutableCopying
  @discussion
  The SBMutableCopying protocol is adopted by immutable classes in order to provide methods by
  which a "read-only" object can be turned into a modifiable variant.  Classes like SBArray
  and SBString adopt this protocol, for example.
*/
@protocol SBMutableCopying

/*!
  @method mutableCopy
  
  Returns a new object that is not immutable -- i.e. it can have its value modified.  The copy is
  "owned" by the caller, so the caller is responsible for releasing the copy.
*/
- (id) mutableCopy;

@end

/*!
  @method SBObject
  @discussion
  SBObject represents the base class of the SBFoundation library.  It extends the GNU "Object" class
  by adding a reference-copying mechanism and autorelease pooling.
  
  Reference copies are shallow copies of an object.  All objects that derive from SBObject implicitly
  have a reference count of 1 when they are instantiated and initialized.  Sending the "retain" message
  to the object increments its reference count; sending the "release" message decrements its reference
  count.  Once an object's reference count reaches zero, it is deallocated and it no longer valid.
  
  Autorelease pooling is a form of garbage collection.  Before any SBFoundation classes are used, at
  least one SBAutoreleasePool object should be allocated and initialized.  When an SBObject-derived
  object is subsequently sent the "autorelease" message, that object is added to the active SBAutoreleasePool.
  When the active SBAutoreleasePool is sent the release message, all autoreleased objects it has collected are
  purged and sent the "release" message.  Most of the classes in this class cluster have class methods to
  allocate and initialize instances that are autoreleased; these are the preferred methods for creating new
  objects.  Consider the following code snippet:
  <pre>
    void
    showMACPrefix(
      SBString*   aString
    )
    {
      [[aString substringToIndex:7] writeToStream:stdout];
    }
  </pre>
  The showMACPrefix() function sends the substringToIndex: message to aString, which returns a new
  object.  Without autorelease pools, the showMACPrefix() function would "own" the returned object and
  would be responsible for sending it the "release" message before returning.  However, since all
  instance methods that return new objects will return an autoreleased object (with the notable exception
  of the "copy" and "mutableCopy" methods), showMACPrefix() can execute as shown and when the active
  SBAutoreleasePool is destroyed the substring object will be deallocated.
  
  As it stands, an SBObject has a single instance variable of type SBUInteger.  The GNU Object
  class has no instance variables.
*/
@interface SBObject : Object
{
  SBUInteger      _references;
}

/*!
  @method init
  @discussion
  Initialize a new instance of SBObject; all this really does is set the receiver's reference count
  to 1.
*/
- (id) init;
/*!
  @method dealloc
  @discussion
  We use this method name in preference to the GNU Object class's "free" method; SBObject's implementation
  merely chains to Object's "free" method.
*/
- (void) dealloc;
/*!
  @method referenceCount
  @discussion
  Returns the number of "in-play" reference copies of the receiver.
*/
- (SBUInteger) referenceCount;
/*!
  @method retain
  @discussion
  Returns a reference copy of the receiver; the receiver's reference count is incremented.  This message can
  be chained with other messages to the receiver:
  <pre>
    [[[SBObject alloc] init] summarizeToStream:stdout];
  </pre>
*/
- (id) retain;
/*!
  @method release
  @discussion
  Release a reference copy of the receiver; the receiver's reference count is decremented.  If the
  reference count has reached zero, the receiver is also sent the "dealloc" message and is no
  longer a valid object.
*/
- (void) release;
/*!
  @method autorelease
  @discussion
  Adds the receiver to the application's autorelease pool for later (possible) automatic removal.
  Returns the receiver, so this message can be chained with other messages to the receiver:
  <pre>
    [[[[SBObject alloc] init] autorelease] summarizeToStream:stdout];
  </pre>
*/
- (id) autorelease;
/*!
  @method summarizeToStream:
  @discussion
  Write a textual, debug-esque description of the receiver to the given stdio stream.  The base
  implementation of this method merely displays:
  <pre>
    ClassName@ObjectPointer[ReferenceCount]
  </pre>
  Subclasses should override this method, chaining to their parent and then displaying any
  additional information.
*/
- (void) summarizeToStream:(FILE*)stream;
/*!
  @method hashForData:byteLength:
  @discussion
  Given a byte stream at "data" containing "byteLength" bytes, calculate a hash code.
*/
- (SBUInteger) hashForData:(const void*)data byteLength:(SBUInteger)byteLength;
/*!
  @method hash
  @discussion
    An override of the GNU Object class's hash method.
*/
- (SBUInteger) hash;
/*!
  @method subclassEnumerator
  @discussion
    When invoked on any SBObject-descendent class, the resulting SBEnumerator enumerates all
    direct subclasses of the receiver class.
*/
+ (SBEnumerator*) subclassEnumerator;

@end

/*!
  @class SBNull
  @discussion
  For arrays and other collections there are times when an "empty" or "null" value is necessary --
  for example, to consume unused indices in a non-sparse array.  The shared instance of SBNull
  can be used for these purposes.
*/
@interface SBNull : SBObject

/*!
  @method null
  @discussion
  Returns the application-wide, shared instance of the SBNull class.
*/
+ (id) null;

@end

@interface SBObject(SBNullObject)

/*!
  @method isNull
  @discussion
    Returns YES if the receiver is an SBNull object.
*/
- (BOOL) isNull;

@end

#import "SBKeyValueCoding.h"

/*!
  @protocol SBStringValue
  @discussion
    Classes that conform to this protocol can produce a textual
    representation of instances of themself.
*/
@protocol SBStringValue

- (SBString*) stringValue;

@end

#ifdef NEED_STRDUP
/*!
  @function strdup
  @discussion
    For systems lacking a native strdup() function.  Allocates and initializes
    a copy of the C string s1.  Caller is reposible for calling free() on the
    returned pointer.
*/
char* strdup(const char* s1);
#endif

#ifdef NEED_FGETLN
/*!
  @function fgetln
  @discussion
    For systems lacking a native fgetln() function.  Reads a single line (delimited
    by UNIX newline) into an internal buffer from the given file and returns a pointer
    to that buffer.  The target of the len pointer is set to the number of characters
    present on the line.  The line is not NUL-terminated! 
*/
char* fgetln(FILE* stream, SBUInteger* len);
#endif

/*!
  @function fileExists
  @discussion
    Returns YES if path is an extant UNIX file path.
*/
BOOL fileExists(const char* path);

/*!
  @function directoryExists
  @discussion
    Returns YES if path is an extant UNIX file path and is a directory.
*/
BOOL directoryExists(const char* path);

/*!
  @function SBInSituByteSwap
  @abstract Endian utilities
  @discussion
  Given "length" bytes of data resident at "ptr", swap the trailing and leading bytes.
*/
void SBInSituByteSwap(void* ptr, SBUInteger length);
/*!
  @function SBByteSwap
  @abstract Endian utilities
  @discussion
  Given "length" bytes of data resident at "src", copy the bytes to "dst".  The trailing and
  leading bytes are swapped as they are copied, so "src" is unchanged while "dst" contains
  a byte-swapped copy of "src".
*/
void SBByteSwap(void* src, SBUInteger length, void* dst);
/*!
  @function SBInSituByteSwapToNetwork
  @abstract Endian utilities
  @discussion
  For a little-endian host, given "length" bytes of data resident at "ptr", swap the trailing
  and leading bytes so that the bytes are in network (big endian) byte order.  For a big-endian
  host, do not alter the byte ordering.
*/
void SBInSituByteSwapToNetwork(void* ptr, SBUInteger length);
/*!
  @function SBByteSwapToNetwork
  @abstract Endian utilities
  @discussion
  For a little-endian host, given "length" bytes of data resident at "src", copy the bytes to
  "dst" so that the bytes are in network (big endian) byte order:  "src" is unchanged while
  "dst" contains a byte-swapped copy of "src".  For a big-endian host, "src" is copied
  to "dst" without altering the byte order.
*/
void SBByteSwapToNetwork(void* src, SBUInteger length, void* dst);
/*!
  @function SBInSituByteSwapFromNetwork
  @abstract Endian utilities
  @discussion
  For a little-endian host, swap the bytes back to little endian order from network (big endian)
  byte order.
  
  Calling SBInSituByteSwapToNetwork() would accomplish the same thing, of course; the alternate
  name is provided for clarity in your code.
*/
void SBInSituByteSwapFromNetwork(void* ptr, SBUInteger length);
/*!
  @function SBByteSwapFromNetwork
  @abstract Endian utilities
  @discussion
  For a little-endian host, given "length" bytes of data resident at "src", copy the bytes to
  "dst" so that the bytes are in little endian byte order:  "src" is unchanged while
  "dst" contains a byte-swapped copy of "src".  For a big-endian host, "src" is copied
  to "dst" without altering the byte order.
  
  Calling SBByteSwapToNetwork() would accomplish the same thing, of course; the alternate
  name is provided for clarity in your code.
*/
void SBByteSwapFromNetwork(void* src, SBUInteger length, void* dst);

@class SBLock;

/*!
  @constant SBGlobalLock
  @discussion
    A shared SBLock instance which is available for generic program-wide thread
    locking.
*/
extern SBLock* SBGlobalLock;

#ifndef SB_BLOCK_ASSERTIONS

/*!
  @defined SBAssert
  @discussion
    Macro that takes two arguments:  a conditional and a message string.  If the conditional
    evaluates as false, the message is printed to stderr and the program aborts.
*/
#define SBAssert(SBASSERT_COND,SBASSERT_MSG) do{if(!(SBASSERT_COND)){fprintf(stderr,"Assertion failed(%s:%d): "SBASSERT_MSG"\n",__FILE__,__LINE__);exit(-1);}}while(0)
/*!
  @defined SBAssert5
  @discussion
    Macro that takes 7 arguments:  a conditional, a message string with 5 arguments, and
    those 5 arguments.  If the conditional evaluates as false, the message is printed to stderr
    (with printf-conversion according to the format elements in the message string and the 5
    arguments) and the program aborts.
*/
#define SBAssert5(SBASSERT_COND,SBASSERT_MSG,SBASSERT_ARG1,SBASSERT_ARG2,SBASSERT_ARG3,SBASSERT_ARG4,SBASSERT_ARG5) do{if(!(SBASSERT_COND)){fprintf(stderr,"Assertion failed(%s:%d): "SBASSERT_MSG"\n",__FILE__,__LINE__,SBASSERT_ARG1,SBASSERT_ARG2,SBASSERT_ARG3,SBASSERT_ARG4,SBASSERT_ARG5);exit(-1);}}while(0)
/*!
  @defined SBAssert4
  @discussion
    Macro that takes 6 arguments:  a conditional, a message string with 4 arguments, and
    those 4 arguments.  If the conditional evaluates as false, the message is printed to stderr
    (with printf-conversion according to the format elements in the message string and the 4
    arguments) and the program aborts.
*/
#define SBAssert4(SBASSERT_COND,SBASSERT_MSG,SBASSERT_ARG1,SBASSERT_ARG2,SBASSERT_ARG3,SBASSERT_ARG4) do{if(!(SBASSERT_COND)){fprintf(stderr,"Assertion failed(%s:%d): "SBASSERT_MSG"\n",__FILE__,__LINE__,SBASSERT_ARG1,SBASSERT_ARG2,SBASSERT_ARG3,SBASSERT_ARG4);exit(-1);}}while(0)
/*!
  @defined SBAssert3
  @discussion
    Macro that takes 5 arguments:  a conditional, a message string with 3 arguments, and
    those 3 arguments.  If the conditional evaluates as false, the message is printed to stderr
    (with printf-conversion according to the format elements in the message string and the 3
    arguments) and the program aborts.
*/
#define SBAssert3(SBASSERT_COND,SBASSERT_MSG,SBASSERT_ARG1,SBASSERT_ARG2,SBASSERT_ARG3) do{if(!(SBASSERT_COND)){fprintf(stderr,"Assertion failed(%s:%d): "SBASSERT_MSG"\n",__FILE__,__LINE__,SBASSERT_ARG1,SBASSERT_ARG2,SBASSERT_ARG3);exit(-1);}}while(0)
/*!
  @defined SBAssert2
  @discussion
    Macro that takes 4 arguments:  a conditional, a message string with 2 arguments, and
    those 2 arguments.  If the conditional evaluates as false, the message is printed to stderr
    (with printf-conversion according to the format elements in the message string and the 2
    arguments) and the program aborts.
*/
#define SBAssert2(SBASSERT_COND,SBASSERT_MSG,SBASSERT_ARG1,SBASSERT_ARG2) do{if(!(SBASSERT_COND)){fprintf(stderr,"Assertion failed(%s:%d): "SBASSERT_MSG"\n",__FILE__,__LINE__,SBASSERT_ARG1,SBASSERT_ARG2);exit(-1);}}while(0)
/*!
  @defined SBAssert1
  @discussion
    Macro that takes 3 arguments:  a conditional, a message string with 1 argument, and
    that argument.  If the conditional evaluates as false, the message is printed to stderr
    (with printf-conversion according to the format element in the message string and the
    argument) and the program aborts.
*/
#define SBAssert1(SBASSERT_COND,SBASSERT_MSG,SBASSERT_ARG) do{if(!(SBASSERT_COND)){fprintf(stderr,"Assertion failed(%s:%d): "SBASSERT_MSG"\n",__FILE__,__LINE__,SBASSERT_ARG);exit(-1);}}while(0)

#else

#define SBAssert(SBASSERT_COND,SBASSERT_MSG) /**/
#define SBAssert5(SBASSERT_COND,SBASSERT_MSG,SBASSERT_ARG1,SBASSERT_ARG2,SBASSERT_ARG3,SBASSERT_ARG4,SBASSERT_ARG5) /**/
#define SBAssert4(SBASSERT_COND,SBASSERT_MSG,SBASSERT_ARG1,SBASSERT_ARG2,SBASSERT_ARG3,SBASSERT_ARG4) /**/
#define SBAssert3(SBASSERT_COND,SBASSERT_MSG,SBASSERT_ARG1,SBASSERT_ARG2,SBASSERT_ARG3) /**/
#define SBAssert2(SBASSERT_COND,SBASSERT_MSG,SBASSERT_ARG1,SBASSERT_ARG2) /**/
#define SBAssert1(SBASSERT_COND,SBASSERT_MSG,SBASSERT_ARG) /**/

#endif /* SB_BLOCK_ASSERTIONS */
