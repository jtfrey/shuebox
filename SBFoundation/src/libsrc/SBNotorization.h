//
// SBFoundation : ObjC Class Library for Solaris
// SBNotorization.h
//
// Class used to represent a special database value we'll call a "notorization" -- the combination
// of a user identifier, timestamp, and remote hostname/IP used to make the request.
//
// $Id$
//
// CREATE TYPE notorization AS (
//   byWhom            CHARACTER VARYING(48),
//   fromWhere         INET,
//   atWhatTime        TIMESTAMP WITH TIME ZONE
// );
//
//

#import "SBObject.h"

@class SBString, SBDate, SBInetAddress;

/*!
  @class SBNotorization
  @discussion
  A notorization is the combination of a timestamp, a user identifier, and an IP address.
  The idea is that we'll often want to indicate who did something, from what host (think
  web interfaces), and at what time.
*/
@interface SBNotorization : SBObject <SBStringValue>
{
  SBString*       _userId;
  SBDate*         _timestamp;
  SBInetAddress*  _fromAddress;
}
/*!
  @method notorization
  @discussion
  Returns a new, autoreleased instance which wraps a default notorization:
  <ul>
    <li>userId = "system"</li>
    <li>fromAddress = "localhost"</li>
    <li>timestamp = now</li>
  </ul>
*/
+ (SBNotorization*) notorization;
/*!
  @method notorizationViaApacheEnvironment
  @discussion
  Returns a new, autoreleased instance which wraps a notorization set using
  the standard environment variables that Apache sets with remote user and
  IP.  If not present, the userId and fromAddress take on default values.
*/
+ (SBNotorization*) notorizationViaApacheEnvironment;
/*!
  @method notorizationWithUserId:
  @discussion
  Returns a new, autoreleased instance which wraps a local notorization; in
  addition to the provided userId:
  <ul>
    <li>fromAddress = "localhost"</li>
    <li>timestamp = now</li>
  </ul>
*/
+ (SBNotorization*) notorizationWithUserId:(SBString*)userId;
/*!
  @method notorizationWithUserId:fromAddress:
  @discussion
  Returns a new, autoreleased instance which wraps a notorization; in
  addition to the provided userId and IP address, the timestamp is set to
  the instant the object was created.
*/
+ (SBNotorization*) notorizationWithUserId:(SBString*)userId fromAddress:(SBInetAddress*)address;
/*!
  @method notorizationWithUserId:fromAddress:withTimestamp:
  @discussion
  Returns a new, autoreleased instance which wraps a notorization.
*/
+ (SBNotorization*) notorizationWithUserId:(SBString*)userId fromAddress:(SBInetAddress*)address withTimestamp:(SBDate*)timestamp;
/*!
  @method initWithUserId:fromAddress:withTimestamp:
  @discussion
  Initializes the receiver using the provided user identifier, timestamp, and
  host address.
  
  Any of the parameters can be nil, which signals for the default value -- "system", "localhost", and
  the current date and time.
*/
- (id) initWithUserId:(SBString*)userId fromAddress:(SBInetAddress*)address withTimestamp:(SBDate*)timestamp;
/*!
  @method userId
  @discussion
  Returns the receiver's userId; returns nil for the default userId ("system").
*/
- (SBString*) userId;
/*!
  @method timestamp
  @discussion
  Returns the receiver's timestamp.
*/
- (SBDate*) timestamp;
/*!
  @method fromAddress
  @discussion
  Returns the IP address associated with the receiver; returns nil for the default
  address ("localhost").
*/
- (SBInetAddress*) fromAddress;

@end
