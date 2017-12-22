//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SHUEBoxCGI.m
//
// Basic framework for a SHUEBox CGI.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

#import "SHUEBoxCGI.h"
#import "SHUEBoxCollaboration.h"
#import "SHUEBoxRepository.h"
#import "SHUEBoxUser.h"
#import "SHUEBoxRole.h"

#import "SBDateFormatter.h"
#import "SBDictionary.h"
#import "SBString.h"
#import "SBRegularExpression.h"
#import "SBFileHandle.h"

//

SBRegularExpression*
__SHUEBoxCGICollabURIRegex(void)
{
  static SBRegularExpression*   collab_regex = nil;
  
  if ( ! collab_regex ) {
    collab_regex = [[SBRegularExpression alloc] initWithUTF8String:"^/([^/]+)/__METADATA__(/+((repository|role|member|keep-alive)(/+(([^/]+)(/+((role|member)(/+([^/]+)?)?)?)?)?)?)?)?$"];
  }
  return collab_regex;
}

//

SBRegularExpression*
__SHUEBoxCGIGuestAcctConfirmURIRegex(void)
{
  static SBRegularExpression*   confirm_regex = nil;
  
  if ( ! confirm_regex ) {
    confirm_regex = [[SBRegularExpression alloc] initWithUTF8String:"^/__CONFIRM__/([0-9A-Fa-f]{16})(.*)$"];
  }
  return confirm_regex;
}

//

@interface SHUEBoxCGI(SHUEBoxCGIPrivate)

- (void) setLastError:(SBError*)anError;
- (void) setStandardXMLResponseHeaders;
- (void) loadRequestTargets;

@end

@implementation SHUEBoxCGI(SHUEBoxCGIPrivate)

  - (void) setLastError:(SBError*)anError
  {
    if ( anError ) anError = [anError retain];
    if ( _lastError ) [_lastError release];
    _lastError = anError;
  }
  
//

  - (void) setStandardXMLResponseHeaders
  {
    [self setResponseHeaderValue:@"application/xml; charset=utf-8" forName:@"Content-type"];
    [self setResponseHeaderValue:@"SHUEBoxMetaDataServer/1.0" forName:@"Server"];
    [self setResponseHeaderValue:@"no-cache" forName:@"Pragma"];
    [self setResponseHeaderValue:@"-1" forName:@"Expires"];
    [self setResponseHeaderValue:@"no-cache" forName:@"Cache-Control"];
  }

