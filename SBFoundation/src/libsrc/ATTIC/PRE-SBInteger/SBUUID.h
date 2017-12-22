//
// SBFoundation : ObjC Class Library for Solaris
// SBUUID.h
//
// Wrap a universally-unique identifier (UUID).
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBObject.h"

#ifdef SOLARIS
#include <uuid/uuid.h>
#endif

@class SBDate, SBString;

/*!
  @class SBUUID
  @discussion
  Instances of SBUUID wrap a 128 bit "universally-unique identifier."  Wikipedia has a nice article on the
  topic of UUIDs at
  <blockquote>
    <a href="http://en.wikipedia.org/wiki/Universally_Unique_Identifier">http://en.wikipedia.org/wiki/Universally_Unique_Identifier</a>
  </blockquote>
  Behind the scenes this class uses libuuid to create and compare UUIDs.
  
  Textually speaking, the UUID is a sequence of 32 hexadecimal digits grouped as
  <pre>
    ########-####-####-####-############
  </pre>
  or in terms of number of digits per block
  <pre>
    8-4-4-4-12
  </pre>
  for a total of 36 characters.
*/
@interface SBUUID : SBObject
{
  uuid_t        _uuid;
}

/*!
  @method uuid
  
  Returns a newly-allocated, autoreleased instance which wraps a newly-generated
  UUID.
*/
+ (SBUUID*) uuid;
/*!
  @method uuidWithBytes:
  
  Returns a newly-allocated, autoreleased instance initialized with the first 16
  bytes at uuidBytes.
*/
+ (SBUUID*) uuidWithBytes:(void*)uuidBytes;
/*!
  @method uuidWithUUID:
  
  Returns a newly-allocated, autoreleased instance initialized with the UUID
  wrapped by aUUID (the result is a copy of aUUID).
*/
+ (SBUUID*) uuidWithUUID:(SBUUID*)aUUID;
/*!
  @method uuidWithString:
  
  Attempts to parse a valid UUID from the given string.  If successful, returns
  a newly-allocated, autoreleased instance which wraps the parsed UUID.  Otherwise,
  returns nil.
*/
+ (SBUUID*) uuidWithString:(SBString*)aString;
/*!
  @method uuidWithUTF8String:
  
  Attempts to parse a valid UUID from the given UTF8 string.  If successful, returns
  a newly-allocated, autoreleased instance which wraps the parsed UUID.  Otherwise,
  returns nil.
*/
+ (SBUUID*) uuidWithUTF8String:(const char*)aCString;
/*!
  @method init
  
  Initializes an instance to contain a newly-generated UUID.
*/
- (id) init;
/*!
  @method initWithBytes:
  
  Initializes an instance to contain the first 16 bytes at uuidBytes.
*/
- (id) initWithBytes:(void*)uuidBytes;
/*!
  @method initWithUUID:
  
  Initializes an instance to contain the same UUID as aUUID.
*/
- (id) initWithUUID:(SBUUID*)aUUID;
/*!
  @method initWithString:
  
  Attempts to parse a valid UUID from the given string.  If successful, initializes the
  receiver to wrap the parsed UUID.  Otherwise, releases the receiver and returns nil.
*/
- (id) initWithString:(SBString*)aString;
/*!
  @method initWithUTF8String:
  
  Attempts to parse a valid UUID from the given UTF8 string.  If successful, initializes the
  receiver to wrap the parsed UUID.  Otherwise, releases the receiver and returns nil.
*/
- (id) initWithUTF8String:(const char*)aCString;
/*!
  @method getUUIDBytes:
  
  Copy the receiver's UUID to the provided buffer (uuid).  The provided buffer must be
  at least 16 bytes in size.
*/
- (void) getUUIDBytes:(void*)uuid;
/*!
  @method isNull
  
  Returns YES if the receiver's UUID is the null UUID.
*/
- (BOOL) isNull;
/*!
  @method compareToUUID:
  
  Compare the receiver's UUID against the UUID wrapped by anotherUUID.  Returns a value
  from the SBComparisonResult enumeration indicating the order of the two UUIDs.
*/
- (SBComparisonResult) compareToUUID:(SBUUID*)anotherUUID;
/*!
  @method asString
  
  Returns an SBString containing the textual form of the receiver's UUID.
*/
- (SBString*) asString;

@end
