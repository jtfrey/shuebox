//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SHUEBoxDictionary.h
//
// Class category which handles lookup of named interval values.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

#import "SBPostgres.h"

@class SBString, SBDictionary, SBPostgresDatabase;

@interface SBPostgresDatabase(SHUEBoxDictionary)

- (SBString*) stringForFullDictionaryKey:(SBString*)aKey;

- (SBDictionary*) stringsForFullDictionaryKeyRegex:(SBString*)aRegexString;
- (SBDictionary*) stringsForDictionaryNamespace:(SBString*)aNamespace;
- (SBDictionary*) stringsForDictionaryKey:(SBString*)aKey;

@end

//

extern SBString* SHUEBoxDictionarySystemBaseURIAuthorityKey;
extern SBString* SHUEBoxDictionarySystemBaseURIPathKey;
extern SBString* SHUEBoxDictionarySystemAdminEmailAddressKey;
extern SBString* SHUEBoxDictionarySystemBaseConfirmURIKey;