//

  - (void) loadRequestTargets
  {
    SBHTTPMethod  method = [self requestMethod];
    SBString*     baseURI = [self pathInfo];
    
    //
    // Authentication helper?
    //
    if ( [baseURI hasPrefix:@"/__LOGIN__/"] || ([baseURI compare:@"/__LOGIN__"] == SBOrderSame) ) {
      _target = kSHUEBoxCGITargetLoginHelper;
      goto loadRequestTargetsDone;
    }
    
    //
    // The /__CONFIRM__ URI is used for confirming guest accounts:
    //
    if ( [baseURI hasPrefix:@"/__CONFIRM__/"] ) {
      SBRegularExpression*    regex = __SHUEBoxCGIGuestAcctConfirmURIRegex();
    
      if ( regex ) {
        [regex setSubjectString:baseURI];
        if ( [regex isPartialMatch] ) {
          SBString*           userIdStr = [regex stringForMatchingGroup:1];
          
          _target = kSHUEBoxCGITargetGuestAccountConfirm;
          if ( [userIdStr length] == 16 ) {
            SHUEBoxUserId     userId = 0;
            int               i = 0;
            
            while ( i < 16 ) {
              UChar             c = [userIdStr characterAtIndex:i++];
              
              userId = (userId << 4);
              switch ( c ) {
                case 'A':
                case 'B':
                case 'C':
                case 'D':
                case 'E':
                case 'F':
                  userId += 10 + (c - 'A');
                  break;
                case 'a':
                case 'b':
                case 'c':
                case 'd':
                case 'e':
                case 'f':
                  userId += 10 + (c - 'a');
                  break;
                default:
                  userId += (c - '0');
                  break;
              }
            }
            if ( (_targetSHUEBoxUser = [SHUEBoxUser shueboxUserWithDatabase:_database userId:userId]) ) {
              if ( [_targetSHUEBoxUser isGuestUser] ) {
                _targetSHUEBoxUser = [_targetSHUEBoxUser retain];
                _targetConfirmationCode = [[regex stringForMatchingGroup:2] copy];
              } else {
                [self setLastError:[SBError errorWithDomain:SHUEBoxErrorDomain 
                                        code:kSHUEBoxCGIInvalidRequest
                                        supportingData:[SBDictionary dictionaryWithObject:@"Not a guest user."
                                                            forKey:SBErrorExplanationKey
                                                          ]
                                      ]
                  ];
              }
            } else {
              [self setLastError:[SBError errorWithDomain:SHUEBoxErrorDomain 
                                      code:kSHUEBoxCGIInvalidRequest
                                      supportingData:[SBDictionary dictionaryWithObject:@"Invalid user supplied to account confirmation."
                                                          forKey:SBErrorExplanationKey
                                                        ]
                                    ]
                ];
            }
          } else {
                  [self setLastError:[SBError errorWithDomain:SHUEBoxErrorDomain 
                                          code:kSHUEBoxCGIInvalidRequest
                                          supportingData:[SBDictionary dictionaryWithObject:@"No such user."
                                                              forKey:SBErrorExplanationKey
                                                            ]
                                        ]
                    ];
          }
        } else {
                [self setLastError:[SBError errorWithDomain:SHUEBoxErrorDomain 
                                        code:kSHUEBoxCGIInvalidRequest
                                        supportingData:[SBDictionary dictionaryWithObject:@"Failed to match confirm regex."
                                                            forKey:SBErrorExplanationKey
                                                          ]
                                      ]
                  ];
        }
      } else {
              [self setLastError:[SBError errorWithDomain:SHUEBoxErrorDomain 
                                      code:kSHUEBoxCGIInvalidRequest
                                      supportingData:[SBDictionary dictionaryWithObject:@"Failed to get confirm regex."
                                                          forKey:SBErrorExplanationKey
                                                        ]
                                    ]
                ];
      }
      goto loadRequestTargetsDone;
    }
    
    //
    // The /__USERDATA__ URI is used for communicating properties for the
    // logged-in SHUEBox user:
    //
    if ( [baseURI hasPrefix:@"/__USERDATA__/"] || ([baseURI compare:@"/__USERDATA__"] == SBOrderSame) ) {
      SHUEBoxUser*  theUser = [self remoteSHUEBoxUser];
      
      if ( theUser ) {
        _target = kSHUEBoxCGITargetUserData;
        _targetSHUEBoxUser = [theUser retain];
      }
      goto loadRequestTargetsDone;
    }
    
    //
    // Eventually I'll build-in the superuser junk; for now, just set the context flag
    // and return:
    //
    if ( [baseURI hasPrefix:@"/__METADATA__/"] || ([baseURI compare:@"/__METADATA__"] == SBOrderSame) ) {
      _target = kSHUEBoxCGITargetSuperuserConsole;
      goto loadRequestTargetsDone;
    }
    
    //
    // We're handling a collaboration admin interface; extract the components:
    //
    SBRegularExpression*    regex = __SHUEBoxCGICollabURIRegex();
    
    if ( regex ) {
      [regex setSubjectString:baseURI];
      if ( [regex isPartialMatch] ) {
        SBString*           component;
        
        //
        // The regex should have the decomposed fields ready for our consumption.  Let's try
        // getting a target collaboration:
        //
        if ( (component = [regex stringForMatchingGroup:1]) && [component length] ) {
          if ( (_targetCollaboration = [[SHUEBoxCollaboration collaborationWithDatabase:_database shortName:component] retain]) ) {
            _target = kSHUEBoxCGITargetCollaboration;
            
            //
            // Does the URI reference a repository, member, etc?
            //
            if ( (component = [regex stringForMatchingGroup:4]) && [component length] ) {
              if ( [component isEqual:@"repository"] ) {
                _target = kSHUEBoxCGITargetCollaborationRepository;
                //
                // Group 7 should contain a repository id or shortname:
                //
                if ( (component = [regex stringForMatchingGroup:7]) && [component length] ) {
                  SBInteger     reposId = [component intValue];
                  
                  if ( reposId ) {
                    _targetRepository = [SHUEBoxRepository repositoryWithDatabase:_database reposId:reposId];
                  } else {
                    _targetRepository = [SHUEBoxRepository repositoryWithParentCollaboration:_targetCollaboration shortName:component];
                  }
                  
                  if ( _targetRepository ) {
                    // Ensure that the repository's parent IS the collaboration we fetched:
                    if ( [_targetRepository parentCollabId] != [_targetCollaboration collabId] ) {
                      _targetRepository = nil;
                      [self setLastError:[SBError errorWithDomain:SHUEBoxErrorDomain 
                                              code:kSHUEBoxCGIInvalidRequest
                                              supportingData:[SBDictionary dictionaryWithObject:@"The given repository is NOT associated with this collaboration."
                                                                  forKey:SBErrorExplanationKey
                                                                ]
                                            ]
                        ];
                    } else {
                      _targetRepository = [_targetRepository retain];
                      
                      //
                      // Check group 10 to see if it's "role"
                      //
                      SBString* grp10 = [regex stringForMatchingGroup:10];
                      
                      if ( grp10 && ([grp10 isEqual:@"role"]) ) {
                        _target = kSHUEBoxCGITargetCollaborationRepositoryRole;
                        
                        //
                        // Check group 12 for a role id:
                        //
                        if ( (component = [regex stringForMatchingGroup:12]) && [component length] ) {
                          if ( isdigit([component characterAtIndex:0]) ) {
                            SHUEBoxRoleId   roleId = (SHUEBoxUserId)[component longLongIntValue];
                            _targetSHUEBoxRole = [SHUEBoxRole shueboxRoleWithDatabase:_database roleId:roleId];
                          } else {
                            _targetSHUEBoxRole = [SHUEBoxRole shueboxRoleWithCollaboration:_targetCollaboration shortName:component];
                          }
                          
                          if ( ! _targetSHUEBoxRole ) {
                            [self setLastError:[SBError errorWithDomain:SHUEBoxErrorDomain 
                                                    code:kSHUEBoxCGIInvalidRequest
                                                    supportingData:[SBDictionary dictionaryWithObject:@"No such role."
                                                                        forKey:SBErrorExplanationKey
                                                                      ]
                                                  ]
                              ];
                          }
                        }
                      }
                    }
                  } else {
                    [self setLastError:[SBError errorWithDomain:SHUEBoxErrorDomain 
                                            code:kSHUEBoxCGIInvalidRequest
                                            supportingData:[SBDictionary dictionaryWithObject:@"No such repository."
                                                                forKey:SBErrorExplanationKey
                                                              ]
                                          ]
                      ];
                  }
                }
              }
              else if ( [component isEqual:@"member"] ) {
                _target = kSHUEBoxCGITargetCollaborationMember;
                //
                // Group 7 should contain a user id:
                //
                if ( (component = [regex stringForMatchingGroup:7]) && [component length] ) {
                  SHUEBoxUserId       userId = (SHUEBoxUserId)[component longLongIntValue];
                  
                  if ( userId ) {
                    _targetSHUEBoxUser = [SHUEBoxUser shueboxUserWithDatabase:_database userId:userId];
                  } else {
                    _targetSHUEBoxUser = [SHUEBoxUser shueboxUserWithDatabase:_database shortName:component];
                  }
                  
                  if ( _targetSHUEBoxUser ) {
                    // Is the user actually a member of the collaboration?
                    if ( ! [_targetCollaboration userIsMember:_targetSHUEBoxUser] ) {
                      _targetSHUEBoxUser = nil;
                      [self setLastError:[SBError errorWithDomain:SHUEBoxErrorDomain 
                                              code:kSHUEBoxCGIInvalidRequest
                                              supportingData:[SBDictionary dictionaryWithObject:@"User is not a member of the collaboration."
                                                                  forKey:SBErrorExplanationKey
                                                                ]
                                            ]
                        ];
                    }
                  } else {
                    [self setLastError:[SBError errorWithDomain:SHUEBoxErrorDomain 
                                            code:kSHUEBoxCGIInvalidRequest
                                            supportingData:[SBDictionary dictionaryWithObject:@"No such user."
                                                                forKey:SBErrorExplanationKey
                                                              ]
                                          ]
                      ];
                  }
                }
              }
              else if ( [component isEqual:@"role"] ) {
                _target = kSHUEBoxCGITargetCollaborationRole;
                //
                // Group 7 should contain a role id:
                //
                if ( (component = [regex stringForMatchingGroup:7]) && [component length] ) {
                  if ( isdigit([component characterAtIndex:0]) ) {
                    SHUEBoxRoleId       roleId = (SHUEBoxRoleId)[component longLongIntValue];
                    _targetSHUEBoxRole = [SHUEBoxRole shueboxRoleWithDatabase:_database roleId:roleId];
                  } else {
                    _targetSHUEBoxRole = [SHUEBoxRole shueboxRoleWithCollaboration:_targetCollaboration shortName:component];
                  }
                  
                  if ( _targetSHUEBoxRole ) {
                    //
                    // Check group 10 to see if it's "member"
                    //
                    SBString* grp10 = [regex stringForMatchingGroup:10];
                    
                    if ( grp10 && ([grp10 isEqual:@"member"]) ) {
                      _target = kSHUEBoxCGITargetCollaborationRoleMember;
                      
                      //
                      // Check group 12 for a user id:
                      //
                      if ( (component = [regex stringForMatchingGroup:12]) && [component length] ) {
                        SHUEBoxUserId   userId = (SHUEBoxUserId)[component longLongIntValue];
                        
                        if ( userId ) {
                          _targetSHUEBoxRoleMember = [SHUEBoxUser shueboxUserWithDatabase:_database userId:userId];
                        } else {
                          _targetSHUEBoxRoleMember = [SHUEBoxUser shueboxUserWithDatabase:_database shortName:component];
                        }
                        
                        if ( ! _targetSHUEBoxRoleMember ) {
                          [self setLastError:[SBError errorWithDomain:SHUEBoxErrorDomain 
                                                  code:kSHUEBoxCGIInvalidRequest
                                                  supportingData:[SBDictionary dictionaryWithObject:@"No such user."
                                                                      forKey:SBErrorExplanationKey
                                                                    ]
                                                ]
                            ];
                        }
                      }
                    }
                  } else {
                    [self setLastError:[SBError errorWithDomain:SHUEBoxErrorDomain 
                                            code:kSHUEBoxCGIInvalidRequest
                                            supportingData:[SBDictionary dictionaryWithObject:@"No such role."
                                                                forKey:SBErrorExplanationKey
                                                              ]
                                          ]
                      ];
                  }
                }
              }
              else if ( [component isEqual:@"keep-alive"] ) {
                _target = kSHUEBoxCGITargetKeepAlive;
              }
            }
          }
        }
      }
      [regex setSubjectString:nil];
    }

loadRequestTargetsDone:
    _targetsAreLoaded = YES;
  }

