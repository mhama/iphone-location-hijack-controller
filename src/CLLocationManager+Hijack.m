//
//  CLLocationManager+Hijack.m
//  SekaiCamera
//
//  Copyright 2011 Tonchidot Corporation. All rights reserved.
//

// TODO:
//  - get current location of iPhone
//  - let the location pointer to follow a cource

#import <objc/runtime.h>
#import <Foundation/Foundation.h>

#include <ifaddrs.h>
#include <arpa/inet.h>

#import "HTTPDynamicFileResponse.h"
#import "HTTPServer.h"
#import "HTTPDataResponse.h"

#import "CLLocationManager+Hijack.h"


#define kControllerHtmlFilePath @"location.html"	//!< the html file in the resource that controls location.
#define kControllerPortNo 12345						//!< the server's port number

#define RETURN_TEXT "<!DOCTYPE html \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">" \
"<html xmlns=\"http://www.w3.org/1999/xhtml\"><body></body></html>";

#define CONTROLLER_HTML ""; // this line will be substituted by location.html contents body by pre-processor.


@implementation SCLocationHttpConnection

- (void) processParamsInMainThread:(NSString *)path
{
	// process location parameters
	NSString *postLocationPath = @"/post_location";
	NSLog(@"relativePath:%@", path);
	NSString *params = [path substringFromIndex:[postLocationPath length]];
	double lat = 0;
	double lon = 0;
	double acc = 100.0;
	if ([params length] > 0 && [params characterAtIndex:0] == '?') {
		NSArray *paramsArray = [[params substringFromIndex:1] componentsSeparatedByString:@"&"];
		for (NSString *param in paramsArray) {
			NSRange range = [param rangeOfString:@"="];
			if (range.location != NSNotFound) {
				NSString *key = [param substringToIndex:range.location];
				NSString *value = [param substringFromIndex:range.location+1];
				
				if ([key isEqualToString:@"lat"]) {
					lat = [value doubleValue];
				}
				else if ([key isEqualToString:@"lon"]) {
					lon = [value doubleValue];
				}
				else if ([key isEqualToString:@"acc"]) {
					acc = [value doubleValue];
				}
			}
		}
	}
	
	if (lat!=0 && lon!=0) {
		[[SCLocationProxy sharedInstance] setLocationWithLat:lat lon:lon accuracy:acc];
	}
}


- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
	// this method will be called when the HTTP server receives a request
	
	NSString *postLocationPath = @"/post_location";
	if ([path hasPrefix:postLocationPath])
	{
		[self performSelectorOnMainThread:@selector(processParamsInMainThread:) withObject:path waitUntilDone:YES];

		char text[] = RETURN_TEXT;
		NSData *data = [NSData dataWithBytes:text length:(strlen(text)+1)];
		return [[[HTTPDataResponse alloc] initWithData:data] autorelease];
	}
	else {
		if ([path isEqualToString:[NSString stringWithFormat:@"/%@", kControllerHtmlFilePath]]) {
			char html[] = CONTROLLER_HTML;
			if (html[0] != '\0') {
				NSData *data = [NSData dataWithBytes:html length:(strlen(html)+1)];
				return [[[HTTPDataResponse alloc] initWithData:data] autorelease];
			}
		}
		if (![[NSFileManager defaultManager] isReadableFileAtPath:path]) {
			char text[] = RETURN_TEXT;
			NSData *data = [NSData dataWithBytes:text length:(strlen(text)+1)];
			return [[[HTTPDataResponse alloc] initWithData:data] autorelease];
		}
		NSMutableDictionary *replacementDict = [NSMutableDictionary dictionaryWithCapacity:5];
		return [[[HTTPDynamicFileResponse alloc] initWithFilePath:[self filePathForURI:path]
												forConnection:self
													separator:@"%%"
										replacementDictionary:replacementDict] autorelease];
	}
	
	return [super httpResponseForMethod:method URI:path];
}

@end


//! external property class for CLLocationManager instances.
@implementation  SCLocationManagerProperty

@synthesize isUpdateLocationEnabled, isUpdateHeadingEnabled, delegate;

- (id)init
{
	self = [super init];
	if (self) {
	}
	return self;
}

- (void)dealloc
{
	self.delegate = nil;
	[super dealloc];
}

@end


//! class extension of SCLocationProxy
@interface SCLocationProxy()

@property(retain, nonatomic) NSMutableDictionary *delegatesDic; //!< id - SCLocationManagerProperty dictionary
@property(retain, nonatomic) HTTPServer *httpServer;

@end



@implementation SCLocationProxy

@synthesize locationManagerAlt, delegatesDic, httpServer, currentLocation, alertView;

