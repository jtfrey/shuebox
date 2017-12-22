/*
 * mod_dav_zfsquota
 *
 * DAV quota property provider for use with DAV shares rooted on
 * a ZFS filesystem.
 *
 * $Id$
 *
 */

#include "httpd.h"
#include "util_xml.h"
#include "apr_strings.h"
#include "http_config.h"
#include "http_log.h"
#include "mod_dav.h"

static const char*    mod_dav_zfsquota_versionstr = "DAVZFSQuota/0.1";
static char*          mod_dav_zfsquota_baseDevicePath = NULL;

/*
 * Quota-handling support functions:
 */
#include <libzfs.h>
#include <sys/fs/zfs.h>


static libzfs_handle_t*
dav_zfsquota_libHandle(void)
{
  static libzfs_handle_t* defaultZFSLibHandle = NULL;
  
  if ( defaultZFSLibHandle == NULL ) {
    defaultZFSLibHandle = libzfs_init();
  }
  return defaultZFSLibHandle;
}

/**/

static int
dav_zfsquota_getProps(
  const char* uri,
  uint64_t*   capacity,
  uint64_t*   used,
  uint64_t*   avail,
  apr_pool_t* pool
)
{
  libzfs_handle_t*    libHandle = dav_zfsquota_libHandle();
  static char*        path = NULL;
  static size_t       pathLen = 0;
  static size_t       basePathLen = 0;
  
  size_t              uriPortionLen = 0;
  int                 slashCount = 0;
  char*               newPath = (char*)uri;
  
  if ( path == NULL ) {
    basePathLen = strlen(mod_dav_zfsquota_baseDevicePath);
  }
  
  while ( (slashCount < 2) && *newPath ) {
    if ( *newPath == '/' ) {
      if ( ++slashCount < 2 )
        uriPortionLen++;
    } else {
      uriPortionLen++;
    }
    newPath++;
  }
  
  if ( uriPortionLen ) {
    size_t              newSize = basePathLen + uriPortionLen + 1;
    
    newPath = NULL;
    if ( pathLen < newSize ) {
      if ( path ) {
        if ( (path = newPath = malloc(newSize)) ) {
          pathLen = newSize;
        }
      } else {
        if ( (newPath = realloc(path, newSize)) ) {
          path = newPath;
          pathLen = newSize;
        }
      }
    } else {
      newPath = path;
    }
    if ( newPath ) {
      memcpy(path, mod_dav_zfsquota_baseDevicePath, basePathLen);
      memcpy(path + basePathLen, uri, uriPortionLen);
      path[basePathLen + uriPortionLen] = '\0';
      if ( libHandle ) {
        zfs_handle_t*     fsHandle = zfs_open(libHandle, path, ZFS_TYPE_ANY);
        
        if ( fsHandle ) {
          if ( used ) {
            *used = zfs_prop_get_int(
                        fsHandle,
                        ZFS_PROP_USED
                      );
          }
          if ( capacity ) {
            *capacity = zfs_prop_get_int(
                          fsHandle,
                          ZFS_PROP_QUOTA
                        );
          }
          if ( avail ) {
            *avail = zfs_prop_get_int(
                        fsHandle,
                        ZFS_PROP_AVAILABLE
                      );
          }
          zfs_close(fsHandle);
          return 0;
        }
      }
    }
  }
  return 1;
}

/**/

enum {
  DAV_PROPID_quota = 26000,
  DAV_PROPID_quotaused,
  DAV_PROPID_quotabytesavail,
  DAV_PROPID_quotabytesused,
  DAV_PROPID_quotabytes
};

/**/

/* forward-declare */
static const dav_hooks_liveprop dav_zfsquota_hooks_liveprop;

/*
** The namespace URIs that we use. There will only ever be "DAV:".
*/
static const char * const dav_zfsquota_namespace_uris[] =
{
    "DAV:",
    NULL        /* sentinel */
};

/*
** Define each of the properties that this provider will handle.
** Note that all of them are in the DAV: namespace, which has a
** provider-local index of 0.
*/
static const dav_liveprop_spec dav_zfsquota_props[] =
{
    /* Specific to Apple's mount_dav */
    { 0, "quota",                DAV_PROPID_quota,                0 },
    { 0, "quotaused",            DAV_PROPID_quotaused,            0 },
    
    /* RFC 4331 */
    { 0, "quota-available-bytes",DAV_PROPID_quotabytesavail,      0 },
    { 0, "quota-used-bytes",     DAV_PROPID_quotabytesused,       0 },
    /* RFC 4331 pre-ratification */
    { 0, "quota-assigned-bytes", DAV_PROPID_quotabytes,           0 },

    { 0 }        /* sentinel */
};

static const dav_liveprop_group dav_zfsquota_liveprop_group =
{
    dav_zfsquota_props,
    dav_zfsquota_namespace_uris,
    &dav_zfsquota_hooks_liveprop
};

/**/

