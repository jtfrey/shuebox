//
// SBLDAPKit - LDAP-oriented extensions to SBFoundation
// SBLDAP.h
//
// Access to LDAP servers.
//
// $Id$
//

#import "SBObject.h"

#include "ldap.h"

@class SBError, SBString, SBDictionary;

/*!
  @constant SBLDAPErrorDomain
  @discussion
  SBError instances returned by SLDAPConnection will have this string
  as their error domain.
*/
extern SBString* SBLDAPErrorDomain;


/*!
  @enum LDAP Kit error codes
*/
enum {
  kSBLDAPOkay = 0,
  
  kSBLDAPMultipleDNInBind = 10000
};


/*!
  @constant SBErrorLDAPMultiDNListKey
  @discussion
  String which keys an SBArray of the matching DNs in an SBError returned
  while attempting to bind to a uid with multiple matches.
*/
extern SBString* SBErrorLDAPMultiDNListKey;


/*!
  @class SBLDAPSearchResult
  @discussion
  When an LDAP search is performed, one or more directory entities will
  be returned.  Each directory entity has a DN and a set of key-value
  attributes.  Each such entity is wrapped by an instance of
  SBLDAPSearchResult.
*/
@interface SBLDAPSearchResult : SBObject
{
  SBString*       _dn;
  SBDictionary*   _attributes;
}

/*!
  @method distinguishedName
  @discussion
  Returns the DN for the directory entity.
*/
- (SBString*) distinguishedName;
/*!
  @method attributes
  @discussion
  Returns the dictionary containing all of the attributes of the
  directory entity.
  
*/
- (SBDictionary*) attributes;
/*!
  @method attributeValueForKey:
  @discussion
  Returns the value associated with a particular attribute.  Attribute
  values will be a single SBString or an SBArray of SBString
  instances.
*/
- (id) attributeValueForKey:(SBString*)key;

@end


/*!
  @class SBLDAPConnection
  @discussion
  An instance of SBLDAPConnection wraps a connection to an LDAP server. Connections
  can be created using the server's hostname and (optionally) the TCP/IP port and basic
  SSL security consideration.  Connections can also be created using an LDAP URL.
  
  A connection is closed when the last reference to an SBLDAPConnection instance is
  released and the object is deallocated.
  
  A per-instance default base DN can be assigned.  The protocol version can also be
  dynamically selected (defaults to protocol version 3).
  
  A TLS session can be established over an existing unencrypted connection; note that
  this will only work if the LDAP server on the other end of that connection supports
  TLS.
  
  Searching can be performed either by specification of an attribute key-value pair or
  by means of an LDAP filter string.  Searches can have specific base DN, scope, and
  attribute treatment associated with them.  For example, to map a filter to one or
  more DNs, the values of all attributes associated with the returned DNs are not
  needed and will both slow down the lookup action and consume far more memory (and
  possibly bandwidth) than truly necessary for the operation.
*/
@interface SBLDAPConnection : SBObject
{
  LDAP*     _ldapConn;
  SBString* _url;
  SBString* _baseDN;
  BOOL      _tlsStarted;
}

