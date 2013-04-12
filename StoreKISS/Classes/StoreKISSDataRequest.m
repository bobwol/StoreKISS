//
//  StoreKISSDataRequest.m
//  StoreKISS
//
//  Created by Misha Karpenko on 5/24/12.
//  Copyright (c) 2012 Redigion. All rights reserved.
//


#import "StoreKISSDataRequest.h"


NSString * const StoreKISSNotificationDataRequestStarted =
    @"com.redigion.storekiss.notification.dataRequest.started";
NSString * const StoreKISSNotificationDataRequestSuccess =
    @"com.redigion.storekiss.notification.dataRequest.success";
NSString * const StoreKISSNotificationDataRequestFailure =
    @"com.redigion.storekiss.notification.dataRequest.failure";


@interface StoreKISSDataRequest ()

@property (strong, nonatomic) id strongSelf;

@property (assign, nonatomic) StoreKISSDataRequestStatus status;
@property (strong, nonatomic) SKProductsRequest *skRequest;
@property (strong, nonatomic) SKProductsResponse *skResponse;
@property (strong, nonatomic) NSSet *productIds;
@property (strong, nonatomic) NSError *error;

@property (copy, nonatomic) StoreKISSDataRequestSuccessBlock success;
@property (copy, nonatomic) StoreKISSDataRequestFailureBlock failure;

@end


@implementation StoreKISSDataRequest

@synthesize reachability = _reachability;


- (id)init
{
	if ((self = [super init]))
    {
		self.status = StoreKISSDataRequestStatusNew;
	}
	return self;
}


- (void)dealloc
{
    if (self.skRequest != nil)
    {
        self.skRequest.delegate = nil;
    }
}


// ------------------------------------------------------------------------------------------
#pragma mark - Getters Overwriting
// ------------------------------------------------------------------------------------------
- (id<StoreKISSReachabilityProtocol>)reachability
{
    NSAssert(_reachability != nil, @"Reachability wrapper must be provided!");
    return _reachability;
}


// ------------------------------------------------------------------------------------------
#pragma mark - Requesting Data
// ------------------------------------------------------------------------------------------
- (void)requestDataForItemWithProductId:(NSString *)productId
								success:(StoreKISSDataRequestSuccessBlock)success
								failure:(StoreKISSDataRequestFailureBlock)failure
{
	[self requestDataForItemsWithProductIds:[NSSet setWithObject:productId]
                                    success:success
                                    failure:failure];
}


- (void)requestDataForItemsWithProductIds:(NSSet *)productIds
								  success:(StoreKISSDataRequestSuccessBlock)success
								  failure:(StoreKISSDataRequestFailureBlock)failure
{
    NSAssert([self isExecuting] == NO, @"Data request is executing already.");
	
	self.success = success;
	self.failure = failure;
	
	if ([self.reachability hasReachableInternetConnection] == NO)
    {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: NSLocalizedString(@"No internet connection.", @"")};
		self.error = [NSError errorWithDomain:StoreKISSErrorDomain
                                         code:StoreKISSErrorNoInternetConnection
                                     userInfo:userInfo];
		[self finish];
		return;
	}
	
    self.productIds = productIds;
	self.skRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:self.productIds];
	self.skRequest.delegate = self;
	
	[self start];
}


- (void)requestDataForItemWithProductId:(NSString *)productId
{
	[self requestDataForItemWithProductId:productId
                                  success:nil
                                  failure:nil];
}


- (void)requestDataForItemsWithProductIds:(NSSet *)productIds
{
	[self requestDataForItemsWithProductIds:productIds
                                    success:nil
                                    failure:nil];
}


// ------------------------------------------------------------------------------------------
#pragma mark - Execution Management
// ------------------------------------------------------------------------------------------
- (void)start
{
    self.strongSelf = self;
    
	[self.skRequest start];
    
	self.status = StoreKISSDataRequestStatusStarted;
	[[NSNotificationCenter defaultCenter] postNotificationName:StoreKISSNotificationDataRequestStarted
                                                        object:self];
}


- (void)finish
{
	self.status = StoreKISSDataRequestStatusFinished;
	
	if (self.error != nil)
    {
        NSDictionary *userInfo = @{StoreKISSNotificationDataRequestErrorKey: self.error};
		[[NSNotificationCenter defaultCenter] postNotificationName:StoreKISSNotificationDataRequestFailure
                                                            object:self
                                                          userInfo:userInfo];
		if (self.failure)
        {
			self.failure(self.error);
		}
	}
    else
    {
        NSDictionary *userInfo = @{StoreKISSNotificationDataRequestResponseKey: self.skResponse};
		[[NSNotificationCenter defaultCenter] postNotificationName:StoreKISSNotificationDataRequestSuccess
                                                            object:self
                                                          userInfo:userInfo];
		if (self.success)
        {
			self.success(self);
		}
	}
    
    self.skRequest.delegate = nil;
    self.strongSelf = nil;
}


- (BOOL)isExecuting
{
	return self.status == StoreKISSDataRequestStatusStarted;
}


// ------------------------------------------------------------------------------------------
#pragma mark - SKProductsRequestDelegate
// ------------------------------------------------------------------------------------------
- (void)productsRequest:(SKProductsRequest *)request
	 didReceiveResponse:(SKProductsResponse *)receivedResponse
{
	self.skResponse = receivedResponse;
}


// ------------------------------------------------------------------------------------------
#pragma mark - SKRequestDelegate
// ------------------------------------------------------------------------------------------
- (void)requestDidFinish:(SKRequest *)request
{
    [self finish];
}


- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
    self.error = error;
    [self finish];
}


@end
