//
// SBFoundation : ObjC Class Library for Solaris
// SBKeyValueCoding.h
//
// String-based access to object instance variables.
//
// $Id$
//

#import "SBKeyValueCoding.h"
#import "SBString.h"
#import "SBValue.h"
#import "SBArray.h"
#import "SBDictionary.h"
#import "SBException.h"

#include <objc/objc.h>
#include <objc/objc-api.h>
#include <objc/encoding.h>

Ivar_t
__SBKeyValueCodingGetIVar(
  id        object,
  char*     key
)
{
  static Ivar_t   ivar_cache = NULL;
  
  if ( ivar_cache ) {
    const char*   ivarName = ivar_cache->ivar_name;
    
    if ( (strcmp(ivarName, key) == 0) ||
         ( (ivarName[0] == '_') && (strcmp(ivarName + 1, key) == 0) )
    ) {
      return ivar_cache;
    }
  }

  Class               myClass = [object class];
  
  while ( myClass != [SBObject class] ) {
    IvarList_t        ivars = myClass->ivars;
    
    if ( ! [myClass accessInstanceVariablesDirectly] )
      return NULL;
      
    if ( ivars && ivars->ivar_count ) {
      int             i = 0, iMax = ivars->ivar_count;
      
      while ( i < iMax ) {
        const char*   ivarName = ivars->ivar_list[i].ivar_name;
        
        if ( ivarName && ((strcmp(ivarName, key) == 0) ||
             ( (ivarName[0] == '_') && (strcmp(ivarName + 1, key) == 0)) )
        ) {
          return ( ivar_cache = &ivars->ivar_list[i] );
        }
        i++;
      }
    }
    myClass = class_get_super_class(myClass);
  }
  return NULL;
}

//

id
__SBKeyValueCodingGetValue(
  id        object,
  char*     key
)
{
  Ivar_t    ivar = __SBKeyValueCodingGetIVar(object, key);
  
  if ( ivar ) {
    void*   ivar_value = ((void*)object) + ivar->ivar_offset;
    
    // Analyze the variable's type; we only work with atomic types!
    switch ( ivar->ivar_type[0] ) {
    
      case _C_ID:
        return *((id*)ivar_value);
      
      case _C_CHR:
        return [SBNumber numberWithInt:(int)(*((char*)ivar_value))];
      
      case _C_UCHR:
        return [SBNumber numberWithUnsignedInt:(unsigned int)(*((unsigned char*)ivar_value))];
      
      case _C_SHT:
        return [SBNumber numberWithInt:(int)(*((short int*)ivar_value))];
      
      case _C_USHT:
        return [SBNumber numberWithUnsignedInt:(unsigned int)(*((unsigned short int*)ivar_value))];
      
      case _C_LNG:
      case _C_INT:
        return [SBNumber numberWithInt:*((int*)ivar_value)];
      
      case _C_ULNG:
      case _C_UINT:
        return [SBNumber numberWithUnsignedInt:*((unsigned int*)ivar_value)];
      
      case _C_LNG_LNG:
        return [SBNumber numberWithInt64:(int64_t)(*((long long int*)ivar_value))];
      
      case _C_FLT:
        return [SBNumber numberWithDouble:(double)(*((float*)ivar_value))];
      
      case _C_DBL:
        return [SBNumber numberWithDouble:*((double*)ivar_value)];
      
      case _C_VOID:
      case _C_UNDEF:
        return [SBNull null];
    
    }
    
  } else {
    [SBException raise:@"Invalid key" format:"Object of class %s has no key %s", [object name], key];
  }
  return nil;
}

//

