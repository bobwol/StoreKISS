#StoreKISS

Lightweight wrapper for Apple's StoreKit framework created with KISS concept and love ❤.

Only for Non-consumable products now. Everything else coming later.

Uses ARC.

##Main idea

There are two request types:

- data request for getting payment data (price and stuff);
- payment request for making payment.

So you basically request price and then execute the payment. That simple.

##How to use

1. Add StoreKit framework to your project at Build Phases > Link Binary With Libraries.

1. Add [Reachability](https://github.com/tonymillion/Reachability) to your project.

1. Import `StoreKISS.h` and start using.

##Usage examples

###Requesting data using blocks

	StoreKISSDataRequest *dataRequest = [[StoreKISSDataRequest alloc] init];
	[dataRequest
	 requestDataForItemWithProductId:@"com.example.myProduct"
	 success:^(StoreKISSDataRequest *dataRequest,
			   SKProductsResponse *response) {
         NSLog(@"Received payment data.")
	 } failure:^(NSError *error) {
         NSLog(@"Houston, we have a problem: %@"), error.localizedDescription); 
	 }];
	 
###Requesting data using notifications

	// Register observer
	- (id)init
	{
	    self = [super init];
	    if (self) {
			[[NSNotificationCenter defaultCenter]
			 addObserver:self
			 selector:@selector(didReceiveDataRequestNotificationSuccess:)
			 name:StoreKISSNotificationDataRequestSuccess
			 object:nil];
			...

	// Launch request
	StoreKISSDataRequest *dataRequest = [[StoreKISSDataRequest alloc] init];
	[dataRequest requestDataForItemWithProductId:@"com.example.myProduct"];
	
	// Handle notifications
	- (void)didReceiveDataRequestNotificationSuccess:(NSNotification *)notification
	{
		NSLog(@"Received notification %@, data request object %@", notification.name, notification.object);
		...
	
	// Don't forget to remove observer
	- (void)dealloc
	{
		[[NSNotificationCenter defaultCenter]
		 removeObserver:self
		 name:StoreKISSNotificationDataRequestSuccess
		 object:nil];
		…
		
The same is for `StoreKISSPaymentRequest`.

##Support

Feel free to open an issue on github or email me at [karpenko.misha@gmail.com](mailto:karpenko.misha@gmail.com).