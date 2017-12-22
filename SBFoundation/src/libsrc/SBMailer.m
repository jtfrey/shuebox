//
// SBFoundation : ObjC Class Library for Solaris
// SBMailer.h
//
// Class which facilitates the sending of email.
//
// $Id$
//

#import "SBMailer.h"
#import "SBHost.h"
#import "SBInetAddress.h"
#import "SBValue.h"
#import "SBArray.h"
#import "SBDictionary.h"
#import "SBError.h"

#include <regex.h>
#include <netdb.h>

#ifndef MIME_BOUNDARY_ENTROPY_LENGTH
#define MIME_BOUNDARY_ENTROPY_LENGTH 32
#endif

SBString* SBMailerErrorDomain = @"email agent";

//

SBString* SBMailerToAddressesKey = @"To";
SBString* SBMailerBCCAddressesKey = @"BCC";
SBString* SBMailerCCAddressesKey = @"CC";
SBString* SBMailerSubjectKey = @"Subject";
SBString* SBMailerFromKey = @"From";
SBString* SBMailerMessageIdKey = @"Message-Id";
SBString* SBMailerReplyToKey = @"Reply-To";
SBString* SBMailerFakeRecipientKey = @"fake-recipient";
SBString* SBMailerMultipartSubtypeKey = @"mime-multipart-subtype";

//

SBString* __SBMailerDefaultSMTPHostName = @"mail.udel.edu";
SBHost*   __SBMailerDefaultSMTPHost = nil;
SBString* __SBMailerDefaultSMTPSender = @"shuebox@udel.edu";
SBString* __SBMailerDefaultSMTPRecipient = @"frey@udel.edu";
SBString* __SBMailerDefaultSMTPSubject = @"[SHUEBox] no subject";
SBString* __SBMailerDefaultAgentName = @"UDel SBMailer SMTP agent";

//

enum {
  kSMTPSessionFlag_Verbose        = 1 << 0,
  kSMTPSessionFlag_StayAlive      = 1 << 1,
  kSMTPSessionFlag_Open           = 1 << 2,
  kSMTPSessionFlag_SenderSent     = 1 << 3,
  kSMTPSessionFlag_RecipientSent  = 1 << 4,
  kSMTPSessionFlag_HeadersSent    = 1 << 5,
  kSMTPSessionFlag_PartSent       = 1 << 6
};

//

static inline BOOL
__SMTPGoodResult(
  int     result
)
{
  switch ( result / 100 ) {
    case 1:
    case 2:
    case 3:
      return YES;
  }
  return NO;
}

//

void
__SMTPGenerateBoundary(
  char*     buffer
)
{
  static const char*    charset = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ0123456789";
  static const char*    format = "==SBMAILER_MULTIPART_BOUNDARY_%s";
  char                  rndString[MIME_BOUNDARY_ENTROPY_LENGTH + 1];
  int                   csetLen,i = MIME_BOUNDARY_ENTROPY_LENGTH;
  
  srand(time(NULL));
  
  csetLen = strlen(charset);
  rndString[i] = '\0';
  while ( i-- ) {
    rndString[i] = charset[ ((int)floor( 256.0 * drand48() )) % csetLen ];
  }
  snprintf(buffer, 64, format, rndString);
}

//

@interface SBMailer(SBMailerPrivate)

- (SBError*) sendHeader:(const char*)header withValue:(SBString*)value;

@end

@implementation SBMailer(SBMailerPrivate)

  - (SBError*) sendHeader:(const char*)header
    withValue:(SBString*)value
  {
    if ( header && value ) {
      SBUInteger    iMax = [value utf8Length];
      
      if ( iMax > 0 ) {
        if ( iMax > 1000 ) {
          return [SBError errorWithDomain:SBMailerErrorDomain code:kSBMailerHeaderLengthExceeded
                      supportingData:[SBDictionary dictionaryWithObject:
                            [SBString stringWithFormat:"Value of header `%s` exceeds 1000 characters.", header]
                            forKey:SBErrorExplanationKey
                          ]
                    ];
        } else {
          fprintf(_smtpOut, "%s: ", header);
          [value writeToStream:_smtpOut];
          fprintf(_smtpOut, "\r\n");
          if ( _flags & kSMTPSessionFlag_Verbose ) {
            fprintf(stderr, "%s: ", header);
            [value writeToStream:stderr];
            fprintf(stderr, "\n");
          }
        }
      }
    }
    return nil;
  }

@end

//
#pragma mark -
//

@implementation SBMailer

  + initialize
  {
    if ( ! __SBMailerDefaultSMTPHost )
      __SBMailerDefaultSMTPHost = [[SBHost hostWithName:__SBMailerDefaultSMTPHostName] retain];
  }

//

  + (SBMailer*) sharedMailer
  {
    static SBMailer* sharedMailer = nil;
    
    if ( sharedMailer == nil ) {
      sharedMailer = [[SBMailer alloc] init];
    }
    return sharedMailer;
  }

//

  - (void) dealloc
  {
    // Force a session cancel if open:
    [self setStayAlive:NO];
    [self cancelSMTPSession];
    
    // Drop any instance vars:
    if ( _smtpOpenHost ) [_smtpOpenHost release];
    if ( _defaultSMTPSender ) [_defaultSMTPSender release];
    if ( _defaultSMTPRecipient ) [_defaultSMTPRecipient release];
    if ( _defaultSMTPSubject ) [_defaultSMTPSubject release];
    if ( _defaultSMTPHost ) [_defaultSMTPHost release];
    if ( _agentName ) [_agentName release];
    
    [super dealloc];
  }

