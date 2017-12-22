/*
 * mod_authnz_shuebox
 *
 * SHUEBox authentication and initial authorization module.
 *
 * $Id$
 *
 */

#include "ap_provider.h"
#include "httpd.h"
#include "http_config.h"
#include "http_core.h"
#include "http_log.h"
#include "http_protocol.h"
#include "http_request.h"
#include "util_ldap.h"
#include "apr_lib.h"
#include "apr_dbd.h"
#include "mod_dbd.h"
#include "apr_strings.h"
#include "mod_auth.h"
#include "apr_md5.h"
#include "apr_xlate.h"
#include "apu_version.h"
#include "apr_ldap.h"

#define APR_WANT_STRFUNC
#include "apr_want.h"
#include "apr_lib.h"

#if APR_HAVE_UNISTD_H
/* for getpid() */
#include <unistd.h>
#endif
#include <ctype.h>

#if 0
#define AUTHNZ_SHUEBOX_DEBUG
#endif

/* UD Emplid LDAP attribute: */
static const char*      udEmplidLDAPAttribute = "udEmplid";

#if !APR_HAS_LDAP
#error mod_authnz_shuebox requires APR-util to have LDAP support built in. To fix add --with-ldap to ./configure.
#endif

#ifndef SBAUTHNZ_CACHE_SIZE
/*
  The initial size for our authentication caches.  Default value is 50.
*/
#define SBAUTHNZ_CACHE_SIZE 50
#endif

#ifndef SBAUTHNZ_CACHE_CLEANUP
/*
  The number of cache lookup/update operations that are allowed to happen
  before we purge expired lines from the cache.  Default value is 80.
*/
#define SBAUTHNZ_CACHE_CLEANUP 80
#endif

#ifndef SBAUTHNZ_CACHE_TTL
/*
  The number of microseconds that a cache line remains valid.  Default value
  is 300000000 (5 minutes).
*/
#define SBAUTHNZ_CACHE_TTL 300 * 1000 * 1000
#endif

/*!
  @typedef SBAuthnzCache
  
  Authentication caching makes use of one of these structures.  The mutex is added
  only if APR is threaded -- otherwise, it's not necessary since Apache will be
  running serially.  Cache lines are stored by means of an APR table which starts
  at a particular size and will grow if exceeded (that's how an APR table behaves).
  The 'cleanup' dictates how often a call to cache lookup/update will trigger a
  purge.
  
  The purge interval should be around twice the initial cache size.  Considering that
  the general operation here is to lookup and then update if nothing was found, on
  average we should see far more lookups based on Apache's need to keep
  reauthenticating a user each time a new request is handled.  The cache is NOT
  updated coincident with such lookups when they yield a cache hit, so the
  percentage of lookups leading to a new line's being added to the cache will
  be fairly small.  Worst case scenario, however, we'll have N distinct users hitting
  us in sequence and triggering a lookup+update; if we keep the cleanup interval close
  to the expected number of events that would fill the cache, we should more likely
  purge some old lines before adding all those new ones.
  
  The other route to go would be to put an upper bound on the cache size and once
  we reach that, purge old + oldest lines.  That's more difficult to implmenent,
  though, and for now I think this should suffice.
*/
typedef struct {
#ifdef APR_HAS_THREADS
  apr_thread_mutex_t* lock;
#endif
  int                 cleanup;
  apr_table_t*        lines;
} SBAuthnzCache;

static SBAuthnzCache SBAuthnzCacheDefault;

/*!
  @function SBAuthnzCacheInit
  
  Initialize a cache data structure.  Make sure the pool being passed to this
  function is survivable through the life of the module -- since we're doing the
  cache init with the same pool used to allocate our module data, I think we're
  safe enough.
*/
static apr_status_t
SBAuthnzCacheInit(
  SBAuthnzCache*        aCache,
  apr_pool_t*           pool,
  const char*           directory
)
{
  memset(aCache,0,sizeof(SBAuthnzCache));
#ifdef APR_HAS_THREADS
  if ( apr_thread_mutex_create(&aCache->lock, APR_THREAD_MUTEX_DEFAULT, pool) != OK ) {
    ap_log_perror(
        APLOG_MARK,
        APLOG_INFO,
        0,
        pool,
        "[authnz_shuebox] unable to allocate cache lock at %s",
        directory
      );
    return HTTP_INTERNAL_SERVER_ERROR;
  }
#endif
  if ( (aCache->lines = apr_table_make(pool,SBAUTHNZ_CACHE_SIZE)) == NULL ) {
    ap_log_perror(
        APLOG_MARK,
        APLOG_INFO,
        0,
        pool,
        "[authnz_shuebox] unable to allocate cache table at %s",
        directory
      );
    return HTTP_INTERNAL_SERVER_ERROR;
  }
  aCache->cleanup = SBAUTHNZ_CACHE_CLEANUP;
  return OK;
}

/*!
  @function SBAuthnzCacheReset
  
  Wipe them out....allllll of them.  Cache lines, anyway.
*/
static void
SBAuthnzCacheReset(
  SBAuthnzCache*        aCache
)
{
#ifdef APR_HAS_THREADS
  apr_thread_mutex_lock(aCache->lock);
#endif

  if ( aCache->lines ) {
    apr_table_clear(aCache->lines);
  }
  
#ifdef APR_HAS_THREADS
  apr_thread_mutex_unlock(aCache->lock);
#endif
}

/*!
  @typedef SBAuthnzCacheArgs
  
  For passing some junk to our cache-cleanup iterator function.
*/
typedef struct {
  apr_time_t        now;
  int               maxCount;
  int               keyCount;
  const char*       *keys;
} SBAuthnzCacheArgs;

/*!
  @function __SBAuthnzCacheCleanupIterator
  
  Iterator function for apr_table_do; builds a list of keys that should
  be dropped.  Note that we build the list making use of the keys' char*
  directly and NOT with copies of the keys; since we're mutex'ing cache
  access the cache table is guaranteed not to change during the course of
  the purge, so we can get away with it.
*/
int
__SBAuthnzCacheCleanupIterator(
  void*         args,
  const char*   uname,
  const char*   timestamp
)
{
  SBAuthnzCacheArgs*    ARGS = (SBAuthnzCacheArgs*)args;
  
  if ( timestamp ) {
    apr_time_t  savedTime = apr_atoi64(timestamp);
    
    if ( ( ARGS->now - savedTime ) > SBAUTHNZ_CACHE_TTL ) {
      ARGS->keys[ARGS->keyCount++] = uname;
      
      //  Stop the iteration if we hit the maximum number of lines
      //  we can "memorize" for flushing:
      if ( ARGS->keyCount == ARGS->maxCount )
        return 0;
    }
  }
  return 1;
}

int
__SBAuthnzCacheWalk(
  void*         args,
  const char*   uname,
  const char*   timestamp
)
{
  FILE*         ARGS = (FILE*)args;
  
  fprintf(ARGS, "[Cache(%08X)] { %s => %s }\n", getpid(), uname, timestamp);
  
  return 1;
}