/*!
  @method defaultProtocolVersion
  @discussion
  Returns the default LDAP protocol version which new instances should use.  Default
  is version 3.
*/
+ (int) defaultProtocolVersion;
/*!
  @method setDefaultProtocolVersion:
  @discussion
  Modify the default LDAP protocol version which new instances should use.
*/
+ (void) setDefaultProtocolVersion:(int)ldapProtVers;
/*!
  @method ldapConnectionWithServer:
  @discussion
  Attempts to open an unencrypted connection to the default LDAP port on the host
  with the given serverName.
  
  Returns nil if the connection could not be established.
*/
+ (id) ldapConnectionWithServer:(SBString*)serverName;
/*!
  @method ldapConnectionWithServer:port:
  @discussion
  Attempts to open an unencrypted connection to the given TCP/IP port on the host
  with the given serverName.
  
  Returns nil if the connection could not be established.
*/
+ (id) ldapConnectionWithServer:(SBString*)serverName port:(int)port;
/*!
  @method ldapConnectionWithServer:secure:
  @discussion
  Attempts to open an encrypted/unencrypted connection to the default LDAP port on
  the host with the given serverName.
  
  Returns nil if the connection could not be established.
*/
+ (id) ldapConnectionWithServer:(SBString*)serverName secure:(BOOL)secure;
/*!
  @method ldapConnectionWithServer:port:secure:
  @discussion
  Attempts to open an encrypted/unencrypted connection to the given TCP/IP port on
  the host with the given serverName.  If 0 < port < 65536, that port number is
  used; otherwise, the default LDAP port is used.  The secure flag indicates whether
  the ldap:// or ldaps:// URL scheme should be used when connecting.
  
  Returns nil if the connection could not be established.
*/
+ (id) ldapConnectionWithServer:(SBString*)serverName port:(int)port secure:(BOOL)secure;
/*!
  @method ldapConnectionWithURL:
  @discussion
  Attempts to open a connection to the LDAP server specified in the ldapURL.  The URL
  scheme provides for specifying the majority of options within the URL.  E.g.
  
    ldap{s}://[hostname]{:port#}/{dn{?attributes{?scope}{?filter}}{?extensions}
    
  See http://www.ietf.org/rfc/rfc1959.txt
*/
+ (id) ldapConnectionWithURL:(SBString*)ldapURL;
/*!
  @method initWithConnection:
  @discussion
  Initializes the receiver using the same connection settings for extantConnection.  Note
  that the "copy" method can also be used to duplicate an existing connection.
*/
- (id) initWithConnection:(SBLDAPConnection*)extantConnection;
/*!
  @method ldapConnectionURL
  @discussion
  Returns the URL used to create the receiver's LDAP server connection.
*/
- (SBString*) ldapConnectionURL;
/*!
  @method protocolVersion
  @discussion
  Returns the LDAP protocol version used by the receiver's connection.
*/
- (int) protocolVersion;
/*!
  @method setProtocolVersion:
  @discussion
  Attempts to modify the LDAP protocol version to be used by the receiver's connection.
*/
- (void) setProtocolVersion:(int)ldapProtVers;
/*!
  @method startTLSEncryption:
  @discussion
  Attempts to start TLS encryption on the receiver's connection.  Returns YES if the
  negotiation was successful (or was previously successful).  In case of any error,
  NO is returned and (if not NULL) error will contain an SBError represented the
  exception.
*/
- (BOOL) startTLSEncryption:(SBError**)error;
/*!
  @method tlsEncryptionIsStarted
  @discussion
  Returns YES if the receiver has started TLS encryption on its LDAP server
  connection.
*/
- (BOOL) tlsEncryptionIsStarted;
/*!
  @method baseDN
  @discussion
  Returns the receiver's base DN which will be used when a DN is not provided explicitly
  to search methods.
*/
- (SBString*) baseDN;
/*!
  @method setBaseDN:
  @discussion
  Set the receiver's default base DN which will be used when a DN is not provided
  explicitly to search methods.
*/
- (void) setBaseDN:(SBString*)baseDN;

@end


/*!
  @category SBLDAPConnection(SBLDAPConnectionSearch)
  @discussion
  Category which groups LDAP search methods.
  
  Possible return values for all methods are:
  <ul>
    <li>SBError:  returned if any error occurred during the search</li>
    <li>SBLDAPSearchResult:  the search produced a single directory entity</li>
    <li>SBArray:  the search produced multiple directory entities</li>
  </ul>
*/
@interface SBLDAPConnection(SBLDAPConnectionSearch)