//

  - (SBError*) startSMTPSession
  {
    return [self startSMTPSessionWithHost:nil port:[self defaultSMTPPort]];
  }
  - (SBError*) startSMTPSessionWithHost:(SBHost*)smtpHost
  {
    return [self startSMTPSessionWithHost:smtpHost port:[self defaultSMTPPort]];
  }
  - (SBError*) startSMTPSessionWithHost:(SBHost*)smtpHost
    port:(SBUInteger)port
  {
    SBString*     errorExplanation = nil;
    int           sd = socket(AF_INET,SOCK_STREAM,0);
    
    if ( sd ) {
      int         rc = 0;
      
      if ( ! smtpHost )
        smtpHost = [self defaultSMTPHost];
      
      if ( ! _smtpOpenHost || ! [smtpHost isEqualToHost:_smtpOpenHost] || (_smtpOpenPort != port) ) {
        //
        // Are we doing IPv4 or IPv6?
        //
        SBInetAddress*    smtpAddr = [smtpHost ipAddress];
        
        switch ( [smtpAddr addressFamily] ) {
        
          case kSBInetAddressIPv4Family: {
            struct sockaddr_in    mailhost;
            
            bzero(&mailhost, sizeof(mailhost));
            if ( ! [smtpAddr setSockAddr:(struct sockaddr*)&mailhost byteSize:sizeof(mailhost)] ) {
              errorExplanation = [SBString stringWithFormat:"Unable to set destination SMTP server address (IPv4) for `%S`", [smtpHost hostname]];
            }
            mailhost.sin_port = htons(port);
            rc = connect(sd, (void*)&mailhost, sizeof(mailhost));
            break;
          }
        
          case kSBInetAddressIPv6Family: {
            struct sockaddr_in6   mailhost;
            
            bzero(&mailhost, sizeof(mailhost));
            if ( ! [smtpAddr setSockAddr:(struct sockaddr*)&mailhost byteSize:sizeof(mailhost)] ) {
              errorExplanation = [SBString stringWithFormat:"Unable to set destination SMTP server address (IPv6) for `%S`", [smtpHost hostname]];
            }
            mailhost.sin6_port = htons(port);
            rc = connect(sd, (void*)&mailhost, sizeof(mailhost));
            break;
          }
          
        }
        if ( rc == 0 ) {
          _smtpOpenHost = [smtpHost retain];
          _smtpOpenPort = port;
          //
          // Successfully connected, get file streams setup:
          //
          _smtpSocket = sd;
          
          _smtpIn = fdopen(sd, "r");
          
          _smtpOut = fdopen(sd, "w");
          setlinebuf(_smtpOut);
          
          fgets(_reserved, 1024, _smtpIn);
          if ( __SMTPGoodResult(atoi(_reserved)) ) {
            SBError*    error = [self sendSMTPCommand:"EHLO %S", [[[SBHost currentHost] hostname] utf16Characters]];
            
            if ( error ) {
              [self cancelSMTPSession];
              return error;
            } else {
              _flags |= kSMTPSessionFlag_Open;
            }
          } else {
            errorExplanation = [SBString stringWithFormat:"Server responded with SMTP result %d", atoi(_reserved)];
          }
        } else {
          errorExplanation = [SBString stringWithFormat:"Unable to connect to SMTP host (errno = %s)", rc];
        }
      }
      if ( errorExplanation ) {
        // Make sure we cancel:
        [self cancelSMTPSession];
      }
    } else {
      errorExplanation = [SBString stringWithFormat:"Unable to open SMTP socket: errno = %d", errno];
    }
    //
    // Any errors?
    //
    if ( errorExplanation ) {
      return [SBError errorWithDomain:SBMailerErrorDomain code:kSBMailerUnableToOpenSocket
                  supportingData:[SBDictionary dictionaryWithObject:errorExplanation forKey:SBErrorExplanationKey]
                ];
    }
    return nil;
  }
  
//

  - (SBError*) sendSMTPCommand:(const char*)format, ...
  {
    va_list         vargs;
    SBString*       command = nil;
    
    va_start(vargs,format);
    command = [[SBString alloc] initWithFormat:format arguments:vargs];
    if ( command ) {
      int           rc;
      
      [command writeToStream:_smtpOut];
      fprintf(_smtpOut,"\r\n");
    
      if ( _flags & kSMTPSessionFlag_Verbose ) {
        fprintf(stderr,"DEBUG: ");
        [command writeToStream:stderr];
        fprintf(stderr,"\n");
      }
      do {
        fgets(_reserved, 1024, _smtpIn);
        if ( _flags & kSMTPSessionFlag_Verbose )
          fprintf(stderr, "DEBUG: RESPONSE: %s", _reserved);
        rc = atoi(_reserved);
      } while ( (rc < 100) || (_reserved[3] == '-') );
      
      if ( ! __SMTPGoodResult(rc) ) {
        return [SBError errorWithDomain:SBMailerErrorDomain code:kSBMailerSMTPCommandFailure
                    supportingData:[SBDictionary dictionaryWithObject:[SBString stringWithFormat:"SMTP command failure (rc = %d): %S", rc, _reserved]
                                      forKey:SBErrorExplanationKey]
                  ];
      }
    } else {
      return [SBError errorWithDomain:SBMailerErrorDomain code:kSBMailerSMTPCommandBuildFailure
                  supportingData:[SBDictionary dictionaryWithObject:@"Unable to build SMTP command string." forKey:SBErrorExplanationKey]
                ];
    }
    va_end(vargs);
    
    return nil;
  }

//

  - (SBError*) cancelSMTPSession
  {
    SBError*      error = nil;
    
    if ( _flags & kSMTPSessionFlag_Open ) {
      error = [self sendSMTPCommand:"RSET"];
      if ( ! (_flags & kSMTPSessionFlag_StayAlive) ) {
        error = [self sendSMTPCommand:"QUIT"];
      }
    }
    if ( _flags & kSMTPSessionFlag_StayAlive ) {
      _flags &= (kSMTPSessionFlag_Open | kSMTPSessionFlag_Verbose | kSMTPSessionFlag_StayAlive);
    } else {
      _flags &= kSMTPSessionFlag_Verbose;
      fclose(_smtpIn); _smtpIn = NULL;
      fclose(_smtpOut); _smtpOut = NULL;
      close(_smtpSocket); _smtpSocket = -1;
      if ( _smtpOpenHost ) { [_smtpOpenHost release]; _smtpOpenHost = nil; }
    }
    return error;
  }
  
