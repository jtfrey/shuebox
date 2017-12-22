//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SBZFSManager.h
//
// Utility routines for working with ZFS filesystems.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SBZFSFilesystem.h"
#import "SBString.h"

libzfs_handle_t*
__SBZFSManager_GetLibHandle()
{
  static libzfs_handle_t*     sharedLibHandle = NULL;
  
  if ( sharedLibHandle == NULL )
    sharedLibHandle = libzfs_init();
  return sharedLibHandle;
}

//

@interface SBZFSFilesystem(SBZFSFilesystemPrivate)

- (id) initWithZFSHandle:(zfs_handle_t*)zfsHandle forFilesystem:(SBString*)filesystem;

@end

@implementation SBZFSFilesystem(SBZFSFilesystemPrivate)

  - (id) initWithZFSHandle:(zfs_handle_t*)zfsHandle
    forFilesystem:(SBString*)filesystem
  {
    if ( self = [self init] ) {
      _zfsHandle = zfsHandle;
      _filesystem = [filesystem copy];
    }
    return self;
  }

@end

//
#pragma mark -
//

@implementation SBZFSFilesystem : SBObject

  + (id) createZFSFilesystem:(SBString*)filesystem
  {
    return [[[SBZFSFilesystem alloc] initWithNewZFSFilesystem:filesystem mountPoint:SBZFSFilesystemDefaultMountpoint mounted:YES] autorelease];
  }

//

  + (BOOL) destroyZFSFilesystem:(SBString*)filesystem
  {
    libzfs_handle_t*    zfsLibHandle = __SBZFSManager_GetLibHandle();
    BOOL                rc = NO;
    
    if ( zfsLibHandle ) {
      SBSTRING_AS_UTF8_BEGIN(filesystem)
#ifdef ZFS_NEW_API
        zfs_handle_t*   zfsHandle = zfs_open(zfsLibHandle, filesystem_utf8, ZFS_TYPE_DATASET);
#else
        zfs_handle_t*   zfsHandle = zfs_open(zfsLibHandle, filesystem_utf8, ZFS_TYPE_ANY);
#endif
        
        if ( zfsHandle ) {
          if ( zfs_unmount(zfsHandle, NULL, 0) == 0 ) {
#ifdef ZFS_NEW_API
            rc = ( zfs_destroy(zfsHandle, 0) == 0 );
#else
            rc = ( zfs_destroy(zfsHandle) == 0 );
#endif
          }
          zfs_close(zfsHandle);
        }
        
      SBSTRING_AS_UTF8_END
    }
    return rc;
  }

//

  - (id) initWithZFSFilesystem:(SBString*)filesystem
  {
    libzfs_handle_t*    zfsLibHandle = __SBZFSManager_GetLibHandle();
    
    if ( zfsLibHandle ) {
      SBSTRING_AS_UTF8_BEGIN(filesystem)
#ifdef ZFS_NEW_API
        zfs_handle_t*   zfsHandle = zfs_open(zfsLibHandle, filesystem_utf8, ZFS_TYPE_DATASET);
#else
        zfs_handle_t*   zfsHandle = zfs_open(zfsLibHandle, filesystem_utf8, ZFS_TYPE_ANY);
#endif
        
        if ( zfsHandle )
          self = [self initWithZFSHandle:zfsHandle forFilesystem:filesystem];
      
      SBSTRING_AS_UTF8_END
    }
    if ( _zfsHandle == NULL ) {
      [self release];
      self = nil;
    }
    return self;
  }
  
