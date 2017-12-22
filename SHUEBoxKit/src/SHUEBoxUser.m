//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SHUEBoxUser.m
//
// Class cluster which represents SHUEBox users.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SHUEBoxUser.h"
#import "SBString.h"
#import "SBArray.h"
#import "SBDictionary.h"
#import "SBDate.h"
#import "SBValue.h"
#import "SBDatabaseAccess.h"
#import "SBUser.h"
#import "SBUDUser.h"
#import "SBObjectCache.h"
#import "SBMD5Digest.h"
#import "SBMailer.h"

#import "SHUEBoxDictionary.h"
#import "SHUEBoxCollaboration.h"

SBString* SHUEBoxUserIdKey                    = @"userid";
SBString* SHUEBoxUserNativeKey                = @"native";
SBString* SHUEBoxUserShortNameKey             = @"shortname";
SBString* SHUEBoxUserFullNameKey              = @"fullname";
SBString* SHUEBoxUserCreationTimestampKey     = @"created";
SBString* SHUEBoxUserModificationTimestampKey = @"modified";
SBString* SHUEBoxUserRemovalTimestampKey      = @"removeafter";
SBString* SHUEBoxUserLastAuthTimestampKey     = @"lastauth";
SBString* SHUEBoxUserCanBeRemovedKey          = @"canberemoved";

SBObjectCache* __SHUEBoxUserCache = nil;

#ifndef SHUEBOX_INITIAL_GUEST_PASSWORD_LENGTH
#define SHUEBOX_INITIAL_GUEST_PASSWORD_LENGTH (16)
#endif

#ifndef SHUEBOX_INITIAL_GUEST_CONFIRMCODE_LENGTH
#define SHUEBOX_INITIAL_GUEST_CONFIRMCODE_LENGTH (32)
#endif

static SBString*
__SHUEBoxUserGenRndCode(
  int     length
)
{
  static const char*  rndPasswdCharSet = "AbCdEfGhIjKlMnOpQrStUvWxYz0123456789aBcDeFgHiJkLmNoPqRsTuVwXyZ!@#$%^&,.-";
    
  FILE*     urandom = fopen("/dev/urandom", "r");
  UChar     passwd[length];
  int       i = 0;
  int       modulus = strlen(rndPasswdCharSet);
  
  while ( i < length ) {
    unsigned int    idx[4];
    
    fread(&idx, 4, sizeof(unsigned int), urandom);
    idx[0] ^= (idx[1] << 5) ^ (idx[2] >> 7) ^ (idx[3] << 11);
    passwd[i++] = rndPasswdCharSet[ idx[0] % modulus ];
  }
  fclose(urandom);
  return [SBString stringWithCharacters:passwd length:length];
}

//
#pragma mark -
//

@interface SHUEBoxGuestDelegate : SBUser
{
  SHUEBoxUser*        _parent;
  SBString*           _password;
  SBString*           _newPassword;
  unsigned char       _md5Password[16];
  SBDate*             _welcomeMsgSent;
  SBDate*             _newWelcomeMsgSent;
  SBDate*             _confirmed;
  SBDate*             _newConfirmed;
  SBString*           _confirmCode;
  SBString*           _newConfirmCode;
	BOOL								_isModified;
  BOOL                _isNewUser;
}

+ (id) shueboxGuestDelegateWithParent:(SHUEBoxUser*)parent;
- (id) initWithParent:(SHUEBoxUser*)parent password:(SBString*)password md5Password:(const char*)md5Password welcomeMsgSent:(SBDate*)welcomeMsgSent confirmed:(SBDate*)confirmed confirmCode:(SBString*)confirmCode;

- (id) initNewUserWithParent:(SHUEBoxUser*)parent;

- (SBError*) sendWelcomeMessage;
- (SBError*) confirmAccountWithCode:(SBString*)confirmationCode;

@end

@interface SHUEBoxGuestDelegate(SHUEBoxGuestDelegateDatabaseStandIns)

- (BOOL) hasBeenModified;
- (void) refreshCommittedProperties;
- (void) revertModifications;
- (BOOL) commitModifications;

@end

unsigned char
__SHUEBoxUserScanHexDigit(
  char      c
)
{
  switch (c) {
    case 'A':
    case 'B':
    case 'C':
    case 'D':
    case 'E':
    case 'F':
      return 10 + (c - 'A');
    case 'a':
    case 'b':
    case 'c':
    case 'd':
    case 'e':
    case 'f':
      return 10 + (c - 'a');
    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9':
      return (c - '0');
  }
  return 0;
}

