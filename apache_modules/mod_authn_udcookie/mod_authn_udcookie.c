//
// mod_authn_udcookie
// Apache 2.x Authentication via Cookie
//
// Authenticates a remote client by means of a cookie.  On a per-directory basis the
// cookie name and a 32-character "entropic secret" must be specified; the incoming cookie
// contains a uid, remote IP, a per-session random integer, and an MD5 hash of those values
// concatenated with the cookie name and secret.  The entropic secret permutes the hash in
// a fashion which should (hypothetically) only be reproducible given prior knowledge of
// the secret.  Coupled with the random integer in the cookie itself, we should have enough
// randomness to keep the cookies secure.
//
// The cookie looks like:
//
//   [user id]:[remote IP]:[expire time]:[random integer]:[cookie hash]
//
// Any punctuation may be used to separate the components.  The [expire time] is presented
// as a UTC offset in a modified ISO 8601 format:  YYYYmmddHHMMSS.
//
// This module consists of three hooks.  First, an access-control hook checks for the presence
// of the specific cookie in which we're interested (a per-directory conf directive controls
// this value).  If the cookie is present, it is parsed and an expanded cookie value containing
// the entropic secret and cookie name is created and hashed.  If the hash of the expanded
// cookie matches the hash embedded in the cookie, then we've established the authenticity of
// the given user.  If we're to be authoritative, then any inability to establish an identity
// yields an HTTP_UNAUTHORIZED.  If successful, an "Authorization" header is added to the
// request (to keep mod_auth_basic happy) and we add a note of our having authenticated the
// request.
//
// The second hook is a basic authentication provider.  Quite simply, it looks for our
// authenticated note on the request and grants access if it is there.  We decline to handle
// authentication otherwise -- this allows authentication to be passed along to other basic
// methods (file, ldap, dbd) which will fail and subsequently return a 401 error to request a
// an actual username/password from the remote agent.
//
// We don't do any authorization -- once we've established a username the other authz providers
// can do it for us!
//
// The final hook is a "fixup" procedure to be run just before a response is sent back to the
// remote agent.  This is the point at which we add a "Set-Cookie" header if the directory
// in question has AuthUDCookieUpdateTTL set to a non-zero number of seconds.  Just as with
// the access-check, we add a note to indicate we've already sent and updated cookie to avoid
// having any sub-requests do likewise.
//
// Copyright © 2009
// J T Frey, Network & Systems Services
// University of Delaware
//
// $Id: mod_authn_udcookie.c 292 2010-02-09 03:55:56Z frey $
//

#include "apr_strings.h"
#define APR_WANT_STRFUNC
#include "apr_want.h"

#include "ap_config.h"
#include "httpd.h"
#include "http_config.h"
#include "http_core.h"
#include "http_log.h"
#include "http_protocol.h"
#include "http_request.h"

#include "ap_regex.h"
#include "mod_auth.h"
#include "util_md5.h"
#include "apr_time.h"
#include "apr_base64.h"
#include "ap_provider.h"

#define AUTHN_UDCOOKIE_WUZHERE_NOTE "authn_udcookie_wuzhere"
#define AUTHN_UDCOOKIE_WUZSENT_NOTE "authn_udcookie_wuzsent"

#define AUTHN_UDCOOKIE_SESSIONTTL -1

module AP_MODULE_DECLARE_DATA authn_udcookie_module;

/*!
  @typedef authn_udcookie_config
  @discussion
  The per-directory configuration data that this module will
  make use of.
  @field authoritative If a cookie is not found or is invalid in any way, should
    the module pass control along to the next hook, or deny access immediately?
  @field verbose Should we add info messages to the error logs?
  @field updateCookieTTL Number of seconds to age a cookie past "now" when
    successfully validated
  @field cookieName The name of the cookie we'll look for
  @field cookieNameLen Length of the cookieName string (cached so we don't have
    to repeatedly call strlen() on it)
  @field entropicSecret The 32-character string which is introduced into the expanded
    form of the cookie to decrease the break-a-bility of the hash
  @field cookieDecompReady Non-zero if the cookieDecomp regex has been initialized
  @field cookieDecome A pre-compiled regular expression used to decompose the cookie
    value into the four components we make use of
*/
typedef struct {
  int           authoritative;
  int           expireInvalid;
  int           verbose;
  
  apr_int64_t   updateCookieTTL;
  char*         cookiePath;
  char*         cookieDomain;
  int           cookieSecureOnly;
  
  char*         cookieName;
  int           cookieNameLen;
  char*         entropicSecret;
  int           cookieDecompReady;
  ap_regex_t    cookieDecomp;
} authn_udcookie_config;