/*!
  @function SBAuthnzCacheLookup
  
  Called by the main authentication function.  Lookup the given uname in
  the cache.  If it is found, then confirm that the TTL hasn't passed on
  that cache line; if it has, purge that line and return 0.  If the TTL
  has not expired, then be sure that the password coming from the remote
  host matches the password attached to the cache line (to be more sure
  it's the same person behind the request that triggered the auth!).
  
  The tmpPool should be a short-lived memory pool that we can use for
  the sake of cache purging.  The request pool is perfect for this!
  
  This routine decrements the internal cleanup counter for the cache and
  performs a purge if the cleanup has reached zero (and then resets the
  counter).
*/
static int
SBAuthnzCacheLookup(
  SBAuthnzCache*        aCache,
  const char*           uname,
  const char*           password,
  apr_pool_t*           tmpPool
)
{
  const char*   value = NULL;
  int           result = 0;
  apr_time_t    now = apr_time_now();

#ifdef AUTHNZ_SHUEBOX_DEBUG
  FILE*         f;
#endif
  
#ifdef APR_HAS_THREADS
  apr_thread_mutex_lock(aCache->lock);
#endif

#ifdef AUTHNZ_SHUEBOX_DEBUG
  f = fopen("/tmp/shuebox.log", "a");
  
  fprintf(f, "[Cache(%08X)] Walk the cache (in lookup):\n", getpid());
  apr_table_do(__SBAuthnzCacheWalk, f, aCache->lines, NULL);
  fprintf(f, "[Cache(%08X)] Done walking the cache (in lookup)\n", getpid());
#endif

  //  Check for the user in the cache:
  if ( value = apr_table_get(aCache->lines,uname) ) {
    apr_time_t  savedTime = apr_atoi64(value);
    char*       savedPass = strchr(value,':');

#ifdef AUTHNZ_SHUEBOX_DEBUG
    fprintf(f,"[Cache(%08X)] Cache time check: %lld > %d ? %s :: ", getpid(), now - savedTime, SBAUTHNZ_CACHE_TTL, value);
#endif
    if ( (now - savedTime) > SBAUTHNZ_CACHE_TTL ) {
      apr_table_unset(aCache->lines,uname);
#ifdef AUTHNZ_SHUEBOX_DEBUG
      fprintf(f,"INVALIDATE LINE [%d]\n", aCache->cleanup);
#endif
    } else if ( strcmp(savedPass + 1,password) == 0 ) {
      result = 1;
#ifdef AUTHNZ_SHUEBOX_DEBUG
      fprintf(f,"VALIDATED [%d]\n", aCache->cleanup);
#endif
    }
  }
#ifdef AUTHNZ_SHUEBOX_DEBUG
  else {
    fprintf(f,"[Cache(%08X)] No cache line for %s\n", getpid(), uname);
  }
#endif
  
  //  Have we hit a cleanup interval?
  if ( --(aCache->cleanup) == 0 ) {
    const char*               *keys = apr_palloc(tmpPool,SBAUTHNZ_CACHE_SIZE * sizeof(char*));
    SBAuthnzCacheArgs         args = { now , SBAUTHNZ_CACHE_SIZE , 0 , keys };
    
    if ( keys ) {
#ifdef AUTHNZ_SHUEBOX_DEBUG
      fprintf(f,"[Cache(%08X)] Cleanup in lookup!\n", getpid());
#endif
      apr_table_do(__SBAuthnzCacheCleanupIterator,&args,aCache->lines,NULL);
      if ( args.keyCount ) {
        const char*           *keyMax = keys + args.keyCount;
        
        while ( keys < keyMax ) {
#ifdef AUTHNZ_SHUEBOX_DEBUG
          fprintf(f,"[Cache(%08X)] REMOVE: %s\n", getpid(), *keys);
#endif
          apr_table_unset(aCache->lines,*keys);
          keys++;
        }
      }
    }
    aCache->cleanup = SBAUTHNZ_CACHE_CLEANUP;
  }
  
#ifdef AUTHNZ_SHUEBOX_DEBUG
  fclose(f);
#endif

#ifdef APR_HAS_THREADS
  apr_thread_mutex_unlock(aCache->lock);
#endif
  return result;
}

/*!
  @function SBAuthnzCacheUpdate
  
  Called by the main authentication function.  Attempt to insert/update
  a cache line associated with uname.  The cache line consists of the
  textual form of the 64-bit timestamp for the current time, a colon, and
  the password that yielded a successful authentication.
  
  The tmpPool should be a short-lived memory pool that we can use for
  the sake of cache purging and line generation.  The request pool is
  perfect for this!
  
  This routine decrements the internal cleanup counter for the cache and
  performs a purge if the cleanup has reached zero (and then resets the
  counter).
*/
static void
SBAuthnzCacheUpdate(
  SBAuthnzCache*        aCache,
  const char*           uname,
  const char*           password,
  size_t                passwordLen,
  apr_pool_t*           tmpPool
)
{
  apr_time_t        now = apr_time_now();
  char*             timestamp = apr_palloc(tmpPool,24 + passwordLen);

#ifdef AUTHNZ_SHUEBOX_DEBUG
  FILE*         f;
#endif
  
#ifdef APR_HAS_THREADS
  apr_thread_mutex_lock(aCache->lock);
#endif

#ifdef AUTHNZ_SHUEBOX_DEBUG
  f = fopen("/tmp/shuebox.log", "a");
  
  fprintf(f, "[Cache(%08X)] Walk the cache (in update):\n", getpid());
  apr_table_do(__SBAuthnzCacheWalk, f, aCache->lines, NULL);
  fprintf(f, "[Cache(%08X)] Done walking the cache (in update)\n", getpid());
#endif

  //  Have we hit a cleanup interval?
  if ( --(aCache->cleanup) == 0 ) {
    const char*               *keys = apr_palloc(tmpPool,SBAUTHNZ_CACHE_SIZE * sizeof(char*));
    SBAuthnzCacheArgs         args = { now , SBAUTHNZ_CACHE_SIZE , 0 , keys };

#ifdef AUTHNZ_SHUEBOX_DEBUG
    fprintf(f,"[Cache(%08X)] Cleanup in update!\n", getpid());
#endif
    if ( keys ) {
      apr_table_do(__SBAuthnzCacheCleanupIterator,&args,aCache->lines,NULL);
      if ( args.keyCount ) {
        const char*           *keyMax = keys + args.keyCount;
        
        while ( keys < keyMax ) {
#ifdef AUTHNZ_SHUEBOX_DEBUG
          fprintf(f,"[Cache(%08X)] REMOVE: %s\n", getpid(), *keys);
#endif
          apr_table_unset(aCache->lines,*keys);
          keys++;
        }
      }
    }
    aCache->cleanup = SBAUTHNZ_CACHE_CLEANUP;
  }
  
  //  Construct a textual timestamp:
  if ( timestamp ) {
    snprintf(timestamp,24 + passwordLen,"%lld:%s",now,password);
    apr_table_set(aCache->lines,uname,timestamp);
    
#ifdef AUTHNZ_SHUEBOX_DEBUG
    fprintf(f,"[Cache(%08X)] Cache update %s => %s\n", getpid(), uname, timestamp);
#endif
  }

#ifdef AUTHNZ_SHUEBOX_DEBUG
  fclose(f);
#endif
  
#ifdef APR_HAS_THREADS
  apr_thread_mutex_unlock(aCache->lock);
#endif
}

/*
 * ===================================================================
 */

module AP_MODULE_DECLARE_DATA authnz_shuebox_module;

/* APR LDAP utility functions we need */
static APR_OPTIONAL_FN_TYPE(uldap_connection_close) *util_ldap_connection_close;
static APR_OPTIONAL_FN_TYPE(uldap_connection_find) *util_ldap_connection_find;
static APR_OPTIONAL_FN_TYPE(uldap_cache_comparedn) *util_ldap_cache_comparedn;
static APR_OPTIONAL_FN_TYPE(uldap_cache_compare) *util_ldap_cache_compare;
static APR_OPTIONAL_FN_TYPE(uldap_cache_checkuserid) *util_ldap_cache_checkuserid;
static APR_OPTIONAL_FN_TYPE(uldap_cache_getuserdn) *util_ldap_cache_getuserdn;
static APR_OPTIONAL_FN_TYPE(uldap_ssl_supported) *util_ldap_ssl_supported;