//

  - (SBError*) finishSMTPSession
  {
    SBError*      error = nil;
    
    if ( _flags & kSMTPSessionFlag_HeadersSent ) {
      int         rc;
      
      if ( _flags & kSMTPSessionFlag_PartSent ) {
        //
        // Final MIME boundary:
        //
        fprintf(_smtpOut, "\r\n--%s--\r\n.\r\n", _boundary);
      } else {
        fprintf(_smtpOut, "\r\n.\r\n");
      }
      //
      // Pull the rest of the responses now:
      //
      do {
        fgets(_reserved, 1024, _smtpIn);
        if ( _flags & kSMTPSessionFlag_Verbose )
          fprintf(stderr, "DEBUG: RESPONSE: %s", _reserved);
        rc = atoi(_reserved);
      } while ( (rc < 100) || (_reserved[3] == '-') );
      if ( ! __SMTPGoodResult(rc) ) {
        error = [SBError errorWithDomain:SBMailerErrorDomain code:kSBMailerErrorDuringSend
                          supportingData:[SBDictionary dictionaryWithObject:
                                [SBString stringWithFormat:"Error when attempting to send message: %s", _reserved]
                              forKey:SBErrorExplanationKey]
                      ];
      } else if ( ! (_flags & kSMTPSessionFlag_StayAlive) ) {
        error = [self sendSMTPCommand:"QUIT"];
      }
    } else {
      error = [SBError errorWithDomain:SBMailerErrorDomain code:kSBMailerIncompleteMessage
                          supportingData:[SBDictionary dictionaryWithObject:@"The session did not contain a complete message and could not be finished." forKey:SBErrorExplanationKey]
                  ];
    }
    if ( _flags & kSMTPSessionFlag_StayAlive ) {
      _flags &= (kSMTPSessionFlag_Open | kSMTPSessionFlag_Verbose | kSMTPSessionFlag_StayAlive);
    } else {
      _flags &= kSMTPSessionFlag_Verbose;
      fclose(_smtpIn); _smtpIn = NULL;
      fclose(_smtpOut); _smtpOut = NULL;
      close(_smtpSocket); _smtpSocket = -1;
      if ( _smtpOpenHost ) { [_smtpOpenHost release]; _smtpOpenHost = nil; }
    }
    return error;
  }

//

  - (BOOL) isVerbose
  {
    return ( (_flags & kSMTPSessionFlag_Verbose) != 0 );
  }
  - (void) setIsVerbose:(BOOL)verbose
  {
    if ( verbose )
      _flags |= kSMTPSessionFlag_Verbose;
    else
      _flags &= ~ kSMTPSessionFlag_Verbose;
  }

//

  - (BOOL) stayAlive
  {
    return ( (_flags & kSMTPSessionFlag_StayAlive) != 0 );
  }
  - (void) setStayAlive:(BOOL)stayAlive
  {
    if ( stayAlive )
      _flags |= kSMTPSessionFlag_StayAlive;
    else {
      if ( (_smtpSocket >= 0) && (_smtpOpenHost) ) {
        _flags &= ~ kSMTPSessionFlag_StayAlive;
        [self cancelSMTPSession];
      } else {
        _flags &= ~ kSMTPSessionFlag_StayAlive;
      }
    }
  }

//

  - (SBString*) agentName
  {
    if ( _agentName ) return _agentName;
    return __SBMailerDefaultAgentName;
  }
  - (void) setAgentName:(SBString*)agentName
  {
    if ( agentName ) agentName = [agentName copy];
    if ( _agentName ) [_agentName release];
    _agentName = agentName;
  }

//

  - (SBString*) defaultSMTPSender
  {
    if ( _defaultSMTPSender ) return _defaultSMTPSender;
    return __SBMailerDefaultSMTPSender;
  }
  - (void) setDefaultSMTPSender:(SBString*)senderAddress
  {
    if ( senderAddress ) senderAddress = [senderAddress copy];
    if ( _defaultSMTPSender ) [_defaultSMTPSender release];
    _defaultSMTPSender = senderAddress;
  }
  
//

  - (SBString*) defaultSMTPRecipient
  {
    if ( _defaultSMTPRecipient ) return _defaultSMTPRecipient;
    return __SBMailerDefaultSMTPRecipient;
  }
  - (void) setDefaultSMTPRecipient:(SBString*)recipientAddress
  {
    if ( recipientAddress ) recipientAddress = [recipientAddress copy];
    if ( _defaultSMTPRecipient ) [_defaultSMTPRecipient release];
    _defaultSMTPRecipient = recipientAddress;
  }
  
//

  - (SBString*) defaultSMTPSubject
  {
    if ( _defaultSMTPSubject ) return _defaultSMTPSubject;
    return __SBMailerDefaultSMTPSubject;
  }
  - (void) setDefaultSMTPSubject:(SBString*)subject
  {
    if ( subject ) subject = [subject copy];
    if ( _defaultSMTPSubject ) [_defaultSMTPSubject release];
    _defaultSMTPSubject = subject;
  }
  
//

  - (SBHost*) defaultSMTPHost
  {
    if ( _defaultSMTPHost ) return _defaultSMTPHost;
    return __SBMailerDefaultSMTPHost;
  }
  - (void) setDefaultSMTPHost:(SBHost*)smtpHost
  {
    if ( smtpHost ) smtpHost = [smtpHost retain];
    if ( _defaultSMTPHost ) [_defaultSMTPHost release];
    _defaultSMTPHost = smtpHost;
  }
  
//

  - (SBUInteger) defaultSMTPPort
  {
    if ( _defaultSMTPPort ) return _defaultSMTPPort;
    return 25;
  }
  - (void) setDefaultSMTPPort:(SBUInteger)aPort
  {
    _defaultSMTPPort = aPort;
  }

@end

//
#pragma mark -
//

@implementation SBMailer(SBMailerMessageComposition)

  - (SBError*) sendFromAddress:(SBString*)fromAddress
  {
    SBError*      error = nil;
    
    if ( _flags & kSMTPSessionFlag_Open ) {
      if ( ! (_flags & kSMTPSessionFlag_SenderSent) ) {
        if ( (fromAddress = [fromAddress stringByDiscardingDisplayNameFromEmailAddress]) ) {
          error = [self sendSMTPCommand:"MAIL FROM: <%s>", [fromAddress utf8Characters]];
          if ( ! error )
            _flags |= kSMTPSessionFlag_SenderSent;
        } else {
          error = [SBError errorWithDomain:SBMailerErrorDomain code:kSBMailerSMTPCommandFailure
                        supportingData:[SBDictionary dictionaryWithObject:@"The message sender address is invalid." forKey:SBErrorExplanationKey]
                      ];
        }
      } else {
        error = [SBError errorWithDomain:SBMailerErrorDomain code:kSBMailerSMTPCommandFailure
                      supportingData:[SBDictionary dictionaryWithObject:@"The message sender address has already been sent." forKey:SBErrorExplanationKey]
                    ];
      }
    } else {
      error = [SBError errorWithDomain:SBMailerErrorDomain code:kSBMailerMessageNotReady
                    supportingData:[SBDictionary dictionaryWithObject:@"A message has not yet been started." forKey:SBErrorExplanationKey]
                  ];
    }
    return error;
  }
  
