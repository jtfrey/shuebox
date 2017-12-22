//
// SBLDAPKit - LDAP-oriented extensions to SBFoundation
// SBLDAP.m
//
// Access to LDAP servers.
//
// $Id$
//

#import "SBLDAP.h"
#import "SBString.h"
#import "SBArray.h"
#import "SBDictionary.h"
#import "SBError.h"


SBString* SBLDAPErrorDomain = @"OpenLDAP";

SBString* SBErrorLDAPMultiDNListKey = @"matching-ldap-dn";

static int __SBLDAPDefaultProtocolVersion = LDAP_VERSION3;
static BOOL __SBLDAPConnectionForceTLSDuringBind = YES;

@interface SBLDAPConnection(SBLDAPConnectionPrivate)

- (id) initWithURL:(SBString*)url;
- (id) initWithLDAPConnection:(LDAP*)ldapConn url:(SBString*)url;

@end

@implementation SBLDAPConnection(SBLDAPConnectionPrivate)

  - (id) initWithURL:(SBString*)url
  {
    if ( url ) {
      SBSTRING_AS_UTF8_BEGIN(url)
        
        LDAP*     ldapConn;
        
        if ( ldap_initialize(&ldapConn, url_utf8) == LDAP_SUCCESS ) {
          return [self initWithLDAPConnection:ldapConn url:url];
        }
        
      SBSTRING_AS_UTF8_END
    } else {
      [self release];
      self = nil;
    }
    return self;
  }

//

  - (id) initWithLDAPConnection:(LDAP*)ldapConn
    url:(SBString*)url
  {
    if ( self = [super init] ) {
      _ldapConn = ldapConn;
      _url = [url copy];
      [self setProtocolVersion:__SBLDAPDefaultProtocolVersion];
    }
    return self;
  }

@end

//
#pragma mark -
//

@interface SBLDAPSearchResult(SBLDAPSearchResultPrivate)

- (id) initWithConnection:(LDAP*)ldapConn message:(LDAPMessage*)message ignoreAttributes:(BOOL)ignoreAttributes;

@end

//
#pragma mark -
//

@implementation SBLDAPConnection

  + (int) defaultProtocolVersion
  {
    return __SBLDAPDefaultProtocolVersion;
  }
  + (void) setDefaultProtocolVersion:(int)ldapProtVers
  {
    if ( ldapProtVers >= LDAP_VERSION_MIN && ldapProtVers <= LDAP_VERSION_MAX )
      __SBLDAPDefaultProtocolVersion = ldapProtVers;
  }

//

  + (id) ldapConnectionWithServer:(SBString*)serverName
  {
    return [self ldapConnectionWithServer:serverName port:-1 secure:NO];
  }
  + (id) ldapConnectionWithServer:(SBString*)serverName
    port:(int)port
  {
    return [self ldapConnectionWithServer:serverName port:port secure:NO];
  }
  + (id) ldapConnectionWithServer:(SBString*)serverName
    secure:(BOOL)secure
  {
    return [self ldapConnectionWithServer:serverName port:-1 secure:secure];
  }
  + (id) ldapConnectionWithServer:(SBString*)serverName
    port:(int)port
    secure:(BOOL)secure
  {
    SBString*     url;
    char          portSubString[24];
    
    if ( port > 0 && port < 65536 ) {
      snprintf(portSubString, 24, ":%d", port);
    } else {
      portSubString[0] = '\0';
    }
     
    url = [SBString stringWithFormat:
                "ldap%s://%S%s/",
                ( secure ? "s" : "" ),
                [serverName utf16Characters],
                portSubString
              ];
    
    return [self ldapConnectionWithURL:url];
  }
  + (id) ldapConnectionWithURL:(SBString*)ldapURL
  {
    if ( ldapURL ) {
      SBSTRING_AS_UTF8_BEGIN(ldapURL)
        
        LDAP*     ldapConn;
        
        if ( ldap_initialize(&ldapConn, ldapURL_utf8) == LDAP_SUCCESS ) {
          return [[[SBLDAPConnection alloc] initWithLDAPConnection:ldapConn url:ldapURL] autorelease];
        }
        
      SBSTRING_AS_UTF8_END
    }
    return nil;
  }
  