/*!
  @function authn_udcookie_cleanupDirConfig
  @discussion
  Called when the memory pool for a authn_udcookie_config is about to be destroyed;
  we need to dispose of the pre-compiled regex if we created it.
*/
static apr_status_t
authn_udcookie_cleanupDirConfig(
  void*           conf
)
{
  authn_udcookie_config*    CONF = (authn_udcookie_config*)conf;
  
  if ( CONF && CONF->cookieDecompReady )
    ap_regfree(&CONF->cookieDecomp);
  return APR_SUCCESS;
}

/*!
  @function authn_udcookie_createConfig
  @discussion
  Allocates and initializes a new per-directory configuration for this module.
  Also pre-compiles the regex which will be used to decompose a cookie value into
  its constituent parts.
*/
static void*
authn_udcookie_createDirConfig(
  apr_pool_t*     p,
  char*           d
)
{
  authn_udcookie_config*      conf = apr_pcalloc(p, sizeof(authn_udcookie_config));
  int                         regexrc;
  
  conf->authoritative = conf->verbose = conf->updateCookieTTL = 0;
  conf->cookieName = NULL;
  conf->cookieNameLen = 0;
  
  conf->cookieDecompReady = ( ap_regcomp(&conf->cookieDecomp, "^=(([^,]+),)(([^,]+),)(([0-9]{8}T[0-9]{6}),)(([^,]+),)([^;]+);?", AP_REG_ICASE) == 0 );
  if ( ! conf->cookieDecompReady ) {
    ap_log_perror(APLOG_MARK, APLOG_ERR, 0, p, "regexrc = %d", regexrc);
  } else {
    apr_pool_cleanup_register(p, conf, authn_udcookie_cleanupDirConfig, authn_udcookie_cleanupDirConfig);
  }
  return (void*)conf;
}

/*!
  @function authn_udcookie_setUpdateCookieTTL
  @discussion
  Command-handler which sets a per-directory config's updateCookieTTL.
*/
static const char*
authn_udcookie_setUpdateCookieTTL(
  cmd_parms*      parms,
  void*           config,
  const char*     arg
)
{
  authn_udcookie_config*      conf = (authn_udcookie_config*)config;
  
  if ( arg ) {
    if ( strcasecmp(arg, "session") == 0 ) {
      conf->updateCookieTTL = AUTHN_UDCOOKIE_SESSIONTTL;
    } else {
      apr_int64_t   seconds = apr_atoi64(arg);
      
      if ( seconds < 0 )
        conf->updateCookieTTL = AUTHN_UDCOOKIE_SESSIONTTL;
      else
        conf->updateCookieTTL = APR_USEC_PER_SEC * seconds;
    }
  } else
    conf->updateCookieTTL = AUTHN_UDCOOKIE_SESSIONTTL;
  return NULL;
}

/*!
  @function authn_udcookie_setCookiePath
  @discussion
  Command-handler which sets a per-directory config's cookiePath
  attribute
*/
static const char*
authn_udcookie_setUpdateCookiePath(
  cmd_parms*      parms,
  void*           config,
  const char*     arg
)
{
  authn_udcookie_config*      conf = (authn_udcookie_config*)config;
  
  if ( arg && strlen(arg) )
    conf->cookiePath = apr_pstrdup(parms->pool, arg);
  return NULL;
}