@end

//
#pragma mark -
//

@implementation SHUEBoxCGI

  - (id) initWithDatabase:(id)database
  {
    if ( (self = [super init]) ) {
      if ( database )
        _database = [database retain];
      [self setStandardXMLResponseHeaders];
      _target = kSHUEBoxCGITargetUndefined;
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _database ) [_database release];
    
    if ( _remoteSHUEBoxUser ) [_remoteSHUEBoxUser release];
    
    if ( _targetCollaboration ) [_targetCollaboration release];
    if ( _targetRepository ) [_targetRepository release];
    if ( _targetSHUEBoxUser ) [_targetSHUEBoxUser release];
    if ( _targetConfirmationCode ) [_targetConfirmationCode release];
    
    [super dealloc];
  }

//

  - (SHUEBoxUser*) remoteSHUEBoxUser
  {
    SBString*   userFromEnv = [super remoteUser];
    
    if ( userFromEnv )
      _remoteSHUEBoxUser = [[SHUEBoxUser shueboxUserWithDatabase:_database shortName:userFromEnv] retain];
    return _remoteSHUEBoxUser;
  }

//

  - (SBString*) textDocumentFromStdin
  {
    SBData*         rawDoc = [[SBFileHandle fileHandleWithStandardInput] readDataToEndOfFile];
    SBString*       textDoc = nil;
    
    if ( rawDoc ) {
      // Convert to a string given a specified charset on the Content-Type; for no charset, assume
      // ISO-8859-1
      SBMIMEType*   myType = [self contentType];
      SBString*     myEncoding = nil;
      
      if ( myType )
        myEncoding = [myType parameterForName:@"Charset"];
      
      textDoc = [[[SBString alloc] initWithData:rawDoc encoding:( myEncoding ? (const char*)[myEncoding utf8Characters] : (const char*)"ISO-8859-1" )] autorelease];
    }
    return textDoc;
  }