//

  - (SBError*) sendRecipient:(SBString*)toAddress
  {
    SBError*      error = nil;
    
    if ( _flags & kSMTPSessionFlag_SenderSent ) {
      if ( ! (_flags & kSMTPSessionFlag_HeadersSent) ) {
        if ( (toAddress = [toAddress stringByDiscardingDisplayNameFromEmailAddress]) ) {
          error = [self sendSMTPCommand:"RCPT TO: <%s>", [toAddress utf8Characters]];
          if ( ! error )
            _flags |= kSMTPSessionFlag_RecipientSent;
        } else {
          error = [SBError errorWithDomain:SBMailerErrorDomain code:kSBMailerSMTPCommandFailure
                        supportingData:[SBDictionary dictionaryWithObject:@"A message recipient address is invalid." forKey:SBErrorExplanationKey]
                      ];
        }
      } else {
        error = [SBError errorWithDomain:SBMailerErrorDomain code:kSBMailerSMTPCommandFailure
                      supportingData:[SBDictionary dictionaryWithObject:@"Message headers have already been sent, cannot add more recipients." forKey:SBErrorExplanationKey]
                    ];
      }
    } else {
      error = [SBError errorWithDomain:SBMailerErrorDomain code:kSBMailerMessageNotReady
                    supportingData:[SBDictionary dictionaryWithObject:@"A sender has not yet been sent." forKey:SBErrorExplanationKey]
                  ];
    }
    return error;
  }
  
//

  - (SBError*) sendRecipients:(SBArray*)toAddresses
  {
    SBError*          error = nil;
    SBUInteger        i = 0, iMax = [toAddresses count];
    
    while ( ! error && (i < iMax) )
      error = [self sendRecipient:[toAddresses objectAtIndex:i++]];
    return error;
  }
  
//

  - (SBError*) sendMessageHeaders:(SBDictionary*)messageProps
  {
    SBError*      error = nil;
    
    if ( _flags & kSMTPSessionFlag_RecipientSent ) {
      if ( ! (_flags & kSMTPSessionFlag_HeadersSent) ) {
        //
        // We need a MIME boundary:
        //
        __SMTPGenerateBoundary(_boundary);
        
        error = [self sendSMTPCommand:"DATA"];
        if ( ! error ) {
          SBString*       from = [messageProps objectForKey:SBMailerFromKey];
          id              to = [messageProps objectForKey:SBMailerToAddressesKey];
          id              cc = [messageProps objectForKey:SBMailerCCAddressesKey];
          SBString*       fakeRecipient = [messageProps objectForKey:SBMailerFakeRecipientKey];
          SBString*       replyTo = [messageProps objectForKey:SBMailerReplyToKey];
          SBString*       msgId = [messageProps objectForKey:SBMailerMessageIdKey];
          SBString*       subject = [messageProps objectForKey:SBMailerSubjectKey];
          
          //
          // From:
          //
          error = [self sendHeader:"From" withValue:( from ? from : [self defaultSMTPSender] )];
          
          //
          // Show or hide the recipients in the headers?
          //
          if ( fakeRecipient ) {
            //
            // Add fake recipient:
            //
            error = [self sendHeader:"To" withValue:fakeRecipient];
          } else {
            SBUInteger        count, totalCount = 0;
            //
            // To:
            //
            if ( to ) {
              if ( [to isKindOf:[SBArray class]] ) {
                count = [to count];
                if ( count ) {
                  error = [self sendHeader:"To" withValue:[to componentsJoinedByString:@","]];
                  if ( ! error )
                    totalCount += count;
                }
              } else {
                error = [self sendHeader:"To" withValue:to];
                if ( ! error )
                  totalCount++;
              }
            }
            //
            // CC:
            //
            if ( ! error && cc ) {
              if ( [cc isKindOf:[SBArray class]] ) {
                count = [cc count];
                if ( count ) {
                  error = [self sendHeader:"CC" withValue:[cc componentsJoinedByString:@","]];
                  if ( ! error )
                    totalCount += count;
                }
              } else {
                error = [self sendHeader:"CC" withValue:cc];
                if ( ! error )
                  totalCount++;
              }
            }
            //
            // Did we send anything?
            //
            if ( ! error && ! totalCount ) {
              error = [self sendHeader:"To" withValue:[self defaultSMTPRecipient]];
            }
          }
          
          if ( ! error ) {
            //
            // Proceed with the rest of the headers:
            //
            if ( replyTo )
              error = [self sendHeader:"Reply-To" withValue:replyTo];
            if ( ! error ) {
              //
              // Identify ourselves:
              //
              error = [self sendHeader:"X-Mailer" withValue:[self agentName]];
              if ( ! error ) {
                //
                // Subject:
                //
                error = [self sendHeader:"Subject" withValue:( subject ? subject : [self defaultSMTPSubject] )];
                if ( ! error ) {
                  if ( msgId ) {
                    //
                    // Message Id:
                    //
                    SBString*     value = [SBString stringWithFormat:"<%S@%S>", [msgId utf16Characters], [[[SBHost currentHost] hostname] utf16Characters]];
                    
                    if ( value ) {
                      error = [self sendHeader:"Message-Id" withValue:value];
                    }
                  }
                  if ( ! error ) {
                    //
                    // MIME junk:
                    //
                    error = [self sendHeader:"MIME-Version" withValue:@"1.0"];
                    if ( ! error ) {
                      SBString*   subtype = [messageProps objectForKey:SBMailerMultipartSubtypeKey];
                      SBString*   value = [SBString stringWithFormat:"multipart/%s;\r\n    boundary=\"%s\"", (subtype ? (const char*)[subtype utf8Characters] : "mixed"),  _boundary];
                      
                      if ( value ) {
                        error = [self sendHeader:"Content-Type" withValue:value];
                        if ( ! error ) {
                          //
                          // We made it!!!!
                          //
                          fprintf(_smtpOut, "\r\n");
                          _flags |= kSMTPSessionFlag_HeadersSent;
                        }
                      } else {
                        error = [SBError errorWithDomain:SBMailerErrorDomain code:kSBMailerSMTPCommandFailure
                                    supportingData:[SBDictionary dictionaryWithObject:@"Failed to create MIME content-type description." forKey:SBErrorExplanationKey]
                                  ];
                      }
                    }
                  }
                }
              }
            }
          }
        }
      } else {
        error = [SBError errorWithDomain:SBMailerErrorDomain code:kSBMailerSMTPCommandFailure
                      supportingData:[SBDictionary dictionaryWithObject:@"The message headers have already been sent." forKey:SBErrorExplanationKey]
                    ];
      }
    } else {
      error = [SBError errorWithDomain:SBMailerErrorDomain code:kSBMailerMessageNotReady
                    supportingData:[SBDictionary dictionaryWithObject:@"A recipient has not yet been sent." forKey:SBErrorExplanationKey]
                  ];
    }
    return error;
  }
  