/* APR DBD utility functions we need */
static APR_OPTIONAL_FN_TYPE(ap_dbd_prepare) *mod_dbd_prepare;
static APR_OPTIONAL_FN_TYPE(ap_dbd_acquire) *mod_dbd_acquire;


/*!
  @struct SBAuthnzConfigRec
  
  This module's configuration records use this data structure.
*/
typedef struct SBAuthnzConfig {

  /* Collaboration ID: */
  char*               collaborationId;

  /* Repository ID: */
  char*               repositoryId;

  /* Database bits: */
  struct {
    char*             guestAuthnQuery;
    char*             authnLogQuery;
    char*             authzCollabUserQuery;
    char*             authzRepoUserQuery;
    char*             authzCollabAdminQuery;
  } dbd;
  
  /* LDAP bits: */
  struct {
    char*             url;
    char*             host;
    int               port;
    char*             baseDN;
    int               secure;
    int               scope;
    char*             filter;
    char*             userMatchAttribute;
    char**            searchAttributes;
  } ldap;
  
  int                 authoritative;

} SBAuthnzConfig;


/*!
  @function SBAuthnzConfigCreate
  
  Create a new module configuration record.
*/
static void*
SBAuthnzConfigCreate(
  apr_pool_t*   pool,
  char*         directory
)
{
  SBAuthnzConfig*     newConfig = apr_pcalloc(pool, sizeof(SBAuthnzConfig));
  
  ap_log_perror(
      APLOG_MARK,
      APLOG_INFO,
      0,
      pool,
      "[authnz_shuebox] create config for %s",
      directory
    );
  
  /* Default is insecure LDAP connections (ouch!) */
  newConfig->ldap.secure = APR_LDAP_NONE;
  
  /* Default is to be authoritative: */
  newConfig->authoritative = 1;
  
  return newConfig;
}


/*!

*/
static void*
SBAuthnzConfigMerge(
  apr_pool_t*     pool,
  void*           parentConf,
  void*           subdirConf
)
{
  SBAuthnzConfig* parent = (SBAuthnzConfig*)parentConf;
  SBAuthnzConfig* subdir = (SBAuthnzConfig*)subdirConf;
  SBAuthnzConfig* merged = (SBAuthnzConfig*)apr_pcalloc(pool, sizeof(SBAuthnzConfig));
  
  // Copy (by-pointer is safe) the collaboration id if it exists on us or our parent:
  merged->collaborationId       = ( subdir->collaborationId ? subdir->collaborationId : parent->collaborationId );
  
  // Copy (by-pointer is safe) the repository id if it exists on us or our parent:
  merged->repositoryId          = ( subdir->repositoryId ? subdir->repositoryId : parent->repositoryId );
  
  // Copy (by-pointer is safe) the database query stuff:
  merged->dbd.guestAuthnQuery       = ( subdir->dbd.guestAuthnQuery ? subdir->dbd.guestAuthnQuery : parent->dbd.guestAuthnQuery );
  merged->dbd.authnLogQuery         = ( subdir->dbd.authnLogQuery ? subdir->dbd.authnLogQuery : parent->dbd.authnLogQuery );
  merged->dbd.authzCollabUserQuery  = ( subdir->dbd.authzCollabUserQuery ? subdir->dbd.authzCollabUserQuery : parent->dbd.authzCollabUserQuery );
  merged->dbd.authzRepoUserQuery    = ( subdir->dbd.authzRepoUserQuery ? subdir->dbd.authzRepoUserQuery : parent->dbd.authzRepoUserQuery );
  merged->dbd.authzCollabAdminQuery = ( subdir->dbd.authzCollabAdminQuery ? subdir->dbd.authzCollabAdminQuery : parent->dbd.authzCollabAdminQuery );
  
  // Copy (by-pointer is safe) the LDAP config:
  merged->ldap.url                = ( subdir->ldap.url ? subdir->ldap.url : parent->ldap.url );
  merged->ldap.host               = ( subdir->ldap.host ? subdir->ldap.host : parent->ldap.host );
  merged->ldap.port               = ( (subdir->ldap.port > 0) ? subdir->ldap.port : parent->ldap.port );
  merged->ldap.baseDN             = ( subdir->ldap.baseDN ? subdir->ldap.baseDN : parent->ldap.baseDN );
  merged->ldap.secure             = ( (subdir->ldap.secure != APR_LDAP_NONE) ? subdir->ldap.secure : parent->ldap.secure );
  merged->ldap.scope              = ( subdir->ldap.scope ? subdir->ldap.scope : parent->ldap.scope );
  merged->ldap.filter             = ( subdir->ldap.filter ? subdir->ldap.filter : parent->ldap.filter );
  merged->ldap.userMatchAttribute = ( subdir->ldap.userMatchAttribute ? subdir->ldap.userMatchAttribute : parent->ldap.userMatchAttribute );
  merged->ldap.searchAttributes   = ( subdir->ldap.searchAttributes ? subdir->ldap.searchAttributes : parent->ldap.searchAttributes );
  
  return merged;
}