//

  - (id) initWithConnection:(SBLDAPConnection*)extantConnection
  {
    SBString*       ldapURL;
    
    if ( extantConnection && (ldapURL = [extantConnection ldapConnectionURL]) ) {
      if ( self = [self initWithURL:ldapURL] ) {
        SBString*   baseDN = [extantConnection baseDN];
        
        if ( baseDN )
          [self setBaseDN:baseDN];
        
        if ( [extantConnection tlsEncryptionIsStarted] ) {
          if ( ! [self startTLSEncryption:NULL] ) {
            [self release];
            self = nil;
          }
        }
      }
    } else {
      [self release];
      self = nil;
    }
    return self;
  }

//

  - (id) copy
  {
    if ( _ldapConn && _url ) {
      SBLDAPConnection*   connCopy = [[SBLDAPConnection alloc] initWithURL:_url];
      
      if ( _baseDN )
        [connCopy setBaseDN:_baseDN];
      if ( _tlsStarted ) {
        if ( ! [connCopy startTLSEncryption:NULL] ) {
          [connCopy release];
          connCopy = nil;
        }
      }
      return connCopy;
    }
    return nil;
  }

//

  - (void) dealloc
  {
    if ( _baseDN ) [_baseDN release];
    if ( _url ) [_url release];
    if ( _ldapConn ) ldap_unbind_ext_s(_ldapConn, NULL, NULL);
    [super dealloc];
  }
  
//

  - (SBString*) ldapConnectionURL
  {
    return _url;
  }

//

  - (int) protocolVersion
  {
    int     ldapProtVers = -1;
    
    if ( _ldapConn ) {
      if ( ldap_get_option(_ldapConn, LDAP_OPT_PROTOCOL_VERSION, &ldapProtVers) != LDAP_SUCCESS )
        ldapProtVers = -1;
    }
    return ldapProtVers;
  }
  - (void) setProtocolVersion:(int)ldapProtVers
  {
    if ( _ldapConn )
      ldap_set_option(_ldapConn, LDAP_OPT_PROTOCOL_VERSION, &ldapProtVers);
  }

//

  - (int) lastResultCode
  {
    int     rc = -1;
    
    if ( _ldapConn )
      ldap_get_option(_ldapConn, LDAP_OPT_RESULT_CODE, &rc);
    return rc;
  }

//

  - (BOOL) startTLSEncryption:(SBError**)error
  {
    if ( ! _tlsStarted && _ldapConn ) {
      int     rc = ldap_start_tls_s(
                        _ldapConn,
                        NULL,
                        NULL
                      );
      switch ( rc ) {
        case LDAP_SUCCESS:
        case LDAP_LOCAL_ERROR:
          _tlsStarted = YES;
          break;
          
        default: {
          if ( error ) {
            *error = [SBError errorWithDomain:SBLDAPErrorDomain
                        code:[self lastResultCode]
                        supportingData:[SBDictionary dictionaryWithObject:@"Unable to start TLS connection phase"
                             forKey:SBErrorExplanationKey]
                      ];
          }
          break;
        }
      }
    }
    return _tlsStarted;
  }
  - (BOOL) tlsEncryptionIsStarted
  {
    return _tlsStarted;
  }

//

  - (SBString*) baseDN { return _baseDN; }
  - (void) setBaseDN:(SBString*)baseDN
  {
    if ( baseDN ) baseDN = [baseDN copy];
    if ( _baseDN ) [_baseDN release];
    _baseDN = baseDN;
  }

@end

//
#pragma mark -
//

