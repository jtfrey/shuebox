//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBLocale.m
//
// Locale management, thanks to ICU.
//
// $Id$
//

#import "SBLocale.h"

static SBLocale* __SBSystemLocaleSharedInstance = nil;
static SBLocale* __SBDefaultLocaleSharedInstance = nil;

@implementation SBLocale

  + (SBLocale*) systemLocale
  {
    if ( __SBSystemLocaleSharedInstance == nil ) {
      __SBSystemLocaleSharedInstance = [[SBLocale alloc] initWithLocaleIdentifier:NULL];
    }
    return __SBSystemLocaleSharedInstance;
  }

//

  + (SBLocale*) defaultLocale
  {
    if ( __SBDefaultLocaleSharedInstance == nil ) {
      __SBDefaultLocaleSharedInstance = [[SBLocale alloc] initWithLocaleIdentifier:uloc_getDefault()];
    }
    return __SBDefaultLocaleSharedInstance;
  }

//

  - (id) initWithLocaleIdentifier:(const char*)localeId
  {
    if ( self = [super init] ) {
      UErrorCode  icuErr = U_ZERO_ERROR;
      char*       canonicalId = NULL;
      int32_t     canonicalIdLen = 0;
      
      //  Canonicalize the Id if possible:
      canonicalIdLen = uloc_getName(localeId, NULL, 0, &icuErr);
      if ( icuErr == U_BUFFER_OVERFLOW_ERROR ) {
        if ( (canonicalId = malloc(canonicalIdLen + 1)) ) {
          icuErr = U_ZERO_ERROR;
          uloc_getName(localeId, canonicalId, canonicalIdLen + 1, &icuErr);
          if ( U_FAILURE(icuErr) ) {
            free(canonicalId);
            canonicalId = NULL;
          }
        }
      }
      if ( canonicalId ) {
        _localeIdentifier = canonicalId;
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
    if ( _localeIdentifier ) free(_localeIdentifier);
    [super dealloc];
  }
  
//

  - (const char*) localeIdentifier
  {
    return _localeIdentifier;
  }
  
//

  - (void) setAsDefaultLocale
  {
    UErrorCode    icuErr = U_ZERO_ERROR;
    
    uloc_setDefault(_localeIdentifier, &icuErr);
    if ( U_SUCCESS(icuErr) && __SBDefaultLocaleSharedInstance ) {
      [__SBDefaultLocaleSharedInstance release];
      __SBDefaultLocaleSharedInstance = nil;
    }
  }
  
@end
