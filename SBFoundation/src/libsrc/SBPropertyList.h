//
// SBFoundation : ObjC Class Library for Solaris
// SBPropertyList.h
//
// Serialization of core types
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

#import "SBObject.h"

@class SBData, SBError, SBInputStream, SBOutputStream;

enum {
  kSBPropertyListImmutable                    = 0,
  kSBPropertyListMutableContainers            = 1 << 0,
  kSBPropertyListMutableContainersAndLeaves   = 1 << 0 | 1 << 1
};
typedef SBUInteger SBPropertyListMutabilityOptions;

@interface SBPropertyListSerialization : SBObject

+ (BOOL) propertyListIsValid:(id)plist;

+ (SBData*) dataWithPropertyList:(id)plist error:(SBError**)error;
+ (SBInteger) writePropertyList:(id)plist toStream:(SBOutputStream*)stream error:(SBError**)error;

+ (id) propertyListWithData:(SBData*)data options:(SBPropertyListMutabilityOptions)options error:(SBError**)error;
+ (id) propertyListWithStream:(SBInputStream*)stream options:(SBPropertyListMutabilityOptions)options error:(SBError**)error;

@end