@implementation SHUEBoxGuestDelegate

  + (id) shueboxGuestDelegateWithParent:(SHUEBoxUser*)parent
  {
    SHUEBoxGuestDelegate*   delegate = nil;
    id                      queryResult = [[parent parentDatabase] executeQuery:
                                              [SBString stringWithFormat:"SELECT password, md5Password, welcomeMsgSent, confirmed, confirmCode FROM users.guest WHERE userId = %lld", [parent shueboxUserId]]
                                            ];
    if ( queryResult && [queryResult queryWasSuccessful] && [queryResult numberOfRows] ) {
      char*                 md5Password = NULL;
      
      if ( [queryResult getValuePointer:(void**)&md5Password atRow:0 fieldNum:1] ) {
        SBString*           password = [queryResult objectForRow:0 fieldNum:0];
        SBDate*             welcomeMsgSent = [queryResult objectForRow:0 fieldNum:2];
        SBDate*             confirmed = [queryResult objectForRow:0 fieldNum:3];
        SBString*           confirmCode = [queryResult objectForRow:0 fieldNum:4];
        
        delegate = [[[SHUEBoxGuestDelegate alloc] initWithParent:parent password:password md5Password:md5Password welcomeMsgSent:welcomeMsgSent confirmed:confirmed confirmCode:confirmCode] autorelease];
      }
    }
    return delegate;
  }
  
//

  - (id) initWithParent:(SHUEBoxUser*)parent
    password:(SBString*)password
    md5Password:(const char*)md5Password
    welcomeMsgSent:(SBDate*)welcomeMsgSent
    confirmed:(SBDate*)confirmed
    confirmCode:(SBString*)confirmCode
  {
    if ( self = [super init] ) {
      // NOT a reference copy, since we're really just an extension of the parent and when
      // it's deallocated so should we be!
      _parent = parent;
      
      _password = ( (password && [password isKindOf:[SBString class]]) ? [password copy] : nil );
      _welcomeMsgSent = ( (welcomeMsgSent && [welcomeMsgSent isKindOf:[SBDate class]]) ? [welcomeMsgSent retain] : nil );
      _confirmed = ( (confirmed && [confirmed isKindOf:[SBDate class]]) ? [confirmed retain] : nil );
      _confirmCode = ( (confirmCode && [confirmCode isKindOf:[SBString class]]) ? [confirmCode copy] : nil );
      
      // We can't just copy the md5Password into our buffer, since we want it in binary form:
      //memcpy(_md5Password, md5Password, 16);
      if ( md5Password ) {
        int     i = 0;
        int     md5PasswordLen = strlen(md5Password);
        
        if ( md5PasswordLen == 32 ) {
          while ( i < 16 ) {
            _md5Password[i] = 16 * __SHUEBoxUserScanHexDigit(md5Password[2 * i]) + __SHUEBoxUserScanHexDigit(md5Password[2 * i + 1]);
            i++;
          }
        } else {
          [self release];
          return nil;
        }
      } else {
        // A "null" MD5 hash won't match anything, so the user is essentially "locked":
        memset(_md5Password, 0, sizeof(_md5Password));
      }
    }
    return self;
  }

//

  - (id) initNewUserWithParent:(SHUEBoxUser*)parent
  {
    if ( (self = [super init]) ) {
      // NOT a reference copy, since we're really just an extension of the parent and when
      // it's deallocated so should we be!
      _parent = parent;
      //
      // At the least, set a random password for the new user and generate
      // an account confirmation code:
      //
      _newPassword = [(__SHUEBoxUserGenRndCode(SHUEBOX_INITIAL_GUEST_PASSWORD_LENGTH)) retain];
      _newConfirmCode = [(__SHUEBoxUserGenRndCode(SHUEBOX_INITIAL_GUEST_CONFIRMCODE_LENGTH)) retain];
      //
      // Modified and a new user:
      //
      _isModified = _isNewUser = YES;
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _password ) [_password release];
    if ( _newPassword ) [_newPassword release];
    if ( _welcomeMsgSent ) [_welcomeMsgSent release];
    if ( _newWelcomeMsgSent ) [_newWelcomeMsgSent release];
    if ( _confirmed) [_confirmed release];
    if ( _newConfirmed) [_newConfirmed release];
    if ( _confirmCode) [_confirmCode release];
    if ( _newConfirmCode) [_newConfirmCode release];
    [super dealloc];
  }

//

  - (SBString*) userPropertyForKey:(SBString*)aKey
  {
    if ( [aKey isEqualToString:SBUserIdentifierKey] )
      return [_parent shortName];
    if ( [aKey isEqualToString:SBUserFullNameKey] )
      return [_parent fullName];
    if ( [aKey isEqualToString:SBUserEmailAddressKey] )
      return [_parent shortName];
    return nil;
  }
  
//

  - (BOOL) setUserProperty:(id)value
    forKey:(SBString*)aKey
  {
    if ( [aKey isEqualToString:SBUserFullNameKey] ) {
      [_parent setFullName:value];
      return YES;
    }
		else if ( [aKey isEqualToString:SBUserPasswordKey] ) {
      // Should be a string:
      if ( value && [value isKindOf:[SBString class]] ) {
        SBString*       password = (SBString*)value;
        
        // Avoiding re-setting to the same value:
        if ( _isModified && _newPassword ) {
          if ( [password isEqual:_newPassword] )
            return YES;
        }
        else if ( _password && [password isEqual:_password] )
          return YES;
          
        password = [password copy];
        if ( _newPassword ) [_newPassword release];
        _newPassword = password;
        
				_isModified = YES;
			}
		}
    return NO;
  }
  