@implementation SBLDAPConnection(SBLDAPConnectionSearch)

  - (id) searchWithFilter:(SBString*)ldapFilter
  {
    return [self searchWithFilter:ldapFilter baseDN:nil scope:LDAP_SCOPE_SUBTREE ignoreAttributes:NO];
  }
  - (id) searchWithFilter:(SBString*)ldapFilter
    baseDN:(SBString*)baseDN
  {
    return [self searchWithFilter:ldapFilter baseDN:baseDN scope:LDAP_SCOPE_SUBTREE ignoreAttributes:NO];
  }
  - (id) searchWithFilter:(SBString*)ldapFilter
    baseDN:(SBString*)baseDN
    scope:(int)scope
  {
    return [self searchWithFilter:ldapFilter baseDN:baseDN scope:scope ignoreAttributes:NO];
  }
  - (id) searchWithFilter:(SBString*)ldapFilter
    baseDN:(SBString*)baseDN
    scope:(int)scope
    ignoreAttributes:(BOOL)ignoreAttributes
  {
    id              resultObj = nil;
    
    if ( _ldapConn ) {
      size_t        ldapFilterLen = [ldapFilter utf8Length] + 1;
      size_t        baseDNLen = 0;
      size_t        localBufferLen = ldapFilterLen;
      
      if ( baseDN ) {
        localBufferLen += (baseDNLen = [baseDN utf8Length] + 1);
      } else if ( _baseDN ) {
        baseDN = _baseDN;
        localBufferLen += (baseDNLen = [baseDN utf8Length] + 1);
      }
      
      if ( localBufferLen ) {
        char          localBuffer[localBufferLen];
        char*         baseDNBuffer = ( baseDN ? localBuffer + ldapFilterLen : NULL );
        LDAPMessage*  results;
        int           rc;
        
        [ldapFilter copyUTF8CharactersToBuffer:localBuffer length:ldapFilterLen];
        if ( baseDNLen )
          [baseDN copyUTF8CharactersToBuffer:baseDNBuffer length:baseDNLen];
        
        rc =ldap_search_ext_s(
              _ldapConn,
              baseDNBuffer,
              scope,
              localBuffer,
              NULL,
              ( ignoreAttributes ? 1 : 0 ),
              NULL,
              NULL,
              NULL,
              0,
              &results
            );
        if ( rc == LDAP_SUCCESS ) {
          if ( results ) {
            LDAPMessage*    message = ldap_first_entry(_ldapConn, results);
            
            if ( message ) {
              int           messageCount = ldap_count_entries(_ldapConn, results);
              
              if ( messageCount == 1 ) {
                resultObj = [[[SBLDAPSearchResult alloc] initWithConnection:_ldapConn message:message ignoreAttributes:ignoreAttributes] autorelease];
              } else {
                SBLDAPSearchResult*   results[messageCount];
                int                   i = 0;
                
                while ( message ) {
                  results[i++] = [[[SBLDAPSearchResult alloc] initWithConnection:_ldapConn message:message ignoreAttributes:ignoreAttributes] autorelease];
                  message = ldap_next_entry(_ldapConn, message);
                }
                resultObj = [SBArray arrayWithObjects:results count:messageCount];
              }
              ldap_msgfree(results);
            }
          }
        } else {
          rc = [self lastResultCode];
          
          return [SBError errorWithDomain:SBLDAPErrorDomain
                        code:rc
                        supportingData:[SBDictionary dictionaryWithObject:
                            [SBString stringWithFormat:"LDAP search failed: %s", ldap_err2string(rc)]
                            forKey:SBErrorExplanationKey]
                      ];
        }
      }
    }
    return resultObj;
  }
  
//

  - (id) searchWithAttributeKey:(SBString*)attrKey
    value:(SBString*)attrValue
  {
    return [self searchWithAttributeKey:attrKey value:attrValue baseDN:nil scope:LDAP_SCOPE_SUBTREE ignoreAttributes:NO];
  }
  - (id) searchWithAttributeKey:(SBString*)attrKey
    value:(SBString*)attrValue
    baseDN:(SBString*)baseDN
  {
    return [self searchWithAttributeKey:attrKey value:attrValue baseDN:baseDN scope:LDAP_SCOPE_SUBTREE ignoreAttributes:NO];
  }
  - (id) searchWithAttributeKey:(SBString*)attrKey
    value:(SBString*)attrValue
    baseDN:(SBString*)baseDN
    scope:(int)scope
  {
    return [self searchWithAttributeKey:attrKey value:attrValue baseDN:baseDN scope:scope ignoreAttributes:NO];
  }
  - (id) searchWithAttributeKey:(SBString*)attrKey
    value:(SBString*)attrValue
    baseDN:(SBString*)baseDN
    scope:(int)scope
    ignoreAttributes:(BOOL)ignoreAttributes
  {
    SBString*     filter = [[SBString alloc] initWithFormat:"(%S=%S)", [attrKey utf16Characters], [attrValue utf16Characters]];
    id            result = [self searchWithFilter:filter baseDN:baseDN scope:scope ignoreAttributes:ignoreAttributes];
    
    [filter release];
    return result;
  }

@end

//
#pragma mark -
//

@implementation SBLDAPConnection(SBLDAPConnectionAuth)

  + (BOOL) forceTLSDuringBind
  {
    return __SBLDAPConnectionForceTLSDuringBind;
  }
  + (void) setForceTLSDuringBind:(BOOL)forceTLSDuringBind
  {
    __SBLDAPConnectionForceTLSDuringBind = forceTLSDuringBind;
  }
  
