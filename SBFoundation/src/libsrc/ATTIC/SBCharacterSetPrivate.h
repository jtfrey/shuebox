//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBCharacterSetPrivate.h
//
// Private (framework-only) interfaces to SBCharacterSet.
//
// $Id$
//

@interface SBCharacterSet(SBCharacterSetPrivate)

- (id) initWithICUCharacterSet:(USet*)icuCharSet;
- (id) initWithPattern:(UChar*)pattern;
- (id) initWithRange:(SBRange)aRange;
- (id) initWithCharactersInString:(SBString*)aString;
- (id) initWithBitmapRepresentation:(SBData*)aBitmap;

- (USet*) icuCharSet;

@end

#undef NEED_USET_CLONE
#undef NEED_USET_FREEZE
#undef NEED_USET_ALLCODEPOINTS
#undef NEED_USET_SPAN

#if U_ICU_VERSION_MAJOR_NUM < 3
#  define NEED_USET_CLONE
#  define NEED_USET_FREEZE
#  define NEED_USET_ALLCODEPOINTS
#  define NEED_USET_SPAN
#else
#  if U_ICU_VERSION_MAJOR_NUM == 3
#    if U_ICU_VERSION_MINOR_NUM < 4
#      define NEED_USET_ALLCODEPOINTS
#    endif
#    if U_ICU_VERSION_MINOR_NUM < 8
#      define NEED_USET_CLONE
#      define NEED_USET_FREEZE
#      define NEED_USET_SPAN
#    endif
#  endif
#endif

#ifdef NEED_USET_CLONE
USet* uset_cloneAsThawed(const USet* set);
USet* uset_clone(const USet* set);
#endif

#ifdef NEED_USET_FREEZE
void uset_freeze(USet* set);
UBool uset_isFrozen(const USet* set);
#endif

#ifdef NEED_USET_ALLCODEPOINTS
void uset_addAllCodePoints(USet* set,const UChar* str,int32_t strLen);
UBool uset_containsAllCodePoints(USet* set,const UChar* str,int32_t strLen);
#endif

#ifdef NEED_USET_SPAN
typedef enum USetSpanCondition {
  USET_SPAN_NOT_CONTAINED = 0,
  USET_SPAN_CONTAINED = 1,
  USET_SPAN_SIMPLE = 2,
  USET_SPAN_CONDITION_COUNT
} USetSpanCondition;

int32_t uset_span(const USet* set,const UChar* s,int32_t length,USetSpanCondition spanCondition);
int32_t uset_spanBack(const USet* set,const UChar* s,int32_t length,USetSpanCondition spanCondition);
#endif
