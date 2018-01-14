//
//  StringUtils.h
//  iXolr
//
//  Created by Bryan Boreham on 03/04/2015.
//
//

#ifndef iXolr_StringUtils_h
#define iXolr_StringUtils_h

@interface NSString (NSInteger)
+ (NSString*) fromNSInteger: (NSInteger)i;
+ (NSString*) fromNSUInteger: (NSUInteger)i;
@end

@interface NSDate (shortFormat)
- (NSString*) asStringWith:(NSString*)fmt;
@end

@interface NSData (utf8string)
- (NSString*) asUTF8String;
@end


#endif