/*!
  @function authn_udcookie_setCookieDomain
  @discussion
  Command-handler which sets a per-directory config's cookieDomain
  attribute
*/
static const char*
authn_udcookie_setUpdateCookieDomain(
  cmd_parms*      parms,
  void*           config,
  const char*     arg
)
{
  authn_udcookie_config*      conf = (authn_udcookie_config*)config;
  
  if ( arg && strlen(arg) )
    conf->cookieDomain = apr_pstrdup(parms->pool, arg);
  return NULL;
}

/*!
  @function authn_udcookie_setCookieName
  @discussion
  Command-handler which sets a per-directory config's cookieName attributed (and
  the cookieNameLen).
*/
static const char*
authn_udcookie_setCookieName(
  cmd_parms*      parms,
  void*           config,
  const char*     arg
)
{
  authn_udcookie_config*      conf = (authn_udcookie_config*)config;
  
  conf->cookieName = apr_pstrdup(parms->pool, arg);
  conf->cookieNameLen = strlen(conf->cookieName);
  return NULL;
}

/*!
  @function authn_udcookie_setEntropicSecret
  @discussion
  Command-handler which sets a per-directory config's entropicSecret; checks
  to ensure the string is 32 characters long, just as we want it to be.
*/
static const char*
authn_udcookie_setEntropicSecret(
  cmd_parms*      parms,
  void*           config,
  const char*     arg
)
{
  authn_udcookie_config*      conf = (authn_udcookie_config*)config;
  
  if ( strlen(arg) != 32 )
    return "The AuthUDCookieEntropicSecret must be 32 characters long.";
    
  conf->entropicSecret = apr_pstrdup(parms->pool, arg);
  return NULL;
}

/*!
  @const authn_udcookie_cmds
  @discussion
  Apache config directives for this module.
*/
static const command_rec authn_udcookie_cmds[] =
{
  AP_INIT_FLAG(
      "AuthUDCookieVerbose",
      ap_set_flag_slot,
      (void *)APR_OFFSETOF(authn_udcookie_config, verbose),
      OR_AUTHCFG,
      "Should we display stuff to error_log?"
    ),
  AP_INIT_FLAG(
      "AuthUDCookieExpireIfInvalid",
      ap_set_flag_slot,
      (void *)APR_OFFSETOF(authn_udcookie_config, expireInvalid),
      OR_AUTHCFG,
      "Should we automatically expire any invalid cookies we see?"
    ),
  AP_INIT_FLAG(
      "AuthUDCookieAuthoritative",
      ap_set_flag_slot,
      (void *)APR_OFFSETOF(authn_udcookie_config, authoritative),
      OR_AUTHCFG,
      "Should we pass-along or block on failed cookie parses?"
    ),
  AP_INIT_TAKE1(
      "AuthUDCookieUpdateTTL",
      authn_udcookie_setUpdateCookieTTL,
      NULL,
      OR_AUTHCFG,
      "Number of seconds to age the cookie when validated successfully; default (0) implies "
      "the cookie should not be automatically updated by us."
    ),
  AP_INIT_TAKE1(
      "AuthUDCookieUpdatePath",
      authn_udcookie_setUpdateCookiePath,
      NULL,
      OR_AUTHCFG,
      "Number of seconds to age the cookie when validated successfully; default (0) implies "
      "the cookie should not be automatically updated by us."
    ),
  AP_INIT_TAKE1(
      "AuthUDCookieUpdateDomain",
      authn_udcookie_setUpdateCookieDomain,
      NULL,
      OR_AUTHCFG,
      "Domain to which the cookie we send back should be applicable"
    ),
  AP_INIT_FLAG(
      "AuthUDCookieUpdateSecureOnly",
      ap_set_flag_slot,
      (void *)APR_OFFSETOF(authn_udcookie_config, cookieSecureOnly),
      OR_AUTHCFG,
      "Should the cookie we output be for secure connections only?"
    ),
  AP_INIT_TAKE1(
      "AuthUDCookieName",
      authn_udcookie_setCookieName,
      NULL,
      OR_AUTHCFG,
      "Name of the cookie to consult for a valid user identifier."
    ),
  AP_INIT_TAKE1(
      "AuthUDCookieEntropicSecret",
      authn_udcookie_setEntropicSecret,
      NULL,
      OR_AUTHCFG,
      "An MD5 string used to add an random unknown to the pre-hash string."
    ),
  {NULL}
};