BOOL
__SBKeyValueCodingValidateValue(
  id        object,
  char*     key,
  id        value
)
{
  Ivar_t    ivar = __SBKeyValueCodingGetIVar(object, key);
  
  if ( ivar ) {
    void*   ivar_value = ((void*)object) + ivar->ivar_offset;
    
    // Make sure we're getting the correct class type based on the
    // variable's type:
    switch ( ivar->ivar_type[0] ) {
    
      case _C_ID:
        return YES;
      
      case _C_CHR:
      case _C_UCHR:
      case _C_SHT:
      case _C_USHT:
      case _C_LNG:
      case _C_INT:
      case _C_ULNG:
      case _C_UINT:
      case _C_LNG_LNG:
      case _C_FLT:
      case _C_DBL:
        if ( [value isKindOf:[SBNumber class]] )
          return YES;
        break;
      
      case _C_VOID:
      case _C_UNDEF:
        if ( [value isNull] )
          return YES;
        break;
    
    }
  } else {
    [SBException raise:@"Invalid key" format:"Object of class %s has no key %s", [object name], key];
  }
  return NO;
}

//

BOOL
__SBKeyValueCodingSetValue(
  id        object,
  char*     key,
  id        value
)
{
  Ivar_t    ivar = __SBKeyValueCodingGetIVar(object, key);
  
  if ( ivar ) {
    void*   ivar_value = ((void*)object) + ivar->ivar_offset;
      
    // Analyze the variable's type; we only work with atomic types!
    switch ( ivar->ivar_type[0] ) {
    
      case _C_ID: {
        id      v = [value retain];
        
        [*((id*)ivar_value) release];
        *((id*)ivar_value) = v;
        return YES;
      }
      
      case _C_CHR: {
        *((char*)ivar_value) = [(SBNumber*)value intValue];
        return YES;
      }
      
      case _C_UCHR: {
        *((unsigned char*)ivar_value) = [(SBNumber*)value unsignedIntValue];
        return YES;
      }
      
      case _C_SHT: {
        *((short int*)ivar_value) = [(SBNumber*)value intValue];
        return YES;
      }
      
      case _C_USHT: {
        *((unsigned short int*)ivar_value) = [(SBNumber*)value unsignedIntValue];
        return YES;
      }
      
      case _C_LNG:
      case _C_INT: {
        *((int*)ivar_value) = [(SBNumber*)value intValue];
        return YES;
      }
      
      case _C_ULNG:
      case _C_UINT: {
        *((unsigned int*)ivar_value) = [(SBNumber*)value unsignedIntValue];
        return YES;
      }
      
      case _C_LNG_LNG: {
        *((long long int*)ivar_value) = (long long int)[(SBNumber*)value int64Value];
        return YES;
      }
      
      case _C_FLT: {
        *((float*)ivar_value) = (float)[(SBNumber*)value doubleValue];
        return YES;
      }
      
      case _C_DBL: {
        *((double*)ivar_value) = (double)[(SBNumber*)value doubleValue];
        return YES;
      }
    
    }
    
  } else {
    [SBException raise:@"Invalid key" format:"Object of class %s has no key %s", [object name], key];
  }
  return NO;
}

//
#pragma mark -
//

@implementation SBObject(SBKeyValueCoding)

  + (BOOL) accessInstanceVariablesDirectly
  {
    return YES;
  }

//

  - (id) valueForKey:(SBString*)aKey
  {
    SBSTRING_AS_UTF8_BEGIN(aKey)
    
      SBUInteger    aKey_len = strlen(aKey_utf8);
      
      if ( aKey_len ) {
        // Is there a method of the same name?
        SEL     selForKey = sel_get_any_uid(aKey_utf8);
        
        if ( selForKey && [self respondsTo:selForKey] )
          return [self perform:selForKey];
        
        if ( [[self class] accessInstanceVariablesDirectly] )
          return __SBKeyValueCodingGetValue(self, aKey_utf8);
        
        [SBException raise:@"Object not KVC compliant" format:"Object of class %s is not KVC compliant", [self name]];
      }
      
    SBSTRING_AS_UTF8_END
    
    return nil;
  }

