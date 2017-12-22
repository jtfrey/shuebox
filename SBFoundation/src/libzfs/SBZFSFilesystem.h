//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SBZFSFilesystem.h
//
// Utility routines for working with ZFS filesystems.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SBObject.h"

#include <libzfs.h>
#include <sys/fs/zfs.h>

/*!
  @defined SBZFSFilesystemDefaultMountpoint
  @discussion
  For clarity of consumer code, this macro may be used to indicate to the
  initWithNewZFSFilesystem:mountPoint:mounted: method that the default (inherited)
  mountPoint should be used for the new filesystem that is created.
*/
#define SBZFSFilesystemDefaultMountpoint    (nil)


enum {
  SBZFSCompressionTypeUnknown,
  SBZFSCompressionTypeNone,
  SBZFSCompressionTypeDefault,
  SBZFSCompressionTypeLZJB
};
typedef SBUInteger SBZFSCompressionType;

@class SBString;

/*!
  @class SBZFSFilesystem
  @discussion
  An instance of SBZFSFilesystem presents an interface to a ZFS "filesystem" storage
  entity.  The class provides methods to aid in getting/setting quota limits, reservations,
  and actual usage.
  
  Any filesystem for which a quota is not set will inherit it's parent filesystem's
  properties.  In the case of SHUEBox, this will basically amount of a filesystem with
  no quota limit; thus, the availableByteCount returned will be the available size of
  the entire ZFS pool.
*/
@interface SBZFSFilesystem : SBObject
{
  SBString*     _filesystem;
  zfs_handle_t* _zfsHandle;
}
/*!
  @method createZFSFilesystem:
  @discussion
  Convenience method which attempts to create a new ZFS filesystem (using the provided
  filesystem name).  Uses the default mountpoint and attempts to mount the filesystem
  if successful.
  
  Returns an autoreleased SBZFSFilesystem instance which wraps the new filesystem if
  successful.
*/
+ (id) createZFSFilesystem:(SBString*)filesystem;
/*!
  @method destroyZFSFilesystem:
  @discussion
  Attempts to destroy the given ZFS filesystem; returns YES if successful.
*/
+ (BOOL) destroyZFSFilesystem:(SBString*)filesystem;
/*!
  @method initWithZFSFilesystem:
  @discussion
  Initialize a newly-allocated instance to provide an interface to the given ZFS
  filesystem.  The filesystem is _not_ the VFS path of the volume:  e.g. would
  be "shuebox/collaborations/nss-code".
  
  Returns nil if the given filesystem could not be found or if the ZFS library
  failed to initialize.
*/
- (id) initWithZFSFilesystem:(SBString*)filesystem;
/*!
  @method initWithNewZFSFilesystem:mountPoint:mounted:
  @discussion
  Create a new ZFS filesystem (named according to filesystem) which mounts at the
  specified mountpoint.  If the mountPoint is nil, then the inherited/default
  mountpoint will be used.  If mounted is YES, then the instance will also
  attempt to mount the filesystem before returing.
  
  If filesystem is an extant ZFS filesystem, this method is equivalent to calling the
  initWithZFSFilesystem: method.
  
  Returns nil under any condition of failure.
*/
- (id) initWithNewZFSFilesystem:(SBString*)filesystem mountPoint:(SBString*)mountPoint mounted:(BOOL)mounted;
/*!
  @method zfsFilesystem
  @discussion
  Returns the ZFS filesystem name associated with the receiver.
*/
- (SBString*) zfsFilesystem;
/*!
  @method isMounted
  @discussion
  Returns YES if the receiver's ZFS filesystem is mounted.
*/
- (BOOL) isMounted;
/*!
  @method setIsMounted:
  @discussion
  Attempts to mount or unmount the receiver's ZFS filesystem based on mounted
  being YES or NO, respectively.  Returns YES if the state was successfully
  set.
*/
- (BOOL) setIsMounted:(BOOL)mounted;
/*!
  @method mountPoint
  @discussion
  Returns the VFS mountpoint of the receiver's ZFS filesystem.
*/
- (SBString*) mountPoint;
/*!
  @method quotaByteCount
  @discussion
  Returns the number of bytes in the quota limit for the receiver's ZFS filesystem.
*/
- (uint64_t) quotaByteCount;
/*!
  @method setQuotaByteCount:
  @discussion
  Attempts to modify the number of bytes in the quota limit for the receiver's ZFS
  filesystem.  Returns YES if successful.
  
  Note that the calling program must have the appropriate (root-like) privileges in
  order to modify a ZFS filesystem property like this.
*/
- (BOOL) setQuotaByteCount:(uint64_t)byteCount;
/*!
  @method reservedByteCount
  @discussion
  Returns the number of bytes of reserved storage for the receiver's ZFS filesystem.
*/
- (uint64_t) reservedByteCount;
/*!
  @method setReservedByteCount:
  @discussion
  Attempts to modify the number of bytes of reserved storage for the receiver's ZFS
  filesystem.  Returns YES if successful.
  
  Note that the calling program must have the appropriate (root-like) privileges in
  order to modify a ZFS filesystem property like this.
*/
- (BOOL) setReservedByteCount:(uint64_t)byteCount;
/*!
  @method inUseByteCount
  @discussion
  Returns the number of bytes being used by the receiver's ZFS filesystem.
*/
- (uint64_t) inUseByteCount;
/*!
  @method availableByteCount
  @discussion
  Returns the number of bytes remaining unused by the receiver's ZFS filesystem.
*/
- (uint64_t) availableByteCount;
/*!
  @method compressionType
  @discussion
  Returns the kind of driver-level compression enabled on the receiver's ZFS
  filesystem.
*/
- (SBZFSCompressionType) compressionType;
/*!
  @method setCompressionType:
  @discussion
  Attempts to set the kind of driver-level compression enabled on the receiver's
  ZFS filesystem.
*/
- (BOOL) setCompressionType:(SBZFSCompressionType)compressionType;
/*!
  @method writeStatusSummaryToStream:
  @discussion
  Prints quota, reservation, usage statistics to the given stream.
*/
- (void) writeStatusSummaryToStream:(FILE*)stream;

