//
//  SignatureVC.m
//  iXolr
//
//  Created by Bryan Boreham on 30/11/2011.
//  Copyright (c) 2011-2018 Bryan Boreham. All rights reserved.
//

#import "SignatureVC.h"
#import "iXolrAppDelegate.h"

@implementation SignatureVC
@synthesize textView;

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.title = @"Signature";
    UIBarButtonItem * clearButton = [[UIBarButtonItem alloc] initWithTitle:@"Clear" style:UIBarButtonItemStylePlain target:self action:@selector(clearButtonPressed:)];
    self.navigationItem.rightBarButtonItem = clearButton;
    self.textView.text = [iXolrAppDelegate settings].signature;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [iXolrAppDelegate settings].signature = self.textView.text;
    [super viewWillDisappear: animated];
}

- (void)viewDidUnload
{
    [self setTextView:nil];
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
	return YES;
}


- (IBAction)clearButtonPressed:(id)sender {
    self.textView.text = @"";
}

@end