//

  - (SBXMLDocument*) xmlDocumentFromStdin
  {
    SBString*       textDoc = [self textDocumentFromStdin];
    SBXMLDocument*  xmlDoc = nil;
    
    if ( textDoc ) {
      if ( (xmlDoc = [[SBXMLDocument alloc] initWithXMLString:textDoc]) )
        xmlDoc = [xmlDoc autorelease];
    }
    return xmlDoc;
  }

//

  - (SHUEBoxCGITarget) target
  {
    if ( ! _targetsAreLoaded )
      [self loadRequestTargets];
    return _target;
  }

//

  - (SHUEBoxCollaboration*) targetCollaboration
  {
    if ( ! _targetsAreLoaded )
      [self loadRequestTargets];
    return _targetCollaboration;
  }
  
//

  - (SHUEBoxRepository*) targetRepository
  {
    if ( ! _targetsAreLoaded )
      [self loadRequestTargets];
    return _targetRepository;
  }
  
//

  - (SHUEBoxUser*) targetSHUEBoxUser
  {
    if ( ! _targetsAreLoaded )
      [self loadRequestTargets];
    return _targetSHUEBoxUser;
  }

//

  - (SHUEBoxRole*) targetSHUEBoxRole
  {
    if ( ! _targetsAreLoaded )
      [self loadRequestTargets];
    return _targetSHUEBoxRole;
  }

