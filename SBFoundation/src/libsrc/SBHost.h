//
// SBFoundation : ObjC Class Library for Solaris
// SBHost.h
//
// A basic interface to DNS name/address resolution.
//
// $Id$
//

#import "SBObject.h"

@class SBString, SBInetAddress, SBArray;

/*!
  @class SBHost
  @discussion
  Instances of SBHost are used to retrieve hostname-to-address and address-to-hostname
  DNS mappings.  Both IPv4 and IPv6 addresses are retrieved, with IPv4 given precedence.
*/
@interface SBHost : SBObject
{
  SBArray*      _hostnames;
  SBArray*      _ipAddresses;
}
/*!
  @method currentHost
  @discussion
  Returns an autoreleased instance which wraps the hostname and IP address information
  for the host on which the program is running.
*/
+ (SBHost*) currentHost;
/*!
  @method hostWithName:
  @discussion
  Returns an autoreleased instance initialized with the hostnames and addresses that
  getipnodebyname() was able to find for the given hostname.
*/
+ (SBHost*) hostWithName:(SBString*)hostname;
/*!
  @method hostWithIPAddress:
  @discussion
  Returns an autoreleased instance initialized with the hostnames and addresses that
  getipnodebyname() was able to find for the hostname associated with ipAddress (as
  determined by getipnodebyaddr()).
*/
+ (SBHost*) hostWithIPAddress:(SBInetAddress*)ipAddress;
/*!
  @method isEqualToHost:
  @discussion
  Returns YES if aHost _at least_ contains our primary hostname and ipAddress in
  its own hostnames and ipAddresses arrays.
*/
- (BOOL) isEqualToHost:(SBHost*)aHost;
/*!
  @method hostname
  @discussion
  Returns the (arbitrary) first element of the receiver's hostnames array.
*/
- (SBString*) hostname;
/*!
  @method hostnames
  @discussion
  Returns the receiver's (unordered) array of hostnames.
*/
- (SBArray*) hostnames;
/*!
  @method ipAddress
  @discussion
  Returns the (arbitrary) first element of the receiver's ipAddresses array.
*/
- (SBInetAddress*) ipAddress;
/*!
  @method ipAddresses
  @discussion
  Returns the receiver's (unordered) array of IP addresses.
*/
- (SBArray*) ipAddresses;

@end