static dav_prop_insert
dav_zfsquota_insert_prop(
  const dav_resource*     resource,
  int                     propid,
  dav_prop_insert         what,
  apr_text_header*        phdr
)
{
  apr_pool_t*               p = resource->pool;
  const char*               s;
  const dav_liveprop_spec*  info;
  long                      global_ns;
  uint64_t                  value;

  if ( mod_dav_zfsquota_baseDevicePath == NULL ) {
    return DAV_PROP_INSERT_NOTSUPP;
  }

  switch (propid) {
  
    case DAV_PROPID_quotabytesavail: {
      if ( dav_zfsquota_getProps(resource->uri, NULL, NULL, &value, p) != 0 ) {
        return DAV_PROP_INSERT_NOTSUPP;
      }
      break;
    }
    
    case DAV_PROPID_quotaused:
    case DAV_PROPID_quotabytesused: {
      if ( dav_zfsquota_getProps(resource->uri, NULL, &value, NULL, p) != 0 ) {
        return DAV_PROP_INSERT_NOTSUPP;
      }
      if ( propid == DAV_PROPID_quotaused ) {
        value /= 512;
      }
      break;
    }
    
    case DAV_PROPID_quota:
    case DAV_PROPID_quotabytes: {
      if ( dav_zfsquota_getProps(resource->uri, &value, NULL, NULL, p) != 0 ) {
        return DAV_PROP_INSERT_NOTSUPP;
      }
      if ( propid == DAV_PROPID_quota ) {
        value /= 512;
      }
      break;
    }
    
    default:
      /*
       * This property is unknown
       */
      return DAV_PROP_INSERT_NOTDEF;
  }

  /* get the information and global NS index for the property */
  global_ns = dav_get_liveprop_info(propid, &dav_zfsquota_liveprop_group, &info);

  if ( what == DAV_PROP_INSERT_SUPPORTED ) {
    s = apr_psprintf(
            p,
            "<D:supported-live-property D:name=\"%s\" D:namespace=\"%s\"/>" DEBUG_CR,
            info->name,
            dav_zfsquota_namespace_uris[info->ns]
          );
  } else if ( what == DAV_PROP_INSERT_VALUE ) {
    s = apr_psprintf(
            p,
            "<lp%ld:%s>%llu</lp%ld:%s>" DEBUG_CR,
            global_ns,
            info->name,
            value,
            global_ns,
            info->name
          );
  } else {
    s = apr_psprintf(
            p,
            "<lp%ld:%s/>" DEBUG_CR,
            global_ns,
            info->name
          );
  }
  apr_text_append(p, phdr, s);

  /* we inserted what was asked for */
  return what;
}

/**/

static int
dav_zfsquota_is_writable(
  const dav_resource*     resource,
  int                     propid
)
{
  /* no writable props */
  return 0;
}

/**/

static dav_error*
dav_zfsquota_validate(
  const dav_resource*     resource,
  const apr_xml_elem*     elem,
  int                     operation,
  void**                  context,
  int*                    defer_to_dead
)
{
  /* no writable props, so anything goes in the dead prop database */
  *defer_to_dead = 1;

  return NULL;
}

/**/

static const dav_hooks_liveprop dav_zfsquota_hooks_liveprop = {
    dav_zfsquota_insert_prop,
    dav_zfsquota_is_writable,
    dav_zfsquota_namespace_uris,
    dav_zfsquota_validate,
    NULL,       /* patch_exec */
    NULL,       /* patch_commit */
    NULL,       /* patch_rollback */
};

/**/

void
dav_zfsquota_register_uris(
  apr_pool_t*       p
)
{  
  /* register the namespace URIs */
  dav_register_liveprop_group(p, &dav_zfsquota_liveprop_group);
}

/**/

static const char*
dav_zfsquota_cmd_devicebase(
  cmd_parms*    cmd,
  void*         config,
  const char*   arg1
)
{
  char*         end = (char*)arg1 + strlen(arg1);
  size_t        len;
  
  while ( *end && (*end == '/') ) {
    end--;
  }
  len = end - arg1;
  
  if ( len == 0 ) {
    return "Empty ZFS base device path not allowed.";
  }
  len++;
  
  if ( mod_dav_zfsquota_baseDevicePath ) {
    free( (void*)mod_dav_zfsquota_baseDevicePath );
  }
  if ( (mod_dav_zfsquota_baseDevicePath = (char*)malloc( len + 1 )) != NULL ) {
    memcpy(mod_dav_zfsquota_baseDevicePath, arg1, len);
    mod_dav_zfsquota_baseDevicePath[len] = '\0';
  } else {
    return "Unable to copy ZFS base device path.";
  }
  return NULL;
}

/**/

static const command_rec dav_zfsquota_commands[] =
{
  AP_INIT_TAKE1(
      "DAVZFSQuotaDeviceBase",
      dav_zfsquota_cmd_devicebase,
      NULL,
      RSRC_CONF,
      "Base ZFS device path for DAV quota properties"
    ),
  { NULL }
};

/**/

int
dav_zfsquota_find_liveprop(
  const dav_resource*         resource,
  const char*                 ns_uri,
  const char*                 name,
  const dav_hooks_liveprop**  hooks
)
{
  return dav_do_find_liveprop(ns_uri, name, &dav_zfsquota_liveprop_group, hooks);
}

/**/

static void
dav_zfsquota_register_hooks(
  apr_pool_t*       p
)
{
  /* DAV uses APR hooks to funnel property requests out to multiple
     providers: */
  dav_hook_find_liveprop(dav_zfsquota_find_liveprop, NULL, NULL, APR_HOOK_FIRST);
  
  /* Register our DAV properties: */
  dav_zfsquota_register_uris(p);
  
  /* Add version info: */
  ap_add_version_component(p, mod_dav_zfsquota_versionstr);
}

/**/

module AP_MODULE_DECLARE_DATA dav_zfsquota_module =
{
    STANDARD20_MODULE_STUFF,
    NULL,                           /* dir config creater */
    NULL,                           /* dir merger --- default is to override */
    NULL,                           /* server config */
    NULL,                           /* merge server config */
    dav_zfsquota_commands,          /* command table */
    dav_zfsquota_register_hooks     /* register hooks */
};