//

  - (BOOL) authenticateWithPassword:(SBString*)password
  {
		if ( _isModified ) {
      if ( _newPassword )
        return [_newPassword isEqual:password];
			return NO;
    }
    if ( _password )
      return [_password isEqual:password];
      
    unsigned char   md5Password[16];
    
    return ( [password md5DigestForUTF8:md5Password] && (memcmp(md5Password, _md5Password, 16) == 0) );
  }

//

  - (SBError*) sendWelcomeMessage
  {
    if ( ! _password && ! _newPassword ) {
      // Assign a random password if the receiver has none at this point:
      [self setUserProperty:__SHUEBoxUserGenRndCode(SHUEBOX_INITIAL_GUEST_PASSWORD_LENGTH) forKey:SBUserPasswordKey];
    }
    if ( ! _confirmCode && ! _newConfirmCode ) {
      // Assign a random confirmation code if the receiver has none at this point:
      _newConfirmCode = [(__SHUEBoxUserGenRndCode(SHUEBOX_INITIAL_GUEST_CONFIRMCODE_LENGTH)) retain];
      _isModified = YES;
    }
    
    if ( _welcomeMsgSent ) return nil;
    
    SBString*         baseUri = [[_parent parentDatabase] stringForFullDictionaryKey:SHUEBoxDictionarySystemBaseConfirmURIKey];
    SBString*         fromAddress = [[_parent parentDatabase] stringForFullDictionaryKey:SHUEBoxDictionarySystemAdminEmailAddressKey];
    
    if ( baseUri && fromAddress ) {
      SBMailer*     mailer = [SBMailer sharedMailer];
      
      if ( mailer ) {
        // Compose the email message:
        SBString*       uname = [_parent shortName];
        SBString*       confirmCode = ( _newConfirmCode ? _newConfirmCode : (_confirmCode ? _confirmCode : (SBString*)[SBString stringWithFormat:"[An error has occurred; please forward this message to %S]", [fromAddress utf16Characters]]));
        SBError*        error = nil;
        SBString*       welcomeMsg = [SBString stringWithFormat:
"Welcome to SHUEBox!\n\n"
"SHUEBox is a collaborative file-sharing system developed by the University of Delaware.  A SHUEBox 'collaboration' is a set of "
"native UD users as well guests like you and one or more 'repositories' in which those users can store data.  There are different "
"kinds of repositories:  WebDAV for basic file sharing; and Subversion and Git for version-controlled data storage.\n\n"
"An administrator of one such collaboration has asked that an account be created for you, and used your email address in that "
"request.\n\n"
"This email was created automatically by SHUEBox to notify you of your account's creation and to request you verify its creation "
"by navigating to the following URL in your web browser:\n\n"
"\t%S/%016llx%S\n\n",
                        [baseUri utf16Characters],
                        [_parent shueboxUserId],
                        [confirmCode utf16Characters]
                      ];
        
        if ( ! (error = [mailer startSMTPSession]) ) {
          
          if ( ! (error = [mailer sendFromAddress:fromAddress]) ) {
            // The shortName = the person's email address:
            if ( ! (error = [mailer sendRecipient:uname]) ) {
              // Send headers, explicitly the subject line:
              if ( ! (error = [mailer sendMessageHeaders:[SBDictionary dictionaryWithObjectsAndKeys:@"[SHUEBox] Please confirm your guest account", SBMailerSubjectKey, uname, SBMailerToAddressesKey, nil]]) ) {
                // Send message body:
                error = [mailer sendTextPart:welcomeMsg];
              }
            }
          }
        }
        if ( error ) {
          [mailer cancelSMTPSession];
          return error;
        } else {
          if ( (error = [mailer finishSMTPSession]) )
            return error;
          
          _newWelcomeMsgSent = [[SBDate alloc] init];
          _isModified = YES;
        }
      }
    }
    return nil;
  }
  