//

  - (SBError*) sendTextPart:(SBString*)text
  {
    return [self sendTextPart:text mimeType:nil];
  }
  
//

  - (SBError*) sendTextPart:(SBString*)text
    mimeType:(SBString*)mimeType
  {
    SBError*      error = nil;
    
    if ( ! mimeType )
      mimeType = @"text/plain";
    
    if ( _flags & kSMTPSessionFlag_HeadersSent ) {
      SBString*   leadIn = [SBString stringWithFormat:
                                  "\r\n"
                                  "--%s\r\n"
                                  "Content-Type: %s; charset=UTF-8\r\n"
                                  "Content-Transfer-Encoding: quoted-printable\r\n\r\n",
                                  _boundary,
                                  [mimeType utf8Characters]
                                ];
      if ( leadIn ) {
        if ( (_flags & kSMTPSessionFlag_PartSent) == 0 )
          fprintf(_smtpOut, "This is a multi-part message in MIME format.");
        [leadIn writeToStream:_smtpOut];
        [text writeQuotedPrintableToSMTPStream:_smtpOut];
        fprintf(_smtpOut, "\r\n");
        _flags |= kSMTPSessionFlag_PartSent;
      } else {
        error = [SBError errorWithDomain:SBMailerErrorDomain code:kSBMailerSMTPCommandFailure
                      supportingData:[SBDictionary dictionaryWithObject:@"Unable to build multipart section header." forKey:SBErrorExplanationKey]
                    ];
      }
    } else {
      error = [SBError errorWithDomain:SBMailerErrorDomain code:kSBMailerMessageNotReady
                    supportingData:[SBDictionary dictionaryWithObject:@"Message headers have not yet been sent." forKey:SBErrorExplanationKey]
                  ];
    }
    return error;
  }

//

  - (SBError*) sendDataPart:(SBData*)data
  {
    return [self sendDataPart:data mimeType:nil filename:nil];
  }
  - (SBError*) sendDataPart:(SBData*)data
    mimeType:(SBString*)mimeType
  {
    return [self sendDataPart:data mimeType:mimeType filename:nil];
  }
  - (SBError*) sendDataPart:(SBData*)data
    mimeType:(SBString*)mimeType
    filename:(SBString*)filename
  {
    SBError*      error = nil;
    
    
    if ( ! mimeType )
      mimeType = @"application/octet-stream";
    
    if ( _flags & kSMTPSessionFlag_HeadersSent ) {
      SBString*   leadIn;
      
      if ( filename && [filename length] ) {
        leadIn = [SBString stringWithFormat:
                                  "\r\n"
                                  "--%s\r\n"
                                  "Content-Type: %s\r\n"
                                  "Content-Transfer-Encoding: base64\r\n"
                                  "Content-Disposition: attachment; filename=%s\r\n\r\n",
                                  _boundary,
                                  [mimeType utf8Characters],
                                  [filename utf8Characters]
                                ];
      } else {
        leadIn = [SBString stringWithFormat:
                                  "\r\n"
                                  "--%s\r\n"
                                  "Content-Type: %s\r\n"
                                  "Content-Transfer-Encoding: base64\r\n"
                                  "Content-Disposition: inline\r\n\r\n",
                                  _boundary,
                                  [mimeType utf8Characters]
                                ];
      }
      if ( leadIn ) {
        if ( (_flags & kSMTPSessionFlag_PartSent) == 0 )
          fprintf(_smtpOut, "This is a multi-part message in MIME format.");
        [leadIn writeToStream:_smtpOut];
        [data writeBase64EncodingToSMTPStream:_smtpOut];
        fprintf(_smtpOut, "\r\n");
        _flags |= kSMTPSessionFlag_PartSent;
      } else {
        error = [SBError errorWithDomain:SBMailerErrorDomain code:kSBMailerSMTPCommandFailure
                      supportingData:[SBDictionary dictionaryWithObject:@"Unable to build multipart section header." forKey:SBErrorExplanationKey]
                    ];
      }
    } else {
      error = [SBError errorWithDomain:SBMailerErrorDomain code:kSBMailerMessageNotReady
                    supportingData:[SBDictionary dictionaryWithObject:@"Message headers have not yet been sent." forKey:SBErrorExplanationKey]
                  ];
    }
    return error;
  }

//

  - (SBError*) sendMessage:(SBString*)message
    withSubject:(SBString*)subject
  {
    SBError*      error = nil;
    
    error = [self startSMTPSession];
    if ( ! error ) {
      error = [self sendFromAddress:[self defaultSMTPSender]];
      if ( ! error ) {
        error = [self sendRecipient:[self defaultSMTPRecipient]];
        if ( ! error ) {
          error = [self sendMessageHeaders:
                      [SBDictionary dictionaryWithObject:( subject ? subject : [self defaultSMTPSubject] ) forKey:SBMailerSubjectKey]
                    ];
          if ( ! error ) {
            error = [self sendTextPart:message];
          }
        }
      }
      //
      // Cleanup:
      //
      if ( error )
        [self cancelSMTPSession];
      else
        error = [self finishSMTPSession];
    }
    return error;
  }
  
