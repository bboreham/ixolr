//
//  CixRequest.m
//  OAuthWithCallback
//
//  Created by Bryan Boreham on 04/09/2011.
//

#import "CixRequest.h"
#import "OAMutableURLRequest.h"
#import "OAToken.h"
#import "StringUtils.h"

@implementation CixRequestManager
{
    NSOperationQueue *_queueForNetworkOps;
}

- (instancetype)init {
    self = [super init];
    _queueForNetworkOps = [[NSOperationQueue alloc] init];
    _queueForNetworkOps.maxConcurrentOperationCount = 1;
    return self;
}

- (void)addOperation:(NSOperation *)op {
    [_queueForNetworkOps addOperation:op];
}

- (void)addOperationWithBlock:(void (^)(void))block {
    [_queueForNetworkOps addOperationWithBlock:block];
}

// After a sequence of network ops, run some final things on the main thread to finish up
- (void)addOperationOnMainThread:(void (^)(void))action {
    [_queueForNetworkOps addOperationWithBlock:^{
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            action();
        }];
    }];
}

- (BOOL)hasQueuedOperationWithRequestStr: (NSString*)requestStr
{
    for (NSOperation* o in [_queueForNetworkOps operations]) {
        if ([o respondsToSelector:@selector(requestStr)]) {
            if ([requestStr isEqual:[o performSelector:@selector(requestStr)]])
                return YES;
        }
    }
    return NO;
}

- (void)cancelAllCIXOperations
{
    NSLog(@"Activity cancelled");
    // cancelAllOperations doesn't seem to work on mainQueue, so do it myself.
    for (NSOperation* o in [_queueForNetworkOps operations]) {
        if ([o respondsToSelector:@selector(iXolrCancel)]) {
            [o performSelector:@selector(iXolrCancel)];
        }
    }
}
@end

@implementation CixRequest
{
    NSHTTPURLResponse *httpResponse;
}

@synthesize delegate;
@synthesize continuation = _continuation;
@synthesize failureBlock = _failureBlock;
@synthesize postProgressNotifications = _postProgressNotifications;

#pragma mark -
#pragma mark Init/Dealloc

+ (id)requestWithDelegate:(id)del {
	CixRequest *request = [[CixRequest alloc] init];
	if (request != nil) {
		request.delegate = del;
	}
	return request;
}


#pragma mark -
#pragma mark Request Construction

/**
 * Create a signed Cix API request. 
 */
- (void)makeRequest: (NSString*)urlString params:(NSString*)params httpMethod: (NSString*)httpMethod body: (NSData*)body consumer:(OAConsumer*)consumer auth:(NSString*)authorizationStr timeout: (NSTimeInterval)timeoutSecs {
	if (authorizationStr == nil) {
        [self unConnectedDidFailWithError:[NSError errorWithDomain:@"This app has not been allowed access to Cix yet." code:401 userInfo:nil]];
		return;
	}
    
    taskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{   // Tell IOS we want this to finish
        NSLog(@"expiration of BackgroundTask %lu", (unsigned long)self->taskIdentifier);
        [[UIApplication sharedApplication] endBackgroundTask:self->taskIdentifier];
        self->taskIdentifier = UIBackgroundTaskInvalid;
    }];
    
	OAToken *token = [[OAToken alloc] initWithHTTPResponseBody:authorizationStr];
	OAMutableURLRequest *request = [[OAMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlString] consumer:consumer token:token realm:nil signatureProvider:nil];
	[request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
	[request setTimeoutInterval:timeoutSecs];
	
	[request setHTTPMethod:httpMethod];
    @try {
        [request prepare];
    } @catch (NSException *exception) {
        NSString *msg = [NSString stringWithFormat:@"Exception preparing request: %@", exception.reason];
        NSLog(@"%@ %@", msg, [exception callStackSymbols]);
        [self unConnectedDidFailWithError:[NSError errorWithDomain:msg code:501 userInfo:nil]];
        return;
    }
    // Need to set body after 'prepare' to avoid crash in OAuth lib
	if (body) {
		[request setHTTPBody:body];
        [request setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
	}
    if (params)
    {
        NSString *oldURL = [[request URL] absoluteString];
        NSString *encodedParams = [params stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        [request setURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@&%@", oldURL, encodedParams]]];
    }
    
    NSLog(@"Sending request: %@", [request URL]);
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

    NSURLSessionDataTask *dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData * newData, NSURLResponse * response, NSError * error) {
        if (error != nil) {
            self->dataTask = nil;
            [self unConnectedDidFailWithError:error];
            return;
        }
        if (response == nil) {
            NSLog(@"Nil response from request");
            return;
        }
        if (newData == nil) {
            NSLog(@"Nil data from request");
            return;
        }
        //NSLog(@"Data received: %@", [newData asUTF8String]);
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        // Callback comes on background thread; jump back to main thread to update UI etc.
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if ((httpResponse.statusCode / 100) != 2) {
                NSString *responseString = newData == nil ? nil : [newData asUTF8String];
                NSLog(@"HTTP error %zd: %@", (ssize_t) httpResponse.statusCode, responseString);
                [self unConnectedDidFailWithError:[NSError errorWithDomain:responseString code:httpResponse.statusCode userInfo:nil]];
                return;
            }
            if (self.delegate && [self.delegate respondsToSelector:@selector(cixRequest:finishedLoadingData:)]) {
                [self.delegate performSelector:@selector(cixRequest:finishedLoadingData:) withObject:self withObject:newData];
            }
            [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
            [[UIApplication sharedApplication] endBackgroundTask:self->taskIdentifier];
        }];
    }];
    if (@available(iOS 15.0, *)) {
        //dataTask.delegate = self;
    }
    [dataTask resume];
}