/*!
  @method searchWithFilter:
  @discussion
  Search the receiver's LDAP directory tree for directory entities matching the provided
  LDAP filter string.  The default base DN for the receiver and subtree scope are implied.
  Attribute values will also be retrieved.
*/
- (id) searchWithFilter:(SBString*)ldapFilter;
/*!
  @method searchWithFilter:baseDN:
  @discussion
  Search the receiver's LDAP directory tree (from the given base DN) for directory entities
  matching the provided LDAP filter string.  Subtree scope is implied.  Attribute values will
  also be retrieved.
  
  If baseDN is nil, the default base DN for the receiver is used.
*/
- (id) searchWithFilter:(SBString*)ldapFilter baseDN:(SBString*)baseDN;
/*!
  @method searchWithFilter:baseDN:scope:
  @discussion
  Search the receiver's LDAP directory tree (from the given base DN) for directory entities
  matching the provided LDAP filter string.  The provided search scope is observed.
  Attribute values will also be retrieved.
  
  If baseDN is nil, the default base DN for the receiver is used.
*/
- (id) searchWithFilter:(SBString*)ldapFilter baseDN:(SBString*)baseDN scope:(int)scope;
/*!
  @method searchWithFilter:baseDN:scope:ignoreAttributes:
  @discussion
  Search the receiver's LDAP directory tree (from the given base DN) for directory entities
  matching the provided LDAP filter string.  The provided search scope is observed.
  Attribute values will only be retrieved if ignoreAttributes is NO.
  
  If baseDN is nil, the default base DN for the receiver is used.
*/
- (id) searchWithFilter:(SBString*)ldapFilter baseDN:(SBString*)baseDN scope:(int)scope ignoreAttributes:(BOOL)ignoreAttributes;
/*!
  @method searchWithAttributeKey:value:
  @discussion
  The attrKey and attrValue are concatenated to "([attrKey]=[attrValue])" form and the
  searchWithFilter: method is invoked.
*/
- (id) searchWithAttributeKey:(SBString*)attrKey value:(SBString*)attrValue;
/*!
  @method searchWithAttributeKey:value:baseDN:
  @discussion
  The attrKey and attrValue are concatenated to "([attrKey]=[attrValue])" form and the
  searchWithFilter:baseDN: method is invoked.
*/
- (id) searchWithAttributeKey:(SBString*)attrKey value:(SBString*)attrValue baseDN:(SBString*)baseDN;
/*!
  @method searchWithAttributeKey:value:baseDN:scope:
  @discussion
  The attrKey and attrValue are concatenated to "([attrKey]=[attrValue])" form and the
  searchWithFilter:baseDN:scope: method is invoked.
*/
- (id) searchWithAttributeKey:(SBString*)attrKey value:(SBString*)attrValue baseDN:(SBString*)baseDN scope:(int)scope;
/*!
  @method searchWithAttributeKey:value:baseDN:scope:ignoreAttributes:
  @discussion
  The attrKey and attrValue are concatenated to "([attrKey]=[attrValue])" form and the
  searchWithFilter:baseDN:scope:ignoreAttributes: method is invoked.
*/
- (id) searchWithAttributeKey:(SBString*)attrKey value:(SBString*)attrValue baseDN:(SBString*)baseDN scope:(int)scope ignoreAttributes:(BOOL)ignoreAttributes;

@end


/*!
  @category SBLDAPConnection(SBLDAPConnectionAuth)
  @discussion
  Category which groups LDAP authentication methods.
*/
@interface SBLDAPConnection(SBLDAPConnectionAuth)

/*!
  @method forceTLSDuringBind
  @discussion
  Returns YES if instances should by default attempt to start TLS on their connection stream
  prior to an LDAP bind which transmits authentication information.
*/
+ (BOOL) forceTLSDuringBind;
/*!
  @method setForceTLSDuringBind:
  @discussion
  If forceTLSDuringBind is YES then instances should attempt to start TLS on their connection
  stream prior to an LDAP bind which transmits authentication information.
*/
+ (void) setForceTLSDuringBind:(BOOL)forceTLSDuringBind;
/*!
  @method bindWithDN:password:error:
  @discussion
  Attempts to perform a simple bind to the given LDAP DN using the given password.  If the
  bind fails, nil is returned and (if not NULL) error contains an SBError representing the
  exception.  If successful, an SBLDAPSearchResult object is returned with all attributes
  found for the given DN.
*/
- (SBLDAPSearchResult*) bindWithDN:(SBString*)aDN password:(SBString*)password error:(SBError**)error;
/*!
  @method bindWithUser:password:error:
  @discussion
  Performs an LDAP search for a directory with a "uid" attribute matching the given uname.
  If a single DN is found, bindWithDN:password:error: is invoked.
  
  If unsuccessful in any regard, nil is returned and (if not NULL) error contains an SBError
  representing the exception.
*/
- (SBLDAPSearchResult*) bindWithUser:(SBString*)uname password:(SBString*)password error:(SBError**)error;
/*!
  @method booleanBindWithDN:password:error:
  @discussion
  Attempts to perform a simple bind to the given LDAP DN using the given password.  If the
  bind fails, nil is returned and (if not NULL) error contains an SBError representing the
  exception.  If successful, YES is returned.
*/
- (BOOL) booleanBindWithDN:(SBString*)aDN password:(SBString*)password error:(SBError**)error;
/*!
  @method booleanBindWithUser:password:error:
  @discussion
  Performs an LDAP search for a directory with a "uid" attribute matching the given uname.
  If a single DN is found, bindWithDN:password:error: is invoked.
*/
- (BOOL) booleanBindWithUser:(SBString*)uname password:(SBString*)password error:(SBError**)error;

@end