//

  - (SBLDAPSearchResult*) bindWithDN:(SBString*)aDN
    password:(SBString*)password
    error:(SBError**)error
  {
    size_t      dnLen = [aDN utf8Length] + 1;
    size_t      bufferLen = dnLen;
    size_t      passwordLen = 0;
    
    if ( __SBLDAPConnectionForceTLSDuringBind )
      if ( ! [self startTLSEncryption:error] )
        return nil;
    
    if ( password )
      bufferLen += (passwordLen = [password utf8Length]);
    
    if ( bufferLen ) {
      BerValue  credentials;
      BerValue* bound = NULL;
      char      buffer[bufferLen];
      char*     passwordBuffer = buffer + dnLen;
      int       rc;
      
      [aDN copyUTF8CharactersToBuffer:buffer length:dnLen];
      [password copyUTF8CharactersToBuffer:passwordBuffer length:passwordLen];
      
      credentials.bv_len = passwordLen;
      credentials.bv_val = passwordBuffer;
      
      rc = ldap_sasl_bind_s(
          _ldapConn,
          buffer,
          LDAP_SASL_SIMPLE,
          &credentials,
          NULL,
          NULL,
          &bound
        );
      
      if ( rc == LDAP_SUCCESS ) {
        id    result = [self searchWithFilter:@"(objectclass=*)" baseDN:aDN scope:LDAP_SCOPE_BASE];
        
        if ( result && [result isKindOf:[SBError class]] ) {
          if ( error )
            *error = result;
          result = nil;
        }
        return result;
      } else if ( error ) {
        rc = [self lastResultCode];
        *error = [SBError errorWithDomain:SBLDAPErrorDomain
                        code:rc
                        supportingData:[SBDictionary dictionaryWithObject:
                            [SBString stringWithFormat:"LDAP bind failed: %s", ldap_err2string(rc)]
                            forKey:SBErrorExplanationKey]
                      ];
      }
    }
    return nil;
  }
  
//

  - (SBLDAPSearchResult*) bindWithUser:(SBString*)uname
    password:(SBString*)password
    error:(SBError**)error
  {
    // Gotta lookup a DN for the username first:
    id      dnForUser = [self searchWithAttributeKey:@"uid" value:uname baseDN:nil scope:LDAP_SCOPE_SUBTREE ignoreAttributes:YES];
    
    if ( dnForUser ) {
      if ( [dnForUser isKindOf:[SBError class]] ) {
        if ( error )
          *error = dnForUser;
      } else {
        SBString*     dn = nil;
        
        if ( [dnForUser isKindOf:[SBArray class]] ) {
          if ( error )
            *error = [SBError errorWithDomain:SBLDAPErrorDomain
                        code:kSBLDAPMultipleDNInBind
                        supportingData:[SBDictionary dictionaryWithObjectsAndKeys:
                            [SBString stringWithFormat:"Attempt to bind to uid `%S` yielded multiple DNs", [uname utf16Characters]],
                            SBErrorExplanationKey,
                            dnForUser,
                            SBErrorLDAPMultiDNListKey,
                            nil
                          ]
                      ];
        
        
          dn = [[dnForUser objectAtIndex:0] distinguishedName];
        } else {
          dn = [dnForUser distinguishedName];
        }
        if ( dn ) {
          return [self bindWithDN:dn password:password error:error];
        }
      }
    }
    return nil;
  }
  
//

  - (BOOL) booleanBindWithDN:(SBString*)aDN
    password:(SBString*)password
    error:(SBError**)error
  {
    size_t      dnLen = [aDN utf8Length] + 1;
    size_t      bufferLen = dnLen;
    size_t      passwordLen = 0;
    
    if ( __SBLDAPConnectionForceTLSDuringBind )
      if ( ! [self startTLSEncryption:error] )
        return NO;
    
    if ( password )
      bufferLen += (passwordLen = [password utf8Length]);
    
    if ( bufferLen ) {
      BerValue  credentials;
      BerValue* bound = NULL;
      char      buffer[bufferLen];
      char*     passwordBuffer = buffer + dnLen;
      int       rc;
      
      [aDN copyUTF8CharactersToBuffer:buffer length:dnLen];
      [password copyUTF8CharactersToBuffer:passwordBuffer length:passwordLen];
      
      credentials.bv_len = passwordLen;
      credentials.bv_val = passwordBuffer;
      
      rc = ldap_sasl_bind_s(
          _ldapConn,
          buffer,
          LDAP_SASL_SIMPLE,
          &credentials,
          NULL,
          NULL,
          &bound
        );
      
      if ( rc == LDAP_SUCCESS ) {
        return YES;
      } else if ( error ) {
        rc = [self lastResultCode];
        *error = [SBError errorWithDomain:SBLDAPErrorDomain
                        code:rc
                        supportingData:[SBDictionary dictionaryWithObject:
                            [SBString stringWithFormat:"LDAP bind failed: %s", ldap_err2string(rc)]
                            forKey:SBErrorExplanationKey]
                      ];
      }
    }
    return NO;
  }
  
