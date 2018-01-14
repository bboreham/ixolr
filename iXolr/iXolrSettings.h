//
//  iXolrSettings.h
//  iXolr
//
//  Created by Bryan Boreham on 12/11/2014.
//
//

#import <Foundation/Foundation.h>

@interface iXolrSettings : NSObject

- (void)restoreState;
- (void)saveState;

@property (nonatomic) NSInteger refreshSecs;
@property (nonatomic) BOOL squishRows;
@property (nonatomic) BOOL autoSync;
@property (nonatomic) BOOL autoUpload;
@property (nonatomic) BOOL reflowText;
@property (nonatomic) BOOL inlineImages;
@property (nonatomic) BOOL myMessagesVisible;
@property (nonatomic) BOOL threadsDefaultOpen;
@property (nonatomic) BOOL threadHeadersVisible;
@property (nonatomic) BOOL showMessageToolbar;
@property (nonatomic) BOOL animationsOn;    // YES if we should do animations when adding messages, etc.
@property (nonatomic) BOOL outboxAlert;
@property (nonatomic) float outboxAlertMinutesDelay;
@property (nonatomic) float messageFontSize;
@property (nonatomic,strong) NSString *signature;
@property (nonatomic) NSInteger markReadDays;
@property (nonatomic) NSInteger timeoutSecs;
@property (nonatomic) BOOL useDynamicType;
@property (nonatomic) BOOL uploadReadStatus;
@property (nonatomic) BOOL uploadStars;
@property (nonatomic) BOOL myMessagesAutoread; // YES if new messages from me are marked read

@end