//

  - (SBError*) confirmAccountWithCode:(SBString*)confirmationCode
  {
    SBError*          error = nil;
    SBString*         realCode = ( _newConfirmCode ? _newConfirmCode : _confirmCode );
    
    //
    // Don't re-confirm, please:
    //
    if ( _confirmed ) return nil;
    
    //
    // Automatic failure if we have no confirmation code assigned to us:
    //
    if ( ! realCode ) return nil;
    
    //
    // Check the saved confirmation code against the incoming one:
    //
    if ( ! confirmationCode || ! [realCode isEqual:confirmationCode] ) {
      return [SBError errorWithDomain:SHUEBoxErrorDomain code:kSHUEBoxGuestConfirmationFailed
                          supportingData:[SBDictionary dictionaryWithObject:
                              [SBString stringWithFormat:"Account confirmation failure for user %lld.", [_parent shueboxUserId]]
                              forKey:SBErrorExplanationKey
                            ]
                        ];
    }
    _newConfirmed = [[SBDate alloc] init];
    _isModified = YES;
    
    SBString*         baseUri = [[_parent parentDatabase] stringForFullDictionaryKey:SHUEBoxDictionarySystemBaseURIAuthorityKey];
    SBString*         fromAddress = [[_parent parentDatabase] stringForFullDictionaryKey:SHUEBoxDictionarySystemAdminEmailAddressKey];
    
    if (  baseUri && fromAddress ) {
      SBMailer*     mailer = [SBMailer sharedMailer];
      
      if ( mailer ) {
        // Compose the email message:
        SBString*       uname = [_parent shortName];
        SBString*       passwd = (_newPassword ? _newPassword : (_password ? _password : (SBString*)[SBString stringWithFormat:"[An error has occurred; please forward this message to %S]", [fromAddress utf16Characters]]));
        SBString*       welcomeMsg = [SBString stringWithFormat:
"Welcome to SHUEBox!\n\n"
"SHUEBox is a collaborative file-sharing system developed by the University of Delaware.  A SHUEBox 'collaboration' is a set of "
"native UD users as well guests like you and one or more 'repositories' in which those users can store data.  There are different "
"kinds of repositories:  WebDAV for basic file sharing; and Subversion and Git for version-controlled data storage.\n\n"
"An administrator of one such collaboration has asked that an account be created for you, and used your email address in that "
"request.\n\n"
"Your account has been confirmed!  Here are your login credentials:\n\n"
"\tUsername:\t%S\n"
"\tPassword:\t%S\n\n"
"Please visit the SHUEBox console as soon as possible to log-in and change your password:\n\n"
"\t%S\n\n"
"From the SHUEBox console you can find the collaborations and repositories to which you have access; change your password and "
"full name for the system; and request removal of your account from the system.\n\n",
                          [uname utf16Characters],
                          [passwd utf16Characters],
                          [baseUri utf16Characters]
                      ];
        
        if ( ! (error = [mailer startSMTPSession]) ) {
          
          if ( ! (error = [mailer sendFromAddress:fromAddress]) ) {
            // The shortName = the person's email address:
            if ( ! (error = [mailer sendRecipient:uname]) ) {
              // Send headers, explicitly the subject line:
              if ( ! (error = [mailer sendMessageHeaders:[SBDictionary dictionaryWithObjectsAndKeys:@"[SHUEBox] Guest account confirmed!", SBMailerSubjectKey, uname, SBMailerToAddressesKey, nil]]) ) {
                // Send message body:
                error = [mailer sendTextPart:welcomeMsg];
              }
            }
          }
        }
        if ( error ) {
          [mailer cancelSMTPSession];
          return error;
        } else {
          if ( (error = [mailer finishSMTPSession]) )
            return error;
        }
      }
    }
    return nil;
  }

@end

@implementation SHUEBoxGuestDelegate(SHUEBoxGuestDelegateDatabaseStandIns)

	- (BOOL) hasBeenModified
	{
		return _isModified;
	}
	
//

	- (void) refreshCommittedProperties
	{
		id				queryResult = [[_parent parentDatabase] executeQuery:
                                [SBString stringWithFormat:"SELECT password, md5Password, welcomeMsgSent, confirmed, confirmCode FROM users.guest WHERE userId = %lld", [_parent shueboxUserId]]
                              ];
    if ( queryResult && [queryResult queryWasSuccessful] && [queryResult numberOfRows] ) {
      char*                 md5Password = NULL;
      
      if ( [queryResult getValuePointer:(void**)&md5Password atRow:0 fieldNum:1] ) {
        SBString*           password = [queryResult objectForRow:0 fieldNum:0];
        SBDate*             welcomeMsgSent = [queryResult objectForRow:0 fieldNum:2];
        SBDate*             confirmed = [queryResult objectForRow:0 fieldNum:3];
        SBString*           confirmCode = [queryResult objectForRow:0 fieldNum:4];
        
        memcpy(_md5Password, md5Password, 16);
        
        if ( _password ) [_password release];
        _password = ( password ? [password copy] : nil );
        
        if ( _welcomeMsgSent ) [_welcomeMsgSent release];
        _welcomeMsgSent = ( welcomeMsgSent ? [welcomeMsgSent retain] : nil );
        
        if ( _confirmed ) [_confirmed release];
        _confirmed = ( confirmCode ? [confirmCode retain] : nil );
        
        if ( _confirmCode ) [_confirmCode release];
        _confirmCode = ( confirmCode ? [confirmCode copy] : nil );
        
        if ( _newPassword ) {
          [_newPassword release];
          _newPassword = nil;
        }
        if ( _newWelcomeMsgSent ) {
          [_newWelcomeMsgSent release];
          _newWelcomeMsgSent = nil;
        }
        if ( _newConfirmed ) {
          [_newConfirmed release];
          _newConfirmed = nil;
        }
        if ( _newConfirmCode ) {
          [_newConfirmCode release];
          _newConfirmCode = nil;
        }
        
        _isModified = NO;
      }
    }
  }
	
