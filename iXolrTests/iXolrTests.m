//
//  iXolrTests.m
//  iXolrTests
//
//  Created by Bryan Boreham on 29/04/2011.
//  Copyright 2011-2018 Bryan Boreham. All rights reserved.
//

#import "iXolrTests.h"
#import "DataController.h"
#import "Message.h"
#import "Topic.h"
#import "Conference.h"
#import "iXolrAppDelegate.h"
#import <UIKit/UIApplication.h>
#import "NSString+HTML.H"
#import "TableViewUtilities.h"

@implementation iXolrTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
    //dataController = [[DataController alloc] init];
    dataController = [iXolrAppDelegate singleton].dataController;

    // delete the existing store
    //NSURL *storeURL = [[myAppDelegate applicationDocumentsDirectory] URLByAppendingPathComponent:@"iXolr.sqlite"];
    //[[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil];
}

- (void)tearDown
{
    // Tear-down code here.
    //[dataController release];
    
    [super tearDown];
}


- (void)testScratchpadReading
{    
    //NSString *jsonfilename = @"/Users/Mary/code/iXolr/iXolrTests/TestScratchpad.txt";
    //NSData *jsondata = [NSData dataWithContentsOfFile:jsonfilename];
    //[dataController createMessagesFromJSONData: jsondata];
    
/*    char *scfilename = "/Users/Mary/code/iXolr/iXolr/scratchp.001";
    [dataController createScratchpadDataFromFile: scfilename];
    NSArray *conferences = [dataController fetchAllConferences];

    STAssertEquals([conferences count], 7U, @"Number of conferences");
    Conference *firstconf = [conferences objectAtIndex:0];
    STAssertEqualObjects(firstconf.name, @"diy", @"First conference name");
    STAssertEquals([firstconf.topics count], 2U, @"Number of topics in first conference"); */
    /*STAssertEquals([dataController countOfList], 284U, @"Number of messages");
    STAssertEqualObjects([[dataController objectInListAtIndex:0] author], @"aeskelson", @"First message author");
    STAssertEqualObjects([[dataController objectInListAtIndex:283] author], @"kdavisa", @"Last message author");

    STAssertEqualObjects([[dataController objectInListAtIndex:0] summary], @"Have a look for a hidden partition. It's fairly common for manaf. to put ", @"First message summary");*/
}

- (void)testFetchOrCreateTopics
{
    for (int index = 0; index < 200; ++index)
        [dataController findOrCreateConference:[NSString stringWithFormat:@"Conf%d", index] Topic:[NSString stringWithFormat:@"Topic%d", index]];
}

- (void)testFetchMessage
{
    int count = 0;
    NSArray * conferences = [[[iXolrAppDelegate singleton] dataController] fetchAllConferences];
    for (Conference *conf in conferences) {
        for (Topic *topic in conf.topics) {
            CIXMessage * message = [topic messageWithNumber:1000];
            if (message != nil)
                count ++;
        }
        if (count > 50)
            break;
    }
}


- (void)testArrayDifference
{
    NSString *a = @"a"; NSString *b = @"b"; NSString *c = @"c"; NSString *d = @"d"; NSString *e = @"e"; NSString *f = @"f"; 
    NSArray *old1 = [NSArray arrayWithObjects:a, b, c, nil];
    NSMutableArray *add, *del;
    NSIndexPath *path = nil;
    [old1 computeDifferenceTo:old1 returningAdded:&add andDeleted:&del inSection:0];
    STAssertTrue([add count] == 0, @"No difference");
    STAssertTrue([del count] == 0, @"No difference");
    NSArray *new2 = [NSArray arrayWithObjects:a, b, c, d, nil];
    [old1 computeDifferenceTo:new2 returningAdded:&add andDeleted:&del inSection:0];
    STAssertTrue([add count] == 1, @"One added");
    path = [add objectAtIndex:0];
    STAssertTrue(path.row == 3, @"Added at position 3");
    STAssertTrue([del count] == 0, @"No difference");
    NSArray *new3 = [NSArray arrayWithObjects:e, f, a, d, c, nil];
    [old1 computeDifferenceTo:new3 returningAdded:&add andDeleted:&del inSection:0];
    NSLog(@"added: %@; deleted: %@", add, del);
    STAssertTrue([add count] == 3, @"Threee added");
    path = [add objectAtIndex:0];
    STAssertTrue(path.row == 0, @"Added at position 0");
    path = [add objectAtIndex:1];
    STAssertTrue(path.row == 1, @"Added at position 1");
    path = [add objectAtIndex:2];
    STAssertTrue(path.row == 3, @"Added at position 3");
    STAssertTrue([del count] == 1, @"One deleted");
    NSArray *new4 = [NSArray arrayWithObjects:nil];
    [old1 computeDifferenceTo:new4 returningAdded:&add andDeleted:&del inSection:0];
    STAssertTrue([add count] == 0, @"No difference");
    STAssertTrue([del count] == 3, @"Three deleted");
    [new4 computeDifferenceTo:old1 returningAdded:&add andDeleted:&del inSection:0];
    STAssertTrue([add count] == 3, @"Threee added");
    STAssertTrue([del count] == 0, @"No difference");
    NSArray *new5 = [NSArray arrayWithObjects:d, a, b, c, nil];
    [old1 computeDifferenceTo:new5 returningAdded:&add andDeleted:&del inSection:0];
    STAssertTrue([add count] == 1, @"One added");
    path = [add objectAtIndex:0];
    STAssertTrue(path.row == 0, @"Added at position zero");
    STAssertTrue([del count] == 0, @"No difference");
    NSArray *new6 = [NSArray arrayWithObjects:a, b, c, d, e, f, nil];
    [old1 computeDifferenceTo:new6 returningAdded:&add andDeleted:&del inSection:0];
    STAssertTrue([add count] == 3, @"Three added");
    path = [add objectAtIndex:2];
    STAssertTrue(path.row == 5, @"Added at position 5");
    STAssertTrue([del count] == 0, @"No difference");
}


