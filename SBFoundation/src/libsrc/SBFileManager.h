//
// SBFoundation : ObjC Class Library for Solaris
// SBFileManager.h
//
// Helpful utilities for working with files/directories.
//
// $Id$
//

#import "SBObject.h"
#import "SBEnumerator.h"

@class SBString, SBData, SBDirectoryEnumerator;

/*!
  @class SBFileManager
  @discussion
    The SBFileManager class is designed to streamline interactions with file attributes.  A
    single shared instance is provided, so consumer code should never need to directly
    allocate an instance of this class.
*/
@interface SBFileManager : SBObject
{
}

/*!
  @method sharedFileManager
  @discussion
    Returns the shared instance of SBFileManager.
*/
+ (id) sharedFileManager;
/*!
  @method workingDirectoryPath
  @discussion
    Returns a string containing the current working directory for the program.
*/
- (SBString*) workingDirectoryPath;
/*!
  @method setWorkingDirectoryPath:
  @discussion
    Attempt to set the program's current working directory to path.  Returns
    YES if successful.
*/
- (BOOL) setWorkingDirectoryPath:(SBString*)path;
/*!
  @method pathExists
  @discussion
    Returns YES if the receiver represents an extant UNIX file path.
*/
- (BOOL) pathExists:(SBString*)path;
/*!
  @method fileExistsAtPath
  @discussion
    Returns YES if the receiver represents an extant UNIX file path and the entity
    is a file (not a socket, directory, symlink, etc.).
*/
- (BOOL) fileExistsAtPath:(SBString*)path;
/*!
  @method directoryExistsAtPath
  @discussion
    Returns YES if the receiver represents an extant UNIX file path and the entity
    is a directory (not a socket, file, symlink, etc.).
*/
- (BOOL) directoryExistsAtPath:(SBString*)path;
/*!
  @method isReadableFileAtPath
  @discussion
    Returns YES if the receiver represents a UNIX file path that is deemed "readable"
    by the program (via the access() function).
*/
- (BOOL) isReadableFileAtPath:(SBString*)path;
/*!
  @method isWritableFileAtPath
  @discussion
    Returns YES if the receiver represents a UNIX file path that is deemed "writable"
    by the program (via the access() function).
*/
- (BOOL) isWritableFileAtPath:(SBString*)path;
/*!
  @method isExecutableFileAtPath
  @discussion
    Returns YES if the receiver represents a UNIX file path that is deemed "executable"
    by the program (via the access() function).
*/
- (BOOL) isExecutableFileAtPath:(SBString*)path;

/*!
  @method openPath:withFlags:mode:
  @discussion
    Attempts to open the file at the UNIX file path represented by the receiver.
    Returns NULL if the file could not be opened.
*/
- (int) openPath:(SBString*)path withFlags:(int)openFlags mode:(mode_t)mode;

/*!
  @method openPath:asCFileStreamWithMode:
  @discussion
    Attempts to open the file at the UNIX file path represented by the receiver.
    Returns NULL if the file could not be opened.
*/
- (FILE*) openPath:(SBString*)path asCFileStreamWithMode:(const char*)mode;

/*!
  @method posixPermissionsAtPath:
  @discussion
    If path is an extant UNIX file path, returns the permissions mask of the entity.
*/
- (mode_t) posixPermissionsAtPath:(SBString*)path;
/*!
  @method setPosixPermissions:atPath:
  @discussion
    If path is an extant UNIX file path, attempts to set the entity's permissions
    mask to mode.  Returns YES if successful.
*/
- (BOOL) setPosixPermissions:(mode_t)mode atPath:(SBString*)path;
/*!
  @method ownerUIdAtPath:
  @discussion
    Returns the UNIX user id number of the user-owner of the entity at path.
*/
- (uid_t) ownerUIdAtPath:(SBString*)path;
/*!
  @method ownerGIdAtPath:
  @discussion
    Returns the UNIX group id number of the group-owner of the entity at path.
*/
- (gid_t) ownerGIdAtPath:(SBString*)path;
/*!
  @method setOwnerUId:atPath:
  @discussion
    If path is an extant UNIX file path, attempts to set the user-owner of the
    entity to userId.  Returns YES if successful.
*/
- (BOOL) setOwnerUId:(uid_t)userId atPath:(SBString*)path;
/*!
  @method setOwnerUId:andGId:atPath:
  @discussion
    If path is an extant UNIX file path, attempts to set the user-owner of the
    entity to userId and the group-owner to groupId.  Returns YES if successful.
*/
- (BOOL) setOwnerUId:(uid_t)userId andGId:(gid_t)groupId atPath:(SBString*)path;
/*!
  @method setOwnerUId:andGId:posixMode:atPath:
  @discussion
    If path is an extant UNIX file path, attempts to set the user-owner of the
    entity to userId and the group-owner to groupId.  Also sets the permissions
    mask to mode.  Returns YES if successful.
    
    Computationally more efficient than separate calls to setOwnerUId:andGId:atPath:
    and setPosixPermissions:atPath:.
*/
- (BOOL) setOwnerUId:(uid_t)userId andGId:(gid_t)groupId posixMode:(mode_t)mode atPath:(SBString*)path;

