//
//  ActivityProviders.h
//  iXolr
//
//  Created by Bryan Boreham on 24/09/2012.
//
//

#import <UIKit/UIKit.h>
#import "Message.h"

extern NSString *const CopyCixLinkActivityType;

@interface CopyCixLinkActivity : UIActivity {
@private
    NSObject <GenericMessage> *message;
}
@end
