//
//  StoreKISSPaymentRequest.m
//  StoreKISS
//
//  Created by Misha Karpenko on 5/28/12.
//  Copyright (c) 2012 Redigion. All rights reserved.
//


#import "StoreKISSPaymentRequest.h"


NSString * const StoreKISSNotificationPaymentRequestStarted =
    @"com.redigion.storekiss.notification.paymentRequest.started";
NSString * const StoreKISSNotificationPaymentRequestSuccess =
    @"com.redigion.storekiss.notification.paymentRequest.success";
NSString * const StoreKISSNotificationPaymentRequestPurchasing =
    @"com.redigion.storekiss.notification.paymentRequest.purchasing";
NSString * const StoreKISSNotificationPaymentRequestFailure =
    @"com.redigion.storekiss.notification.PaymentRequest.failure";
NSString * const StoreKISSNotificationPaymentRequestTransactionRemoved =
    @"com.redigion.storekiss.notification.PaymentRequest.transaction_removed";


@interface StoreKISSPaymentRequest ()

@property (strong, nonatomic) id strongSelf;

@property (assign, nonatomic) StoreKISSPaymentRequestStatus status;
@property (strong, nonatomic) SKPayment *skPayment;
@property (strong, nonatomic) NSArray *skTransactions;
@property (strong, nonatomic) SKPaymentTransaction *skTransaction;
@property (strong, nonatomic) NSError *error;

@property (copy, nonatomic) StoreKISSPaymentRequestSuccessBlock success;
@property (copy, nonatomic) StoreKISSPaymentRequestFailureBlock failure;

@end


@implementation StoreKISSPaymentRequest

@synthesize reachability = _reachability;


- (id)init
{
	if ((self = [super init]))
    {
		self.status = StoreKISSPaymentRequestStatusNew;
	}
	return self;
}


- (void)dealloc
{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
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
#pragma mark - Checking payment possibility
// ------------------------------------------------------------------------------------------
- (BOOL)canMakePayments
{
	return [SKPaymentQueue canMakePayments];
}


- (void)checkIfCanMakePayments
{
    if ([self canMakePayments] == NO)
    {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: NSLocalizedString(@"In-App Purchasing is disabled.", nil)};
		self.error = [NSError errorWithDomain:StoreKISSErrorDomain
                                         code:StoreKISSErrorIAPDisabled
                                     userInfo:userInfo];
	}
}


- (void)checkIfHasReachableInternetConnection
{
    if ([self.reachability hasReachableInternetConnection] == NO)
    {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: NSLocalizedString(@"No internet connection.", nil)};
		self.error = [NSError errorWithDomain:StoreKISSErrorDomain
                                         code:StoreKISSErrorNoInternetConnection
                                     userInfo:userInfo];
	}
}


- (void)checkIfValidSKProduct:(SKProduct *)skProduct
{
    if (skProduct == nil)
    {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: NSLocalizedString(@"SKProduct should not be nil.", nil)};
		self.error = [NSError errorWithDomain:StoreKISSErrorDomain
                                         code:StoreKISSErrorInvalidSKProduct
                                     userInfo:userInfo];
	}
}


// ------------------------------------------------------------------------------------------
#pragma mark - Making payment
// ------------------------------------------------------------------------------------------
- (void)makePaymentWithSKProduct:(SKProduct *)skProduct
						 success:(StoreKISSPaymentRequestSuccessBlock)success
						 failure:(StoreKISSPaymentRequestFailureBlock)failure
{
	if ([self isExecuting])
    {
		return;
	}
    
    self.success = success;
	self.failure = failure;
	
	[self checkIfCanMakePayments];
    [self checkIfHasReachableInternetConnection];
    [self checkIfValidSKProduct:skProduct];
    
    if (self.error)
    {
        [self finish];
        return;
    }

	self.skPayment = [SKPayment paymentWithProduct:skProduct];
	
	[self start];
}


- (void)makePaymentWithSKProduct:(SKProduct *)skProduct
{
	[self makePaymentWithSKProduct:skProduct success:nil failure:nil];
}


// ------------------------------------------------------------------------------------------
#pragma mark - Restoring payments
// ------------------------------------------------------------------------------------------
- (void)restorePaymentsWithSuccess:(StoreKISSPaymentRequestSuccessBlock)success
                           failure:(StoreKISSPaymentRequestFailureBlock)failure
{
    if ([self isExecuting])
    {
		return;
	}
    
    self.success = success;
	self.failure = failure;
    
    [self checkIfCanMakePayments];
    [self checkIfHasReachableInternetConnection];
    
    if (self.error)
    {
        [self finish];
        return;
    }
    
    [self startPaymentsRestoring];
}


- (void)restorePayments
{
    [self restorePaymentsWithSuccess:nil failure:nil];
}


// ------------------------------------------------------------------------------------------
#pragma mark - Execution control
// ------------------------------------------------------------------------------------------
- (void)start
{
    self.strongSelf = self;

    self.status = StoreKISSPaymentRequestStatusStarted;
	[[NSNotificationCenter defaultCenter] postNotificationName:StoreKISSNotificationPaymentRequestStarted
                                                        object:self];
    
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
	[[SKPaymentQueue defaultQueue] addPayment:self.skPayment];
}