- (void)testHTMLstringing
{
    UIFont *testFont = [[UIFont fontWithName:@"helvetica" size:10] autorelease];
    NSString *msg1 = @"A CIX message with *shouting* and /italics/ and _underline_.";
    STAssertEqualObjects([msg1 stringByConvertingCIXMsgToHTMLwithReflow: NO lineBreakWidth: 60 font:nil inlineImages: NO], @"A CIX message with <b>shouting</b> and <i>italics</i> and <u>underline</u>.", @"CIX message 1");
        NSString *msg2 = @"A CIX message with *bold over a\nnewline*.";
    STAssertEqualObjects([msg2 stringByConvertingCIXMsgToHTMLwithReflow: NO lineBreakWidth: 60 font:nil inlineImages: NO], @"A CIX message with *bold over a<br>\nnewline*.", @"CIX message 2");
    NSString *msg3 = @"A CIX message with 2/3 of a fraction. ***";
    STAssertEqualObjects([msg3 stringByConvertingCIXMsgToHTMLwithReflow: NO lineBreakWidth: 60 font:nil inlineImages: NO], @"A CIX message with 2/3 of a fraction. ***", @"CIX message 3");
    NSString *msg4 = @"A URL: http://www.google.co.uk/something/else and then some";
    STAssertEqualObjects([msg4 stringByConvertingCIXMsgToHTMLwithReflow: NO lineBreakWidth: 60 font:nil inlineImages: NO], @"A URL: http://www.google.co.uk/something/else and then some", @"CIX message 4");
    NSString *msg5 = @"/One line/\n/And another/\n";
    STAssertEqualObjects([msg5 stringByConvertingCIXMsgToHTMLwithReflow: NO lineBreakWidth: 60 font:nil inlineImages: NO], @"<i>One line</i><br>\n<i>And another</i><br>\n", @"CIX message 5");
    NSString *msg6 = @"A long line with a story about the quick brown fox\nwho jumps over the lazy dog that is sitting on a fox and a bear";
    STAssertEqualObjects([msg6 stringByConvertingCIXMsgToHTMLwithReflow: YES lineBreakWidth: 320 font:testFont inlineImages: NO], @"A long line with a story about the quick brown fox who jumps over the lazy dog that is sitting on a fox and a bear", @"CIX message 6");
    NSString *msg7 = @"Quoting \n> A long line with a story about the quick brown fox who jumps over the lazy dog\nAfter Quoting";
    STAssertEqualObjects([msg7 stringByConvertingCIXMsgToHTMLwithReflow: YES lineBreakWidth: 320 font:testFont inlineImages: NO], @"Quoting <br>\n<font color='blue'>&gt; A long line with a story about the quick brown fox who jumps over the </font><br>\n<font color='blue'>&gt; lazy dog </font><br>\nAfter Quoting", @"CIX message 7");
    STAssertEqualObjects([msg7 stringByConvertingCIXMsgToHTMLwithReflow: NO lineBreakWidth: 60 font:nil inlineImages: NO], @"Quoting <br>\n<font color='blue'>&gt; A long line with a story about the quick brown fox who jumps over the lazy dog</font><br>\nAfter Quoting", @"CIX message 7b");
}

- (void)teststringReflow
{
    NSString *msg6 = @"A long line with a story about the quick brown fox\nwho jumps over the lazy dog that is sitting on a fox and a bear";
    STAssertEqualObjects([msg6 stringWithReflow], @"A long line with a story about the quick brown fox who jumps over the lazy dog that is sitting on a fox and a bear", @"CIX message 6");
    NSString *msg7 = @"Quoting \n> A long line with a story about the quick brown fox who jumps over the lazy dog\nAfter Quoting";
    STAssertEqualObjects([msg7 stringWithReflow], @"Quoting \n> A long line with a story about the quick brown fox who jumps over the lazy dog\nAfter Quoting", @"CIX message 7");
}

-(void)testMessageRange
{
    NSArray *vals = @[@1,@2,@3,@9,@5,@6,@7];
    NSString *str = [[iXolrAppDelegate singleton] performSelector:@selector(printableStringFromMessageNumbers:) withObject:vals];
    STAssertEqualObjects(str, @"1-3,5-7,9", @"printableStringFromMessageNumbers");
}

@end