static SCLocationProxy *sharedSCLocationProxyInstance = nil; //!< singleton instance

- (id)init
{
	self = [super init];
	if (self) {
		self.locationManagerAlt = [[CLLocationManager alloc] init];
		self.locationManagerAlt.delegate = self;
		[self.locationManagerAlt startUpdatingHeading];
		self.delegatesDic = [NSMutableDictionary dictionary];
		[self startServer];
	}
	return self;
}

//! create singleton instance
+ (SCLocationProxy *)sharedInstance
{
	SCLocationProxy * instance = nil;
	@synchronized(self) {
		if (sharedSCLocationProxyInstance == nil) {
			sharedSCLocationProxyInstance = [[self alloc] init];
		}
		instance = sharedSCLocationProxyInstance;
	}
	return instance;
}

- (id) retain { return nil; }
- (void) release {}
- (id) autorelease { return nil; }
- (NSUInteger) retainCount { return NSUIntegerMax; }

//  start HTTP server to control location.
- (void) startServer
{
	httpServer = [[HTTPServer alloc] init];
	[httpServer setType:@"_http._tcp."];
	[httpServer setPort:kControllerPortNo];
	[httpServer setConnectionClass:[SCLocationHttpConnection class]];
	NSString *webPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@""];
	//NSLog(@"Setting document root: %@", webPath);
	[httpServer setDocumentRoot:webPath];
	NSError *error;
	if(![httpServer start:&error])
	{
		NSLog(@"Error starting HTTP Server: %@", error);
	}
}

- (void)dealloc
{
	self.httpServer = nil;
	self.delegatesDic = nil;
	self.locationManagerAlt = nil;
	self.alertView = nil;
	self.currentLocation = nil;
	[super dealloc];
}

- (void) addDelegate:(id<CLLocationManagerDelegate>) delegate forLocationManager:(CLLocationManager *)manager
{
	NSString *desc = [manager description];
	if (![self.delegatesDic objectForKey:desc]) {
		SCLocationManagerProperty *locationProp = [[[SCLocationManagerProperty alloc] init] autorelease];
		locationProp.delegate = delegate;
		[self.delegatesDic setObject:locationProp forKey:desc];
	}
}

- (void) removeDelegateForLocationManager:(CLLocationManager *)manager
{
	NSString *desc = [manager description];
	if ([self.delegatesDic objectForKey:desc]) {
		[self.delegatesDic removeObjectForKey:desc];
	}
}

- (SCLocationManagerProperty *) getPropForLocationManager:(CLLocationManager *)manager 
{
	NSString *desc = [manager description];
	return (SCLocationManagerProperty *)[self.delegatesDic objectForKey:desc];
}

- (void) setLocationWithLat:(double)lat lon:(double)lon accuracy:(double)acc
{
	CLLocationCoordinate2D coord;
	coord.latitude = lat;
	coord.longitude = lon;
	
	CLLocation *newLocation = [[[CLLocation alloc] initWithCoordinate:coord 
															 altitude:0
												   horizontalAccuracy:10.0
													 verticalAccuracy:acc
															timestamp:[NSDate date]] autorelease];
	
	self.currentLocation  = newLocation;
															
	// notify location to the registered delegates.
	for(NSString *managerName in self.delegatesDic) {
		SCLocationManagerProperty *prop = [self.delegatesDic objectForKey:managerName];
		if (prop.isUpdateLocationEnabled) {
			[prop.delegate locationManager:nil didUpdateToLocation:newLocation fromLocation:self.currentLocation];
		}
	}
}

- (NSString *) getURL
{
	UInt16 port = [httpServer port];
	NSString *url = [NSString stringWithFormat:@"http://%@:%d/%@", [[SCLocationProxy sharedInstance] getCurrentIP], port, kControllerHtmlFilePath];
	return url;
}

- (NSString *)getCurrentIP {
	NSString *ip = @"";
	struct ifaddrs *interfaces = NULL;
	if (getifaddrs(&interfaces) == 0) {
		struct ifaddrs *addr = interfaces;
		while (addr != NULL) {
			if(addr->ifa_addr->sa_family == AF_INET
			   && strcmp(addr->ifa_name, "en0") == 0)  {
				ip = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)addr->ifa_addr)->sin_addr)];
			}
			addr = addr->ifa_next;
		}
	}
	freeifaddrs(interfaces);
	return ip;
}

//! show the URL
- (void) showURLWithAlert
{
	NSString *message = [NSString stringWithFormat:@"This iPhone's location controller URL:\n %@\nYou can access the page from the same Wifi network.", [self getURL]];
	
	self.alertView = [[[UIAlertView alloc] initWithTitle:nil
												 message:message
												delegate:self
									   cancelButtonTitle:@"OK"
									   otherButtonTitles:@"Mail URL", nil] autorelease];
	[self.alertView show];
}