//

	- (void) revertModifications
	{
    if ( _newPassword ) {
      [_newPassword release];
      _newPassword = nil;
    }
    if ( _newWelcomeMsgSent ) {
      [_newWelcomeMsgSent release];
      _newWelcomeMsgSent = nil;
    }
    if ( _newConfirmed ) {
      [_newConfirmed release];
      _newConfirmed = nil;
    }
    if ( _newConfirmCode ) {
      [_newConfirmCode release];
      _newConfirmCode = nil;
    }
		_isModified = NO;
	}

//

	- (BOOL) commitModifications
	{
		if ( _isNewUser || _isModified ) {
			id			database = [_parent parentDatabase];
			
			if ( database && [database beginTransaction] ) {
        SBMutableString*    queryStr = nil;
        
        if ( _isNewUser ) {
          if ( _newWelcomeMsgSent ) {
            queryStr = [[SBMutableString alloc] initWithFormat:"INSERT INTO users.guest (userId, md5Password, password, confirmCode, welcomeMsgSent) VALUES (%lld, md5('%S'), '%S', '%S', now())",
                              [_parent shueboxUserId],
                              [_newPassword utf16Characters],
                              [_newPassword utf16Characters],
                              [_newConfirmCode utf16Characters]
                            ];
          } else {
            queryStr = [[SBMutableString alloc] initWithFormat:"INSERT INTO users.guest (userId, md5Password, password, confirmCode) VALUES (%lld, md5('%S'), '%S', '%S')",
                              [_parent shueboxUserId],
                              [_newPassword utf16Characters],
                              [_newPassword utf16Characters],
                              [_newConfirmCode utf16Characters]
                            ];
          }
        } else {
          //
          // Updating extant user:
          //
          if ( _newPassword ) {
            SBString*         queryReadyPwd = [database stringEscapedForQuery:_newPassword];
            
            if ( queryReadyPwd )
              queryStr = [[SBMutableString alloc] initWithFormat:"password = '%S'",
                                [queryReadyPwd utf16Characters]
                              ];
          }
          if ( _newWelcomeMsgSent ) {
            // Textually-formatted date needed:
            SBDateFormatter*    sqlFormatter = [SBDateFormatter sqlDateFormatter];
            SBString*           dateStr = [sqlFormatter stringFromDate:_newWelcomeMsgSent];
            
            if ( dateStr ) {
              if ( queryStr ) {
                [queryStr appendFormat:", welcomeMsgSent = '%S'",
                        [dateStr utf16Characters]
                      ];
              } else {
                queryStr = [[SBMutableString alloc] initWithFormat:"welcomeMsgSent = '%S'",
                                [dateStr utf16Characters]
                              ];
              }
            }
          }
          if ( _newConfirmed ) {
            // Textually-formatted date needed:
            SBDateFormatter*    sqlFormatter = [SBDateFormatter sqlDateFormatter];
            SBString*           dateStr = [sqlFormatter stringFromDate:_newConfirmed];
            
            if ( dateStr ) {
              if ( queryStr ) {
                [queryStr appendFormat:", confirmed = '%S'",
                        [dateStr utf16Characters]
                      ];
              } else {
                queryStr = [[SBMutableString alloc] initWithFormat:"confirmed = '%S'",
                                [dateStr utf16Characters]
                              ];
              }
            }
          }
          if ( _newConfirmCode ) {
            SBString*         queryReadyCode = [database stringEscapedForQuery:_newConfirmCode];
            
            if ( queryReadyCode ) {
              if ( queryStr ) {
                [queryStr appendFormat:", confirmCode = '%S'",
                        [queryReadyCode utf16Characters]
                      ];
              } else {
                queryStr = [[SBMutableString alloc] initWithFormat:"confirmCode = '%S'",
                                [queryReadyCode utf16Characters]
                              ];
              }
            }
          }
          if ( queryStr ) {
            [queryStr insertString:@"UPDATE users.guest SET " atIndex:0];
            [queryStr appendFormat:" WHERE userId = %lld", [_parent shueboxUserId]];
          }
        }
        
        [queryStr writeToStream:stdout];
        
        if ( queryStr ) {
          BOOL      success = [database executeQueryWithBooleanResult:queryStr];
          
          [queryStr release];
          if ( success ) {
            if ( [database commitLastTransaction] ) {
              _isModified = NO;
              _isNewUser = NO;
              
              if ( _newPassword ) {
                if ( _password ) [_password release];
                _password = _newPassword;
                _newPassword = nil;
              
                [_password md5DigestForUTF8:_md5Password];
              }
              
              if ( _newWelcomeMsgSent ) {
                if ( _welcomeMsgSent ) [_welcomeMsgSent release];
                _welcomeMsgSent = _newWelcomeMsgSent;
                _newWelcomeMsgSent = nil;
              }
              
              if ( _newConfirmed ) {
                if ( _confirmed ) [_confirmed release];
                _confirmed = _newConfirmed;
                _newConfirmed = nil;
              }
              
              if ( _newConfirmCode ) {
                if ( _confirmCode ) [_confirmCode release];
                _confirmCode = _newConfirmCode;
                _newConfirmCode = nil;
              }
              
              return YES;
            }
          } else {
            [database discardLastTransaction];
          }
        } else {
          [database discardLastTransaction];
        }
      }
      return NO;
		}
		return YES;
	}