//

  - (SHUEBoxUser*) targetSHUEBoxRoleMember
  {
    if ( ! _targetsAreLoaded )
      [self loadRequestTargets];
    return _targetSHUEBoxRoleMember;
  }

//

  - (SBString*) targetConfirmationCode
  {
    if ( ! _targetsAreLoaded )
      [self loadRequestTargets];
    return _targetConfirmationCode;
  }

//

  - (SBError*) lastError
  {
    return _lastError;
  }

//

  - (void) sendErrorDocument:(SBString*)title
    description:(SBString*)description
    forError:(SBError*)anError
  {
    //
    // Write the document:
    //
    [self appendFormatToResponseText:"<?xml version=\"1.0\" encoding=\"UTF-8\"?><error><title><![CDATA[%S]]></title><description><![CDATA[%S]]></description>",
        ( title ? [title utf16Characters] : (UChar*)"" ),
        ( description ? [description utf16Characters] : (UChar*)"" )
      ];
    while ( anError ) {
      SBDictionary* supportingData = [anError supportingData];
      SBString*     explanation = ( supportingData ? [supportingData objectForKey:SBErrorExplanationKey] : nil );
      
      [self appendFormatToResponseText:"<error-object domain=\"%S\" code=\"%d\">", [[anError domain] utf16Characters], [anError code]];
      if ( explanation )
        [self appendFormatToResponseText:"<explanation><![CDATA[%S]]></explanation>", [explanation utf16Characters]];
      [self appendStringToResponseText:@"</error-object>"];
      anError = ( supportingData ? [supportingData objectForKey:SBErrorUnderlyingErrorKey] : nil );
    }
    [self appendStringToResponseText:@"</error>"];
    
    //
    // Send now!
    //
    [self sendResponse];
  }

@end
