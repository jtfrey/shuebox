//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBInetAddress.h
//
// Class cluster that represents IPv4 and IPv6 addresses.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBObject.h"
#include <sys/types.h>
#include <sys/socket.h>

@class SBString, SBData;


/*!
  @typedef SBInetAddressFamily
  
  Identifiers for the address families supported by this class cluster.  Note
  that they do _not_ necessarily correspond to the system's family identifier
  types!
*/
typedef enum {
  kSBInetAddressUnknownFamily = 0,
  kSBInetAddressIPv4Family,
  kSBInetAddressIPv6Family
} SBInetAddressFamily;


/*!
  @typedef SBInetAddressData
  
  Variable-length data structure that wraps an Internet address.  This typedef
  is present solely to define the ordering of fields as exported by this class's
  inetAddressAsData method.
*/
typedef struct {
  unsigned char   family;
  unsigned char   totalBitLength;
  unsigned char   prefixBitLength;
  unsigned char   bytes[1];
} SBInetAddressData;


/*!
  @class SBInetAddress
  
  SBInetAddress objects are used to wrap IPv4 and IPv6 address information.  This
  encompasses both host address as well as networks (e.g. a CIDR).
  
  Instances can be instantiated from:
  
    * a byte array containing the binary address
    * a byte array with an explicit prefix length
    * a sockaddr structure (AF_INET or AF_INET6)
    * a string containing an appropriate textual form for the address/CIDR
  
  Both C strings and SBString objects can be parsed.
  
  Do not directly allocate or initialize instances of SBInetAddress; this class
  represents the top of a private class cluster.  Instead, use the inetAddressWith...
  class methods to create instances.
*/
@interface SBInetAddress : SBObject

/*!
  @method inetAddressWithIPv4Bytes:
  
  Create an autoreleased object which wraps the IPv4 address provided in binary
  form -- an array of four bytes.
*/
+ (SBInetAddress*) inetAddressWithIPv4Bytes:(const void*)bytes;
/*!
  @method inetAddressWithIPv4Bytes:prefixLength:
  
  Create an autoreleased object which wraps the IPv4 address provided in binary
  form -- an array of four bytes.  Only the leading prefixLength bits are
  considered significant.
*/
+ (SBInetAddress*) inetAddressWithIPv4Bytes:(const void*)bytes prefixLength:(unsigned int)prefixLength;
/*!
  @method inetAddressWithIPv6Bytes:
  
  Create an autoreleased object which wraps the IPv6 address provided in binary
  form -- an array of sixteen bytes.
*/
+ (SBInetAddress*) inetAddressWithIPv6Bytes:(const void*)bytes;
/*!
  @method inetAddressWithIPv6Bytes:prefixLength:
  
  Create an autoreleased object which wraps the IPv6 address provided in binary
  form -- an array of sixteen bytes.  Only the leading prefixLength bits are
  considered significant.
*/
+ (SBInetAddress*) inetAddressWithIPv6Bytes:(const void*)bytes prefixLength:(unsigned int)prefixLength;
/*!
  @method inetAddressWithSockAddr:
  
  Given an (externally initialized) sockaddr data structure, create an autoreleased
  object which wraps the Internet address contained in that struct.  Since the sockaddr
  structure allows for both IPv4 and IPv6 addresses, the returned object is created
  according to the address family indicated in sockAddr.
*/
+ (SBInetAddress*) inetAddressWithSockAddr:(struct sockaddr*)sockAddr;
/*!
  @method inetAddressWithCString:
  
  Attempt to parse an Internet address from a nul-terminated C string.  The address can
  have a suffix of "/[0-9]+" which provides the significant bit count (prefix length)
  that should be applied to the parsed address.  The parsed address may be either IPv4
  or IPv6 format; the parsing is accomplished using the inet_pton() function -- see its
  manual page for more information.
  
  For IPv4 addresses, the form of "address/netmask" is also valid, e.g.
  
    128.175.13.92/255.255.255.192
    
*/
+ (SBInetAddress*) inetAddressWithCString:(const char*)cString;
/*!
  @method inetAddressWithString:
  
  Same behavior as inetAddressWithCString: but operates on the content of an SBString
  object.
*/
+ (SBInetAddress*) inetAddressWithString:(SBString*)aString;


/*!
  @method addressFamily
  
  Returns a constant from the SBInetAddressFamily which indicates what kind of Internet
  address is represented by the receiver.
*/
- (SBInetAddressFamily) addressFamily;

/*!
  @method prefixBitLength
  
  Returns the number of network-significant bits in the receiver.
*/
- (unsigned int) prefixBitLength;
/*!
  @method totalBitLength
  
  Returns the total number of bits in the receiver's Internet address.
*/
- (unsigned int) totalBitLength;
/*!
  @method byteLength
  
  Returns the number of bytes necessary to hold the receiver's Internet address.
*/
- (unsigned int) byteLength;
/*!
  @method isEqualToInetAddress:
  
  Compare the receiver to another SBInetAddress; returns TRUE if the addresses are equivalent.
*/
- (BOOL) isEqualToInetAddress:(SBInetAddress*)anotherAddress;
/*!
  @method compareToInetAddress:
  
  Compare the receiver to another SBInetAddress, returning a value from the SBComparisonResult
  enumartion to indicate the ordering of the two addresses (ascending, descending, same).
*/
- (SBComparisonResult) compareToInetAddress:(SBInetAddress*)anotherAddress;
/*!
  @method copyAddressBytes:length:
  
  Copies at most "length" bytes of the recevier's address to the provided
  memory buffer.  If length is larger than the receiver's required byte count,
  then only those many bytes are copied and the rest of buffer is untouched.
  
  Returns the actual number of bytes copied to buffer.
*/
- (size_t) copyAddressBytes:(void*)buffer length:(size_t)length;
/*!
  @method copyMaskedAddressBytes:length:
  
  Copies at most "length" bytes of the recevier's address to the provided
  memory buffer.  If length is larger than the receiver's required byte count,
  then only those many bytes are copied and the rest of buffer is untouched.
  
  This method actually respects the prefixLength and zeroes any bits outside
  that range as it copies them into the destination buffer.
  
  Returns the actual number of bytes copied to buffer.
*/
- (size_t) copyMaskedAddressBytes:(void*)buffer length:(size_t)length;
/*!
  @method setSockAddr:byteSize:
  
  Initializes the provided sockaddr data structure to contain the receiver's
  Internet address.  The byteSize is used to determine whether the provided
  sockaddr structure is large enough to hold the receiver's address -- we
  don't just blindly copy into sockAddr, in other words.
*/
- (BOOL) setSockAddr:(struct sockaddr*)sockAddr byteSize:(size_t)byteSize;
/*!
  @method inetAddressAsString
  
  Returns an SBString object that contains a textual rendition of the
  receiver's Internet address.
*/
- (SBString*) inetAddressAsString;
/*!
  @method inetAddressAsData
  
  Returns an SBData object that contains the receiver's Internet address.
*/
- (SBData*) inetAddressAsData;

@end