//

  - (BOOL) booleanBindWithUser:(SBString*)uname
    password:(SBString*)password
    error:(SBError**)error
  {
    // Gotta lookup a DN for the username first:
    id      dnForUser = [self searchWithAttributeKey:@"uid" value:uname baseDN:nil scope:LDAP_SCOPE_SUBTREE ignoreAttributes:YES];
    
    if ( dnForUser ) {
      if ( [dnForUser isKindOf:[SBError class]] ) {
        if ( error )
          *error = dnForUser;
      } else {
        SBString*     dn = nil;
        
        if ( [dnForUser isKindOf:[SBArray class]] ) {
          if ( error )
            *error = [SBError errorWithDomain:SBLDAPErrorDomain
                        code:kSBLDAPMultipleDNInBind
                        supportingData:[SBDictionary dictionaryWithObjectsAndKeys:
                            [SBString stringWithFormat:"Attempt to bind to uid `%S` yielded multiple DNs", [uname utf16Characters]],
                            SBErrorExplanationKey,
                            dnForUser,
                            SBErrorLDAPMultiDNListKey,
                            nil
                          ]
                      ];
        
        
          dn = [[dnForUser objectAtIndex:0] distinguishedName];
        } else {
          dn = [dnForUser distinguishedName];
        }
        if ( dn ) {
          return [self booleanBindWithDN:dn password:password error:error];
        }
      }
    }
    return NO;
  }

@end

//
#pragma mark -
//

@implementation SBLDAPSearchResult(SBLDAPSearchResultPrivate)

  - (id) initWithConnection:(LDAP*)ldapConn
    message:(LDAPMessage*)message
    ignoreAttributes:(BOOL)ignoreAttributes
  {
    char*       dn = ldap_get_dn(ldapConn, message);
    
    if ( ! dn ) {
      [self release];
      self = nil;
    } else if ( self = [super init] ) {
      char*       attrKey;
      BerElement* attrValue;
      
      _dn = [[SBString alloc] initWithUTF8String:dn];
      ldap_memfree(dn);
      
      if ( ! ignoreAttributes ) {
        _attributes = [[SBMutableDictionary alloc] init];
        
        // Populate the attributes:
        attrKey = ldap_first_attribute(ldapConn, message, &attrValue);
        while ( attrKey ) {
          BerValue    **values = ldap_get_values_len(ldapConn, message, attrKey);
          
          if ( values ) {
            int         valueCount = ldap_count_values_len(values);
            id          valueObj = [SBNull null];
            BerValue**  valuesSaved = values;
            
            if ( valueCount > 0 ) {
              if ( valueCount > 1 ) {
                SBString*   strings[valueCount];
                int         i = 0;
                
                while ( *values ) {
                  strings[i++] = [SBString stringWithUTF8String:(*values)->bv_val length:(*values)->bv_len];
                  values++;
                }
                valueObj = [SBArray arrayWithObjects:strings count:valueCount];
              } else {
                valueObj = [SBString stringWithUTF8String:(*values)->bv_val length:(*values)->bv_len];
              }
            }
            [_attributes setValue:valueObj forKey:[SBString stringWithUTF8String:attrKey]];
            ldap_value_free_len(valuesSaved);
          }
          
          ldap_memfree(attrKey);
          attrKey = ldap_next_attribute(ldapConn, message, attrValue);
        }
      }
    } else {
      ldap_memfree(dn);
    }
    return self;
  }

@end

@implementation SBLDAPSearchResult

  - (void) dealloc
  {
    if ( _dn ) [_dn release];
    if ( _attributes ) [_attributes release];
    [super dealloc];
  }

//

  - (SBString*) distinguishedName { return _dn; }
  - (SBDictionary*) attributes { return _attributes; }
  - (id) attributeValueForKey:(SBString*)key
  {
    if ( _attributes )
      return [_attributes valueForKey:key];
    return nil;
  }
  
//

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(stream, "{\n    dn: ");
    if ( _dn )
      [_dn writeToStream:stream];
    fprintf(stream, "\n    attributes:");
    if ( _attributes )
      [_attributes summarizeToStream:stream];
    fprintf(stream, "\n}\n");
  }

@end
