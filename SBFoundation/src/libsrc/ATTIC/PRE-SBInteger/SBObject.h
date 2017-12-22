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

/*!
  @defined SBNotFound
  @discussion
  For routines which return unsigned integer index values, the value of SBNotFound represents
  an invalid or unknown index.
*/
#define SBNotFound ((unsigned int)-1)

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
typedef enum {
  SBOrderDescending = -1,
  SBOrderSame = 0,
  SBOrderAscending = 1
} SBComparisonResult;

/*!
  @typedef SBRange
  @discussion
  SBRange is used to represent a range of unsigned integer values.
*/
typedef struct {
  unsigned int    start;
  unsigned int    length;
} SBRange;

/*!
  @const SBEmptyRange
  @discussion
  An SBRange that represents zero unsigned integer values.
*/
extern SBRange SBEmptyRange;

/*!
  @function SBRangeCreate
  @discussion
  Initializes and returns an SBRange.
*/
static inline SBRange SBRangeCreate(
  unsigned int    start,
  unsigned int    length
)
{
  SBRange   newRange = { start , length };
  return newRange;
}

/*!
  @function SBRangeMax
  @discussion
  Returns the unsigned integer that is one past the final value in the range.  Useful
  as the terminating value of a loop over the range, e.g.
  <pre>
    SBRange       aRange = SBRangeCreate(0,15);
    unsigned int  i = 0, iMax = SBRangeMax(aRange);
    
    while ( i < iMax ) {
       :
      i++;
    }
  </pre>
*/
static inline unsigned int SBRangeMax(
  SBRange         aRange
)
{
  return ( aRange.start + aRange.length );
}

/*!
  @function SBRangeContains
  @discussion
  Returns boolean true if "value" lies within the given unsigned integer range (aRange).
*/
static inline SBRangeContains(
  SBRange         aRange,
  unsigned int    value
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
  Returns boolean true if aRange contains zero unsigned integer values (basically,
  length is equal to zero).
*/
static inline SBRangeEmpty(
  SBRange         aRange
)
{
  return ( aRange.length == 0 );
}

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
  
  Autorelease pooling is a form of garbage collection.  When an SBObject-derived object is sent the
  "autorelease" message, that object is added to an internal array.  The next time SBObject's
  "emptyAutoreleasePool" class method is invoked, all objects in that internal array are purged and sent
  the "release" message.  Most of the classes in this class cluster have class methods to allocate and
  initialize instances that are autoreleased; these are the preferred methods for creating new objects.
  Consider the following code snippet:
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
  of the "copy" and "mutableCopy" methods), showMACPrefix() can execute as shown and the next invocation
  of "emptyAutoreleasePool" will take care of disposing of the substring object.
  
  As it stands, an SBObject has a single instance variable of type unsigned integer.  The GNU Object
  class has no instance variables.
*/
@interface SBObject : Object
{
  unsigned int      _references;
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
- (unsigned int) referenceCount;
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
- (unsigned int) hashForData:(const void*)data byteLength:(size_t)byteLength;

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

- (BOOL) isNull;

@end

#import "SBKeyValueCoding.h"

@class SBString;

@protocol SBStringValue

- (SBString*) stringValue;

@end

#ifdef NEED_STRDUP
char* strdup(const char* s1);
#endif

#ifdef NEED_FGETLN
char* fgetln(FILE* stream,size_t* len);
#endif

BOOL fileExists(const char* path);
BOOL directoryExists(const char* path);

/*!
  @function SBInSituByteSwap
  @abstract Endian utilities
  @discussion
  Given "length" bytes of data resident at "ptr", swap the trailing and leading bytes.
*/
void SBInSituByteSwap(void* ptr, size_t length);
/*!
  @function SBByteSwap
  @abstract Endian utilities
  @discussion
  Given "length" bytes of data resident at "src", copy the bytes to "dst".  The trailing and
  leading bytes are swapped as they are copied, so "src" is unchanged while "dst" contains
  a byte-swapped copy of "src".
*/
void SBByteSwap(void* src, size_t length, void* dst);
/*!
  @function SBInSituByteSwapToNetwork
  @abstract Endian utilities
  @discussion
  For a little-endian host, given "length" bytes of data resident at "ptr", swap the trailing
  and leading bytes so that the bytes are in network (big endian) byte order.  For a big-endian
  host, do not alter the byte ordering.
*/
void SBInSituByteSwapToNetwork(void* ptr, size_t length);
/*!
  @function SBByteSwapToNetwork
  @abstract Endian utilities
  @discussion
  For a little-endian host, given "length" bytes of data resident at "src", copy the bytes to
  "dst" so that the bytes are in network (big endian) byte order:  "src" is unchanged while
  "dst" contains a byte-swapped copy of "src".  For a big-endian host, "src" is copied
  to "dst" without altering the byte order.
*/
void SBByteSwapToNetwork(void* src, size_t length, void* dst);
/*!
  @function SBInSituByteSwapFromNetwork
  @abstract Endian utilities
  @discussion
  For a little-endian host, swap the bytes back to little endian order from network (big endian)
  byte order.
  
  Calling SBInSituByteSwapToNetwork() would accomplish the same thing, of course; the alternate
  name is provided for clarity in your code.
*/
void SBInSituByteSwapFromNetwork(void* ptr, size_t length);
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
void SBByteSwapFromNetwork(void* src, size_t length, void* dst);

@class SBLock;

/*!
  @constant SBGlobalLock
  @discussion
    A shared SBLock instance which is available for generic program-wide thread
    locking.
*/
extern SBLock* SBGlobalLock;
