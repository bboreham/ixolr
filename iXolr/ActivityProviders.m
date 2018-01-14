//
//  ActivityProviders.m
//  iXolr
//
//  Created by Bryan Boreham on 24/09/2012.
//
//

#import "ActivityProviders.h"

NSString *const CopyCixLinkActivityType = @"CopyCixLinkActivityType";


@implementation CopyCixLinkActivity

- (NSString *)activityType { return CopyCixLinkActivityType; }
- (NSString *)activityTitle { return @"Copy Link"; }
- (UIImage *)activityImage { return [UIImage imageNamed:@"Link.png"]; }

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems {
    for (id object in activityItems)
        if ([object isKindOfClass:[CIXMessage class]])
            return YES;
    return NO;
}

-(void)prepareWithActivityItems:(NSArray *)activityItems {
    message = nil;
    for (id object in activityItems)
        if ([object isKindOfClass:[CIXMessage class]]) {
            message = object;
            break;
        }
}

- (void)performActivity {
    if (message) {
        [UIPasteboard generalPasteboard].string = message.cixLink;
        [self activityDidFinish:YES];
    }
}


@end
