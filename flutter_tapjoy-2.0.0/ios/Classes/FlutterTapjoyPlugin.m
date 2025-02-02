#import "FlutterTapjoyPlugin.h"
#import <AppTrackingTransparency/AppTrackingTransparency.h>

@implementation FlutterTapjoyPlugin

    FlutterMethodChannel* tapJoyChannel;
FlutterViewController* flutterViewController;
    NSDictionary *placements;

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  tapJoyChannel = [FlutterMethodChannel
      methodChannelWithName:@"flutter_tapjoy"
            binaryMessenger:[registrar messenger]];
    FlutterTapjoyPlugin* instance = [[FlutterTapjoyPlugin alloc] init];
    
  [registrar addMethodCallDelegate:instance channel:tapJoyChannel];
    
  flutterViewController =
    [[FlutterViewController alloc] initWithProject:nil
                                   nibName:nil
                                            bundle:nil];
    
    placements =  [[NSMutableDictionary alloc]initWithCapacity:100];
    
    [[NSNotificationCenter defaultCenter] addObserver:self  selector:@selector(tjcConnectSuccess:) name:TJC_CONNECT_SUCCESS object:nil ];
       [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tjcConnectFail:) name:TJC_CONNECT_FAILED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showEarnedCurrencyAlert:) name:TJC_CURRENCY_EARNED_NOTIFICATION object:nil];
    [Tapjoy setDefaultViewController:flutterViewController];
}
- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSDictionary *dict = call.arguments;
    NSString *placementName = dict[@"placementName"];
  if ([@"connectTapJoy" isEqualToString:call.method]) {
    [ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:^(ATTrackingManagerAuthorizationStatus status) {
      NSString *apiKey = dict[@"iOSApiKey"];
      NSNumber *methodDebug = dict[@"debug"];
      [Tapjoy setDebugEnabled:methodDebug.boolValue];
      [Tapjoy connect:apiKey];
      result(@YES);
    }];
  } else if ([@"setUserID" isEqualToString:call.method]) {
      NSString *userID = dict[@"userID"];
      [Tapjoy setUserID:userID];
      result(@YES);
  }  else if ([@"setPrivacyPolicy" isEqualToString:call.method]) {
      TJPrivacyPolicy *privacyPolicy = [Tapjoy getPrivacyPolicy];
      NSNumber *subjectToGDPRNumber = dict[@"subjectToGDPR"];
      NSString *userConsent = dict[@"userConsent"];
      NSNumber *belowConsentAgeNumber = dict[@"belowConsentAge"];
      NSString *usPrivacy = dict[@"usPrivacy"];
      bool subjectToGDPR = subjectToGDPRNumber.boolValue;
      bool belowConsentAge = belowConsentAgeNumber.boolValue;

      NSLog(@"Privacy Policy subjectToGDPR: %d", subjectToGDPR);
      NSLog(@"Privacy Policy userConsent: %@", userConsent);
      NSLog(@"Privacy Policy belowConsentAge: %d", belowConsentAge);
      NSLog(@"Privacy Policy usPrivacy: %@", usPrivacy);
      [privacyPolicy setSubjectToGDPR: subjectToGDPR];
      [privacyPolicy setUserConsent: userConsent];
      [privacyPolicy setBelowConsentAge: belowConsentAge];
      [privacyPolicy setUSPrivacy: usPrivacy];
      result(@YES);
  } else if ([@"isConnected" isEqualToString:call.method]) {
      BOOL isConnected = [Tapjoy isConnected];
      if (isConnected) {
          result(@YES);
      } else {
          result(@NO);
      }
  } else if ([@"createPlacement" isEqualToString:call.method]) {
      [FlutterTapjoyPlugin addPlacement:placementName];
      result(@YES);
  } else if ([@"requestContent" isEqualToString:call.method]) {
      TJPlacement *myPlacement = placements[placementName];
      if (myPlacement) {
          [myPlacement requestContent];
      } else {
          NSDictionary *args;
          args = @{ @"error" : @"Placement Not Found, Please Add placement first",@"placementName":placementName};
          [tapJoyChannel invokeMethod:@"requestFail" arguments:args];
      }
      result(@YES);
  } else if ([@"showPlacement" isEqualToString:call.method]) {
      TJPlacement *myPlacement = placements[placementName];
      [myPlacement showContentWithViewController:flutterViewController];
  } else if ([@"getCurrencyBalance" isEqualToString:call.method]) {
      [Tapjoy getCurrencyBalanceWithCompletion: ^ (NSDictionary * parameters, NSError * error) {
          NSDictionary *args;
          if (error) {
              args = @{ @"error" : error.description};
          } else {
              args = @{ @"currencyName" : parameters[@"currencyName"],@"balance":parameters[@"amount"]};
          }
          [tapJoyChannel invokeMethod:@"onGetCurrencyBalanceResponse" arguments:args];
      }];
  }  else if ([@"spendCurrency" isEqualToString:call.method]) {
      NSNumber *amountToSpend = dict[@"amount"];
      [Tapjoy spendCurrency:amountToSpend.intValue completion:^(NSDictionary *parameters, NSError *error) {
          NSDictionary *args;
          if (error) {
              args = @{ @"error" : error.description};
          } else {
              args = @{ @"currencyName" : parameters[@"currencyName"],@"balance":parameters[@"amount"]};
          }
          [tapJoyChannel invokeMethod:@"onSpendCurrencyResponse" arguments:args];
      }];
  }  else if ([@"awardCurrency" isEqualToString:call.method]) {
      NSNumber *amountToAward = dict[@"amount"];
      [Tapjoy awardCurrency:amountToAward.intValue completion:^(NSDictionary *parameters, NSError *error) {
          NSDictionary *args;
          if (error) {
              args = @{ @"error" : error.description};
              
          } else {
              args = @{ @"currencyName" : parameters[@"currencyName"],@"balance":parameters[@"amount"]};
          }
          [tapJoyChannel invokeMethod:@"onAwardCurrencyResponse" arguments:args];
      }];
  } else if ([@"getATT" isEqualToString: call.method]) {
      if (@available(iOS 14, *)) {
      [ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:^(ATTrackingManagerAuthorizationStatus status) {
          switch (status) {
              case ATTrackingManagerAuthorizationStatusNotDetermined:
                  result(@"NotDetermined");
                  break;
              case ATTrackingManagerAuthorizationStatusRestricted:
                  result(@"Restricted");
                  break;
              case ATTrackingManagerAuthorizationStatusDenied:
                  result(@"Denied");
                  break;
              case ATTrackingManagerAuthorizationStatusAuthorized:
                  result(@"Authorized");
                  break;
              default:
                  result(@"NotFound");
                  break;
          }
         
      }];
      } else {
          result(@"NOT");
          
      }
  }
  else {
    result(FlutterMethodNotImplemented);
  }
}

