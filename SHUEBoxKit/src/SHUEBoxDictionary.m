//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SHUEBoxDictionary.m
//
// Class category which handles lookup of named interval values.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

#import "SHUEBoxDictionary.h"

#import "SBString.h"
#import "SBDictionary.h"

@implementation SBPostgresDatabase(SHUEBoxDictionary)

  - (SBString*) stringForFullDictionaryKey:(SBString*)aKey
  {
    SBString*           value = nil;
    SBMutableString*    query = [[SBMutableString alloc] initWithFormat:"SELECT value FROM dictionary.keystore WHERE key = '%S'", 
                                              [[self stringEscapedForQuery:aKey] utf16Characters]
                                            ];
    
    if ( query ) {
      id                queryResult = [self executeQuery:query];
      
      if ( queryResult && [queryResult numberOfRows] ) {
        value = [queryResult objectForRow:0 fieldNum:0];
      }
      [query release];
    }
    return value;
  }

//

  - (SBDictionary*) stringsForFullDictionaryKeyRegex:(SBString*)aRegexString
  {
    SBDictionary*       outDict = nil;
    SBMutableString*    query = [[SBMutableString alloc] initWithFormat:"SELECT key, value FROM dictionary.keystore WHERE key ~ '%S'", 
                                              [[self stringEscapedForQuery:aRegexString] utf16Characters]
                                            ];
    
    if ( query ) {
      id                queryResult = [self executeQuery:query];
      SBUInteger        i = 0, iMax;
      
      if ( queryResult && (iMax = [queryResult numberOfRows]) ) {
        SBString*       keys[iMax];
        SBString*       values[iMax];
        
        while ( i < iMax ) {
          keys[i] = [queryResult objectForRow:i fieldNum:0];
          values[i] = [queryResult objectForRow:i fieldNum:1];
          i++;
        }
        outDict = [SBDictionary dictionaryWithObjects:values forKeys:keys count:iMax];
      }
      [query release];
    }
    return outDict;
  }

//

  - (SBDictionary*) stringsForDictionaryNamespace:(SBString*)aNamespace
  {
    SBDictionary*       outDict = nil;
    SBMutableString*    query = [[SBMutableString alloc] initWithFormat:"SELECT key, value FROM dictionary.keystore WHERE dictionary.namespace(key) = '%S'", 
                                              [[self stringEscapedForQuery:aNamespace] utf16Characters]
                                            ];
    
    if ( query ) {
      id                queryResult = [self executeQuery:query];
      SBUInteger        i = 0, iMax;
      
      if ( queryResult && (iMax = [queryResult numberOfRows]) ) {
        SBString*       keys[iMax];
        SBString*       values[iMax];
        
        while ( i < iMax ) {
          keys[i] = [queryResult objectForRow:i fieldNum:0];
          values[i] = [queryResult objectForRow:i fieldNum:1];
          i++;
        }
        outDict = [SBDictionary dictionaryWithObjects:values forKeys:keys count:iMax];
      }
      [query release];
    }
    return outDict;
  }
  
//

  - (SBDictionary*) stringsForDictionaryKey:(SBString*)aKey
  {
    SBDictionary*       outDict = nil;
    SBMutableString*    query = [[SBMutableString alloc] initWithFormat:"SELECT key, value FROM dictionary.keystore WHERE dictionary.key(key) = '%S'", 
                                              [[self stringEscapedForQuery:aKey] utf16Characters]
                                            ];
    
    if ( query ) {
      id                queryResult = [self executeQuery:query];
      SBUInteger        i = 0, iMax;
      
      if ( queryResult && (iMax = [queryResult numberOfRows]) ) {
        SBString*       keys[iMax];
        SBString*       values[iMax];
        
        while ( i < iMax ) {
          keys[i] = [queryResult objectForRow:i fieldNum:0];
          values[i] = [queryResult objectForRow:i fieldNum:1];
          i++;
        }
        outDict = [SBDictionary dictionaryWithObjects:values forKeys:keys count:iMax];
      }
      [query release];
    }
    return outDict;
  }

@end

//

SBString* SHUEBoxDictionarySystemBaseURIAuthorityKey = @"system:base-uri-authority";
SBString* SHUEBoxDictionarySystemBaseURIPathKey = @"system:base-uri-path";
SBString* SHUEBoxDictionarySystemAdminEmailAddressKey = @"system:admin-email-address";
SBString* SHUEBoxDictionarySystemBaseConfirmURIKey = @"system:base-confirm-uri";