//

  - (SBError*) sendMessage:(SBString*)message
    withProperties:(SBDictionary*)messageProps
  {
    SBError*      error = nil;
    
    error = [self startSMTPSession];
    if ( ! error ) {
      SBString*   from = [messageProps objectForKey:SBMailerFromKey];
      
      error = [self sendFromAddress:( from ? from : [self defaultSMTPSender])];
      if ( ! error ) {
        id              to = [messageProps objectForKey:SBMailerToAddressesKey];
        id              cc = [messageProps objectForKey:SBMailerCCAddressesKey];
        id              bcc = [messageProps objectForKey:SBMailerBCCAddressesKey];
        SBUInteger      count, totalCount = 0;
        
        //
        // Handle "to" addresses:
        //
        if ( to ) {
          if ( [to isKindOf:[SBArray class]] ) {
            count = [to count];
            while ( ! error && (count--) ) {
              error = [self sendRecipient:[to objectAtIndex:count]];
              if ( ! error )
                totalCount++;
            }
          } else {
            error = [self sendRecipient:to];
            if ( ! error )
              totalCount++;
          }
        }
        //
        // Handle "cc" addresses:
        //
        if ( ! error && cc ) {
          if ( [cc isKindOf:[SBArray class]] ) {
            count = [cc count];
            while ( ! error && (count--) ) {
              error = [self sendRecipient:[cc objectAtIndex:count]];
              if ( ! error )
                totalCount++;
            }
          } else {
            error = [self sendRecipient:cc];
            if ( ! error )
              totalCount++;
          }
        }
        //
        // Handle "bcc" addresses:
        //
        if ( ! error && bcc ) {
          if ( [bcc isKindOf:[SBArray class]] ) {
            count = [bcc count];
            while ( ! error && (count--) ) {
              error = [self sendRecipient:[bcc objectAtIndex:count]];
              if ( ! error )
                totalCount++;
            }
          } else {
            error = [self sendRecipient:bcc];
            if ( ! error )
              totalCount++;
          }
        }
        if ( ! error && (totalCount == 0) ) {
          //
          // No addresses found in properties dictionary, use the default recipient:
          //
          error = [self sendRecipient:[self defaultSMTPRecipient]];
        }
        if ( ! error ) {
          //
          // Done with recipient list, now let's send headers:
          //
          error = [self sendMessageHeaders:messageProps];
          if ( ! error ) {
            error = [self sendTextPart:message];
          }
        }
      }
      //
      // Cleanup:
      //
      if ( error )
        [self cancelSMTPSession];
      else
        error = [self finishSMTPSession];
    }
    return error;
  }

//

  - (SBError*) sendMessageWithComposer:(id)composer
    properties:(SBDictionary*)messageProps
  {
    SBError*      error = nil;
    
    // Does the composer implement the protocol?
    if ( ! [composer conformsTo:@protocol(SBMailerComposer)] ) {
      return [SBError errorWithDomain:SBMailerErrorDomain code:kSBMailerParameterError
                  supportingData:[SBDictionary dictionaryWithObject:@"sendMessageWithComposer:properties: invoked with composer object not conforming to SBMailerComposer protocol!" forKey:SBErrorExplanationKey]
                ];
    }
    
    error = [self startSMTPSession];
    if ( ! error ) {
      SBString*   from = [messageProps objectForKey:SBMailerFromKey];
      
      error = [self sendFromAddress:( from ? from : [self defaultSMTPSender])];
      if ( ! error ) {
        id              to = [messageProps objectForKey:SBMailerToAddressesKey];
        id              cc = [messageProps objectForKey:SBMailerCCAddressesKey];
        id              bcc = [messageProps objectForKey:SBMailerBCCAddressesKey];
        SBUInteger      count, totalCount = 0;
        
        //
        // Handle "to" addresses:
        //
        if ( to ) {
          if ( [to isKindOf:[SBArray class]] ) {
            count = [to count];
            while ( ! error && (count--) ) {
              error = [self sendRecipient:[to objectAtIndex:count]];
              if ( ! error )
                totalCount++;
            }
          } else {
            error = [self sendRecipient:to];
            if ( ! error )
              totalCount++;
          }
        }
        //
        // Handle "cc" addresses:
        //
        if ( ! error && cc ) {
          if ( [cc isKindOf:[SBArray class]] ) {
            count = [cc count];
            while ( ! error && (count--) ) {
              error = [self sendRecipient:[cc objectAtIndex:count]];
              if ( ! error )
                totalCount++;
            }
          } else {
            error = [self sendRecipient:cc];
            if ( ! error )
              totalCount++;
          }
        }
        //
        // Handle "bcc" addresses:
        //
        if ( ! error && bcc ) {
          if ( [bcc isKindOf:[SBArray class]] ) {
            count = [bcc count];
            while ( ! error && (count--) ) {
              error = [self sendRecipient:[bcc objectAtIndex:count]];
              if ( ! error )
                totalCount++;
            }
          } else {
            error = [self sendRecipient:bcc];
            if ( ! error )
              totalCount++;
          }
        }
        if ( ! error && (totalCount == 0) ) {
          //
          // No addresses found in properties dictionary, use the default recipient:
          //
          error = [self sendRecipient:[self defaultSMTPRecipient]];
        }
        if ( ! error ) {
          //
          // Done with recipient list, now let's send headers:
          //
          error = [self sendMessageHeaders:messageProps];
          if ( ! error ) {
            //
            // Let the composer do it's thing now:
            //
            error = [composer addMessagePartsToMailer:self];
          }
        }
      }
      //
      // Cleanup:
      //
      if ( error )
        [self cancelSMTPSession];
      else
        error = [self finishSMTPSession];
    }
    return error;
  }