/*!
  @function SBAuthnzConfigSetLDAPURL
  
  Configuration-phase translation of an LDAP URL into its components.
  
  Borrowed from mod_authnz_ldap.
*/
static const char*
SBAuthnzConfigSetLDAPURL(
  cmd_parms*    cmd,
  void*         cfg,
  const char*   url,
  const char*   secureMode
)
{
  SBAuthnzConfig*         CFG = (SBAuthnzConfig*)cfg;
  int                     rc;
  unsigned int            attribCount = 0;
  int                     emplidAttribAtIndex = -1;
  apr_ldap_url_desc_t*    ldapURL;
  apr_ldap_err_t*         result;

  rc = apr_ldap_url_parse(cmd->pool, url, &ldapURL, &result);
  if (rc != APR_SUCCESS) {
      return result->reason;
  }
  CFG->ldap.url = apr_pstrdup(cmd->pool, url);
  
  /* Set the host: */
  CFG->ldap.host = ( ldapURL->lud_host ? apr_pstrdup(cmd->pool, ldapURL->lud_host) : "localhost" );
  
  /* Set the base DN: */
  CFG->ldap.baseDN = ( ldapURL->lud_dn ? apr_pstrdup(cmd->pool, ldapURL->lud_dn) : "" );
  
  /* Port and security information: */
  if ( secureMode ) {
    if ( strcasecmp(secureMode, "NONE") == 0 ) {
      CFG->ldap.secure = APR_LDAP_NONE;
    }
    else if ( strcasecmp(secureMode, "SSL") == 0 ) {
      CFG->ldap.secure = APR_LDAP_SSL;
    }
    else if ( strcasecmp(secureMode, "TLS") == 0 ) {
      CFG->ldap.secure = APR_LDAP_STARTTLS;
    }
    else {
      return "[authnz_shuebox] Invalid LDAP connection mode setting: must be one of NONE, "
             "SSL, or TLS";
    }
  }
  if ( strncasecmp(url, "ldaps", 5) == 0 ) {
    CFG->ldap.secure = APR_LDAP_SSL;
    CFG->ldap.port = ( ldapURL->lud_port ? ldapURL->lud_port : LDAPS_PORT );
  } else {
    CFG->ldap.port = ( ldapURL->lud_port ? ldapURL->lud_port : LDAP_PORT );
  }
  
  /* Search scope: */
  CFG->ldap.scope = ( (ldapURL->lud_scope == LDAP_SCOPE_ONELEVEL) ? LDAP_SCOPE_ONELEVEL : LDAP_SCOPE_SUBTREE );
  
  /* Search filter: */
  if ( ldapURL->lud_filter) {
    if (ldapURL->lud_filter[0] == '(') {
      /*
       * Get rid of the surrounding parentheses; later on when generating the per-authn
       * filter, they'll be put back.
       */
      size_t        filterLen = strlen(ldapURL->lud_filter + 1);
      
      if ( filterLen > 0 ) {
        if ( ldapURL->lud_filter[filterLen - 1] == ')' ) {
          filterLen--;
        }
        if ( filterLen > 0 ) {
          CFG->ldap.filter = apr_pcalloc(cmd->pool, filterLen + 1);
          memcpy( CFG->ldap.filter, ldapURL->lud_filter + 1, filterLen );
        }
      }
    } else {
      CFG->ldap.filter = apr_pstrdup(cmd->pool, ldapURL->lud_filter);
    }
  }
  if ( CFG->ldap.filter == NULL ) {
    CFG->ldap.filter = "objectclass=*";
  }
  
  /*
   * Attributes; count how many attributes, make sure udEmplid is among them:
   */
  if ( ldapURL->lud_attrs && ldapURL->lud_attrs[0] ) {
    while ( ldapURL->lud_attrs[++attribCount] ) {
      if ( strcasecmp(ldapURL->lud_attrs[attribCount], udEmplidLDAPAttribute) == 0 )
        emplidAttribAtIndex = attribCount;
    }
  }
  
  /* Allocate an array: */
  CFG->ldap.searchAttributes = apr_pcalloc(cmd->pool, sizeof(char *) * (attribCount + 2 - (emplidAttribAtIndex == -1 ? 0 : 1)));
  
  /* Copy the attribute names: */
  CFG->ldap.searchAttributes[0] = (char*)udEmplidLDAPAttribute;
  if ( attribCount ) {
    char**        attribPtr = CFG->ldap.searchAttributes + 1;
    
    attribCount = 0;
    while ( ldapURL->lud_attrs[attribCount] ) {
      if ( attribCount != emplidAttribAtIndex )
        *attribPtr++ = apr_pstrdup(cmd->pool, ldapURL->lud_attrs[attribCount]);
      attribCount++;
    }
  }
    
  CFG->ldap.userMatchAttribute = "uid";
  
  return NULL;
}



/*!
  @function SBAuthnzPrepareQuery
  
  Generic configuration-phase database query preparer.
*/
static const char* SBAuthnzPrepareQuery(
  cmd_parms*    cmd,
  void*         cfg,
  const char*   query
)
{
  static unsigned int   label_num = 0;
  char*                 label = NULL;
  
  /* Just in case we get hit before the optional fns hook: */
  if ( mod_dbd_prepare == NULL ) {
    mod_dbd_prepare = APR_RETRIEVE_OPTIONAL_FN(ap_dbd_prepare);
    if (mod_dbd_prepare == NULL)
      return "You must load mod_dbd to enable mod_authnz_shuebox";
  }
    
  /* Create a unique label for the query: */
  label = apr_psprintf(cmd->pool, "authnz_shuebox_%u", ++label_num);
  
  /* Prepare the query: */
  mod_dbd_prepare(cmd->server, query, label);

  /* Save the label in our config so we can reference the query
     later */
  return ap_set_string_slot(cmd, cfg, label);
}


/*!
  @function SBAuthnzPostConfig
  
  Do any checking of our state after Apache configuration phase has completed.
*/
static int
SBAuthnzPostConfig(
  apr_pool_t*   p,
  apr_pool_t*   plog,
  apr_pool_t*   ptemp,
  server_rec*   s
)
{
  /* Make sure we got the LDAP functionality */
  if ( ap_find_linked_module("util_ldap.c") == NULL ) {
    ap_log_error(
        APLOG_MARK,
        APLOG_ERR,
        0,
        s,
        "Module mod_ldap missing and must be loaded for mod_authnz_shuebox to function properly"
      );
    return HTTP_INTERNAL_SERVER_ERROR;
  }
  
  /* Make sure we got the DBD functionality */
  if ( ap_find_linked_module("mod_dbd.c") == NULL ) {
    ap_log_error(
        APLOG_MARK,
        APLOG_ERR,
        0,
        s,
        "Module mod_dbd missing and must be loaded for mod_authnz_shuebox to function properly"
      );
    return HTTP_INTERNAL_SERVER_ERROR;
  }
  
  return OK;
}


/*!
  @function __SBAuthnzAuthenticate_DBD
  
  DBD-specific user authentication driver.
*/
static authn_status
__SBAuthnzAuthenticate_DBD(
  request_rec*    request,
  SBAuthnzConfig* shueboxConf,
  const char*     username,
  const char*     password
)
{
  static char           hexDigits[18] = "0123456789abcdef";
  
  ap_dbd_t*             dbdConn = mod_dbd_acquire(request);
  apr_dbd_prepared_t*   queryStatement = NULL;
  apr_dbd_results_t*    queryResult = NULL;
  apr_dbd_row_t*        queryResultRow = NULL;
  int                   rc;
  apr_status_t          rv;
  unsigned char         md5Password[APR_MD5_DIGESTSIZE * 2 + 1];
  int                   hashDigits = APR_MD5_DIGESTSIZE;
  char*                 md5PasswordTop = ((char*)&md5Password[0]) + APR_MD5_DIGESTSIZE * 2;
  
  if ( dbdConn == NULL ) {
    ap_log_rerror(
        APLOG_MARK,
        APLOG_ERR,
        0,
        request,
        "[authn_shuebox] Failed to acquire database connection to look up user '%s'",
        username
      );
    return AUTH_GENERAL_ERROR;
  }
  
  /* Do we have a query defined? */
  if ( shueboxConf->dbd.guestAuthnQuery == NULL ) {
    ap_log_rerror(
        APLOG_MARK,
        APLOG_ERR,
        0,
        request,
        "[authn_shuebox] No AuthSHUEBoxGuestAuthnQuery specified in configuration"
      );
    return AUTH_GENERAL_ERROR;
  }
  
  /* Find the prepared query label: */
  queryStatement = apr_hash_get(dbdConn->prepared, shueboxConf->dbd.guestAuthnQuery, APR_HASH_KEY_STRING);
  if ( queryStatement == NULL ) {
    ap_log_rerror(
        APLOG_MARK,
        APLOG_ERR,
        0,
        request,
        "[authn_shuebox] A prepared statement could not be found for AuthSHUEBoxGuestAuthnQuery with the key '%s'",
        shueboxConf->dbd.guestAuthnQuery
      );
    return AUTH_GENERAL_ERROR;
  }
  
  /* MD5 hash the password; the lower half of md5Password contains the byte-wise hash returned
     by apr_md5, and we fill-in the textual rep from the top of the buffer down, in-place: */
  apr_md5(
      md5Password,
      (const unsigned char *)password,
      strlen(password)
    );
  *md5PasswordTop = '\0';
  while ( hashDigits-- ) {
    md5PasswordTop--; *md5PasswordTop = hexDigits[ md5Password[hashDigits] % 16 ];
    md5PasswordTop--; *md5PasswordTop = hexDigits[ md5Password[hashDigits] / 16 ];
  }
  
#ifdef AUTHNZ_SHUEBOX_DEBUG
  ap_log_rerror(
      APLOG_MARK,
      APLOG_ERR,
      0,
      request,
      "[authn_shuebox] Trying to authenticate '%s:%s'",
      username,
      md5Password
    );
#endif
  
  /* Perform the query: */
  rc = apr_dbd_pvselect(
          dbdConn->driver,
          request->pool,
          dbdConn->handle,
          &queryResult,
          queryStatement,
          0,
          username,
          md5Password,
          NULL
        );
  if ( rc ) {
    ap_log_rerror(
        APLOG_MARK,
        APLOG_ERR,
        0,
        request,
        "[authn_shuebox] Failure to authenticate '%s:%s' due to query exec error: %d",
        username,
        md5Password,
        rc
      );
    return AUTH_GENERAL_ERROR;
  }
  
  /* Should produce a non-zero value for row 0, column 0 if authenication
     was successful: */
  rc = -1;
  while ( (rv = apr_dbd_get_row(dbdConn->driver, request->pool, queryResult, &queryResultRow, -1)) != -1 ) {
    if (rv != 0) {
      ap_log_rerror(
          APLOG_MARK,
          APLOG_ERR,
          0,
          request,
          "[authn_shuebox] Failure to authenticate '%s:%s' due to query result error: %d",
          username,
          md5Password,
          rv
        );
      return AUTH_GENERAL_ERROR;
    } else if ( rc == -1 ) {
      const char*       authResult = apr_dbd_get_entry(dbdConn->driver, queryResultRow, 0);

#ifdef AUTHNZ_SHUEBOX_DEBUG
      ap_log_rerror(
          APLOG_MARK,
          APLOG_ERR,
          0,
          request,
          "[authn_shuebox] Authentication of '%s:%s' = %s",
          username,
          md5Password,
          ( authResult ? authResult : "<n/a>" )
        );
#endif

      if ( authResult ) {
        long            authResultVal = strtol(authResult, NULL, 10);
        
        if ( errno != EINVAL ) {
          rc = ( authResultVal != 0 );
        }
      }
    }
  }
  switch ( rc ) {
    case -1:
      return AUTH_USER_NOT_FOUND;
    case 0:
      return AUTH_DENIED;
    case 1:
      return AUTH_GRANTED;
  }
}


