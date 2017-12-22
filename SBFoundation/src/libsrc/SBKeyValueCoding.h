//
// SBFoundation : ObjC Class Library for Solaris
// SBKeyValueCoding.h
//
// String-based access to object instance variables.
//
// $Id$
//

#import "SBObject.h"

@class SBString;

/*!
  @category SBObject(SBKeyValueCoding)
  @discussion
  Key-value coding is a mechanism by which instance variables of an
  object can be accessed by name or by a path comprised of names
  joined by a dot.
  
  For example, assume "anObj" has an instance variable named "_properties".
  Using a key path we can access a specific value in the dictionary as
  <pre>
  
    timestamp = [anObj valueForKeyPath:\@"properties.timestamp"];
    
  </pre>
  If any object along a key path does not allow direct access to instance
  variables and resolving the next path component would require direct
  access, the resolution will fail and the path will be considered
  invalid.
  
  By default, the valueForKey: method will search the receiver for a
  method with a name which matches the key and will simply invoke
  that method.  Likewise, the setValue:forKey: method searches the
  receiver for a method named as "set<Key>:" where the first character
  of the key is capitalized (e.g. "setTimestamp:").
  
  There is a special "@count" operator that can be used as a key against a
  collection object (SBArray or SBDictionary) to retrieve the number of
  objects in the collection.
  
  For classes which allow direct access to instance variables, most of
  the basic atomic types will automatically be converted to and from
  object form.  For example, integer and floating-point instance variables
  accessed via valueForKey: will return an instance of SBNumber which
  wraps the numerical value.  Likewise, a setValue:forKey: message with
  an SBNumber value will result in the atomic instance variable being
  set via the appropriate "[type]Value" message.
*/
@interface SBObject(SBKeyValueCoding)

/*!
  @method accessInstanceVariablesDirectly
  @discussion
  Classes should override this method if they wish to discourage the
  key-value coding interfaces from accessing instance variables through
  the compiler-built data structures rather than through accessors.
*/
+ (BOOL) accessInstanceVariablesDirectly;
/*!
  @method valueForKey:
  @discussion
  Attempt to locate a value associated with the receiver.
*/
- (id) valueForKey:(SBString*)aKey;
/*!
  @method setValue:forKey:
  @discussion
  Attempts to set the named (by aKey) value associated with the receiver.
*/
- (void) setValue:(id)value forKey:(SBString*)aKey;
/*!
  @method validateValue:forKey:
  @discussion
  Validate the value pointed at by inOutValue as an appropriate value
  to be associated with aKey.  Subclasses can substitute an alternate
  value by modifying *inOutValue with a different object.
  
  The method should return YES if the value was acceptable as-is or
  was modified to be acceptable.
*/
- (BOOL) validateValue:(id*)inOutValue forKey:(SBString*)aKey;
/*!
  @method valueForKeyPath:
  @discussion
  Attempt to locate a value associated with the given key path rooted
  at the receiver.  This method should rarely be overridden; it's far more
  likely you'll override the valueForKey: method.
*/
- (id) valueForKeyPath:(SBString*)keyPath;
/*!
  @method setValue:forKeyPath:
  @discussion
  Attempts to set the named value associated with the key path rooted
  at the receiver.  This method should rarely be overridden; it's far more
  likely you'll override the setValue:forKey: method.
*/
- (void) setValue:(id)value forKeyPath:(SBString*)keyPath;
/*!
  @method validateValue:forKeyPath:
  @discussion
  Validate the value pointed at by inOutValue as an appropriate value
  associated with the key path rooted at the receiver.  Subclasses can
  substitute an alternate value by modifying *inOutValue with a different
  object.  That being said, this method should rarely be overridden;
  it's far more likely you'll override the validateValue:forKey: method.
  
  The method should return YES if the value was acceptable as-is or
  was modified to be acceptable.
*/
- (BOOL) validateValue:(id*)inOutValue forKeyPath:(SBString*)keyPath;

@end