//

  - (SBError*) sendMessageWithComposerFunction:(SBMailerMultipartComposerFunction)composer
    context:(void*)composerContext
    properties:(SBDictionary*)messageProps
  {
    SBError*      error = nil;
    
    error = [self startSMTPSession];
    if ( ! error ) {
      SBString*   from = [messageProps objectForKey:SBMailerFromKey];
      
      error = [self sendFromAddress:( from ? from : [self defaultSMTPSender])];
      if ( ! error ) {
        id              to = [messageProps objectForKey:SBMailerToAddressesKey];
        id              cc = [messageProps objectForKey:SBMailerCCAddressesKey];
        id              bcc = [messageProps objectForKey:SBMailerBCCAddressesKey];
        SBUInteger      count, totalCount = 0;
        
        //
        // Handle "to" addresses:
        //
        if ( to ) {
          if ( [to isKindOf:[SBArray class]] ) {
            count = [to count];
            while ( ! error && (count--) ) {
              error = [self sendRecipient:[to objectAtIndex:count]];
              if ( ! error )
                totalCount++;
            }
          } else {
            error = [self sendRecipient:to];
            if ( ! error )
              totalCount++;
          }
        }
        //
        // Handle "cc" addresses:
        //
        if ( ! error && cc ) {
          if ( [cc isKindOf:[SBArray class]] ) {
            count = [cc count];
            while ( ! error && (count--) ) {
              error = [self sendRecipient:[cc objectAtIndex:count]];
              if ( ! error )
                totalCount++;
            }
          } else {
            error = [self sendRecipient:cc];
            if ( ! error )
              totalCount++;
          }
        }
        //
        // Handle "bcc" addresses:
        //
        if ( ! error && bcc ) {
          if ( [bcc isKindOf:[SBArray class]] ) {
            count = [bcc count];
            while ( ! error && (count--) ) {
              error = [self sendRecipient:[bcc objectAtIndex:count]];
              if ( ! error )
                totalCount++;
            }
          } else {
            error = [self sendRecipient:bcc];
            if ( ! error )
              totalCount++;
          }
        }
        if ( ! error && (totalCount == 0) ) {
          //
          // No addresses found in properties dictionary, use the default recipient:
          //
          error = [self sendRecipient:[self defaultSMTPRecipient]];
        }
        if ( ! error ) {
          //
          // Done with recipient list, now let's send headers:
          //
          error = [self sendMessageHeaders:messageProps];
          if ( ! error ) {
            //
            // Let the composer do it's thing now:
            //
            error = composer(self, composerContext);
          }
        }
      }
      //
      // Cleanup:
      //
      if ( error )
        [self cancelSMTPSession];
      else
        error = [self finishSMTPSession];
    }
    return error;
  }

@end

//
#pragma mark -
//

@implementation SBString(SBMailerAdditions)

  - (void) writeQuotedPrintableToSMTPStream:(FILE*)stream
  {
    if ( [self nativeEncoding] == kSBStringUTF8NativeEncoding ) {
      unsigned char*      str = (unsigned char*)[self utf8Characters];
      SBUInteger          strLen = [self utf8Length];
      int                 i = 1;
      
      while ( strLen-- ) {
        unsigned char     c = *str++;
        char              out[4];
        
        if ( i >= 74 ) {
          fprintf(stream, "=\r\n");
          i = 0;
        }
        
        if ( c >= 33 && c <= 126 ) {
          //
          // ASCII characters are all directly printable EXCEPT "=":
          //
          if ( c == 61 ) {
            if ( i >= 72 ) {
              fprintf(stream, "=\r\n");
              i = 0;
            }
            strcpy(out, "=3D");
          } else if ( (c == '.') && ((i == 0) && ((strLen == 0) || ((strLen > 1) && (*str == '\r') && (*(str + 1) == '\n')))) ) {
            //
            // Special case, where a single "." would appear on a line:
            //
            out[0] = '.';
            out[1] = '.';
            out[2] = '\0';
          } else {
            out[0] = c;
            out[1] = '\0';
          }
        } else {
          //
          // All other 8-bit values must be encoded, except TAB and SPACE
          // which can appear as-is if they are NOT at the end of a
          // line:
          //
          switch ( c ) {
              
            case 9:
            case 32: {
              if ( i == 72 ) {
                snprintf(out, 4, "=%02hhX", c);
              } else if ( i > 72 ) {
                fprintf(stream, "=\r\n");
                i = 0;
                out[0] = c;
                out[1] = '\0';
              } else {
                out[0] = c;
                out[1] = '\0';
              }
              break;
            }
            
            default: {
              if ( i > 72 ) {
                fprintf(stream, "=\r\n");
                i = 0;
              }
              snprintf(out, 4, "=%02hhX", c);
              break;
            }
            
          }
        }
        
        //
        // Write:
        //
        fprintf(stream, out);
        if ( strLen )
          i += strlen(out);
      }
      if ( i != 0 )
        fprintf(stream, "\r\n");
      
    } else {
      SBSTRING_AS_UTF8_BEGIN(self)
      
        unsigned char*      str = (unsigned char*)self_utf8;
        unsigned char       c;
        int                 i = 1;
        
        while ( (c = *str++) ) {
          char              out[4];
          
          if ( i >= 74 ) {
            fprintf(stream, "=\r\n");
            i = 0;
          }
          i++;
          
          if ( c >= 33 && c <= 126 ) {
            //
            // ASCII characters are all directly printable EXCEPT "=":
            //
            if ( c == 61 ) {
              if ( i >= 72 ) {
                fprintf(stream, "=\r\n");
                i = 0;
              }
              strcpy(out, "=3D");
            } else if ( (c == '.') && (i == 0) && ((*str == 0) || (strncmp(str, "\r\n", 2) == 0)) ) {
              //
              // Special case, where a single "." would appear on a line:
              //
              out[0] = '.';
              out[1] = '.';
              out[2] = '\0';
            } else {
              out[0] = c;
              out[1] = '\0';
            }
          } else {
            //
            // All other 8-bit values must be encoded, except TAB and SPACE
            // which can appear as-is if they are NOT at the end of a
            // line:
            //
            switch ( c ) {
                
              case 9:
              case 32: {
                if ( i == 72 ) {
                  snprintf(out, 4, "=%02hhX", c);
                } else if ( i > 72 ) {
                  fprintf(stream, "=\r\n");
                  i = 0;
                  out[0] = c;
                  out[1] = '\0';
                } else {
                  out[0] = c;
                  out[1] = '\0';
                }
                break;
              }
              
              default: {
                if ( i > 72 ) {
                  fprintf(stream, "=\r\n");
                  i = 0;
                }
                snprintf(out, 4, "=%02hhX", c);
                break;
              }
              
            }
          }
          
          //
          // Write:
          //
          fprintf(stream, out);
          if ( *str )
            i += strlen(out);
        }
        if ( i != 0 )
          fprintf(stream, "\r\n");
      
      SBSTRING_AS_UTF8_END
    }
  }