@end

/*!
  @category SBZFSFilesystem(SBZFSFilesystemNaturalPropertyValues)
  @discussion
  This category groups convenience methods which present the numerical ZFS filesystem
  properties in a more natural, user-friendly manner:  megabytes and percentages.
*/
@interface SBZFSFilesystem(SBZFSFilesystemNaturalPropertyValues)

/*!
  @method quotaMegabytes
  @discussion
  Returns the receiver's quota limit in units of megabytes.
*/
- (SBUInteger) quotaMegabytes;
/*!
  @method setQuotaMegabytes:
  @discussion
  Calls through to setQuotaByteCount: after converting megabytes to bytes (multiplying
  by 1024^2).
  
  See setQuotaByteCount: for return values, etc.
*/
- (BOOL) setQuotaMegabytes:(SBUInteger)megabytes;
/*!
  @method reservedMegabytes
  @discussion
  Returns the receiver's storage reservation in units of megabytes.
*/
- (SBUInteger) reservedMegabytes;
/*!
  @method setReservedMegabytes:
  @discussion
  Calls through to setReservedByteCount: after converting megabytes to bytes (multiplying
  by 1024^2).
  
  See setReservedByteCount: for return values, etc.
*/
- (BOOL) setReservedMegabytes:(SBUInteger)megabytes;
/*!
  @method inUsePercentage
  @discussion
  Returns the percentage of the total space alloted to the receiver's ZFS filesystem
  that is actually in use.
  
  Range is 0.0 to 100.0.
*/
- (float) inUsePercentage;
/*!
  @method availablePercentage
  @discussion
  Returns the percentage of the total space alloted to the receiver's ZFS filesystem
  that is not currently use.
  
  Range is 0.0 to 100.0.
*/
- (float) availablePercentage;

@end
