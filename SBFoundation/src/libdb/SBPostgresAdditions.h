//
// SBDatabaseKit - Database-oriented extensions to SBFoundation
// SBPostgresAdditions.h
//
// Postgres-oriented category additions to SBFoundation classes.
//
// $Id$
//

#import "SBDate.h"
#import "SBMemoryPool.h"

/*!
  @category SBDate(SBPostgresAdditions)
  @discussion
  Groups methods which extend SBDate to handle Postgres' own timestamp representation.
  As it turns out, internally Postgres uses an alternate epoch to express timestamps:
  seconds relative to 2000-01-01 00:00:00 (rather than 1970-01-01 00:00:00).
*/
@interface SBDate(SBPostgresAdditions)

/*!
  @method dateWithPostgresTimestamp:
  Returns a newly-initialized, autoreleased instance of SBDate which wraps the
  given Postgres timestamp.
*/
+ (SBDate*) dateWithPostgresTimestamp:(int64_t)pgTimestamp;
/*!
  @method postgresTimestamp
  Returns the receiver's timestamp as a Postgres timestamp value (seconds since
  2000-01-01 00:00:00).
*/
- (int64_t) postgresTimestamp;

@end

/*!
  @category SBObject(SBPostgresSerialization)
  @discussion
  Groups methods which use binary data coming from a Postgres database to initialize
  objects and methods which produce binary-encoded forms to be sent to a Postgres
  database.
  
  Rather than augment classes with a formal protocol that inextricably entagles
  the SBFoundation and SBDatabaseKit classes, I've opted for the informal protocol
  approach.
  
  While all that is presented here is the informal protocol interface, the source
  accompanying this header file actually implements the methods for the SBNotorization
  class (since it is a user-defined type and comes in as a RECORD which needs to
  be split out into individual sub-fields).
*/
@interface SBObject(SBPostgresSerialization)

/*!
  @method initWithPostgresBinaryData:length:
  @discussion
  Initialize the receiver using binary-encoded data coming from a Postgres database.
*/
- (id) initWithPostgresBinaryData:(const void*)binaryData length:(SBUInteger)length;
/*!
  @method encodePostgresBinaryData:length:usingPool:
  @discussion
  Attempt to create a binary-encoded form of this object which can be sent to a
  Postgres database.  The general procedure is:
  <ol>
    <li>Determine the byte size of the encoded data</li>
    <li>Allocate the necessary buffer from the given memory pool</li>
    <li>Add the necessary information into that buffer (taking care to byte-swap to network order as necessary)</li>
  </ol>
  A return value of YES indicates that the encoding was successful and *buffer and *length were
  set accordingly.  If NO is returned, the encoding process was unsuccessful.
*/
- (BOOL) encodePostgresBinaryData:(void**)buffer length:(SBUInteger*)length usingPool:(SBMemoryPoolRef)pool;

@end
