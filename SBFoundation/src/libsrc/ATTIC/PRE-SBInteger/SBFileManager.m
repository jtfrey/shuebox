//
// SBFoundation : ObjC Class Library for Solaris
// SBFileManager.h
//
// Helpful utilities for working with files/directories.
//
// $Id$
//

#import "SBFileManager.h"
#import "SBString.h"
#import "SBData.h"

#include <sys/types.h>
#include <dirent.h>

//

int
__SBFileManagerRmDir(
  const char*   d
)
{
  DIR*      dh = opendir(d);
  int       rc = 0;
  
  if ( dh ) {
    struct dirent   *de;
    struct stat     metaData;
    size_t          dlen = strlen(d);
    
    while ( (de = readdir(dh)) ) {
      // Don't bother with . and ..
      if ( ! ( (de->d_name[0] == '.') && ((de->d_name[1] == '\0') || ((de->d_name[1] == '.') && (de->d_name[2] == '\0'))) ) ) {
        size_t        fullpathlen = dlen + strlen(de->d_name) + 2;
        char          fullpath[fullpathlen];
        struct stat   metaData;
        
        snprintf(fullpath, fullpathlen, "%s/%s", d, de->d_name);
        if ( stat(fullpath, &metaData) == 0 ) {
          if ( (metaData.st_mode & S_IFDIR) != 0 ) {
            // Descend into directory:
            rc = __SBFileManagerRmDir(fullpath);
            if ( rc == 0 ) {
              // Directory should be empty, remove it now:
              if ( rmdir(fullpath) != 0 ) {
                rc = errno;
                break;
              }
            } else {
              break;
            }
          } else if ( unlink(fullpath) != 0 ) {
            rc = errno;
            break;
          }
        } else {
          rc = errno;
          break;
        }
      }
    }
    closedir(dh);
    
    // Remove the directory itself!
    if ( rmdir(d) != 0 )
      rc = errno;
  } else {
    rc = ENOENT;
  }
  return rc;
}

//

@interface SBFileManager(SBFileManagerPrivate)

- (BOOL) getStat:(struct stat*)statPtr forPath:(SBString*)path;

@end

@implementation SBFileManager(SBFileManagerPrivate)

  - (BOOL) getStat:(struct stat*)statPtr
    forPath:(SBString*)path
  {
    SBSTRING_AS_UTF8_BEGIN(path)
    
      return ( stat(path_utf8, statPtr) == 0 );
    
    SBSTRING_AS_UTF8_END
    
    return NO;
  }

@end

//
#pragma mark -
//

@implementation SBDirectoryEnumerator

  - (id) nextObject { return nil; }
  - (uid_t) ownerUId { return -1; }
  - (gid_t) ownerGId { return -1; }
  - (mode_t) posixPermissions { return 0; }
  - (BOOL) isDirectory { return NO; }

@end

//
#pragma mark -
//

@interface SBConcreteDirectoryEnumerator : SBDirectoryEnumerator
{
  char*             _dirPath;
  DIR*              _dirHandle;
  SBMutableString*  _entryName;
  uid_t             _ownerUId;
  gid_t             _ownerGId;
  mode_t            _posixPermissions;
  BOOL              _isDirectory;
}

- (id) initWithPath:(const char*)path;

@end