//

  - (void) setValue:(id)value
    forKey:(SBString*)aKey
  {
    SBSTRING_AS_UTF8_BEGIN(aKey)
    
      SBUInteger    aKey_len = strlen(aKey_utf8);
      
      if ( aKey_len ) {
        char    selName[aKey_len + 5];
        SEL     selForKey;
        
        // Is there a "set<key>:" method for this class:
        snprintf(selName, aKey_len + 5, "set%c%s:", toupper(*aKey_utf8), aKey_utf8 + 1);
        if ( (selForKey = sel_get_any_uid(selName)) && [self respondsTo:selForKey] ) {
          // Figure out what type that method is expecting:
          Method_t        m = class_get_instance_method([self class], selForKey);
          char*           t = (char*)m->method_types;
          
          // Should properly be a void return value:
          if ( *t == _C_VOID ) {
            int           n, l;
            
            // Skip ahead to the first argument:
            t++; sscanf(t, "%d%n", &l, &n); t += n;
            t++; sscanf(t, "%d%n", &l, &n); t += n;
            t++; sscanf(t, "%d%n", &l, &n); t += n;
            
            switch ( *t ) {
            
              case _C_ID:
                [self perform:selForKey with:value];
                break;
              
              case _C_CHR:
                (m->method_imp)(self, selForKey, (char)[(SBNumber*)value intValue]);
                break;
              
              case _C_UCHR:
                (m->method_imp)(self, selForKey, (unsigned char)[(SBNumber*)value intValue]);
                break;
              
              case _C_SHT:
                (m->method_imp)(self, selForKey, (short int)[(SBNumber*)value intValue]);
                break;
              
              case _C_USHT:
                (m->method_imp)(self, selForKey, (unsigned short int)[(SBNumber*)value intValue]);
                break;
              
              case _C_LNG:
              case _C_INT:
                (m->method_imp)(self, selForKey, [(SBNumber*)value intValue]);
                break;
              
              case _C_ULNG:
              case _C_UINT:
                (m->method_imp)(self, selForKey, [(SBNumber*)value unsignedIntValue]);
                break;
      
              case _C_LNG_LNG:
                (m->method_imp)(self, selForKey, (long long int)[(SBNumber*)value int64Value]);
                break;
              
              case _C_FLT:
                (m->method_imp)(self, selForKey, (float)[(SBNumber*)value doubleValue]);
                break;
                
              case _C_DBL:
                (m->method_imp)(self, selForKey, [(SBNumber*)value doubleValue]);
                break;
                
            }
          }
        } else if ( [[self class] accessInstanceVariablesDirectly] ) {
          __SBKeyValueCodingSetValue(self, aKey_utf8, value);
        } else {
          [SBException raise:@"Object not KVC compliant" format:"Object of class %s is not KVC compliant", [self name]];
        }
      }
      
    SBSTRING_AS_UTF8_END
  }

//

  - (BOOL) validateValue:(id*)inOutValue
    forKey:(SBString*)aKey
  {
    SBSTRING_AS_UTF8_BEGIN(aKey)
    
      SBUInteger    aKey_len = strlen(aKey_utf8);
      
      if ( aKey_len ) {
        char    selName[aKey_len + 17];
        SEL     selForKey;
        
        // Is there a "validate<Key>:forKey:" method for this class:
        snprintf(selName, aKey_len + 17, "validate%c%s:forKey:", toupper(*aKey_utf8), aKey_utf8 + 1);
        if ( (selForKey = sel_get_any_uid(selName)) && [self respondsTo:selForKey] ) {
          // Figure out what type that method is expecting:
          Method_t        m = class_get_instance_method([self class], selForKey);
          retval_t        r;
          
          r = (m->method_imp)(self, selForKey, inOutValue, aKey);
          
          return *((BOOL*)r);
        } else if ( [[self class] accessInstanceVariablesDirectly] ) {
          return __SBKeyValueCodingValidateValue(self, aKey_utf8, *inOutValue);
        } else {
          [SBException raise:@"Object not KVC compliant" format:"Object of class %s is not KVC compliant", [self name]];
        }
      }
      
    SBSTRING_AS_UTF8_END
    
    return NO;
  }
  
//

  - (id) valueForKeyPath:(SBString*)keyPath
  {
    id              prev = nil;
    id              target = self;
    SBEnumerator*   eKey = [[keyPath componentsSeparatedByString:@"."] objectEnumerator];
    SBString*       key;
    
    while( target && (key = [eKey nextObject]) ) {
      prev = target;
      target = [target valueForKey:key];
    }
    return target;
  }