/*!
  @function SBAuthnzLogLDAPAuthn
  
  Logging of successful authentication is implicit for guest users, since it goes through
  the database already.  But for domestic users being authn'ed through LDAP, we need to
  follow-up with a logging query to the database.
*/
static int
SBAuthnzLogLDAPAuthn(
  request_rec*    request,
  SBAuthnzConfig* shueboxConf,
  const char*     username,
  const char*     emplid
)
{
  ap_dbd_t*             dbdConn = mod_dbd_acquire(request);
  apr_dbd_prepared_t*   queryStatement = NULL;
  apr_dbd_results_t*    queryResult = NULL;
  apr_dbd_row_t*        queryResultRow = NULL;
  int                   rc;
  
  if ( dbdConn == NULL ) {
    ap_log_rerror(
        APLOG_MARK,
        APLOG_ERR,
        0,
        request,
        "[authn_shuebox] Failed to acquire database connection to log user '%s' authentication",
        username
      );
    return 1;
  }
  
  /* Do we have a query defined? */
  if ( shueboxConf->dbd.authnLogQuery == NULL ) {
    ap_log_rerror(
        APLOG_MARK,
        APLOG_ERR,
        0,
        request,
        "[authn_shuebox] No AuthSHUEBoxAuthnLogQuery specified in configuration"
      );
    return 1;
  }
  
  /* Find the prepared query label: */
  queryStatement = apr_hash_get(dbdConn->prepared, shueboxConf->dbd.authnLogQuery, APR_HASH_KEY_STRING);
  if ( queryStatement == NULL ) {
    ap_log_rerror(
        APLOG_MARK,
        APLOG_ERR,
        0,
        request,
        "[authn_shuebox] A prepared statement could not be found for AuthSHUEBoxAuthnLogQuery with the key '%s'",
        shueboxConf->dbd.authnLogQuery
      );
    return 1;
  }
  
  /* Perform the query: */
  rc = apr_dbd_pvselect(
          dbdConn->driver,
          request->pool,
          dbdConn->handle,
          &queryResult,
          queryStatement,
          0,
          username,
          emplid,
          NULL
        );
  if ( rc ) {
    ap_log_rerror(
        APLOG_MARK,
        APLOG_ERR,
        0,
        request,
        "[authn_shuebox] Failure to log successful authentication of '%s' due to query exec error: %d",
        username,
        rc
      );
    return 1;
  }
  
  /* Discard any results we got back: */
  while ( apr_dbd_get_row(dbdConn->driver, request->pool, queryResult, &queryResultRow, -1) != -1 );
  
  return 0;
}