//

  - (void) writeEncodedWordToSMTPStream:(FILE*)stream
  {
    fprintf(stream, "=?UTF-8?B?");
    
    if ( [self nativeEncoding] == kSBStringUTF8NativeEncoding ) {
      unsigned char*      str = (unsigned char*)[self utf8Characters];
      SBUInteger          strLen = [self utf8Length];
      int                 lineLen = 0;
      
      while ( strLen > 0 ) {
        // Next 3 bytes:
        unsigned char     chunk[4];
        
        chunk[0] = (str[0] & 0xFC) >> 2;
        if ( strLen > 1 ) {
          chunk[1] = ((str[0] & 0x03) << 4) | ((str[1] & 0xF0) >> 4);
          if ( strLen > 2 ) {
            chunk[2] = ((str[1] & 0x0F) << 2) | ((str[2] & 0xC0) >> 6);
            chunk[3] = str[2] & 0x3F;
            str += 3;
            strLen -= 3;
          } else {
            chunk[2] = (str[1] & 0x0F) << 2;
            chunk[3] = 64;
            str += 2;
            strLen -= 2;
          }
        } else {
          chunk[1] = (str[0] & 0x03) << 4;
          chunk[2] = 64;
          chunk[3] = 64;
          str++;
          strLen--;
        }
        fputc(SBBase64CharSet[chunk[0]], stream); if ( ++lineLen == 74 ) { lineLen = 0; fprintf(stream, "\r\n"); }
        fputc(SBBase64CharSet[chunk[1]], stream); if ( ++lineLen == 74 ) { lineLen = 0; fprintf(stream, "\r\n"); }
        fputc(SBBase64CharSet[chunk[2]], stream); if ( ++lineLen == 74 ) { lineLen = 0; fprintf(stream, "\r\n"); }
        fputc(SBBase64CharSet[chunk[3]], stream); if ( ++lineLen == 74 ) { lineLen = 0; fprintf(stream, "\r\n"); }
      }
    } else {
      SBSTRING_AS_UTF8_BEGIN(self)
        
        unsigned char*      str = (unsigned char*)self_utf8;
        SBUInteger          strLen = strlen(str);
        int                 lineLen = 0;
        
        while ( strLen > 0 ) {
          // Next 3 bytes:
          unsigned char     chunk[4];
        
          chunk[0] = (str[0] & 0xFC) >> 2;
          if ( strLen > 1 ) {
            chunk[1] = ((str[0] & 0x03) << 4) | ((str[1] & 0xF0) >> 4);
            if ( strLen > 2 ) {
              chunk[2] = ((str[1] & 0x0F) << 2) | ((str[2] & 0xC0) >> 6);
              chunk[3] = str[2] & 0x3F;
              str += 3;
              strLen -= 3;
            } else {
              chunk[2] = (str[1] & 0x0F) << 2;
              chunk[3] = 64;
              str += 2;
              strLen -= 2;
            }
          } else {
            chunk[1] = (str[0] & 0x03) << 4;
            chunk[2] = 64;
            chunk[3] = 64;
            str++;
            strLen--;
          }
          fputc(SBBase64CharSet[chunk[0]], stream); if ( ++lineLen == 74 ) { lineLen = 0; fprintf(stream, "\r\n"); }
          fputc(SBBase64CharSet[chunk[1]], stream); if ( ++lineLen == 74 ) { lineLen = 0; fprintf(stream, "\r\n"); }
          fputc(SBBase64CharSet[chunk[2]], stream); if ( ++lineLen == 74 ) { lineLen = 0; fprintf(stream, "\r\n"); }
          fputc(SBBase64CharSet[chunk[3]], stream); if ( ++lineLen == 74 ) { lineLen = 0; fprintf(stream, "\r\n"); }
        }
        
      SBSTRING_AS_UTF8_END
    }
    
    fprintf(stream, "?=");
    fflush(stream);
  }
  
//

  - (SBString*) stringByDiscardingDisplayNameFromEmailAddress
  {
    SBRange       end = [self rangeOfString:@">" options:SBStringBackwardsSearch];
    
    // No ">" means we'll interpret this as an unadorned email address:
    if ( SBRangeEmpty(end) ) return self;
    
    SBRange       start = [self rangeOfString:@"<" options:SBStringBackwardsSearch range:SBRangeCreate(0, end.start)];
    
    // No preceding "<" makes this kinda invalid:
    if ( SBRangeEmpty(start) ) return nil;
    
    return [self substringWithRange:SBRangeCreate(start.start + 1, end.start - start.start - 1)];
  }
  
@end

//
#pragma mark -
//

@implementation SBData(SBMailerAdditions)

  - (void) writeBase64EncodingToSMTPStream:(FILE*)stream
  {
    unsigned char*      ptr = (unsigned char*)[self bytes];
    SBUInteger          byteLen = [self length];
    int                 lineLen = 0;
      
    while ( byteLen > 0 ) {
      // Next 3 bytes:
      unsigned char     chunk[4];
      
      chunk[0] = (ptr[0] & 0xFC) >> 2;
      if ( byteLen > 1 ) {
        chunk[1] = ((ptr[0] & 0x03) << 4) | ((ptr[1] & 0xF0) >> 4);
        if ( byteLen > 2 ) {
          chunk[2] = ((ptr[1] & 0x0F) << 2) | ((ptr[2] & 0xC0) >> 6);
          chunk[3] = ptr[2] & 0x3F;
          ptr += 3;
          byteLen -= 3;
        } else {
          chunk[2] = (ptr[1] & 0x0F) << 2;
          chunk[3] = 64;
          ptr += 2;
          byteLen -= 2;
        }
      } else {
        chunk[1] = (ptr[0] & 0x03) << 4;
        chunk[2] = 64;
        chunk[3] = 64;
        ptr++;
        byteLen--;
      }
      fputc(SBBase64CharSet[chunk[0]], stream); if ( ++lineLen == 76 ) { lineLen = 0; fprintf(stream, "\r\n"); }
      fputc(SBBase64CharSet[chunk[1]], stream); if ( ++lineLen == 76 ) { lineLen = 0; fprintf(stream, "\r\n"); }
      fputc(SBBase64CharSet[chunk[2]], stream); if ( ++lineLen == 76 ) { lineLen = 0; fprintf(stream, "\r\n"); }
      fputc(SBBase64CharSet[chunk[3]], stream); if ( ++lineLen == 76 ) { lineLen = 0; fprintf(stream, "\r\n"); }
    }
    fflush(stream);
  }

@end