/*!
  @method removeFileAtPath:
  @discussion
    Attempts to delete the entity at the given UNIX file path.  Returns YES if
    the entity is not a directory and the current user had permission to delete
    the entity.
*/
- (BOOL) removeFileAtPath:(SBString*)path;
/*!
  @method removeItemAtPath:
  @discussion
    Attempts to delete the entity at the given UNIX file path.  For non-directory
    entities, behaves just like removeFileAtPath:.  For a directory, the directory
    and all of its content (sub-directories and files) are removed.  Returns YES if
    successful.
*/
- (BOOL) removeItemAtPath:(SBString*)path;

/*!
  @method movePath:toPath:
  @discussion
    Attempts to rename the entity at src to dest.  Note that this method will fail
    and return NO if the two paths reside on different filesystems!
*/
- (BOOL) movePath:(SBString*)src toPath:(SBString*)dest;

/*!
  @method enumeratorAtPath:
  @discussion
    Returns an SBDirectoryEnumerator that walks the contents of the directory at
    path.
*/
- (SBDirectoryEnumerator*) enumeratorAtPath:(SBString*)path;
/*!
  @method createDirectoryAtPath:
  @discussion
    If path is not an extant UNIX file path, create a new directory at path with default
    permissions and ownership.  Returns YES if successful.
*/
- (BOOL) createDirectoryAtPath:(SBString*)path;
/*!
  @method createDirectoryAtPath:mode:
  @discussion
    If path is not an extant UNIX file path, create a new directory at path with default
    ownership and permissions specified by mode.  Returns YES if successful.
*/
- (BOOL) createDirectoryAtPath:(SBString*)path mode:(mode_t)mode;
/*!
  @method contentsAtPath:
  @discussion
    Attempts to open the file at path and read its content into memory.  If successful,
    an SBData object containing the file's content is returned.  Otherwise, nil is
    returned.
*/  
- (SBData*) contentsAtPath:(SBString*)path;
/*!
  @method createFileAtPath:contents:
  @discussion
    Attempts to open the file at path for writing (creating it if not present) and
    writes the contents of the data object to the file.  Returns YES if successful.
*/
- (BOOL) createFileAtPath:(SBString*)path contents:(SBData*)data;

@end

/*!
  @class SBDirectoryEnumerator
  @discussion
    A public sub-class of SBEnumerator that is used for walking the contents of a
    directory.  Each invocation of "nextObject" steps the receiver to the next child
    entity of the directory; this class's accessor methods operate on the in-scope
    child entity.
*/
@interface SBDirectoryEnumerator : SBEnumerator

/*!
  @method ownerUId
  @discussion
    Returns the Unix user id number of the user-owner of the in-scope child entity.
*/  
- (uid_t) ownerUId;
/*!
  @method ownerGId
  @discussion
    Returns the Unix group id number of the group-owner of the in-scope child entity.
*/  
- (gid_t) ownerGId;
/*!
  @method posixPermissions
  @discussion
    Returns the permissions mask for the in-scope child entity.
*/  
- (mode_t) posixPermissions;
/*!
  @method isDirectory
  @discussion
    Returns YES if the in-scope child entity is a directory.
*/
- (BOOL) isDirectory;

@end