@end

//
#pragma mark -
//

@interface SHUEBoxUser(SHUEBoxUserPrivate)

- (BOOL) setupDelegate;

@end

@implementation SHUEBoxUser(SHUEBoxUserPrivate)

  - (BOOL) setupDelegate
  {
    id      delegate = nil;
    
    if ( [self isGuestUser] )
      delegate = [SHUEBoxGuestDelegate shueboxGuestDelegateWithParent:self];
    else
      delegate = [SBUDUser udUserWithUserIdentifier:[self shortName]];
    
    if ( delegate ) {
      _delegate = [delegate retain];
      return YES;
    }
    return NO;
  }

@end

//
#pragma mark -
//

@implementation SHUEBoxUser

  + (id) initialize
  {
    if ( __SHUEBoxUserCache == nil ) {
      __SHUEBoxUserCache = [[SBObjectCache alloc] initWithBaseClass:[SHUEBoxUser class]];
      
      if ( __SHUEBoxUserCache ) {
        [__SHUEBoxUserCache createCacheIndexForKey:SHUEBoxUserShortNameKey];
        [__SHUEBoxUserCache createCacheIndexForKey:SHUEBoxUserIdKey];
      }
    }
  }

//

  + (void) flushUserCache
  {
    if ( __SHUEBoxUserCache )
      [__SHUEBoxUserCache flushCache];
  }
  
//

  + (void) removeUserFromCache:(SHUEBoxUser*)aUser
  {
    if ( __SHUEBoxUserCache )
      [__SHUEBoxUserCache evictObjectFromCache:aUser];
  }

//

  + (SBString*) tableNameForClass
  {
    return @"users.base";
  }
  
//

  + (SBString*) objectIdKeyForClass
  {
    return @"userid";
  }
  
//

  + (SBArray*) propertyKeysForClass
  {
    static SBArray*     SHUEBoxUserKeys = nil;
    
    if ( SHUEBoxUserKeys == nil ) {
      SHUEBoxUserKeys = [[SBArray alloc] initWithObjects:
                                        SHUEBoxUserIdKey,
                                        SHUEBoxUserNativeKey,
                                        SHUEBoxUserShortNameKey,
                                        SHUEBoxUserFullNameKey,
                                        SHUEBoxUserCreationTimestampKey,
                                        SHUEBoxUserModificationTimestampKey,
                                        SHUEBoxUserRemovalTimestampKey,
                                        SHUEBoxUserLastAuthTimestampKey,
                                        SHUEBoxUserCanBeRemovedKey,
                                        nil
                                      ];
    }
    return SHUEBoxUserKeys;
  }

//

  + (SBArray*) shueboxUsersForRemovalWithDatabase:(id)database
  {
    id                idLookup = [database executeQuery:@"SELECT userId FROM users.base WHERE canBeRemoved AND now() > removeAfter"];
    SBUInteger        rowCount;
    SBArray*          userList = nil;
    
    if ( idLookup && [idLookup queryWasSuccessful] && (rowCount = [idLookup numberOfRows]) ) {
      SHUEBoxUser*    objects[rowCount];
      SBUInteger      index = 0;
      
      while ( rowCount-- ) {
        SBNumber*     userId = [idLookup objectForRow:rowCount fieldNum:0];
      
        if ( userId ) {
          SHUEBoxUser*  newUser = [self shueboxUserWithDatabase:database userId:[userId integerValue]];
          
          if ( newUser ) objects[index++] = [newUser retain];
        }
      }
      if ( index ) {
        userList = [SBArray arrayWithObjects:objects count:index];
        while ( index-- > 0 ) [objects[index] release];
      }
    }
    return userList;
  }

//

  + (SBArray*) shueboxUsersNeedingWelcomeMessageWithDatabase:(id)database
  {
    id                idLookup = [database executeQuery:@"SELECT userId FROM users.guest WHERE welcomeMsgSent IS NULL"];
    SBUInteger        rowCount;
    SBArray*          userList = nil;
    
    if ( idLookup && [idLookup queryWasSuccessful] && (rowCount = [idLookup numberOfRows]) ) {
      SHUEBoxUser*    objects[rowCount];
      SBUInteger      index = 0;
      
      while ( rowCount-- ) {
        SBNumber*     userId = [idLookup objectForRow:rowCount fieldNum:0];
      
        if ( userId ) {
          SHUEBoxUser*  newUser = [self shueboxUserWithDatabase:database userId:[userId integerValue]];
          
          if ( newUser ) objects[index++] = [newUser retain];
        }
      }
      if ( index ) {
        userList = [SBArray arrayWithObjects:objects count:index];
        while ( index-- > 0 ) [objects[index] release];
      }
    }
    return userList;
  }