/*!
  @function __SBAuthnzAuthenticate_LDAP
  
  LDAP-specific user authentication driver.
*/
static authn_status
__SBAuthnzAuthenticate_LDAP(
  request_rec*    request,
  SBAuthnzConfig* shueboxConf,
  const char*     username,
  const char*     password
)
{
  util_ldap_connection_t*     ldapConn = NULL;
  const char*                 filter = shueboxConf->ldap.filter;
  const char*                 userAttrib = shueboxConf->ldap.userMatchAttribute;
  char*                       usernamePtr = (char*)username;
  int                         failureCount = 0;
  int                         result;
  
  /* Do we have a URL? */
  if ( ! shueboxConf->ldap.url ) {
    ap_log_rerror(
        APLOG_MARK,
        APLOG_WARNING,
        0,
        request,
        "[%" APR_PID_T_FMT "] authnz_shuebox: no LDAP URL specified in config",
        getpid()
      );
    return AUTH_GENERAL_ERROR;
  }
  
  /* Find the LDAP connection: */
  ldapConn = util_ldap_connection_find(
                request,
                shueboxConf->ldap.host,
                shueboxConf->ldap.port,
                NULL,    /* search-based bind DN */
                NULL,    /* search-based bind password */
                always,  /* alias dereference behavior */
                shueboxConf->ldap.secure
              );
  if ( ldapConn ) {
    size_t          userFilterLen;
    size_t          partUserFilterLen = 6; /* (&()(=  */
    char*           userFilter;
    
    if ( filter )
      partUserFilterLen += strlen(filter);
    partUserFilterLen += strlen(userAttrib);
    
    /* Assume the worst for the username in terms of escaping: */
    userFilterLen += 3 + 2 * strlen(username); /* + 1 + )) + .. */
    
    if ( (userFilter = apr_pcalloc(request->pool, userFilterLen)) ) {
      char*           p = userFilter + partUserFilterLen;
      const char**    attribValues = NULL;
      const char*     userDN = NULL;
      
      apr_snprintf(userFilter, userFilterLen, "(&(%s)(%s=", filter, userAttrib);
      while ( *usernamePtr ) {
        char      c = *usernamePtr;
        
        switch ( c ) {
          case '*':
          case '(':
          case ')':
          case '\\':
            *p++ = '\\';
          default:
            *p++ = c;
        }
        usernamePtr++;
      }
      *p++ = ')';
      *p++ = ')';
      *p++ = '\0';

#ifdef AUTHNZ_SHUEBOX_DEBUG
      ap_log_rerror(
          APLOG_MARK,
          APLOG_WARNING,
          0,
          request,
          "[%" APR_PID_T_FMT "] authnz_shuebox: search filter : `%s`",
          getpid(),
          userFilter
        );
#endif

      /* Try a couple times: */
      while ( failureCount <= 5 ) {

        /* do the user search */
        result = util_ldap_cache_checkuserid(
                    request,
                    ldapConn,
                    shueboxConf->ldap.url,
                    shueboxConf->ldap.baseDN,
                    LDAP_SCOPE_SUBTREE,
                    shueboxConf->ldap.searchAttributes,
                    userFilter,
                    password,
                    &userDN,
                    &attribValues
                  );
        util_ldap_connection_close(ldapConn);
        
        if ( ! AP_LDAP_IS_SERVER_DOWN(result) ) {
          break;
        }
        failureCount++;
      }
      
      if ( failureCount <= 5 ) {
        /* Success? */
        if ( result != LDAP_SUCCESS ) {
          ap_log_rerror(
              APLOG_MARK,
              APLOG_WARNING,
              0,
              request,
              "[%" APR_PID_T_FMT "] authnz_shuebox: user %s authentication failed; URI %s [%s][%s]",
              getpid(),
              username,
              request->uri,
              ldapConn->reason,
              ldap_err2string(result)
            );

          return (LDAP_NO_SUCH_OBJECT == result) ? AUTH_USER_NOT_FOUND
#ifdef LDAP_SECURITY_ERROR
                  : (LDAP_SECURITY_ERROR(result)) ? AUTH_DENIED
#else
                  : (LDAP_INAPPROPRIATE_AUTH == result) ? AUTH_DENIED
                  : (LDAP_INVALID_CREDENTIALS == result) ? AUTH_DENIED
#ifdef LDAP_INSUFFICIENT_ACCESS
                  : (LDAP_INSUFFICIENT_ACCESS == result) ? AUTH_DENIED
#endif
#ifdef LDAP_INSUFFICIENT_RIGHTS
                  : (LDAP_INSUFFICIENT_RIGHTS == result) ? AUTH_DENIED
#endif
#endif
                  : AUTH_GENERAL_ERROR;
        }
        /* YES!  User was authenticated successfully: */
        if ( shueboxConf->dbd.authnLogQuery && attribValues ) {
          /* Get the emplid: */
          if ( attribValues[0] )
            SBAuthnzLogLDAPAuthn(request, shueboxConf, username, attribValues[0]);
        }
        return AUTH_GRANTED;
      } else {
        /* Failure: */
        ap_log_rerror(
            APLOG_MARK,
            APLOG_WARNING,
            0,
            request,
            "[%" APR_PID_T_FMT "] authnz_shuebox: user %s authentication failed; URI %s [%s][%s]",
            getpid(),
            username,
            request->uri,
            ldapConn->reason,
            ldap_err2string(result)
          );
      }
      
    } else {
      ap_log_rerror(
          APLOG_MARK,
          APLOG_WARNING,
          0,
          request,
          "[%" APR_PID_T_FMT "] authnz_shuebox: unable to create user filter",
          getpid()
        );
    }
  } else {
    ap_log_rerror(
        APLOG_MARK,
        APLOG_WARNING,
        0,
        request,
        "[%" APR_PID_T_FMT "] authnz_shuebox: unable to get LDAP connection",
        getpid()
      );
  }
  return AUTH_GENERAL_ERROR;
}


typedef enum {
  kSBAuthzSubTypeCollaborationUser,
  kSBAuthzSubTypeRepositoryUser,
  kSBAuthzSubTypeCollaborationAdmin
} SBAuthzSubType;


/*!
  @function __SBAuthnzAuthorize_DBD
  
  DBD-specific user authorization driver.
*/
static int
__SBAuthnzAuthorize_DBD(
  request_rec*    request,
  SBAuthnzConfig* shueboxConf,
  const char*     username,
  SBAuthzSubType  subType
)
{
  ap_dbd_t*             dbdConn = mod_dbd_acquire(request);
  char*                 queryLabel = NULL;
  apr_dbd_prepared_t*   queryStatement = NULL;
  apr_dbd_results_t*    queryResult = NULL;
  apr_dbd_row_t*        queryResultRow = NULL;
  int                   rc;
  apr_status_t          rv;
  
  if ( dbdConn == NULL ) {
    ap_log_rerror(
        APLOG_MARK,
        APLOG_ERR,
        0,
        request,
        "[authn_shuebox] Failed to acquire database connection to authorize user '%s'",
        username
      );
    return HTTP_UNAUTHORIZED;
  }
  
  switch ( subType ) {
    case kSBAuthzSubTypeCollaborationUser:
      queryLabel = shueboxConf->dbd.authzCollabUserQuery;
      break;
    case kSBAuthzSubTypeRepositoryUser:
      queryLabel = shueboxConf->dbd.authzRepoUserQuery;
      break;
    case kSBAuthzSubTypeCollaborationAdmin:
      queryLabel = shueboxConf->dbd.authzCollabAdminQuery;
      break;
  }
  
  /* Do we have a query defined? */
  if ( queryLabel == NULL ) {
    ap_log_rerror(
        APLOG_MARK,
        APLOG_ERR,
        0,
        request,
        "[authn_shuebox] No query (subtype = %d) specified in configuration",
        subType
      );
    return HTTP_UNAUTHORIZED;
  }
  
  /* Find the prepared query label: */
  queryStatement = apr_hash_get(dbdConn->prepared, queryLabel, APR_HASH_KEY_STRING);
  if ( queryStatement == NULL ) {
    ap_log_rerror(
        APLOG_MARK,
        APLOG_ERR,
        0,
        request,
        "[authn_shuebox] A prepared statement could not be found for query (subtype = %d) with the key '%s'",
        subType,
        queryLabel
      );
    return HTTP_UNAUTHORIZED;
  }
  
  /* Perform the query: */
  switch ( subType ) {
  
    case kSBAuthzSubTypeCollaborationUser:
    case kSBAuthzSubTypeCollaborationAdmin:
      rc = apr_dbd_pvselect(
              dbdConn->driver,
              request->pool,
              dbdConn->handle,
              &queryResult,
              queryStatement,
              0,
              shueboxConf->collaborationId,
              username,
              NULL
            );
      break;
    
    case kSBAuthzSubTypeRepositoryUser:
      rc = apr_dbd_pvselect(
              dbdConn->driver,
              request->pool,
              dbdConn->handle,
              &queryResult,
              queryStatement,
              0,
              shueboxConf->collaborationId,
              shueboxConf->repositoryId,
              username,
              NULL
            );
      break;
  
  }
  if ( rc ) {
    ap_log_rerror(
        APLOG_MARK,
        APLOG_ERR,
        0,
        request,
        "[authn_shuebox] Failure to authorize '%s:%s:%s' due to query exec error: %d",
        shueboxConf->collaborationId,
        shueboxConf->repositoryId,
        username,
        rc
      );
    return HTTP_UNAUTHORIZED;
  }
  
  /* Should produce a non-zero value for row 0, column 0 if authenication
     was successful: */
  rc = -1;
  while ( (rv = apr_dbd_get_row(dbdConn->driver, request->pool, queryResult, &queryResultRow, -1)) != -1 ) {
    if (rv != 0) {
      ap_log_rerror(
          APLOG_MARK,
          APLOG_ERR,
          0,
          request,
          "[authn_shuebox] Failure to authorize '%s:%s:%s' due to query result error: %d",
          shueboxConf->collaborationId,
          shueboxConf->repositoryId,
          username,
          rv
        );
      return HTTP_UNAUTHORIZED;
    } else if ( rc == -1 ) {
      const char*       authResult = apr_dbd_get_entry(dbdConn->driver, queryResultRow, 0);

#ifdef AUTHNZ_SHUEBOX_DEBUG
      ap_log_rerror(
          APLOG_MARK,
          APLOG_ERR,
          0,
          request,
          "[authn_shuebox] Authorization (subtype = %d) of '%s:%s:%s' = %s",
          subType,
          shueboxConf->collaborationId,
          shueboxConf->repositoryId,
          username,
          ( authResult ? authResult : "<n/a>" )
        );
#endif

      if ( authResult ) {
        long            authResultVal = strtol(authResult, NULL, 10);
        
        if ( errno != EINVAL ) {
          rc = ( authResultVal != 0 );
        }
      }
    }
  }
  switch ( rc ) {
    case -1:
      return HTTP_UNAUTHORIZED;
    case 0:
      return HTTP_UNAUTHORIZED;
    case 1:
      return OK;
  }
}