/*!
  @function authn_udcookie_expireCookie
  @discussion
  Add an output header to invalidate the cookie.
*/
static void
authn_udcookie_expireCookie(
  request_rec*    r
)
{
  authn_udcookie_config*      conf = ap_get_module_config(
                                            r->per_dir_config,
                                            &authn_udcookie_module
                                          );
                                          
  const char*                 notes;
  
  (notes = apr_table_get(r->notes, AUTHN_UDCOOKIE_WUZSENT_NOTE)) || (notes = (r->main ? apr_table_get(r->main->notes, AUTHN_UDCOOKIE_WUZSENT_NOTE) : NULL));
  if ( ! notes ) {
    const char*               newCookie = apr_table_get(r->err_headers_out, "Set-Cookie");
    char*                     newValue;
    
    // Empty cookie, with an expire time in the past:
    newValue = apr_psprintf(
                      r->pool,
                      "%s=; expires=Fri, 25-Mar-1977 00:00:00 GMT;",
                      conf->cookieName
                    );
    if ( conf->cookiePath )
      newValue = apr_pstrcat(r->pool, newValue, "path=", conf->cookiePath, "; ", NULL);
    if ( conf->cookieDomain )
      newValue = apr_pstrcat(r->pool, newValue, "domain=", conf->cookieDomain, "; ", NULL);
    if ( conf->cookieSecureOnly )
      newValue = apr_pstrcat(r->pool, newValue, "secure; ", NULL);
    
    if ( newCookie )
      apr_table_set(r->err_headers_out, "Set-Cookie", apr_pstrcat(r->pool, newCookie, ";", newValue, NULL));
    else
      apr_table_set(r->err_headers_out, "Set-Cookie", newValue);
    
    if ( conf->verbose )
      ap_log_rerror(APLOG_MARK, APLOG_ERR, 0, r, "Expire cookie: %s", newValue);
    
    //
    // So we only send an updated cookie once per session:
    //
    apr_table_setn(
      r->notes,
      AUTHN_UDCOOKIE_WUZSENT_NOTE,
      "1"
    );
  }
}