NSTimeInterval standardTimeout(void)
{
    NSInteger timeoutSecs = 120;
    NSNumber *timeoutNum = [((NSObject*)UIApplication.sharedApplication.delegate) valueForKey:@"timeoutSecs"];
    if (timeoutNum != nil)
        timeoutSecs = [timeoutNum integerValue];
    return timeoutSecs;
}

char *urlRoot = "https://api.cixonline.com/v2.0/cix.svc";
//char *urlRoot = "http://betaapi.cixonline.com/v1.0/cix.svc";

- (BOOL)makeGenericRequest: (NSString*)request consumer:(OAConsumer*)consumer auth:(NSString*)authStr
{
    NSCharacterSet *disallowedChars = [NSCharacterSet characterSetWithCharactersInString:@"&"];
    NSRange range = [request rangeOfCharacterFromSet:disallowedChars];
    NSRange range2 = [request rangeOfString:@"./"];
    if (range.location != NSNotFound || range2.location != NSNotFound) {  // Return straightaway if any disallowed characters found
        NSLog(@"CIXrequest makeGenericRequest: disallowed characters in '%@' - request ignored", request);
        return NO;
    }
    NSString *encodedRequest = [request stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"%s/%@.json", urlRoot, encodedRequest];
    [self makeRequest: urlString params:nil httpMethod:@"GET" body:nil consumer:consumer auth:authStr timeout:standardTimeout()];
    return YES;
}

- (BOOL)makeGenericRequest: (NSString*)request params:(NSString*)params consumer:(OAConsumer*)consumer auth:(NSString*)authStr
{
    NSString *urlString = [NSString stringWithFormat:@"%s/%@.json", urlRoot, request];
    [self makeRequest: urlString params:params httpMethod:@"GET" body:nil consumer:consumer auth:authStr timeout:standardTimeout()];
    return YES;
}

- (void)makeGenericPostRequest:(NSString*)request body:(NSData*)body consumer:(OAConsumer*)consumer auth:(NSString*)authStr
{
    NSString *urlString = [NSString stringWithFormat:@"%s/%@.json", urlRoot, request];
    [self makeRequest: urlString params:nil httpMethod:@"POST" body:body consumer:consumer auth:authStr timeout:standardTimeout()];
}

#pragma mark -
#pragma mark HTTP

- (void)cancel {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	self.delegate = nil;
	if (dataTask) {
        NSLog(@"CIXRequest operation cancelled (background task %lu)", (unsigned long)taskIdentifier);
        [[UIApplication sharedApplication] endBackgroundTask:taskIdentifier];
		[dataTask cancel];
	}
}

#pragma mark -
#pragma mark NSURLSessionDataDelegate methods

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    httpResponse = (NSHTTPURLResponse*)response;
    self->contentSize = [httpResponse expectedContentLength];
    if (self.postProgressNotifications)
        [[NSNotificationCenter defaultCenter] postNotificationName:@"refreshProgress" object:nil];
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)newData {
    NSLog(@"Data received: %lu bytes", (unsigned long)[newData length]);
    bytesReceived += [newData length];
    if (self.postProgressNotifications) {
        float progress = (float)bytesReceived / (float)contentSize * 0.5;  // Multiply by 0.5 so that network download is half of progress; parsing is second half
        [[NSNotificationCenter defaultCenter] postNotificationName:@"refreshProgress" object:@(progress)];
    }
}

