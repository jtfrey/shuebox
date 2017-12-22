
#import "SBFoundation.h"
#import "SBObjectCache.h"
#import "SBPostgres.h"
#import "SHUEBoxCollaboration.h"

int
main()
{
  SBAutoreleasePool*      pool = [[SBAutoreleasePool alloc] init];
  SBPostgresDatabase*     shueboxDB = [[SBPostgresDatabase alloc] initWithConnectionString:@"user=postgres dbname=shuebox"];
  
  SHUEBoxCollaboration*   c = [SHUEBoxCollaboration collaborationWithDatabase:shueboxDB shortName:@"cisc275"];
  
  if ( c ) {
    SBArray*              r = [c repositories];
    
    int count = 0;
    
    while ( count++ < 1000 ) {
      [pool release];
      pool = [[SBAutoreleasePool alloc] init];
      
      [c reloadRepositories];
      if ( (r = [c repositories]) ) {
        SBUInteger    i = 0, iMax = [r count];
        
        while ( i < iMax ) {
          [[[r objectAtIndex:i++] shortName] utf8Characters];
        }
      }
    }
  }
  
  [shueboxDB release];
  
  [pool release];
  
  return 0;
}