/*!
*/
static authn_status
SBAuthnzAuthenticate(
  request_rec*    request,
  const char*     username,
  const char*     password
)
{
  int                 rc = AUTH_DENIED;
  SBAuthnzConfig*     shueboxConf = (SBAuthnzConfig*)ap_get_module_config(request->per_dir_config,&authnz_shuebox_module);

  if ( shueboxConf == NULL ) {
    return DECLINED;
  }
  
  if ( username && ((rc = ap_get_basic_auth_pw(request,(const char**)&password)) == OK) && password ) {
    size_t        passwordLen = strlen(password);

#ifdef AUTHNZ_SHUEBOX_DEBUG
    ap_log_rerror(
        APLOG_MARK,
        APLOG_INFO,
        0,
        request,
        "[authnz_shuebox] going to authenticate user '%s' with password '%s' for uri '%s'",
        username,
        password,
        request->unparsed_uri
      );
#endif

    //  First and foremost, check our cache:
    if ( SBAuthnzCacheLookup(&SBAuthnzCacheDefault, username, password, request->pool) == 0 ) {
    
      //  Here's where we split the task based on the inclusion of an "@" in the username:
      if ( ap_strchr(username, '@') ) {
        rc = __SBAuthnzAuthenticate_DBD(request, shueboxConf, username, password);
      } else {
        rc = __SBAuthnzAuthenticate_LDAP(request, shueboxConf, username, password);
      }
        
      //  Cache this user:
      if ( rc == AUTH_GRANTED ) {
        SBAuthnzCacheUpdate(&SBAuthnzCacheDefault, username, password, passwordLen, request->pool);
      } else {
        ap_note_basic_auth_failure(request);
      }

#ifdef AUTHNZ_SHUEBOX_DEBUG
      ap_log_rerror(
          APLOG_MARK,
          APLOG_INFO,
          0,
          request,
          "[authnz_shuebox] - CACHE MISS for user '%s'",
          username
        );
#endif

    } else {
      rc = AUTH_GRANTED;
      
#ifdef AUTHNZ_SHUEBOX_DEBUG
      ap_log_rerror(
          APLOG_MARK,
          APLOG_INFO,
          0,
          request,
          "[authnz_shuebox] - CACHE HIT for user '%s'",
          username
        );
#endif

    }
  }

#ifdef AUTHNZ_SHUEBOX_DEBUG
  ap_log_rerror(APLOG_MARK, APLOG_INFO, 0, request,
          "[authnz_shuebox] access = %d for \"%s\"",
          rc, username);
#endif

  return rc;
}


/*!
*/
static int
SBAuthnzAuthorize(
  request_rec*    request
)
{
  SBAuthnzConfig*     shueboxConf = (SBAuthnzConfig*)ap_get_module_config(request->per_dir_config,&authnz_shuebox_module);
  const char*         username = request->user;
  int                 method = request->method_number;
  int                 rc;

  /* Do we have a collaboration id? */
  if ( shueboxConf->collaborationId == NULL ) {
    ap_log_rerror(
        APLOG_MARK,
        APLOG_ERR,
        0,
        request,
        "[%" APR_PID_T_FMT "] authnz_shuebox: no collaboration ID for directory %s",
        getpid(),
        request->uri
      );
    rc = HTTP_UNAUTHORIZED;
  } else {
    const apr_array_header_t*   reqs_arr = ap_requires(request);
    require_line*               reqs;
    int                         i = 0;
    
    /* Nothing actually required? */
    if ( ! reqs_arr )
      return DECLINED;
      
    /* Run through the requires: */
    reqs = (require_line *)reqs_arr->elts;
    while ( i < reqs_arr->nelts ) {
      /* Is the request method actually restricted? */
      if ( (reqs[i].method_mask & (AP_METHOD_BIT << method)) ) {
        const char*             line = reqs[i].requirement;
        
        if ( line ) {
          const char*           word = ap_getword_white(request->pool, &line);
          
          /* Our authorization methods: */
          
          /* User is a member of collaboration: */
          if ( ! strcasecmp(word, "shuebox-collab-user") ) {
            rc = __SBAuthnzAuthorize_DBD(request, shueboxConf, username, kSBAuthzSubTypeCollaborationUser);
            if ( rc == OK )
              return OK;
          }
          /* User is a member of collaboration repository: */
          else if ( ! strcasecmp(word, "shuebox-repo-user") ) {
            rc = __SBAuthnzAuthorize_DBD(request, shueboxConf, username, kSBAuthzSubTypeRepositoryUser);
            if ( rc == OK )
              return OK;
          }
          /* User is a member of the collaboration's administrative role: */
          else if ( ! strcasecmp(word, "shuebox-collab-admin") ) {
            rc = __SBAuthnzAuthorize_DBD(request, shueboxConf, username, kSBAuthzSubTypeCollaborationAdmin);
            if ( rc == OK )
              return OK;
          }
          /* Getting here implies authentication worked, so valid-user is satisfied: */
          else if ( ! strcasecmp(word, "valid-user") ) {
            return OK;
          }
        }
      }
      i++;
    }
  }
  
  /* We don't make the final decision: */
  if ( ! shueboxConf->authoritative )
    return DECLINED;
  
  /* Denied! */
  ap_log_rerror(APLOG_MARK, APLOG_ERR, 0, request,
                "access to %s failed, reason: user '%s' does not meet "
                "'require'ments for user to be allowed access",
                request->uri, username);
  ap_note_basic_auth_failure(request);
  return HTTP_UNAUTHORIZED;
}


/*!
  @struct SBAuthnzProviderRec
  
  Authentication provider callbacks.
*/
static const authn_provider SBAuthnzProviderRec = {
  &SBAuthnzAuthenticate,
};



