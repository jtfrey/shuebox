//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBNotification.h
//
// Inter-object notifications.
//
// $Id$
//

#import "SBObject.h"

@class SBString;
@class SBDictionary;


/*!
  @class SBNotification
  
  Instances of SBNotification are created when an event is posted to a notification
  center.  The resuling object is passed to each listener; the notification name and
  additional data posted to the notification center are made available to th
  listeners through the SBNotification object they receive.
  
  A listener should _not_ attempt to release the SBNotification object passed to
  it.
*/  
@interface SBNotification : SBObject
{
  SBString*     _notificationName;
  SBDictionary* _extraInfo;
}

- (SBString*) notificationName;
- (SBDictionary*) extraInfo;

@end


/*!
  @class SBNotificationCenter
  
  An SBNotificationCenter acts as a distribution point for inter-object communication.
  A notification is posted by providing its name (a unique string) and, optionally, any
  additional data encapsulated in an SBDictionary object.  Each object that has
  previously registered an interest in notifications having said name will be notified
  by performing the selector that was specified at registration time with an instance of
  SBNotification holding the notification name and extra-info.
  
  There is a default, shared notification center created by default in a running
  application; this center can be accessed using the defaultNotificationCenter class
  method.  Honestly, you'll probably never need to create your own notification center(s)
  anyway!
*/
@interface SBNotificationCenter : SBObject
{
  SBDictionary* _registry;
}

/*!
  @method defaultNotificationCenter
  
  Returns the default, application-wide notification center.  Do not attempt to release
  or retain the returned object!
*/
+ (SBNotificationCenter*) defaultNotificationCenter;

/*!
  @method addListener:selector:forNotification:
  
  Register "object" as wanting notification when "notificationName" is posted to this
  notification center.  When "notificationName" is posted, the given "selector" will
  be performed on "object."
  
  E.g. assume "object" has the following instance method:
  
    - (void) respondToNotification:(SBNotification*)aNotify
    {
    }
  
  The following code would register "object" to have this method invoked when a notification
  named "ethernetOffline" is posted:
  
    [[SBNotificationCenter defaultNotificationCenter]
        addListener:object
        selector:@selector(respondToNotification:)
        forNotification:[SBString stringWithUTF8String:"ethernetOffline"]
      ];
*/
- (void) addListener:(id)object selector:(SEL)selector forNotification:(SBString*)notificationName;
/*!
  @method removeListener:
  
  For all registered notification names in the receiver, remove "object" as a listener if
  present.
*/
- (void) removeListener:(id)object;
/*!
  @method removeListener:forNotification:
  
  Remove "object" as a listener (if present) for the specific notification (by name).
*/
- (void) removeListener:(id)object forNotification:(SBString*)notificationName;
/*!
  @method postNotification:
  
  Given the passed-in notificationName, notify all those objects that are registered listeners
  for a notification having that name.
*/
- (void) postNotification:(SBString*)notificationName;
/*!
  @method postNotification:extraInfo:
  
  Given the passed-in notificationName, notify all those objects that are registered listeners
  for a notification having that name.  Additional data associated with the notification (as passed
  in extraInfo) will be included in the per-listener notification.
*/
- (void) postNotification:(SBString*)notificationName extraInfo:(SBDictionary*)extraInfo;

@end