@implementation SBConcreteDirectoryEnumerator

  - (id) initWithPath:(const char*)path
  {
    if ( self = [super init] ) {
      _ownerUId = _ownerGId = -1;
      _posixPermissions = 0;
      _isDirectory = NO;
      
      _dirHandle = opendir(path);
      if ( _dirHandle ) {
        _entryName = [[SBMutableString alloc] init];
        _dirPath = strdup(path);
      }
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    if ( _dirHandle )
      closedir(_dirHandle);
    if ( _entryName )
      [_entryName release];
    if ( _dirPath )
      free(_dirPath);
    [super dealloc];
  }
  
//

  - (id) nextObject
  {
    if ( _dirHandle ) {
      struct dirent   *dirEntry;
      struct stat     metaData;
      
      if ( (dirEntry = readdir(_dirHandle)) ) {
        UChar         slash = ((UChar)0x002f);
        
        [_entryName deleteAllCharacters];
        [_entryName appendFormat:"%s/%s", _dirPath, dirEntry->d_name];
        
        if ( [[SBFileManager sharedFileManager] getStat:&metaData forPath:_entryName] ) {
          _ownerUId = metaData.st_uid;
          _ownerGId = metaData.st_gid;
          _posixPermissions = metaData.st_mode & (S_IRWXU | S_IRWXG | S_IRWXO | S_ISUID | S_ISGID | S_ISVTX);
          _isDirectory = ( (metaData.st_mode & S_IFDIR) != 0 );
        }
        
        [_entryName deleteAllCharacters];
        [_entryName setWithUTF8String:dirEntry->d_name];
        
        return _entryName;
      } else {
        closedir(_dirHandle); _dirHandle = NULL;
        [_entryName release]; _entryName = nil;
        free(_dirPath);
        _ownerUId = _ownerGId = -1;
        _posixPermissions = 0;
        _isDirectory = NO;
      }
    }
    return _entryName;
  }

//

  - (uid_t) ownerUId { return _ownerUId; }
  - (gid_t) ownerGId { return _ownerGId; }
  - (mode_t) posixPermissions { return _posixPermissions; }
  - (BOOL) isDirectory { return _isDirectory; }

@end

//
#pragma mark -
//

@implementation SBFileManager

  + (id) sharedFileManager
  {
    static SBFileManager*   __sharedFileManager = nil;
    
    if ( __sharedFileManager == nil )
      __sharedFileManager = [[[SBFileManager alloc] init] retain];
    return __sharedFileManager;
  }
  
//

  - (SBDirectoryEnumerator*) enumeratorAtPath:(SBString*)path
  {
    SBSTRING_AS_UTF8_BEGIN(path)
    
      if ( directoryExists(path_utf8) )
        return [[[SBConcreteDirectoryEnumerator alloc] initWithPath:path_utf8] autorelease];
    
    SBSTRING_AS_UTF8_END
    
    return nil;
  }
  
//

  - (SBString*) workingDirectoryPath
  {
    SBString*   result = nil;
    char*       workingDir = getcwd(NULL, 0);
    
    if ( workingDir ) {
      result = [SBString stringWithUTF8String:workingDir];
      free(workingDir);
    }
    return result;
  }
  - (BOOL) setWorkingDirectoryPath:(SBString*)path
  {
    SBSTRING_AS_UTF8_BEGIN(path)
    
      return ( chdir(path_utf8) == 0 );
    
    SBSTRING_AS_UTF8_END
    
    return NO;
  }

//

  - (BOOL) movePath:(SBString*)src
    toPath:(SBString*)dest
  {
    int       rc;
    
    SBSTRING_AS_UTF8_BEGIN(src)
      SBSTRING_AS_UTF8_BEGIN(dest)
      
        rc = rename(src_utf8, dest_utf8);
        return ( rc == 0 );
      
      SBSTRING_AS_UTF8_END
    SBSTRING_AS_UTF8_END
    
    return NO;
  }

//

  - (BOOL) pathExists:(SBString*)path
  {
    struct stat     metaData;
    
    return [self getStat:&metaData forPath:path];
  }
  - (BOOL) fileExistsAtPath:(SBString*)path
  {
    struct stat     metaData;
    
    if ( [self getStat:&metaData forPath:path] )
      return ( (metaData.st_mode & S_IFREG) == S_IFREG );
    return NO;
  }
  - (BOOL) directoryExistsAtPath:(SBString*)path
  {
    struct stat     metaData;
    
    if ( [self getStat:&metaData forPath:path] )
      return ( (metaData.st_mode & S_IFDIR) == S_IFDIR );
    return NO;
  }

//

  - (BOOL) isReadableFileAtPath:(SBString*)path
  {
    SBSTRING_AS_UTF8_BEGIN(path)
    
      return ( access(path_utf8, R_OK) == 0 );
    
    SBSTRING_AS_UTF8_END
    return NO;
  }
  - (BOOL) isWritableFileAtPath:(SBString*)path
  {
    SBSTRING_AS_UTF8_BEGIN(path)
    
      return ( access(path_utf8, W_OK) == 0 );
    
    SBSTRING_AS_UTF8_END
    return NO;
  }
  - (BOOL) isExecutableFileAtPath:(SBString*)path
  {
    SBSTRING_AS_UTF8_BEGIN(path)
    
      return ( access(path_utf8, X_OK) == 0 );
    
    SBSTRING_AS_UTF8_END
    return NO;
  }

//

  - (mode_t) posixPermissionsAtPath:(SBString*)path
  {
    struct stat     metaData;
    
    if ( [self getStat:&metaData forPath:path] )
      return ( metaData.st_mode & (S_IRWXU | S_IRWXG | S_IRWXO | S_ISUID | S_ISGID | S_ISVTX) );
    return 0;
  }
  - (BOOL) setPosixPermissions:(mode_t)mode
    atPath:(SBString*)path
  {
    SBSTRING_AS_UTF8_BEGIN(path)
    
      return ( chmod(path_utf8, mode) == 0 );
    
    SBSTRING_AS_UTF8_END
    
    return NO;
  }

//

  - (uid_t) ownerUIdAtPath:(SBString*)path
  {
    struct stat     metaData;
    
    if ( [self getStat:&metaData forPath:path] )
      return metaData.st_uid;
    return -1;
  }
  
//

  - (gid_t) ownerGIdAtPath:(SBString*)path
  {
    struct stat     metaData;
    
    if ( [self getStat:&metaData forPath:path] )
      return metaData.st_gid;
    return -1;
  }
  
//

  - (BOOL) setOwnerUId:(uid_t)userId
    atPath:(SBString*)path
  {
    SBSTRING_AS_UTF8_BEGIN(path)
    
      return ( chown(path_utf8, userId, -1) == 0 );
    
    SBSTRING_AS_UTF8_END
    
    return NO;
  }
  
//

  - (BOOL) setOwnerUId:(uid_t)userId
    andGId:(gid_t)groupId
    atPath:(SBString*)path
  {
    SBSTRING_AS_UTF8_BEGIN(path)
    
      return ( chown(path_utf8, userId, groupId) == 0 );
    
    SBSTRING_AS_UTF8_END
    
    return NO;
  }
  
//

  - (BOOL) setOwnerUId:(uid_t)userId
    andGId:(gid_t)groupId
    posixMode:(mode_t)mode
    atPath:(SBString*)path
  {
    SBSTRING_AS_UTF8_BEGIN(path)
    
      if ( chown(path_utf8, userId, groupId) == 0 )
        return ( chmod(path_utf8, mode) == 0 );
    
    SBSTRING_AS_UTF8_END
    
    return NO;
  }
  
//

  - (BOOL) removeFileAtPath:(SBString*)path
  {
    SBSTRING_AS_UTF8_BEGIN(path)
    
      return ( unlink(path_utf8) == 0 );
    
    SBSTRING_AS_UTF8_END
    
    return NO;
  }
  
//

  - (BOOL) removeItemAtPath:(SBString*)path
  {
    SBSTRING_AS_UTF8_BEGIN(path)
    
      struct stat     metaData;
      
      if ( stat(path_utf8, &metaData) == 0 ) {
        if ( (metaData.st_mode & S_IFDIR) == S_IFDIR ) {
          // Directory:  we need to do a recursive removal:
          return ( __SBFileManagerRmDir(path_utf8) == 0 );
        } else {
          return ( unlink(path_utf8) == 0 );
        }
        
      }
      
    SBSTRING_AS_UTF8_END
    
    return NO;
  }
  
//

  - (BOOL) createDirectoryAtPath:(SBString*)path
  {
    return [self createDirectoryAtPath:path mode:0777];
  }
  - (BOOL) createDirectoryAtPath:(SBString*)path
    mode:(mode_t)mode
  {
    SBSTRING_AS_UTF8_BEGIN(path)
    
      return ( mkdir(path_utf8, mode) == 0 );
    
    SBSTRING_AS_UTF8_END
    
    return NO;
  }

//

  - (SBData*) contentsAtPath:(SBString*)path
  {
    return [SBData dataWithContentsOfFile:path];  
  }
  
//

  - (BOOL) createFileAtPath:(SBString*)path
    contents:(SBData*)data
  {
    SBSTRING_AS_UTF8_BEGIN(path)
    
      int         fd;
      size_t      len, written;
      
      if ((fd = open (path_utf8, O_WRONLY|O_TRUNC|O_CREAT, 0666)) < 0)
        return NO;

      written = (len = [data length]) ? write(fd, [data bytes], len) : 0;
      close (fd);

      return (written == len);
    
    SBSTRING_AS_UTF8_END
    
    return NO;
  }

//

  - (int) openPath:(SBString*)path
    withFlags:(int)openFlags
    mode:(mode_t)mode
  {
    SBSTRING_AS_UTF8_BEGIN(path)
      return open(path_utf8, openFlags, mode);
    SBSTRING_AS_UTF8_END
    
    return -1;
  }

//

  - (FILE*) openPath:(SBString*)path
    asCFileStreamWithMode:(const char*)mode
  {
    SBSTRING_AS_UTF8_BEGIN(path)
      return fopen(path_utf8, mode);
    SBSTRING_AS_UTF8_END
    
    return NULL;
  }

@end
