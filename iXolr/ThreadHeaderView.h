//
//  ThreadHeaderView.h
//  iXolr
//
//  Created by Bryan Boreham on 21/04/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ThreadHeaderViewDelegate;

@interface ThreadHeaderView : UIView

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *disclosureLabel;
@property (nonatomic, strong) UILabel *countsLabel;
@property (nonatomic, assign) BOOL isOpen;
@property (nonatomic, assign) NSInteger section;
@property (nonatomic, assign) NSInteger numMessages;
@property (nonatomic, assign) NSInteger numUnreadMessages;
@property (nonatomic, weak) id <ThreadHeaderViewDelegate> delegate;   // Note we do not retain the delegate to avoid cycles.

-(id)initWithFrame:(CGRect)frame title:(NSString*)title section:(NSInteger)sectionNumber open:(BOOL)open delegate:(id <ThreadHeaderViewDelegate>)delegate;
-(void)toggleOpenWithUserAction:(BOOL)userAction;
- (void)setNumMessages:(NSInteger)numMessages numUnread:(NSInteger)numUnreadMessages;
- (void) setFonts;
@end



/*
 Protocol to be adopted by the section header's delegate; the section header tells its delegate when the section should be opened and closed.
 */
@protocol ThreadHeaderViewDelegate <NSObject>

@optional
-(void)threadHeaderView:(ThreadHeaderView*)threadHeaderView sectionOpened:(NSInteger)section;
-(void)threadHeaderView:(ThreadHeaderView*)threadHeaderView sectionClosed:(NSInteger)section;
-(void)threadHeaderView:(ThreadHeaderView*)threadHeaderView longPress:(NSInteger)section;

@end

