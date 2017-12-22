//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SHUEBoxPathManager.h
//
// Manages paths under the various SHUEBox trees; base paths come from
// a config file.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SHUEBox.h"
#import "SBFileManager.h"

@class SBError, SBString, SBZFSFilesystem;


/*!
  @class SHUEBoxPathManager
  @discussion
  SHUEBoxPathManager is a helper class designed solely to provide a single
  in-memory mapping between internal keys and on-disk paths to the data associated
  with that key.  For example, the path to a utility program that removes an 
  SVN repository might be keyed by the string "SVNRM" while the program that restarts
  Apache would be keyed by "APACHECTL".
  
  There is a default instance of the class that is retrieved using the
  shueboxPathManager method; this instance uses a path-mapping file named
  "paths.strpairs" found in the SHUEBoxKit's "etc" directory.
  
  Consumers may also allocate an instance of this class and initialize it to make
  use of any string-pair file on-disk.
*/
@interface SHUEBoxPathManager : SBObject
{
  id          _paths;
}

/*!
  @method shueboxPathManager
  @discussion
  Returns the shared instance of this class which uses a central, default file of
  string pairs (from SHUEBoxKit's "etc" directory).
*/
+ (id) shueboxPathManager;
/*!
  @method initWithPathMappingFile:
  @discussion
  Initialize a newly-allocated instance to wrap the path mapping string pairs found
  in the given pathMapFile.
  
  If the file cannot be opened or parsed as a string-pair file, or if the file
  contained no string pairs, the instance is released and nil is returned instead.
*/
- (id) initWithPathMappingFile:(SBString*)pathMapFile;
/*!
  @method pathForKey:
  @discussion
  If the receiver contains a path which is keyed by aKey, that path is returned.
  Otherwise, nil is returned.
*/
- (SBString*) pathForKey:(SBString*)aKey;
/*!
  @method addPathComponent:toPathForKey:
  @discussion
  If the receiver contains a path which is keyed by aKey, the given path is
  appended and the resulting path is returned.  Otherwise, nil is returned.
*/
- (SBString*) addPathComponent:(SBString*)path toPathForKey:(SBString*)aKey;
/*!
  @method createTemporaryFile:
  @discussion
  Creates a new temporary file and returns a file descriptor; if outPath is
  non-NULL then on return outPath will be set to an SBString containing the
  path to the temporary file.
*/
- (int) createTemporaryFile:(SBString**)outPath error:(SBError**)error;

@end

@interface SHUEBoxPathManager(SHUEBoxPathManagerZFS)

/*!
  @method zfsFilesystemForCollaborationId:
  @discussion
  Given a collaboration identifier, returns the ZFS filesystem that should be
  used for that collaboration.  The receiver must have a string keyed by
  SHUEBoxZFSBaseFilesystem defined for this method to work.
*/
- (SBZFSFilesystem*) zfsFilesystemForCollaborationId:(SBString*)collabId;
/*!
  @method createZFSFilesystemForCollaborationId:
  @discussion
  Given a collaboration identifier, attempts to create a new ZFS filesystem for
  that collaboration.  The receiver must have a string keyed by
  SHUEBoxZFSBaseFilesystem defined for this method to work.
  
  If a aptly-named ZFS filesystem already exists, this method merely returns
  a SBZFSFilesystem object for that extant filesystem.
*/
- (SBZFSFilesystem*) createZFSFilesystemForCollaborationId:(SBString*)collabId;

@end

@interface SHUEBoxPathManager(SHUEBoxPathManagerResourceHandling)

- (SBError*) installResource:(SBString*)resourceName inDirectory:(SBString*)directory;
- (SBError*) installResource:(SBString*)resourceName inDirectory:(SBString*)directory withInstanceName:(SBString*)instanceName;

@end

/*!
  @constant SHUEBoxZFSBaseFilesystem
  @discussion
  Key used to lookup the base ZFS filesystem under which SHUEBox collaborations
  should be created/managed.
  
  The key string itself is "zfs-fs-prefix".
*/
extern SBString* SHUEBoxZFSBaseFilesystem;

/*!
  @constant SHUEBoxResourceBundlePath
  @discussion
  Key used to lookup the path to SHUEBox's static filesystem resources
  (file and directory templates, etc).
  
  The key string itself is "resource-bundle".
*/
extern SBString* SHUEBoxResourceBundlePath;

/*!
  @constant SHUEBoxApacheConfsPath
  @discussion
  Key used to lookup the path to the per-collaboration Apache configuration
  files' directory.
  
  The key string itself is "apache-confs".
*/
extern SBString* SHUEBoxApacheConfsPath;

/*!
  @constant SHUEBoxApachectlPath
  @discussion
  Key used to lookup the path to the Apache "apachectl" utility.
  
  The key string itself is "apachectl".
*/
extern SBString* SHUEBoxApachectlPath;

/*!
  @constant SHUEBoxTmpPath
  @discussion
  Key used to lookup the directory which should be used for
  temporary files.
  
  The key string itself is "tmp-path".
*/
extern SBString* SHUEBoxTmpPath;