//

  - (id) initWithNewZFSFilesystem:(SBString*)filesystem
    mountPoint:(SBString*)mountPoint
    mounted:(BOOL)mounted
  {
    libzfs_handle_t*    zfsLibHandle = __SBZFSManager_GetLibHandle();
    
    if ( zfsLibHandle ) {
      SBSTRING_AS_UTF8_BEGIN(filesystem)
      
        // Does filesystem exist?
#ifdef ZFS_NEW_API
        zfs_handle_t*     zfsHandle = zfs_open(zfsLibHandle, filesystem_utf8, ZFS_TYPE_DATASET);
#else
        zfs_handle_t*     zfsHandle = zfs_open(zfsLibHandle, filesystem_utf8, ZFS_TYPE_ANY);
#endif
        nvlist_t*         props = NULL;
        int               rc;
        
        if ( zfsHandle )
          return [self initWithZFSHandle:zfsHandle forFilesystem:filesystem];
        
        // Nope, try to create it:
        if ( mountPoint ) {
          if ( nvlist_alloc(&props, NV_UNIQUE_NAME, 0) == 0 ) {
            if ( nvlist_add_string(props, zfs_prop_to_name(ZFS_PROP_MOUNTPOINT), [mountPoint utf8Characters]) != 0 ) {
              nvlist_free(props);
              [self release];
              return nil;
            }
          }
        }
        rc = zfs_create(zfsLibHandle, filesystem_utf8, ZFS_TYPE_FILESYSTEM, props);
        if ( props )
          nvlist_free(props);
        if ( rc != 0 ) {
          [self release];
          return nil;
        }
#ifdef ZFS_NEW_API
        zfsHandle = zfs_open(zfsLibHandle, filesystem_utf8, ZFS_TYPE_DATASET);
#else
        zfsHandle = zfs_open(zfsLibHandle, filesystem_utf8, ZFS_TYPE_ANY);
#endif
        if ( zfsHandle )
          self = [self initWithZFSHandle:zfsHandle forFilesystem:filesystem];
          
      SBSTRING_AS_UTF8_END
    }
    if ( _zfsHandle == NULL ) {
      [self release];
      self = nil;
    } else if ( mounted ) {
      [self setIsMounted:YES];
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _filesystem ) [_filesystem release];
    if ( _zfsHandle ) zfs_close(_zfsHandle);
    [super dealloc];
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    char            mp[MAXPATHLEN];
    int             rc = zfs_prop_get(
                              _zfsHandle,
                              ZFS_PROP_MOUNTPOINT,
                              mp,
                              MAXPATHLEN,
                              NULL,
                              NULL,
                              0,
                              B_FALSE
                            );
                            
    [super summarizeToStream:stream];
    fprintf(stream, " {\n  filesystem: ");
    [_filesystem writeToStream:stream];
    fprintf(
        stream,
        "  mount point: %s\n"
        "  is mouned:   %s\n"
        "}\n",
        ( rc == 0 ? mp : "<default>" ),
        ( [self isMounted] ? "yes" : "no" )
      );
  }

//

  - (SBString*) zfsFilesystem
  {
    return _filesystem;
  }

//

  - (SBString*) mountPoint
  {
    char            mp[MAXPATHLEN];
    int             rc = zfs_prop_get(
                              _zfsHandle,
                              ZFS_PROP_MOUNTPOINT,
                              mp,
                              MAXPATHLEN,
                              NULL,
                              NULL,
                              0,
                              B_FALSE
                            );
    
    if ( rc == 0 )
      return [SBString stringWithUTF8String:mp];
    return nil;
  }

//

  - (BOOL) isMounted
  {
    char*     mountPoint = NULL;
    
    return ( zfs_is_mounted(_zfsHandle, &mountPoint) == B_TRUE );
  }
  - (BOOL) setIsMounted:(BOOL)mounted
  {
    BOOL      rc = YES;
    
    if ( mounted != [self isMounted] ) {
      if ( ! mounted ) {
        rc = ( zfs_unmount(_zfsHandle, NULL, 0) == 0 );
      } else {
        int     RC = zfs_mount(_zfsHandle, NULL, 0);
        
        rc = (RC == 0 );
      }
    }
    return rc;
  }

//

  - (uint64_t) quotaByteCount
  {
    return zfs_prop_get_int(_zfsHandle, ZFS_PROP_QUOTA);
  }
  - (BOOL) setQuotaByteCount:(uint64_t)byteCount
  {
    int       rc = 0;
    
    if ( byteCount > 0 ) {
      char          byteCountAsString[64];
      
      snprintf(byteCountAsString, 64, "%llu", byteCount);

#ifdef ZFS_PROP_SET_USES_ENUM
      rc = zfs_prop_set(_zfsHandle, ZFS_PROP_QUOTA, byteCountAsString);
    } else {
      rc = zfs_prop_set(_zfsHandle, ZFS_PROP_QUOTA, "none");
#else
      rc = zfs_prop_set(_zfsHandle, zfs_prop_to_name(ZFS_PROP_QUOTA), byteCountAsString);
    } else {
      rc = zfs_prop_set(_zfsHandle, zfs_prop_to_name(ZFS_PROP_QUOTA), "none");
#endif
    }
    return ( rc == 0 );
  }
  
//

  - (uint64_t) reservedByteCount
  {
    return zfs_prop_get_int(_zfsHandle, ZFS_PROP_RESERVATION);
  }
  - (BOOL) setReservedByteCount:(uint64_t)byteCount
  {
    int       rc = 0;
    
    if ( byteCount > 0 ) {
      char          byteCountAsString[64];
      
      snprintf(byteCountAsString, 64, "%llu", byteCount);

#ifdef ZFS_PROP_SET_USES_ENUM
      rc = zfs_prop_set(_zfsHandle, ZFS_PROP_RESERVATION, byteCountAsString);
    } else {
      rc = zfs_prop_set(_zfsHandle, ZFS_PROP_RESERVATION, "none");
#else
      rc = zfs_prop_set(_zfsHandle, zfs_prop_to_name(ZFS_PROP_RESERVATION), byteCountAsString);
    } else {
      rc = zfs_prop_set(_zfsHandle, zfs_prop_to_name(ZFS_PROP_RESERVATION), "none");
#endif
    }
    return ( rc == 0 );
  }
  