/*!
  @function authn_udcookie_checkAccess
  @discussion
  This is the main workhorse of this module.  Long story short, check for our cookie;
  if it's present in the request headers, then parse-out its components and calculate
  the MD5 hash of a reconstructed expanded cookie which contains our "secret" data.
  If that hash and the hash in the transmitted cookie match, then we know you, man!
*/
static int
authn_udcookie_checkAccess(
  request_rec*    r
)
{
  authn_udcookie_config*      conf = ap_get_module_config(
                                            r->per_dir_config,
                                            &authn_udcookie_module
                                          );
  const char*                 notes = NULL;
  int                         setNoteOnError = 0;
  
  //
  // In case we already had this check performed successfully for a parent request; by checking
  // the r->main request we can catch the authentication we already performed for the parent in a
  // keep-alive session, for instance:
  //
  (notes = apr_table_get(r->notes, AUTHN_UDCOOKIE_WUZHERE_NOTE)) || (notes = (r->main ? apr_table_get(r->main->notes, AUTHN_UDCOOKIE_WUZHERE_NOTE) : NULL));                                   
  if ( notes ) {
    if ( strcmp(notes, "1") == 0 )
      return OK;
    return ( conf->authoritative ? HTTP_UNAUTHORIZED : DECLINED );
  }
  
  // We know what cookie to check:
  if ( conf->cookieName && conf->cookieDecompReady ) {
    const char*               cookieHeader = apr_table_get(
                                                  r->headers_in,
                                                  "Cookie"
                                                );
    // Analyze the cookie (if it's there):
    if ( cookieHeader ) {
      // Can we find that cookie?
      char*                   cookieValue = ap_strstr(cookieHeader, conf->cookieName);
      
      if ( cookieValue ) {
        char*                 startOfValue = cookieValue + conf->cookieNameLen;
        char*                 endOfValue = ap_strstr(startOfValue, ";");
        ap_regmatch_t         matches[10];
        char*                 value;
        
        if ( endOfValue )
          value = apr_pstrmemdup(r->pool, startOfValue, endOfValue - startOfValue);
        else
          value = apr_pstrdup(r->pool, startOfValue);

        // Unescape any URI encoding:
        ap_unescape_url(value);
        
        if ( ap_regexec(&conf->cookieDecomp, value, 10, matches, 0) == 0 ) {
          // Build the expanded cookie using the components we isolated PLUS the
          // entropicSecret and stuff:
          //
          // matches[2] = uid
          // matches[4] = remote IP
          // matches[6] = expiration date and time
          // matches[8] = per-session random integer
          // matches[9] = expanded cookie hash
          
          // We want a non-null uid string for starters; we're not going to validate it at all, but
          // we can't do anything if the remote agent has no user identifier!!  Likewise, if the embedded
          // MD5 hash isn't the right length, we can't validate anything properly:
          if ( (matches[2].rm_eo > matches[2].rm_so) && (matches[9].rm_eo - matches[9].rm_so == 32) ) {
            char*                 uid = apr_pstrndup(r->pool, value + matches[2].rm_so, matches[2].rm_eo - matches[2].rm_so);
            char*                 remoteIP = apr_pstrndup(r->pool, value + matches[4].rm_so, matches[4].rm_eo - matches[4].rm_so);
            char*                 expiration = apr_pstrndup(r->pool, value + matches[6].rm_so, matches[6].rm_eo - matches[6].rm_so);
            char                  now[32];
            apr_size_t            dummy;
            apr_time_exp_t        expTime;
            
            // Has this thing expired?
            apr_time_exp_gmt(&expTime, apr_time_now());
            apr_strftime(now, &dummy, 32, "%Y%m%dT%H%M%S", &expTime);
            if ( strcasecmp(now, expiration) >= 0 ) {
              if ( conf->verbose ) {
                ap_log_rerror(APLOG_MARK, APLOG_ERR, 0, r, "Cookie has expired: %s > %s",
                    now,
                    expiration
                  );
              }
              goto cookie_error; 
            }
            
            // Let's also make sure the IP address of the remote agent matches the IP on this
            // request:
            if ( strcasecmp(r->connection->remote_ip, remoteIP) == 0 ) {
              char*               nonce = apr_pstrndup(r->pool, value + matches[8].rm_so, matches[8].rm_eo - matches[8].rm_so);
              char*               hash;
              char*               expandedCookie = apr_psprintf(
                                                        r->pool,
                                                        "%s %s %s %s %s %s",
                                                        uid,
                                                        remoteIP,
                                                        expiration,
                                                        nonce,
                                                        conf->cookieName,
                                                        conf->entropicSecret
                                                      );
              
              // Get the md5 hash of the expanded cookie:
              hash = ap_md5(r->pool, (const unsigned char*)expandedCookie);
              if ( hash && strncasecmp(hash, value + matches[9].rm_so, matches[9].rm_eo - matches[9].rm_so) == 0 ) {
                char*   authData = apr_psprintf(r->pool, "%s:", uid);
                int     authDataLen = strlen(authData);
                char*   encodedAuthData = NULL;
                int     encodedAuthDataLen;
                
                r->user = uid;
                if ( conf->verbose ) {
                  ap_log_rerror(APLOG_MARK, APLOG_ERR, 0, r, "Set request user from cookie: %s",
                      uid
                    );
                }
                //
                // Add an authentication header so basic mod_auth will NOT send a 401 to request a password:
                //
                encodedAuthData = apr_palloc(r->pool, apr_base64_encode_len(authDataLen) + 1);
                encodedAuthData[ apr_base64_encode(encodedAuthData, authData, authDataLen) ] = '\0';
                authData = apr_psprintf(r->pool, "Basic %s", encodedAuthData);
                apr_table_set(
                    r->headers_in,
                    ((PROXYREQ_PROXY == r->proxyreq) ? "Proxy-Authorization" : "Authorization"),
                    authData
                  );
                //
                // Finally, make a note of our being here so our authn function will pass the authentication
                // phase:
                //
                apr_table_setn(
                    r->notes,
                    AUTHN_UDCOOKIE_WUZHERE_NOTE,
                    "1"
                  );
                return OK;
              } else {
                if ( conf->verbose )
                  ap_log_rerror(APLOG_MARK, APLOG_ERR, 0, r, "Expanded cookie hash mismatch: %s <> %s",
                      hash,
                      apr_pstrndup(r->pool, value + matches[9].rm_so, matches[9].rm_eo - matches[9].rm_so)
                    );
                setNoteOnError = 1;
              }
            } else {
              if ( conf->verbose )
                ap_log_rerror(APLOG_MARK, APLOG_ERR, 0, r, "Cookie and request IP mismatch: %s <> %s",
                    r->connection->remote_ip,
                    remoteIP
                  );
              setNoteOnError = 1;
            }
          } else  {
            if ( conf->verbose )
              ap_log_rerror(APLOG_MARK, APLOG_ERR, 0, r, "Invalid user identifier or hash in cookie");
            setNoteOnError = 1;
          }
        } else {
          if ( conf->verbose )
            ap_log_rerror(APLOG_MARK, APLOG_ERR, 0, r, "Unrecognized cookie format: %s", cookieValue);
          setNoteOnError = 1;
        }
      }
    }
  }
  
cookie_error:
  if ( setNoteOnError ) {
    //
    // Invalidate the bad cookie?
    //
    if ( conf->expireInvalid )
      authn_udcookie_expireCookie(r);
      
    //
    // Make a note of our being here so for the rest of this session we don't have to re-check
    // this invalid cookie:
    //
    apr_table_setn(
        r->notes,
        AUTHN_UDCOOKIE_WUZHERE_NOTE,
        "0"
      );
  }
  return ( conf->authoritative ? HTTP_UNAUTHORIZED : DECLINED );
}

