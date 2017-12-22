//
// SBFoundation : ObjC Class Library for Solaris
// SBMACAddress.h
//
// Class which handles MAC addresses.  Lots borrowed from my ieee-oui code
// for MAC-to-Manuf resolution.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBObject.h"

@class SBString;

/*!
  @typedef SBMACAddressFormat
  
  Constants which should be used to specify the textual output format
  for a MAC address.
  
  One value each from the "delimiter" and "grouping" constant sets can
  be OR'ed together to create a "composite" format type (see the
  "compiled" set that follows).
*/
typedef enum {
  /* Digit-delimiter constants: */
  SBMACAddressColonDelimFormat = 0,
  SBMACAddressHyphenDelimFormat = 1,
  SBMACAddressDotDelimFormat = 2,
  SBMACAddressDelimMask = 0xF,
  
  /* Digit-grouping constants: */
  SBMACAddressSixByteFormat = 0 << 4,
  SBMACAddressThreeWordFormat = 1 << 4,
  SBMACAddressTwoTripletFormat = 2 << 4,
  SBMACAddressNoDelimFormat = 3 << 4,
  SBMACAddressGroupingMask = 0xF0,
  
  /* "Compiled" constants: */
  SBMACAddressDefaultFormat = 0,
  SBMACAddressDottedFormat = SBMACAddressDotDelimFormat | SBMACAddressThreeWordFormat
} SBMACAddressFormat;


/*!
  @class SBMACAddress
  @discussion
  Instances of SBMACAddress represent Ethernet hardware addresses.  A MAC address is
  technically 6 unsigned bytes; the first three bytes represent an originating entity
  which owns the MAC address space in which the address is resident.
  
  Instances can be created from binary representation (6 bytes) or from text strings.
  The format of the incoming text string is very loose:  essentially, any non-hex
  characters can be used to separate the sequences of hex digits; a sequence of hex
  digits is implicitly left-padded by '0' if not of even length; and any string
  yielding zero bytes is considered invalid while a string yielding less than six
  bytes will be considered valid with any unfilled bytes of the MAC address being set
  to zero.
*/
@interface SBMACAddress : SBObject
{
  unsigned char       _bytes[6];
}

/*!
  @method macAddressWithBytes:
  
  Create an autoreleased instance initialized with the first six bytes of data at
  "bytes".
  
  If "bytes" is NULL then nil is returned.
*/
+ (SBMACAddress*) macAddressWithBytes:(const void*)bytes;
/*!
  @method macAddressWithCString:
  
  Create an autoreleased instance initialized by scanning the passed-in cString
  for byte sequences -- see the SBMACAddress class documentation for a description
  of the acceptable string formatting.
  
  If cString is NULL then nil is returned.
*/
+ (SBMACAddress*) macAddressWithCString:(const char*)cString;
/*!
  @method macAddressWithString:
  
  Behaves the same as macAddressWithCString: but operates on an SBString object.
  
  If aString is NULL then nil is returned.
*/
+ (SBMACAddress*) macAddressWithString:(SBString*)aString;

/*!
  @method initWithBytes:
  
  Initialize a newly-allocated instance using the first six bytes resident at
  "bytes".
*/
- (id) initWithBytes:(const void*)bytes;
/*!
  @method initWithCString:
  
  Initialize a newly-allocated instance by scanning the passed-in cString for
  byte sequences -- see the SBMACAddress class documentation for a description
  of the acceptable string formatting.
*/
- (id) initWithCString:(const char*)cString;
/*!
  @method initWithString:
  
  Behaves the same as initWithCString: but operates on an SBString object.
*/
- (id) initWithString:(SBString*)aString;

/*!
  @method isEqualToMACAddress:
  
  Returns YES if the receiver and aMACAddr contain the same address.
*/
- (BOOL) isEqualToMACAddress:(SBMACAddress*)aMACAddr;
/*!
  @method compareToMACAddress:
  
  Compare the receiver to another SBMACAddress, returning a value from the SBComparisonResult
  enumartion to indicate the ordering of the two addresses (ascending, descending, same).
*/
- (SBComparisonResult) compareToMACAddress:(SBMACAddress*)aMACAddr;
/*!
  @method copyAddressBytes:length:
  
  Copies at most "length" bytes of the recevier's address to the provided
  memory buffer.  If length is larger than six, then only six bytes are copied
  and the rest of buffer is untouched.
  
  Returns the actual number of bytes copied to buffer.
*/
- (SBUInteger) copyAddressBytes:(unsigned char*)buffer length:(SBUInteger)length;
/*!
  @method macAddressAsStringWithFormat:
  
  Returns an SBString object that contains a textual rendition of the
  receiver's MAC address.  The format argument dictates what byte-grouping
  and delimiter character should be used, e.g. two-triplet with dot
  delimiter producing
  
    012345.6789ab
    
  and three-word with hyphen producing
  
    0123-4567-89ab
    
  The default format is the most-often-seen
  
    01:23:45:67:89:ab
    
*/
- (SBString*) macAddressAsStringWithFormat:(SBMACAddressFormat)format;

@end

#ifdef WANT_EXTENDED_SBMACADDRESS

/*!
  @category SBMACAddress(SBMACAddressManufacturerLookup)
  
  Additions to SBMACAddress that extend its functionality beyond simply holding a
  MAC address.
*/
@interface SBMACAddress(SBMACAddressManufacturerLookup)

/*!
  @method manufacturerName
  
  Attempt to resolve the OUI portion of the receiver's MAC address to a specific
  manufacturer.  If found, returns the registered manufacturer name as an
  SBString.  Otherwise, nil is returned. 
*/
- (SBString*) manufacturerName;

@end

#endif /* WANT_EXTENDED_SBMACADDRESS */
