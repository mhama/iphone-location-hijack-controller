//
//  CLLocationManager+Hijack.h
//  SekaiCamera
//
//  Copyright 2011 Tonchidot Corporation. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import "HTTPConnection.h"


//! CocoaHttpServer connection class
@interface SCLocationHttpConnection : HTTPConnection
@end


//! external property class for CLLocationManager instances.
@interface SCLocationManagerProperty : NSObject {
}

@property(assign, nonatomic) BOOL isUpdateLocationEnabled;
@property(assign, nonatomic) BOOL isUpdateHeadingEnabled;
@property(assign, nonatomic) id<CLLocationManagerDelegate> delegate;

@end


//! proxy class to get location information from HTTPServer and push it to LocationManagerDelegates.
@interface SCLocationProxy : NSObject<CLLocationManagerDelegate> {
}

@property(retain, nonatomic) CLLocationManager *locationManagerAlt;	//!< alternative location manager instance.
@property(retain, nonatomic) CLLocation *currentLocation;			//!< current location value
@property(retain, nonatomic) UIAlertView *alertView;				//!< alert dialog

//! get the singleton instance
+ (SCLocationProxy *)sharedInstance;

//! start HTTP server
- (void) startServer;

//! set current location to the dummy location manager.
- (void) setLocationWithLat:(double)lat lon:(double)lon accuracy:(double)acc;

//! get the external properties for the location manager instance.
- (SCLocationManagerProperty *) getPropForLocationManager:(CLLocationManager *)manager;

//! get current IP of this iPhone device.
- (NSString *)getCurrentIP;

@end


//! CLLocationManager hijacking code
@interface CLLocationManager(Hijack)

//! exchange method implementations of CLLocationManager class with our own.
+ (void) exchange_LocationManager_methods;

@end