//

  - (uint64_t) inUseByteCount
  {
    return zfs_prop_get_int(_zfsHandle, ZFS_PROP_USED);
  }
  
//

  - (uint64_t) availableByteCount
  {
    return zfs_prop_get_int(_zfsHandle, ZFS_PROP_AVAILABLE);
  }

//

  - (void) writeStatusSummaryToStream:(FILE*)stream
  {
    char            mp[MAXPATHLEN];
    int             rc = zfs_prop_get(
                              _zfsHandle,
                              ZFS_PROP_MOUNTPOINT,
                              mp,
                              MAXPATHLEN,
                              NULL,
                              NULL,
                              0,
                              B_FALSE
                            );
                            
    [_filesystem writeToStream:stream];
    fprintf(
        stream,
        " {\n"
        "  mount point:      %s\n"
        "  is mounted:       %s\n"
        "  quota:            %llu (%u MB)\n"
        "  reservation:      %llu (%u MB)\n"
        "  usage:            %.2f%% (%llu bytes)\n"
        "  compression-type: " SBUIntegerFormat "\n"
        "}\n",
        ( rc == 0 ? mp : "<default>" ),
        ( [self isMounted] ? "yes" : "no" ),
        [self quotaByteCount], [self quotaMegabytes],
        [self reservedByteCount], [self reservedMegabytes],
        [self inUsePercentage], [self inUseByteCount],
        [self compressionType]
      );
  }

//

  - (SBZFSCompressionType) compressionType
  {
    char      property[ZFS_MAXPROPLEN];
    int       rc = zfs_prop_get(_zfsHandle, ZFS_PROP_COMPRESSION, property, sizeof(property), NULL, NULL, 0, B_FALSE);
    
    if ( rc == 0 ) {
      if ( strcmp(property, "off") == 0 )
        return SBZFSCompressionTypeNone;
      if ( strcmp(property, "on") == 0 )
        return SBZFSCompressionTypeDefault;
      if ( strcmp(property, "lzjb") == 0 )
        return SBZFSCompressionTypeLZJB;
    }
    return SBZFSCompressionTypeUnknown;
  }
  - (BOOL) setCompressionType:(SBZFSCompressionType)compressionType
  {
    int       rc = 1;
    char*     type = NULL;
    
    switch ( compressionType ) {
      
      case SBZFSCompressionTypeNone:
        type = "off";
        break;
        
      case SBZFSCompressionTypeDefault:
        type = "on";
        break;
        
      case SBZFSCompressionTypeLZJB:
        type = "lzjb";
        break;
        
      default:
        // Invalid compression type:
        break;
        
    }
    if ( type )
#ifdef ZFS_PROP_SET_USES_ENUM
      rc = zfs_prop_set(_zfsHandle, ZFS_PROP_COMPRESSION, type);
#else
      rc = zfs_prop_set(_zfsHandle, zfs_prop_to_name(ZFS_PROP_COMPRESSION), type);
#endif
    return ( rc == 0 );
  }
  
//

@end

//
#pragma mark -
//

@implementation SBZFSFilesystem(SBZFSFilesystemNaturalPropertyValues)

  - (SBUInteger) quotaMegabytes
  {
    uint64_t        bytes = [self quotaByteCount];
    
    return (SBUInteger)( bytes >> 20 );
  }
  - (BOOL) setQuotaMegabytes:(SBUInteger)megabytes
  {
    uint64_t        bytes = ((uint64_t)megabytes) << 20;
    
    return [self setQuotaByteCount:bytes];
  }
  - (SBUInteger) reservedMegabytes
  {
    uint64_t        bytes = [self reservedByteCount];
    
    return (SBUInteger)( bytes >> 20 );
  }
  - (BOOL) setReservedMegabytes:(SBUInteger)megabytes
  {
    uint64_t        bytes = ((uint64_t)megabytes) << 20;
    
    return [self setReservedByteCount:bytes];
  }
  - (float) inUsePercentage
  {
    uint64_t        used = [self inUseByteCount];
    uint64_t        avail = [self availableByteCount];
    
    return (100.f) * (float)((double)used / (double)(used + avail));
  }
  - (float) availablePercentage
  {
    uint64_t        used = [self inUseByteCount];
    uint64_t        avail = [self availableByteCount];
    
    return (100.f) * (float)((double)avail / (double)(used + avail));
  }

@end