/*!
  @function authn_udcookie_password
  @discussion
  A simple authn hook that allows us to catch any authorization already granted via the access
  check (above) and still keep us hooked into the basic authnz chain so that authorization
  checks will happily use the username we pulled from the cookie.
*/
static authn_status
authn_udcookie_checkPassword(
  request_rec*  r,
  const char*   user,
  const char*   password
)
{
  authn_udcookie_config*        conf = ap_get_module_config(
                                            r->per_dir_config,
                                            &authn_udcookie_module
                                          );
  const char*                   notes = NULL;
  
  // Is our note in the request's notes table?
  (notes = apr_table_get(r->notes, AUTHN_UDCOOKIE_WUZHERE_NOTE)) || (notes = (r->main ? apr_table_get(r->main->notes, AUTHN_UDCOOKIE_WUZHERE_NOTE) : NULL));
  if ( notes && (strcmp(notes, "1") == 0) ) {
    if ( conf->verbose )
      ap_log_rerror(APLOG_MARK, APLOG_ERR, 0, r, "Authenticated from cookie: %s", user);
    return AUTH_GRANTED;
  }
  // We don't have to worry about being authoritative at this point -- our access check would have
  // caught that already.
  return AUTH_USER_NOT_FOUND;
}

static int
authn_udcookie_updateCookie(
  request_rec*    r
)
{
  authn_udcookie_config*      conf = ap_get_module_config(
                                            r->per_dir_config,
                                            &authn_udcookie_module
                                          );
  const char*                 notes;
  
  if ( conf->updateCookieTTL ) {
    (notes = apr_table_get(r->notes, AUTHN_UDCOOKIE_WUZSENT_NOTE)) || (notes = (r->main ? apr_table_get(r->main->notes, AUTHN_UDCOOKIE_WUZSENT_NOTE) : NULL));
    if ( ! notes ) {
      (notes = apr_table_get(r->notes, AUTHN_UDCOOKIE_WUZHERE_NOTE)) || (notes = (r->main ? apr_table_get(r->main->notes, AUTHN_UDCOOKIE_WUZHERE_NOTE) : NULL));
      //
      // Auto-update the cookie?  If there was no AUTHN_UDCOOKIE_WUZHERE_NOTE, then we auth'ed through
      // some other mechanism; if there was, then it has to be "1" (success):
      //
      if ( r->user && (! notes || (*notes == '1')) ) {
        char                  now[32], otherNow[APR_RFC822_DATE_LEN];
        apr_size_t            dummy;
        apr_time_t            when;
        apr_time_exp_t        expTime;
        long int              newNonce = random();
        const char*           newCookie = apr_table_get(r->headers_out, "Set-Cookie");
        char*                 newValue;
        char*                 hash;
        
        // If session, then add an inordinate amount of time:
        if ( conf->updateCookieTTL == AUTHN_UDCOOKIE_SESSIONTTL )
          when = apr_time_now() + (APR_USEC_PER_SEC * 315360000); // 10 years
        else
          when = apr_time_now() + conf->updateCookieTTL;
        
        apr_time_exp_gmt(&expTime, when);
        apr_strftime(now, &dummy, 32, "%Y%m%dT%H%M%S", &expTime);
        apr_rfc822_date(otherNow, when);
        newValue = apr_psprintf(
                          r->pool,
                          "%s %s %s %d %s %s",
                          r->user,
                          r->connection->remote_ip,
                          now,
                          newNonce,
                          conf->cookieName,
                          conf->entropicSecret
                        );
        hash = ap_md5(r->pool, (const unsigned char*)newValue);
        
        newValue = apr_psprintf(
                        r->pool,
                        "%s,%s,%s,%d,%s",
                        r->user,
                        r->connection->remote_ip,
                        now,
                        newNonce,
                        hash
                      );
        
        newValue = apr_psprintf(
                        r->pool,
                        ( conf->updateCookieTTL == AUTHN_UDCOOKIE_SESSIONTTL ?
                            "%s=%s; " :
                            "%s=%s; expires=%s; "
                          ),
                        conf->cookieName,
                        ap_escape_uri(r->pool, newValue),
                        otherNow
                      );
        if ( conf->cookiePath )
          newValue = apr_pstrcat(r->pool, newValue, "path=", conf->cookiePath, "; ", NULL);
        if ( conf->cookieDomain )
          newValue = apr_pstrcat(r->pool, newValue, "domain=", conf->cookieDomain, "; ", NULL);
        if ( conf->cookieSecureOnly )
          newValue = apr_pstrcat(r->pool, newValue, "secure; ", NULL);
        
        if ( newCookie )
          apr_table_set(r->headers_out, "Set-Cookie", apr_pstrcat(r->pool, newCookie, ";", newValue, NULL));
        else
          apr_table_set(r->headers_out, "Set-Cookie", newValue);
        
        //
        // So we only send an updated cookie once per session:
        //
        apr_table_setn(
          r->notes,
          AUTHN_UDCOOKIE_WUZSENT_NOTE,
          "1"
        );
      }
    }
  }
  return OK;
}

/*!
  @function authn_udcookie_registerHooks
  @discussion
  Register our hooks so that we can actually affect the serving of pages!
*/
static void
authn_udcookie_registerHooks(
  apr_pool_t*   p
)
{
  static const authn_provider authn_udcookie_provider = {
    &authn_udcookie_checkPassword,
    NULL
  };
    
  ap_hook_access_checker(authn_udcookie_checkAccess, NULL, NULL, APR_HOOK_FIRST);
  ap_hook_fixups(authn_udcookie_updateCookie, NULL, NULL, APR_HOOK_LAST);
  ap_register_provider(p, AUTHN_PROVIDER_GROUP, "udcookie", "0", &authn_udcookie_provider);
}

module AP_MODULE_DECLARE_DATA authn_udcookie_module =
{
    STANDARD20_MODULE_STUFF,
    authn_udcookie_createDirConfig,   /* dir config creater */
    NULL,                             /* dir merger --- default is to override */
    NULL,                             /* server config */
    NULL,                             /* merge server config */
    authn_udcookie_cmds,              /* command apr_table_t */
    authn_udcookie_registerHooks      /* register hooks */
};