//

  + (SBArray*) shueboxUsersForCollaboration:(SHUEBoxCollaboration*)collaboration
  {
		id								database = [collaboration parentDatabase];
    id                idLookup = [database executeQuery:[SBString stringWithFormat:"SELECT userId FROM collaboration.member WHERE collabId = " SBIntegerFormat, [collaboration collabId]]];
    SBUInteger        rowCount;
    SBArray*          userList = nil;
    
    if ( idLookup && [idLookup queryWasSuccessful] && (rowCount = [idLookup numberOfRows]) ) {
      SHUEBoxUser*    objects[rowCount];
      SBUInteger      index = 0;
      
      while ( rowCount-- ) {
        SBNumber*     userId = [idLookup objectForRow:rowCount fieldNum:0];
      
        if ( userId ) {
          SHUEBoxUser*  newUser = [self shueboxUserWithDatabase:database userId:[userId integerValue]];
          
          if ( newUser ) objects[index++] = [newUser retain];
        }
      }
      if ( index ) {
        userList = [SBArray arrayWithObjects:objects count:index];
        while ( index-- > 0 ) [objects[index] release];
      }
    }
    return userList;
  }

//

  + (id) shueboxUserWithDatabase:(id)database
    userId:(SHUEBoxUserId)userId;
  {
    id            object = nil;
    SBNumber*     objId = [SBNumber numberWithInt64:userId];
    
    if ( ! (object = [__SHUEBoxUserCache cachedObjectForKey:SHUEBoxUserIdKey value:objId]) ) {
      object = [self databaseObjectWithDatabase:database objectId:userId];
      
      if ( object ) {
        if ( [object setupDelegate] ) {
          [__SHUEBoxUserCache addObjectToCache:object];
        } else {
          object = nil;
        }
      }
    } else {
      [object refreshCommittedProperties];
    }
    return object;
  }
  
//
  
  + (id) shueboxUserWithDatabase:(id)database
    shortName:(SBString*)shortName
  {
    id            object = nil;
    
    if ( ! (object = [__SHUEBoxUserCache cachedObjectForKey:SHUEBoxUserShortNameKey value:shortName]) ) {
      object = [self databaseObjectWithDatabase:database key:SHUEBoxUserShortNameKey value:shortName];
      
      if ( object ) {
        if ( [object setupDelegate] ) {
          [__SHUEBoxUserCache addObjectToCache:object];
        } else {
          object = nil;
        }
      }
    } else {
      [object refreshCommittedProperties];
    }
    return object;
  }

//

  - (void) dealloc
  {
    if ( _delegate ) [_delegate release];
    [super dealloc];
  }

//

  - (SHUEBoxUserId) shueboxUserId
  {
    SBNumber*     userId = [self propertyForKey:SHUEBoxUserIdKey];
    
    if ( [userId isKindOf:[SBNumber class]] )
      return (SHUEBoxUserId)[userId int64Value];
    return 0;
  }

//

  - (BOOL) isGuestUser
  {
    SBNumber*     nativeFlag = [self propertyForKey:SHUEBoxUserNativeKey];
    
    if ( nativeFlag && [nativeFlag isKindOf:[SBNumber class]] )
      return ( ! [nativeFlag boolValue] );
    return YES;
  }
  
//

  - (BOOL) isSuperUser
  {
    return NO;
  }

//

  - (SBString*) shortName
  {
    SBString*     value = [self propertyForKey:SHUEBoxUserShortNameKey];
    
    if ( [value isNull] )
      return nil;
    return value;
  }
  
//

  - (SBString*) fullName
  {
    SBString*     value = [self propertyForKey:SHUEBoxUserFullNameKey];
    
    if ( [value isNull] )
      return nil;
    return value;
  }
  - (void) setFullName:(SBString*)fullName
  {
    if ( ! [fullName isEqual:[self fullName]] ) {
      [self setProperty:fullName forKey:SHUEBoxUserFullNameKey];
    }
  }
  
//

  - (SBString*) emailAddress
  {
    if ( _delegate )
      return [(SBUser*)_delegate userPropertyForKey:SBUserEmailAddressKey];
    return nil;
  }
  
//

  - (SBDate*) creationTimestamp
  {
    SBDate*     value = [self propertyForKey:SHUEBoxUserCreationTimestampKey];
    
    if ( [value isNull] )
      return nil;
    return value;
  }
  - (SBDate*) modificationTimestamp
  {
    SBDate*     value = [self propertyForKey:SHUEBoxUserModificationTimestampKey];
    
    if ( [value isNull] )
      return nil;
    return value;
  }