//! open mail app with the URL.
- (void) sendURLViaMail
{
	NSString *subject = @"iPhone's Location Hijack Controller";
	NSString *body = [NSString stringWithFormat:@"This is the URL for your iPhone's location controller.\n %@\nYou can access the page from the same Wifi network.", [self getURL]];
	NSString *mailtoString = [NSString stringWithFormat:@"mailto:?to=&subject=%@&body=%@"
							  , [subject stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
							  , [body stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	NSURL *mailtoUrl = [NSURL URLWithString:mailtoString];
	[[UIApplication sharedApplication] openURL:mailtoUrl];
}


#pragma mark -
#pragma mark CLLocationManagerDelegate methods

//! Called when the location is updated
- (void)locationManager:(CLLocationManager *)manager
	didUpdateToLocation:(CLLocation *)newLocation
		   fromLocation:(CLLocation *)oldLocation
{
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading
{
	// open an alert to show the controller URL
	static int first = 1;
	if (first) {
		first = 0;
		[self showURLWithAlert];
	}
	
	for(NSString *managerName in self.delegatesDic) {
		SCLocationManagerProperty *prop = [self.delegatesDic objectForKey:managerName];
		if (prop.isUpdateHeadingEnabled) {
			[prop.delegate locationManager:manager didUpdateHeading:newHeading];
		}
	}
}

#pragma mark -
#pragma mark UIAlertViewDelegate methods

- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alert == self.alertView) {
		if (buttonIndex == 1) {
			[self sendURLViaMail];
			[self showURLWithAlert]; // show the alert again
		}
		else {
			self.alertView = nil;
		}
	}
}

@end



@implementation CLLocationManager(Hijack)

+(void) load
{
	[SCLocationProxy sharedInstance]; // init singleton
	[self exchange_LocationManager_methods];
}

+ (void) exchangeMethod:(SEL) s1 withMethod:(SEL) s2
{
	id classObj = [CLLocationManager class];
	Method orig_method = class_getInstanceMethod(classObj,s1);
	Method alt_method = class_getInstanceMethod(classObj,s2);
	method_exchangeImplementations(orig_method,alt_method);
}

- (void) _dealloc
{
	[[SCLocationProxy sharedInstance] removeDelegateForLocationManager:self];
	[self _dealloc]; // call the original implementation
}

- (void) _setDelegate:(id<CLLocationManagerDelegate>) delegate
{
	[[SCLocationProxy sharedInstance] addDelegate:delegate forLocationManager:self];
}

- (void) _startUpdatingLocation
{
	SCLocationManagerProperty *prop = [[SCLocationProxy sharedInstance] getPropForLocationManager:self];
	prop.isUpdateLocationEnabled = true;
}

- (void) _stopUpdatingLocation
{
	SCLocationManagerProperty *prop = [[SCLocationProxy sharedInstance] getPropForLocationManager:self];
	prop.isUpdateLocationEnabled = false;
}

- (void) _startUpdatingHeading
{
	SCLocationManagerProperty *prop = [[SCLocationProxy sharedInstance] getPropForLocationManager:self];
	prop.isUpdateHeadingEnabled = true;
}

- (void) _stopUpdatingHeading
{
	SCLocationManagerProperty *prop = [[SCLocationProxy sharedInstance] getPropForLocationManager:self];
	prop.isUpdateHeadingEnabled = false;
}

- (CLLocation *) _location
{
	return [[SCLocationProxy sharedInstance] currentLocation];
}

// headingAvailable retains original implementation.

+ (void) exchange_LocationManager_methods
{
	// exchange CLLocationManager methods
	[CLLocationManager exchangeMethod:@selector(_setDelegate:) withMethod:@selector(setDelegate:)];
	[CLLocationManager exchangeMethod:@selector(_dealloc) withMethod:@selector(dealloc)];
	[CLLocationManager exchangeMethod:@selector(_startUpdatingLocation) withMethod:@selector(startUpdatingLocation)];
	[CLLocationManager exchangeMethod:@selector(_stopUpdatingLocation) withMethod:@selector(stopUpdatingLocation)];
	[CLLocationManager exchangeMethod:@selector(_startUpdatingHeading) withMethod:@selector(startUpdatingHeading)];
	[CLLocationManager exchangeMethod:@selector(_stopUpdatingHeading) withMethod:@selector(stopUpdatingHeading)];
	[CLLocationManager exchangeMethod:@selector(_location) withMethod:@selector(location)];
}

@end
