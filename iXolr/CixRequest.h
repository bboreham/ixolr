//
//  CixRequest.h
//  OAuthWithCallback
//
//  Created by Bryan Boreham on 04/09/2011.
//

#import <Foundation/Foundation.h>

@interface CixRequestManager : NSObject
- (void)addOperation:(NSOperation *)op;
- (void)addOperationOnMainThread:(void (^)(void))action;
- (void)addOperationWithBlock:(void (^)(void))block;
- (void)cancelAllCIXOperations;
- (BOOL)hasQueuedOperationWithRequestStr: (NSString*)requestStr;
@end

@protocol CixRequestDelegate;

@class OAConsumer;

typedef void (^RequestContinuation)(NSData*);
typedef void (^FailureBlock)(NSError*);

@interface CixRequest : NSObject<NSURLConnectionDataDelegate> {
@private
    NSURLConnection	*connection;
    long long contentSize;
	NSMutableData	*data;
	NSObject<CixRequestDelegate> *delegate;
    UIBackgroundTaskIdentifier  taskIdentifier; // To tell IOS we have completed this operation
}

@property(nonatomic,strong) NSObject<CixRequestDelegate> * delegate;
@property(nonatomic,copy) RequestContinuation continuation;
@property(nonatomic,copy) FailureBlock failureBlock;
@property(nonatomic,assign) BOOL postProgressNotifications;  // If YES then post notifications as data comes in

+ (id)requestWithDelegate:(id)del;
- (BOOL)makeGenericRequest: (NSString*)request consumer:(OAConsumer*)consumer auth:(NSString*)authStr;
- (BOOL)makeGenericRequest: (NSString*)request params:(NSString*)params consumer:(OAConsumer*)consumer auth:(NSString*)authStr;
- (void)makeGenericPostRequest:(NSString*)request body:(NSData*)body consumer:(OAConsumer*)consumer auth:(NSString*)authStr;

/**
 * Cancels the current request.
 */
- (void)cancel;
@end

/**
 * Delegates must implement the routines below to handle success or failure.
 */
@protocol CixRequestDelegate 

@required
- (void)cixRequest:(CixRequest*)request finishedLoadingData:(NSData*)data;
- (void)cixRequest:(CixRequest*)request failedWithError:(NSError*)error;
@end

@class CixRequestOperation;
typedef void (^StartedBlock)(CixRequestOperation*);

@interface CixRequestOperation : NSOperation <CixRequestDelegate>

+ (id)operationWithRequest: (NSString*)requestStr params:(NSString*)params consumer:(OAConsumer*)consumer auth:(NSString*)authStr successBlock:(RequestContinuation)successBlock;
- (id)initWithRequest: (NSString*)requestUrl consumer:(OAConsumer*)consumer auth:(NSString*)authStr successBlock:(RequestContinuation)successBlock;
- (id)initWithRequest: (NSString*)requestUrl params:(NSString*)params consumer:(OAConsumer*)consumer auth:(NSString*)authStr successBlock:(RequestContinuation)successBlock;

@property (nonatomic, copy) NSData* body;
@property (nonatomic, copy) NSString* requestStr;
@property (nonatomic, copy) StartedBlock startedBlock;
@property (nonatomic, copy) RequestContinuation successBlock;
@property (nonatomic, copy) FailureBlock failureBlock;
@property (nonatomic, assign) BOOL postProgressNotifications;  // If YES then post notifications as data comes in

@end
