//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBNotification.m
//
// Inter-object notifications.
//
// $Id$
//

#import "SBNotification.h"
#import "SBString.h"
#import "SBDictionary.h"
#import "SBArray.h"

@interface SBNotificationRegistration : SBObject
{
  id      _object;
  SEL     _selector;
}

- (id) initWithObject:(id)object;
- (id) initWithObject:(id)object andSelector:(SEL)selector;
- (id) object;
- (SEL) selector;
- (void) notify:(SBNotification*)aNotification;

@end

@implementation SBNotificationRegistration

  - (id) initWithObject:(id)object
  {
    if ( self = [super init] )
      _object = object;
    return self;
  }

//

  - (id) initWithObject:(id)object
    andSelector:(SEL)selector
  {
    if ( self = [super init] ) {
      _object = object;
      _selector = selector;
    }
    return self;
  }
  
//

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(stream,
        "  object : %s@%p\n",
        [_object name], _object
      );
  }

//

  - (BOOL) isEqual:(id)otherObject
  {
    if ( [otherObject isKindOf:[self class]] ) {
      if ( [otherObject object] == _object )
        return YES;
    }
    return NO;
  }

//

  - (id) object { return _object; }
  - (SEL) selector { return _selector; }
  - (void) notify:(SBNotification*)aNotification
  {
    [_object perform:_selector with:aNotification];
  }

@end

//
#pragma mark -
//

@interface SBNotification(SBNotificationPrivate)

- (id) initWithNotification:(SBString*)notificationName extraInfo:(SBDictionary*)extraInfo;

@end

@implementation SBNotification(SBNotificationPrivate)

  - (id) initWithNotification:(SBString*)notificationName
    extraInfo:(SBDictionary*)extraInfo
  {
    if ( self = [super init] ) {
      _notificationName = [notificationName retain];
      if ( extraInfo )
        _extraInfo = [extraInfo retain];
    }
    return self;
  }

@end

@implementation SBNotification

  - (void) dealloc
  {
    if ( _notificationName ) [_notificationName release];
    if ( _extraInfo ) [_extraInfo release];
    [super dealloc];
  }

//

  - (SBString*) notificationName { return _notificationName; }
  - (SBDictionary*) extraInfo { return _extraInfo; }

@end

//
#pragma mark -
//

@implementation SBNotificationCenter

  + (SBNotificationCenter*) defaultNotificationCenter
  {
    static SBNotificationCenter*    defaultCenter = nil;
    
    if ( defaultCenter == nil ) {
      defaultCenter = [[SBNotificationCenter alloc] init];
    }
    return defaultCenter;
  }
  
//

  - (id) init
  {
    if ( self = [super init] ) {
      _registry = [[SBDictionary alloc] init];
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    if ( _registry )
      [_registry release];
    [super dealloc];
  }
  
//

  - (void) summarizeToStream:(FILE*)stream
  {
    SBEnumerator*     eKey = [_registry keyEnumerator];
    SBString*         key;
    
    [super summarizeToStream:stream];
    fprintf(stream, "  registry: \n");
    while ( key = [eKey nextObject] ) {
      SBEnumerator*                 eListener = [[_registry objectForKey:key] objectEnumerator];
      SBNotificationRegistration*   listener;
      
      SBSTRING_AS_UTF8_BEGIN(key)
        fprintf(stream, "    %s => {\n", key_utf8);
        while ( listener = [eListener nextObject] ) {
          fprintf(stream, "        %s@%p\n", [listener name], listener);
        }
      SBSTRING_AS_UTF8_END
      
      fprintf(stream, "      }\n");
    }
  }

//

  - (void) addListener:(id)object
    selector:(SEL)selector
    forNotification:(SBString*)notificationName
  {
    if ( notificationName && [notificationName length] ) {
      SBArray*                      registrationsForName = [_registry objectForKey:notificationName];
      SBNotificationRegistration*   newRegistration = [[SBNotificationRegistration alloc] initWithObject:object andSelector:selector];
      
      if ( registrationsForName ) {
        unsigned int                index = [registrationsForName indexOfObjectIdenticalTo:newRegistration];
        
        if ( index == SBNotFound ) {
          [registrationsForName addObject:newRegistration];
        } else {
          [registrationsForName replaceObject:newRegistration atIndex:index];
        }
      } else {
        if ( (registrationsForName = [[SBArray alloc] initWithObject:newRegistration]) ) {
          [_registry setObject:registrationsForName forKey:notificationName];
          [registrationsForName release];
        }
      }
      [newRegistration release];
    }
  }
  
//

  - (void) removeListener:(id)object
  {
    SBEnumerator*                   eArrays = [_registry objectEnumerator];
    SBArray*                        array;
    SBNotificationRegistration*     toMatch = [[SBNotificationRegistration alloc] initWithObject:object];
    
    while ( array = [eArrays nextObject] ) {
      unsigned int  i = [array indexOfObject:toMatch];
      
      while ( i != SBNotFound ) {
        [array removeObjectAtIndex:i];
        i = [array indexOfObject:toMatch];
      }
    }
    [toMatch release];
  }
  
//

  - (void) removeListener:(id)object
    forNotification:(SBString*)notificationName
  {
    if ( notificationName && [notificationName length] ) {
      SBArray*                        array = [_registry objectForKey:notificationName];
      
      if ( array ) {
        SBNotificationRegistration*   toMatch = [[SBNotificationRegistration alloc] initWithObject:object];
        unsigned int                  i = [array indexOfObject:toMatch];
        
        while ( i != SBNotFound ) {
          [array removeObjectAtIndex:i];
          i = [array indexOfObject:toMatch];
        }
        [toMatch release];
      }
    }
  }
  
//

  - (void) postNotification:(SBString*)notificationName
  {
    [self postNotification:notificationName extraInfo:nil];
  }
  
//

  - (void) postNotification:(SBString*)notificationName
    extraInfo:(SBDictionary*)extraInfo
  {
    SBArray*          array = [_registry objectForKey:notificationName];
    
    if ( array ) {
      SBNotification* aNotification = [[SBNotification alloc] initWithNotification:notificationName extraInfo:extraInfo];
      
      [array makeObjectsPerformSelector:@selector(notify:) withObject:aNotification];
      [aNotification release];
    }
  }

@end
