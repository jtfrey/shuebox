//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SHUEBoxPathManager.m
//
// Manages paths under the various SHUEBox trees; base paths come from
// a config file.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SHUEBoxPathManager.h"
#import "SBString.h"
#import "SBZFSFilesystem.h"
#import "SBDictionary.h"
#import "SBError.h"

//

SBString* SHUEBoxPathManagerDefaultMappingFile = SHUEBOXKIT_PATHMAP;

//

@interface SHUEBoxPathManager(SHUEBoxPathManagerPrivate)

- (const char*) tmpFileTemplate;

@end

@implementation SHUEBoxPathManager(SHUEBoxPathManagerPrivate)

  - (const char*) tmpFileTemplate
  {
    static char*    template = NULL;
    
    if ( template == NULL ) {
      SBString*     tmpPath = [self pathForKey:SHUEBoxTmpPath];
      
      if ( tmpPath == nil ) {
        template = "/tmp/SHUEBOX.XXXXXX";
      } else {
        size_t        tlen = [tmpPath utf8Length] + strlen("/SHUEBOX.XXXXXX") + 1;
        
        template = objc_malloc(tlen);
        if ( template ) {
          snprintf(
              template,
              tlen,
              "%s/SHUEBOX.XXXXXX",
              [tmpPath utf8Characters]
            );
        }
      }
    }
    return template;
  }

@end

//
#pragma mark -
//

@implementation SHUEBoxPathManager : SBObject

  + (id) shueboxPathManager
  {
    static SHUEBoxPathManager* sharedInstance = nil;
    
    if ( sharedInstance == nil ) {
      sharedInstance = [[SHUEBoxPathManager alloc] initWithPathMappingFile:SHUEBoxPathManagerDefaultMappingFile];
    }
    return sharedInstance;
  }

//

  - (id) initWithPathMappingFile:(SBString*)pathMapFile
  {
    if ( self = [super init] ) {
      _paths = [[SBMutableDictionary alloc] init];
      if ( _paths ) {
        if ( [_paths addElementsFromStringPairFile:pathMapFile] == 0 ) {
          [self release];
          self = nil;
        }
      } else {
        [self release];
        self = nil;
      }
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _paths ) [_paths release];
    [super dealloc];
  }

//

  - (SBString*) pathForKey:(SBString*)aKey
  {
    return [_paths objectForKey:aKey];
  }

//

  - (SBString*) addPathComponent:(SBString*)path
    toPathForKey:(SBString*)aKey
  {
    SBString*     basePath = [_paths objectForKey:aKey];
    
    if ( basePath )
      return [basePath stringByAppendingPathComponent:path];
    return nil;
  }
  
//

  - (int) createTemporaryFile:(SBString**)outPath
    error:(SBError**)error
  {
    const char*   tmpl = [self tmpFileTemplate];
    int           fd = -1;
    size_t        tmplLen = strlen(tmpl) + 1;
    
    while ( 1 ) {
      char        ltmpl[tmplLen];
      
      strncpy(ltmpl, tmpl, tmplLen);
      if ( mktemp(ltmpl) ) {
        fd = open(ltmpl, O_WRONLY | O_CREAT | O_EXCL, 0660);
        if ( fd >= 0 ) {
          if ( outPath )
            *outPath = [SBString stringWithUTF8String:ltmpl];
          if ( error )
            *error = nil;
          break;
        }
      } else {
        if ( error )
          *error = [SBError posixErrorWithCode:errno supportingData:[SBDictionary dictionaryWithObject:@"Unable to create a temporary filename (mkstemp)" forKey:SBErrorExplanationKey]]; 
        fd = -1;
        break;
      }
    }
    return fd;
  }

@end

//
#pragma mark -
//

@implementation SHUEBoxPathManager(SHUEBoxPathManagerZFS)

  - (SBZFSFilesystem*) zfsFilesystemForCollaborationId:(SBString*)collabId
  {
    SBZFSFilesystem*    zfsFS = nil;
    SBString*           baseZFS = [_paths objectForKey:SHUEBoxZFSBaseFilesystem];
    
    if ( baseZFS )
      zfsFS = [[[SBZFSFilesystem alloc] initWithZFSFilesystem:[baseZFS stringByAppendingPathComponent:collabId]] autorelease];
    return zfsFS;
  }
  
//

  - (SBZFSFilesystem*) createZFSFilesystemForCollaborationId:(SBString*)collabId
  {
    SBZFSFilesystem*    zfsFS = nil;
    SBString*           baseZFS = [_paths objectForKey:SHUEBoxZFSBaseFilesystem];
    
    if ( baseZFS )
      zfsFS = [SBZFSFilesystem createZFSFilesystem:[baseZFS stringByAppendingPathComponent:collabId]];
    return zfsFS;
  }

@end

//
#pragma mark -
//

@implementation SHUEBoxPathManager(SHUEBoxPathManagerResourceHandling)

  - (SBError*) installResource:(SBString*)resourceName
    inDirectory:(SBString*)directory
  {
    return [self installResource:resourceName inDirectory:directory withInstanceName:nil];
  }
  
//

  - (SBError*) installResource:(SBString*)resourceName
    inDirectory:(SBString*)directory
    withInstanceName:(SBString*)instanceName
  {
    SBString*         rsrcPath = [self addPathComponent:resourceName toPathForKey:SHUEBoxResourceBundlePath];
    SBString*         explanation = nil;
    int               code = 0;
    
    if ( rsrcPath && [[SBFileManager sharedFileManager] directoryExistsAtPath:rsrcPath] && [[SBFileManager sharedFileManager] directoryExistsAtPath:directory] ) {
      // Invoke the resource's install method:
      pid_t           installTask = fork();
      
      if ( installTask == 0 ) {
        //
        // Child task -- hop into the resource's directory and execute its
        // install script
        //
        [[SBFileManager sharedFileManager] setWorkingDirectoryPath:rsrcPath];
        execlp(
            "./install",
            "./install",
            [directory utf8Characters],
            ( instanceName ? [instanceName utf8Characters] : [resourceName utf8Characters] ),
            NULL
          );
      } else {
        int           status;
        
        //
        // Master task -- wait for the child to finish:
        //
        waitpid(installTask, &status, 0);
        if ( WIFEXITED(status) ) {
          int         rc = WEXITSTATUS(status);
          
          if ( rc != 0 ) {
            explanation = [SBString stringWithFormat:"Resource `%S` installer returned error code %d", [resourceName utf16Characters], rc];
            code = kSHUEBoxPathManagerResourceInstallFailed;
          }
        } else {
          explanation = [SBString stringWithFormat:"Could not call resource `%S` installer (code = %d)", [resourceName utf16Characters], status];
          code = kSHUEBoxPathManagerResourceInstallFailed;
        }
      }
      
    } else {
      explanation = [SBString stringWithFormat:"No such SHUEBox resource `%S`", [resourceName utf16Characters]];
      code = kSHUEBoxPathManagerInvalidResource;
    }
    if ( explanation )
      return [SBError errorWithDomain:SHUEBoxErrorDomain code:code
                      supportingData:[SBDictionary dictionaryWithObject:explanation forKey:SBErrorExplanationKey]
                    ];
    return nil;
  }

@end

SBString* SHUEBoxZFSBaseFilesystem = @"zfs-fs-prefix";
SBString* SHUEBoxResourceBundlePath = @"resource-bundle";
SBString* SHUEBoxApacheConfsPath = @"apache-confs";
SBString* SHUEBoxApachectlPath = @"apachectl";
SBString* SHUEBoxTmpPath = @"tmp-path";
