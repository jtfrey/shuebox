//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SHUEBox.m
//
// Constants, etc.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SHUEBox.h"
#import "SBString.h"

SBString* SHUEBoxErrorDomain = @"SHUEBox";

@implementation SBDateFormatter(SHUEBoxAdditions)

  + (SBDateFormatter*) iso8601DateFormatter
  {
    static SBDateFormatter* __iso8601DateFormatter = nil;
    
    if ( ! __iso8601DateFormatter ) {
      if ( (__iso8601DateFormatter = [[SBDateFormatter alloc] init]) ) {
        [__iso8601DateFormatter setPattern:@"yyyy-MM-dd'T'HH:mm:ssZZZ"];
      }
    }
    return __iso8601DateFormatter;
  }
  
//

  + (SBDateFormatter*) sqlDateFormatter
  {
    static SBDateFormatter* __sqlDateFormatter = nil;
    
    if ( ! __sqlDateFormatter ) {
      if ( (__sqlDateFormatter = [[SBDateFormatter alloc] init]) ) {
        [__sqlDateFormatter setPattern:@"yyyy-MM-dd' 'HH:mm:ssZZZ"];
      }
    }
    return __sqlDateFormatter;
  }

@end