//

  - (void) setValue:(id)value
    forKeyPath:(SBString*)keyPath
  {
    id              target = self;
    SBEnumerator*   eKey = [[keyPath componentsSeparatedByString:@"."] objectEnumerator];
    SBString*       key = [eKey nextObject];
    
    while( target && key ) {
      SBString*     nextKey = [eKey nextObject];
      
      if ( nextKey == nil ) {
        // "key" is the final component, so set the value in the current target:
        [target setValue:value forKey:key];
        return;
      }
      target = [target valueForKey:key];
      key=nextKey;
    }
  }

//

  - (BOOL) validateValue:(id*)inOutValue
    forKeyPath:(SBString*)keyPath
  {
    id              target = self;
    SBEnumerator*   eKey = [[keyPath componentsSeparatedByString:@"."] objectEnumerator];
    SBString*       key = [eKey nextObject];
    
    while( target && key ) {
      SBString*     nextKey = [eKey nextObject];
      
      if ( nextKey == nil ) {
        // "key" is the final component, so set the value in the current target:
        return [target validateValue:inOutValue forKey:key];
      }
      target = [target valueForKey:key];
      key=nextKey;
    }
    return NO;
  }
  
//

/*
  - (retval_t) forward:(SEL)sel
    :(arglist_t)args
  {
    const char*     selName = sel_get_name(sel);
    const char*     prefixSet = "set";
    int             i, iMax = 0;
    Ivar_t          ivar = NULL;
    
    // Does it start with "set"?
    i = 0;
    while ( i < 3 ) {
      if ( selName[i] == ':' ) {
        break;
      }
      if ( tolower(selName[i]) != tolower(prefixSet[i]) )
        break;
      i++;
    }
    iMax = i;
    // Locate the first (if any) colon:
    while ( selName[iMax] && (selName[iMax] != ':' ) )
      iMax++;
    
    if ( i == 3 ) {
      char          varName[(iMax -= 3) + 1];
      
      memcpy(varName, selName + 3, iMax);
      varName[0] = tolower(varName[0]);
      varName[iMax] = '\0';
      
      if ( (ivar = __SBKeyValueCodingGetIVar(self, varName)) ) {
        Method*         m = class_get_instance_method([self class], @selector(setValue:forKey:));
        const char*     type;
        char*           arg1 = method_get_nth_argument(m, args, 2, &type);
        
        if ( arg1 ) {
          IMP           imp = objc_msg_lookup(self, @selector(setValue:forKey:));
          
          printf("%p %hhd\n", arg1, *arg1 );
          
          [self setValue:(id)arg1 forKey:[SBString stringWithUTF8String:(char*)selName + 3]];
          return NULL;
        }
      }
    } else if ( selName[iMax] == '\0' ) {
      if ( (ivar = __SBKeyValueCodingGetIVar(self, (char*)selName)) ) {
        id              value = [self valueForKey:[SBString stringWithUTF8String:(char*)selName]];
        SBValue*        valueWrap = [SBValue valueWithPointer:value];
        
        return [valueWrap bytes];
      }
    }
    return [self error:"Selector not implemented: %s\n", selName];
  }
*/
  
@end

//
#pragma mark -
//

//
// For array types, the "count" pseudo-value is available:
//
@implementation SBArray(SBKeyValueCoding)

  - (id) valueForKey:(SBString*)aKey
  {
    if ( [aKey isEqual:@"@count"] )
      return [SBNumber numberWithUnsignedInt:[self count]];
    return [super valueForKey:aKey];
  }

@end

//
// For dictionary types, the KV-coding methods should just call through to the
// dictionary's usual object accessors:
//
@implementation SBDictionary(SBKeyValueCoding)

  - (id) valueForKey:(SBString*)aKey
  {
    if ( [aKey isEqual:@"@count"] )
      return [SBNumber numberWithUnsignedInt:[self count]];
    return [self objectForKey:aKey];
  }

@end

@implementation SBMutableDictionary(SBKeyValueCoding)

  - (void) setValue:(id)value
    forKey:(SBString*)aKey
  {
    [self setObject:value forKey:aKey];
  }

@end
