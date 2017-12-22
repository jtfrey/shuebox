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

@interface SBFileManager : SBObject
{
}

+ (id) sharedFileManager;

- (SBString*) workingDirectoryPath;
- (BOOL) setWorkingDirectoryPath:(SBString*)path;

/*!
  @method pathExists
  
  Returns YES if the receiver represents an extant UNIX file path.
*/
- (BOOL) pathExists:(SBString*)path;

- (BOOL) fileExistsAtPath:(SBString*)path;
- (BOOL) directoryExistsAtPath:(SBString*)path;
- (BOOL) isReadableFileAtPath:(SBString*)path;
- (BOOL) isWritableFileAtPath:(SBString*)path;
- (BOOL) isExecutableFileAtPath:(SBString*)path;

/*!
  @method openPathWithFlags:mode:

  Attempts to open the file at the UNIX file path represented by the receiver.
  Returns NULL if the file could not be opened.
*/
- (int) openPath:(SBString*)path withFlags:(int)openFlags mode:(mode_t)mode;

/*!
  @method openPathAsCFileStreamWithMode:

  Attempts to open the file at the UNIX file path represented by the receiver.
  Returns NULL if the file could not be opened.
*/
- (FILE*) openPath:(SBString*)path asCFileStreamWithMode:(const char*)mode;

- (mode_t) posixPermissionsAtPath:(SBString*)path;
- (BOOL) setPosixPermissions:(mode_t)mode atPath:(SBString*)path;

- (uid_t) ownerUIdAtPath:(SBString*)path;
- (gid_t) ownerGIdAtPath:(SBString*)path;
- (BOOL) setOwnerUId:(uid_t)userId atPath:(SBString*)path;
- (BOOL) setOwnerUId:(uid_t)userId andGId:(gid_t)groupId atPath:(SBString*)path;
- (BOOL) setOwnerUId:(uid_t)userId andGId:(gid_t)groupId posixMode:(mode_t)mode atPath:(SBString*)path;

- (BOOL) removeFileAtPath:(SBString*)path;
- (BOOL) removeItemAtPath:(SBString*)path;

- (BOOL) movePath:(SBString*)src toPath:(SBString*)dest;

- (SBDirectoryEnumerator*) enumeratorAtPath:(SBString*)path;

- (BOOL) createDirectoryAtPath:(SBString*)path;
- (BOOL) createDirectoryAtPath:(SBString*)path mode:(mode_t)mode;

- (SBData*) contentsAtPath:(SBString*)path;
- (BOOL) createFileAtPath:(SBString*)path contents:(SBData*)data;

@end

@interface SBDirectoryEnumerator : SBEnumerator

- (uid_t) ownerUId;
- (gid_t) ownerGId;
- (mode_t) posixPermissions;
- (BOOL) isDirectory;

@end
