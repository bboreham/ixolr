//
//  LoginViewController.m
//  iXolr
//
//  Created by Bryan Boreham on 31/12/2014.
//
//

#import "LoginViewController.h"
#import "OAMutableURLRequest.h"
#import "OARequestParameter.h"
#import "OAAsynchronousDataFetcher.h"
#import "OAServiceTicket.h"
#import "OAConsumer.h"
#import "iXolrAppDelegate.h"
#import "StringUtils.h"

@implementation LoginViewController
{
    OAToken		*_requestToken;
    UINavigationController *_saveNC;
}


#pragma mark - OAuth

/**
 * Step 1: Reuqest a request token.
 */
- (void)requestRequestToken: (UINavigationController*)nc {
    _saveNC = nc;
    OAMutableURLRequest *request = [[OAMutableURLRequest alloc] initWithURL:
                                    [NSURL URLWithString:@"https://api.cixonline.com/v2.0/cix.svc/getrequesttoken"]
                                                                   consumer:[iXolrAppDelegate singleton].consumer
                                                                      token:nil					// we don't have a token yet
                                                                      realm:nil					// our service provider doesn't specify a realm
                                                          signatureProvider:nil]; 	// use the default method, HMAC-SHA1
    OAAsynchronousDataFetcher *dataFetcher = [OAAsynchronousDataFetcher asynchronousFetcherWithRequest:request delegate:self didFinishSelector:@selector(setRequestToken:withData:) didFailSelector:@selector(serviceTicket:didFailWithError:)];
    [dataFetcher start];
}

/**
 * Once a request token has been obtained, store it and
 * tell the delegate it can load the authorization webpage.
 */
- (void)setRequestToken:(OAServiceTicket *)ticket withData:(NSData *)data {
    NSString *dataString = [data asUTF8String];
    NSLog(@"Response %ld: %@", (long)[((NSHTTPURLResponse*)ticket.response) statusCode], dataString);
    if (!ticket.didSucceed || !data) {
        [self serviceTicket:nil didFailWithError:[NSError errorWithDomain:
                                                  NSLocalizedString(@"CIX rejected the authentication.", @"Failed to start authentication")
                                                                     code:0 userInfo:nil]];
        return;
    }
    
    if (!dataString) {
        [self serviceTicket:nil didFailWithError:[NSError errorWithDomain:
                                                  NSLocalizedString(@"CIX rejected the authentication.", @"Failed to start authentication")
                                                                     code:0 userInfo:nil]];
        return;
    }
    
    _requestToken = [[OAToken alloc] initWithHTTPResponseBody:dataString];
    
    [_saveNC pushViewController:self animated:YES];
    [self.view layoutIfNeeded];
    [self startAuthorization:[self authorizeURLRequest]];
}

- (void)setRequestToken:(NSString*)dataString
{
    _requestToken = [[OAToken alloc] initWithHTTPResponseBody:dataString];
}

/**
 * This generates a URL request that can be passed to a UIWebView.
 * It will open a page in which the user must enter their credentials
 */
- (NSURLRequest*)authorizeURLRequest {
    OAMutableURLRequest *request = [[OAMutableURLRequest alloc] initWithURL:
                                     [NSURL URLWithString: @"https://forums.cix.co.uk/secure/authapp.aspx"]
                                     consumer:nil
                                     token:_requestToken
                                     realm:nil
                                     signatureProvider:nil];
    NSMutableArray *requestParameters = [NSMutableArray arrayWithCapacity:3];
    [requestParameters addObject:[[OARequestParameter alloc] initWithName:@"oauth_token" value:_requestToken.key]];
    [requestParameters addObject:[[OARequestParameter alloc] initWithName:@"oauth_callback" value:@"x-com-ixolr-oauth://success"]];
    [request setParameters:requestParameters];
    return request;
}

- (void)requestAccessToken
{
    OAMutableURLRequest *request = [[OAMutableURLRequest alloc] initWithURL:
                                    [NSURL URLWithString:@"https://api.cixonline.com/v2.0/cix.svc/getaccesstoken"]
                                    consumer:[iXolrAppDelegate singleton].consumer
                                    token:_requestToken
                                    realm:nil					// our service provider doesn't specify a realm
                                    signatureProvider:nil]; 	// use the default method, HMAC-SHA1
    OAAsynchronousDataFetcher *dataFetcher = [OAAsynchronousDataFetcher asynchronousFetcherWithRequest:request delegate:self didFinishSelector:@selector(setAccessToken:withData:) didFailSelector:@selector(serviceTicket:didFailWithError:)];
    [dataFetcher start];
}

/**
 * The access token has been obtained. Store it and use it for making API calls.
 */
- (void)setAccessToken:(OAServiceTicket*)ticket withData:(NSData*)data {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    if (ticket.didSucceed && data != nil) {
        NSString *dataString = [data asUTF8String];
        NSLog(@"Response %ld: %@", (long)[((NSHTTPURLResponse*)ticket.response) statusCode], dataString);
        if (dataString) {
            [[iXolrAppDelegate singleton] receiveAccessToken: dataString];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"loginStatus" object:nil];
            NSLog(@"Authorized");
            [self.navigationController popViewControllerAnimated:YES];
            return;
        }
    }
    
    [self serviceTicket:nil didFailWithError:[NSError errorWithDomain:
                                              NSLocalizedString(@"CIX rejected the authentication.", @"Failed to start authentication")
                                                                 code:0 userInfo:nil]];
}

- (void)serviceTicket:(OAServiceTicket*)ticket didFailWithError:(NSError*)err {
    NSLog(@"Authorization failed: %@", [err localizedDescription]);
    NSLog(@"Authorization failed detail: %@", [err userInfo]);
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"loginStatus" object:err];
}

/**
 * Request token is in. Let user enter credentials in webpage.
 */
- (void)startAuthorization:(NSURLRequest*)request {
    NSLog(@"Opening: %@", [request URL]);
    [self.webView loadRequest:request];
}

// Check what is happening in the webview
- (BOOL)webView:(UIWebView*)wv shouldStartLoadWithRequest:(NSURLRequest*)request navigationType:(UIWebViewNavigationType)navigationType {
    
    BOOL    response = YES;
    NSURL 	*requestURL = [request URL];
    
    NSLog(@"Login webview URL: %@", [requestURL description]);
    if ([[requestURL host] isEqualToString:@"success"]) {
        [self performSelector:@selector(requestAccessToken) withObject:[requestURL absoluteString] afterDelay:0.1];
        return NO;
    }
    
    switch (navigationType) {
        case UIWebViewNavigationTypeLinkClicked:
            [[UIApplication sharedApplication] openURL:[request URL]];
            response = NO;
            break;
        case UIWebViewNavigationTypeFormSubmitted:
            NSLog(@"Authenticating...");
            break;
        case UIWebViewNavigationTypeBackForward:
            response = NO;
            break;
        case UIWebViewNavigationTypeReload:
            break;
        case UIWebViewNavigationTypeFormResubmitted:
            break;
        case UIWebViewNavigationTypeOther:
            break;
        default:
            break;
    }
    return response;
}

- (void)webView:(UIWebView*)wv didFailLoadWithError:(NSError*)error {
    NSLog(@"%@", [error localizedDescription]);
}
@end