+ (void)tjcConnectSuccess:(NSNotification *)notifyObj
{

    [tapJoyChannel invokeMethod:@"connectionSuccess" arguments:nil];
}

+ (void)tjcConnectFail:(NSNotification *)notifyObj
{

    [tapJoyChannel invokeMethod:@"connectionFail" arguments:nil];
}

+ (void)requestDidSucceed:(TJPlacement*)placement{
    NSDictionary *args;
    [args setValue:placement.placementName forKey:@"placementName"];
    [tapJoyChannel invokeMethod:@"requestSuccess" arguments:args];
}

// Called when there was a problem during connecting Tapjoy servers.
+ (void)requestDidFail:(TJPlacement*)placement error:(NSError*)error{
    NSDictionary *args = @{ @"placementName" : placement.placementName, @"error":error.description};
    [tapJoyChannel invokeMethod:@"requestFail" arguments:args];
}

// Called when the content is actually available to display.
+ (void)contentIsReady:(TJPlacement*)placement{
    NSDictionary *args = @{ @"placementName" : placement.placementName};
    [tapJoyChannel invokeMethod:@"contentReady" arguments:args];
}

// Called when the content is showed.
+ (void)contentDidAppear:(TJPlacement*)placement{
    NSDictionary *args = @{ @"placementName" : placement.placementName};
    [tapJoyChannel invokeMethod:@"contentDidAppear" arguments:args];
}

// Called when the content is dismissed.
+ (void)contentDidDisappear:(TJPlacement*)placement{
    NSDictionary *args = @{ @"placementName" : placement.placementName};
    [tapJoyChannel invokeMethod:@"contentDidDisAppear" arguments:args];
}

+ (void)addPlacement:(NSString*)placementName{
    TJPlacement *myPlacement = [TJPlacement placementWithName:placementName delegate:self];
    [placements setValue:myPlacement forKey:placementName];
}

+ (void)showEarnedCurrencyAlert:(NSNotification*)notifyObj
{
//    NSNumber *currencyEarned = notifyObj.object;
//    int earnedNum = [currencyEarned intValue];
    NSDictionary *args = @{ @"earnedAmount" : notifyObj.object};
    [tapJoyChannel invokeMethod:@"onAwardCurrencyResponse" arguments:args];
    
    // This is a good place to remove this notification since it is undesirable to have a pop-up alert more than once per app run.
    [[NSNotificationCenter defaultCenter] removeObserver:self name:TJC_CURRENCY_EARNED_NOTIFICATION object:nil];
}
@end