//

  - (BOOL) hasAuthenticated
  {
    SBDate*     value = [self propertyForKey:SHUEBoxUserLastAuthTimestampKey];
    
    if ( [value isNull] )
      return NO;
    return YES;
  }
  - (SBDate*) lastAuthenticated
  {
    SBDate*     value = [self propertyForKey:SHUEBoxUserLastAuthTimestampKey];
    
    if ( [value isNull] )
      return nil;
    return value;
  }

//

  - (BOOL) canBeRemoved
  {
    SBNumber*   value = [self propertyForKey:SHUEBoxUserCanBeRemovedKey];
    
    if ( [value isNull] )
      return NO;
    return [value boolValue];
  }
  - (SBDate*) removalTimestamp
  {
    SBDate*     value = [self propertyForKey:SHUEBoxUserRemovalTimestampKey];
    
    if ( [value isNull] )
      return nil;
    return value;
  }
  - (void) setRemovalTimestamp:(SBDate*)removalTimestamp
  {
    [self setProperty:( removalTimestamp ? (id)removalTimestamp : (id)[SBNull null] ) forKey:SHUEBoxUserRemovalTimestampKey];
  }
  - (BOOL) scheduledForRemoval
  {
    return ( [[self propertyForKey:SHUEBoxUserRemovalTimestampKey] isKindOf:[SBDate class]] );
  }
  - (BOOL) shouldBeRemoved
  {
    SBDate*       removalTime = [self propertyForKey:SHUEBoxUserRemovalTimestampKey];
    
    return ( removalTime && ([removalTime compare:[SBDate dateWhichIsAlwaysNow]] == SBOrderAscending) );
  }

//

  - (SBError*) removeFromDatabase
  {
    SHUEBoxUserId userId = [self shueboxUserId];
    SBError*      anError = nil;
    
    if ( userId > 0 ) {
      // Update the database accordingly:
      if ( ! [self deleteFromDatabase] ) {
        anError = [SBError errorWithDomain:SHUEBoxErrorDomain code:kSHUEBoxUserRemovalFailed
                      supportingData:[SBDictionary dictionaryWithObject:
                          [SBString stringWithFormat:"Unable to remove user `%S` from database.", [[self shortName] utf16Characters]]
                          forKey:SBErrorExplanationKey
                        ]
                    ];
      } else {
        // Make sure to drop us from the cache now, too:
        [SHUEBoxUser removeUserFromCache:self];
      }
    } else {
      anError = [SBError errorWithDomain:SHUEBoxErrorDomain code:kSHUEBoxUserRemovalFailed
                          supportingData:[SBDictionary dictionaryWithObject:
                              [SBString stringWithFormat:"Invalid user id : %lld.", userId]
                              forKey:SBErrorExplanationKey
                            ]
                        ];
    }
    return anError;
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    if ( _delegate )
      [_delegate summarizeToStream:stream];
  }
	
//

	- (BOOL) hasBeenModified
	{
		if ( [self isGuestUser] && _delegate && [_delegate hasBeenModified] )
			return YES;
		return [super hasBeenModified];
	}

//

	- (void) refreshCommittedProperties
	{
		if ( [self isGuestUser] && _delegate )
			[_delegate refreshCommittedProperties];
		[super refreshCommittedProperties];
	}
	
//

	- (void) revertModifications
	{
		if ( [self isGuestUser] && _delegate )
			[_delegate revertModifications];
		[super revertModifications];
	}

//

	- (BOOL) commitModifications
	{
		BOOL			rc = YES;
    
		if ( [self isGuestUser] && _delegate )
			rc = [_delegate commitModifications];
    if ( rc )
      rc = [super commitModifications];
		return rc;
	}

//
  
  - (SBError*) sendWelcomeMessage
  {
    if ( [self isGuestUser] && _delegate )
      [_delegate sendWelcomeMessage];
  }

//
  
  - (SBError*) confirmAccountWithCode:(SBString*)confirmationCode
  {
    if ( [self isGuestUser] && _delegate )
      [_delegate confirmAccountWithCode:confirmationCode];
  }

@end

//

@implementation SHUEBoxUser(SHUEBoxUserAuthentication)

	+ (id) authenticateWithDatabase:(id)database
		shortName:(SBString*)shortName
		password:(SBString*)password
	{
		SHUEBoxUser*		theUser = [SHUEBoxUser shueboxUserWithDatabase:database shortName:shortName];
		
		if ( theUser && ! [theUser authenticateUsingPassword:password] )
			theUser = nil;
		return theUser;
	}
	
//

	- (BOOL) authenticateUsingPassword:(SBString*)password
	{
		if ( _delegate )
			return [_delegate authenticateWithPassword:password];
		return NO;
	}
	
//

	- (BOOL) setPassword:(SBString*)newPassword
	{
		if ( _delegate )
			return [_delegate setUserProperty:newPassword forKey:SBUserPasswordKey];
		return NO;
	}

@end