- (void)startPaymentsRestoring
{
    self.strongSelf = self;
    
    self.status = StoreKISSPaymentRequestStatusStarted;
    [[NSNotificationCenter defaultCenter] postNotificationName:StoreKISSNotificationPaymentRequestStarted
                                                        object:self];
    
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}


- (void)finish
{
	self.status = StoreKISSPaymentRequestStatusFinished;
    
    if (self.error != nil)
    {
        if (self.failure != nil)
        {
            self.failure(self.error);
        }
    }
    else
    {
        if (self.success != nil)
        {
            self.success(self);
        }
    }
    
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    self.strongSelf = nil;
}


- (BOOL)isExecuting
{
	return self.status == StoreKISSPaymentRequestStatusStarted;
}


- (BOOL)isFinished
{
    return self.status == StoreKISSPaymentRequestStatusFinished;
}


// ------------------------------------------------------------------------------------------
#pragma mark - SKPaymentTransactionObserver
// ------------------------------------------------------------------------------------------
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions 
{
    self.skTransactions = transactions;
    
    BOOL allTransactionsOnTheQueueAreFinished = YES;
    
    for (SKPaymentTransaction *skTransaction in self.skTransactions)
    {
        // Search for skPayment if needed
        if (self.skPayment != nil)
        {
            if ([skTransaction.payment isEqual:self.skPayment])
            {
                self.skTransaction = skTransaction;
            }
        }
        
        switch (skTransaction.transactionState)
        {
            case SKPaymentTransactionStatePurchasing:
            {
                NSDictionary *userInfo = @{StoreKISSNotificationPaymentRequestTransactionKey: skTransaction};
                [[NSNotificationCenter defaultCenter] postNotificationName:
                    StoreKISSNotificationPaymentRequestPurchasing
                                                                    object:self
                                                                  userInfo:userInfo];
                // Don't call [self finish] until at least one transaction is still being processed
                allTransactionsOnTheQueueAreFinished = NO;
                break;
            }
                
            case SKPaymentTransactionStatePurchased:
            {
                NSNumber *successResultValue = [NSNumber numberWithInt:
                                                    StoreKISSNotificationPaymentRequestSuccessResultPurchased];
                NSDictionary *userInfo =
                    @{StoreKISSNotificationPaymentRequestTransactionKey: skTransaction,
                      StoreKISSNotificationPaymentRequestSuccessResultKey: successResultValue};
                [[NSNotificationCenter defaultCenter] postNotificationName:
                    StoreKISSNotificationPaymentRequestSuccess
                                                                    object:self
                                                                  userInfo:userInfo];
                [[SKPaymentQueue defaultQueue] finishTransaction:skTransaction];
                break;
            }
                
            case SKPaymentTransactionStateRestored:
            {
                NSNumber *successResultValue = [NSNumber numberWithInt:
                                                    StoreKISSNotificationPaymentRequestSuccessResultRestored];
                NSDictionary *userInfo =
                    @{StoreKISSNotificationPaymentRequestTransactionKey: skTransaction,
                      StoreKISSNotificationPaymentRequestSuccessResultKey: successResultValue};
                [[NSNotificationCenter defaultCenter] postNotificationName:
                    StoreKISSNotificationPaymentRequestSuccess
                                                                    object:self
                                                                  userInfo:userInfo];
                [[SKPaymentQueue defaultQueue] finishTransaction:skTransaction];
                break;
            }
                
            case SKPaymentTransactionStateFailed:
            {
                if (self.skTransaction != nil)
                {
                    self.error = self.skTransaction.error;
                }
                else
                {
                    NSDictionary *userInfo = @{NSLocalizedDescriptionKey: 
                                               NSLocalizedString(@"One of several transactions failed, please "
                                                                  "see transactions array property for errors.", nil};
                    self.error = [NSError errorWithDomain:StoreKISSErrorDomain
                                                     code:StoreKISSErrorTransactionFailed
                                                 userInfo:userInfo];
                }
                
                NSDictionary *userInfo = @{StoreKISSNotificationPaymentRequestTransactionKey: skTransaction,
                                           StoreKISSNotificationPaymentRequestErrorKey: skTransaction.error};
                [[NSNotificationCenter defaultCenter] postNotificationName:
                    StoreKISSNotificationPaymentRequestFailure
                                                                    object:self
                                                                  userInfo:userInfo];
                [[SKPaymentQueue defaultQueue] finishTransaction:skTransaction];
                break;
            }
        }
    }
    
    if (allTransactionsOnTheQueueAreFinished && ! [self isFinished])
    {
        [self finish];
    }
}


- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray *)transactions 
{
    for (SKPaymentTransaction *skTransaction in transactions)
    {
        NSDictionary *userInfo = @{StoreKISSNotificationPaymentRequestTransactionKey: skTransaction};
        [[NSNotificationCenter defaultCenter] postNotificationName:
             StoreKISSNotificationPaymentRequestTransactionRemoved
                                                            object:self
                                                          userInfo:userInfo];
    }
}


- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
{
    if ( ! [self isFinished])
    {
        self.error = error;
        [self finish];
    }
}


- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
    if ( ! [self isFinished])
    {
        [self finish];
    }
}


@end