- (void)unConnectedDidFailWithError:(NSError*)error {
    NSLog(@"%@", [error localizedDescription]);
    if (self.delegate && [self.delegate respondsToSelector:@selector(cixRequest:failedWithError:)]) {
        [self.delegate performSelector:@selector(cixRequest:failedWithError:) withObject:self withObject:error];
    }
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [[UIApplication sharedApplication] endBackgroundTask:taskIdentifier];
}

@end


@implementation CixRequestOperation {
@private
    OAConsumer* _consumer;
    NSString* _requestStr, *_authStr, *_params;
    StartedBlock _startedBlock;
    RequestContinuation _successBlock;
    FailureBlock _failureBlock;
    CixRequest *_request;
    BOOL _finished, _inProgress;
}

@synthesize requestStr=_requestStr;
@synthesize body=_body;
@synthesize startedBlock=_startedBlock;
@synthesize successBlock=_successBlock;
@synthesize failureBlock=_failureBlock;
@synthesize postProgressNotifications=_postProgressNotifications;

+ (id)operationWithRequest: (NSString*)requestStr params:(NSString*)params consumer:(OAConsumer*)consumer auth:(NSString*)authStr successBlock:(RequestContinuation)successBlock
{
    return [[CixRequestOperation alloc] initWithRequest:requestStr params:params consumer:consumer auth:authStr successBlock:successBlock];
}

- (id)initWithRequest: (NSString*)requestStr params:(NSString*)params consumer:(OAConsumer*)consumer auth:(NSString*)authStr successBlock:(RequestContinuation)successBlock {
    if (self = [super init]) {
        _successBlock = [successBlock copy];
        _consumer = consumer;
        _requestStr = requestStr;
        _authStr = authStr;
        _params = params;
    }
    return self;
}

- (id)initWithRequest: (NSString*)requestStr consumer:(OAConsumer*)consumer auth:(NSString*)authStr successBlock:(RequestContinuation)successBlock {
    return [self initWithRequest:requestStr params:nil consumer:consumer auth:authStr successBlock:successBlock];
}


- (BOOL)isConcurrent
{
    return YES;
}

- (BOOL)isFinished 
{
	return _finished;
}

- (BOOL)isExecuting {
	return _inProgress;
}


-(void)start {
	if (![self isCancelled])
	{
        _inProgress = YES;
        // Kick off on main queue.  Means all callbacks come on main thread too.
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        if (self->_startedBlock != nil)
            self->_startedBlock(self);
        self->_request = [CixRequest requestWithDelegate:self];
        self->_request.postProgressNotifications = self.postProgressNotifications;
        if (self->_body != nil)
            [self->_request makeGenericPostRequest:self->_requestStr body:self->_body consumer:self->_consumer auth:self->_authStr];
        else
            [self->_request makeGenericRequest:self->_requestStr params:self->_params consumer:self->_consumer auth:self->_authStr];
        }];
    }
    else {
        [self markAsFinished];
    }
}

- (void)cancel
{
    if (_inProgress) {
        [_request cancel];
        [self markAsFinished];
    }
    [super cancel];
}

- (void) iXolrCancel {
    [self cancel];
}

- (void)markAsFinished
{
    BOOL wasInProgress = _inProgress;
    BOOL wasFinished = _finished;

    if (!wasFinished)
    [self willChangeValueForKey:@"isFinished"];
    if (wasInProgress)
    [self willChangeValueForKey:@"isExecuting"];

    _inProgress = NO;
    _finished = YES;

    if (wasInProgress)
        [self didChangeValueForKey:@"isExecuting"];
    if (!wasFinished)
        [self didChangeValueForKey:@"isFinished"];
}

- (void)cixRequest:(CixRequest*)request finishedLoadingData:(NSData*)data
{
    if (![self isCancelled] && _successBlock != nil)
        _successBlock(data);
    [self markAsFinished];
}

- (void)cixRequest:(CixRequest*)request failedWithError:(NSError*)error
{
    if (![self isCancelled] && _failureBlock != nil)
        _failureBlock(error);
    [self markAsFinished];
}

@end