/*!
  @function SBAuthnzImportOptionalFns
  
  Borrowed from mod_authnz_ldap; retrieve pointers to functions provided by
  other modules.
*/
static void
SBAuthnzImportOptionalFns(
  void
)
{
  util_ldap_connection_close  = APR_RETRIEVE_OPTIONAL_FN(uldap_connection_close);
  util_ldap_connection_find   = APR_RETRIEVE_OPTIONAL_FN(uldap_connection_find);
  util_ldap_cache_comparedn   = APR_RETRIEVE_OPTIONAL_FN(uldap_cache_comparedn);
  util_ldap_cache_compare     = APR_RETRIEVE_OPTIONAL_FN(uldap_cache_compare);
  util_ldap_cache_checkuserid = APR_RETRIEVE_OPTIONAL_FN(uldap_cache_checkuserid);
  util_ldap_cache_getuserdn   = APR_RETRIEVE_OPTIONAL_FN(uldap_cache_getuserdn);
  util_ldap_ssl_supported     = APR_RETRIEVE_OPTIONAL_FN(uldap_ssl_supported);
  
  mod_dbd_prepare             = APR_RETRIEVE_OPTIONAL_FN(ap_dbd_prepare);
  mod_dbd_acquire             = APR_RETRIEVE_OPTIONAL_FN(ap_dbd_acquire);
}



/*!
  @function SBAuthnzRegisterHooks
  
  At module load, create our hooks into the authentication stack and the
  authorization chain.  Also setup hook to retrieve external module functions
  that we use and do post-configuration checks.
*/
static void
SBAuthnzRegisterHooks(
  apr_pool_t*   p
)
{
  /* Modules we want to check authorization prior to us -- mod_authz_user catches the valid-user
   * directive:
   */
  static const char* const  authzAfter[] = { "mod_authz_user.c", NULL };
  
  apr_status_t              status;
  
  /* Register as an authentication provider: */
  status = ap_register_provider(
      p,
      AUTHN_PROVIDER_GROUP,
      "shuebox",
      "0",
      &SBAuthnzProviderRec
    );
  if ( status != 0 ) {
    ap_log_perror(
        APLOG_MARK,
        APLOG_ERR,
        0,
        p,
        "mod_authnz_shuebox: failed to register auth provider [rc = %d]",
        status
      );
  }
  
  SBAuthnzCacheInit(&SBAuthnzCacheDefault, p, NULL);
  
  /* Post-configuration processing: */
  ap_hook_post_config(
      SBAuthnzPostConfig,
      NULL,
      NULL,
      APR_HOOK_MIDDLE
    );
  
  /* Hook into the authorization chain */
  ap_hook_auth_checker(
      SBAuthnzAuthorize,
      NULL,
      authzAfter,
      APR_HOOK_MIDDLE
    );
  
  /* Retrieve any library functions we need: */
  ap_hook_optional_fn_retrieve(
      SBAuthnzImportOptionalFns,
      NULL,
      NULL,
      APR_HOOK_MIDDLE
    );
}


/*!
  @struct SBAuthnzConfigCmdTbl
  
  Array of configuration commands recognized by the module.
*/
static const command_rec SBAuthnzConfigCmdTbl[] = {
  
  AP_INIT_TAKE1(
      "AuthSHUEBoxCollaborationId",
      ap_set_string_slot,
      (void *)APR_OFFSETOF(SBAuthnzConfig, collaborationId),
      ACCESS_CONF,
      "Internal identification of the collaboration associated with a directory"
    ),
  
  AP_INIT_TAKE1(
      "AuthSHUEBoxRepositoryId",
      ap_set_string_slot,
      (void *)APR_OFFSETOF(SBAuthnzConfig, repositoryId),
      ACCESS_CONF,
      "Internal identification of the repository associated with a directory"
    ),
  
  AP_INIT_TAKE1(
      "AuthSHUEBoxGuestAuthnQuery",
      SBAuthnzPrepareQuery,
      (void *)APR_OFFSETOF(SBAuthnzConfig, dbd.guestAuthnQuery),
      ACCESS_CONF,
      "Query used to authenticate a guest user"
    ),
  
  AP_INIT_TAKE1(
      "AuthSHUEBoxAuthzCollabUserQuery",
      SBAuthnzPrepareQuery,
      (void *)APR_OFFSETOF(SBAuthnzConfig, dbd.authzCollabUserQuery),
      ACCESS_CONF,
      "Query used to authorize a user for collaboration access"
    ),
  
  AP_INIT_TAKE1(
      "AuthSHUEBoxAuthzRepoUserQuery",
      SBAuthnzPrepareQuery,
      (void *)APR_OFFSETOF(SBAuthnzConfig, dbd.authzRepoUserQuery),
      ACCESS_CONF,
      "Query used to authorize a user for collaboration repository access"
    ),
  
  AP_INIT_TAKE1(
      "AuthSHUEBoxAuthzCollabAdminQuery",
      SBAuthnzPrepareQuery,
      (void *)APR_OFFSETOF(SBAuthnzConfig, dbd.authzCollabAdminQuery),
      ACCESS_CONF,
      "Query used to authorize a user for collaboration administrative access"
    ),
  
  AP_INIT_TAKE1(
      "AuthSHUEBoxAuthnLogQuery",
      SBAuthnzPrepareQuery,
      (void *)APR_OFFSETOF(SBAuthnzConfig, dbd.authnLogQuery),
      ACCESS_CONF,
      "Query used to log a users' successful authentication"
    ),
  
  AP_INIT_TAKE12(
      "AuthSHUEBoxLDAPURL",
      SBAuthnzConfigSetLDAPURL,
      (void *)APR_OFFSETOF(SBAuthnzConfig, ldap.host),
      ACCESS_CONF,
      "URL to define LDAP connection. This should be an RFC 2255 complaint\n"
      "URL of the form ldap[s]://host[:port]/basedn[?attrib[?scope[?filter]]].\n"
      "<ul>\n"
      "<li>Host is the name of the LDAP server. Use a space separated list of hosts \n"
      "to specify redundant servers.\n"
      "<li>Port is optional, and specifies the port to connect to.\n"
      "<li>basedn specifies the base DN to start searches from\n"
      "<li>Attrib specifies what attribute to search for in the directory. If not "
      "provided, it defaults to <b>uid</b>.\n"
      "<li>Scope is the scope of the search, and can be either <b>sub</b> or "
      "<b>one</b>. If not provided, the default is <b>sub</b>.\n"
      "<li>Filter is a filter to use in the search. If not provided, "
      "defaults to <b>(objectClass=*)</b>.\n"
      "</ul>\n"
      "Searches are performed using the attribute and the filter combined. "
      "For example, assume that the\n"
      "LDAP URL is <b>ldap://ldap.airius.com/ou=People, o=Airius?uid?sub?(posixid=*)</b>. "
      "Searches will\n"
      "be done using the filter <b>(&((posixid=*))(uid=<i>username</i>))</b>, "
      "where <i>username</i>\n"
      "is the user name passed by the HTTP client. The search will be a subtree "
      "search on the branch <b>ou=People, o=Airius</b>."
    ),
  
  AP_INIT_FLAG("AuthSHUEBoxAuthoritative", ap_set_flag_slot,
               (void *)APR_OFFSETOF(SBAuthnzConfig, authoritative),
               OR_AUTHCFG,
               "Set to 'Off' to allow access control to be passed along to "
               "lower modules if the SHUEBox directives are not met. "
               "(default: On)"),
  
  { NULL } /* Sentinel (look out, Wolverine!) */

};


/*!
  @struct authnz_shuebox_module
  
  The singular data structure that describes this module and its basic entry
  points.
*/
module AP_MODULE_DECLARE_DATA authnz_shuebox_module =
{
  STANDARD20_MODULE_STUFF,
  SBAuthnzConfigCreate,            /* dir config creater */
  SBAuthnzConfigMerge,             /* dir merger --- default is to override */
  NULL,                            /* server config */
  NULL,                            /* merge server config */
  SBAuthnzConfigCmdTbl,            /* command apr_table_t */
  SBAuthnzRegisterHooks            /* register hooks */
};
