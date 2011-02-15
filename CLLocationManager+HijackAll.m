
#ifdef DEBUG // only for debug mode (this can be changed to whatever)

//============================= contents of <cocoahttpserver/HTTPServer.h>
#import <Foundation/Foundation.h>

@class GCDAsyncSocket;
@class WebSocket;

#if TARGET_OS_IPHONE
  #if __IPHONE_OS_VERSION_MIN_REQUIRED >= 40000 // iPhone 4.0
    #define IMPLEMENTED_PROTOCOLS <NSNetServiceDelegate>
  #else
    #define IMPLEMENTED_PROTOCOLS 
  #endif
#else
  #if MAC_OS_X_VERSION_MIN_REQUIRED >= 1060 // Mac OS X 10.6
    #define IMPLEMENTED_PROTOCOLS <NSNetServiceDelegate>
  #else
    #define IMPLEMENTED_PROTOCOLS 
  #endif
#endif


@interface HTTPServer : NSObject IMPLEMENTED_PROTOCOLS
{
	// Underlying asynchronous TCP/IP socket
	dispatch_queue_t serverQueue;
	dispatch_queue_t connectionQueue;
	GCDAsyncSocket *asyncSocket;
	
	// HTTP server configuration
	NSString *documentRoot;
	Class connectionClass;
	NSString *interface;
	UInt16 port;
	
	// NSNetService and related variables
	NSNetService *netService;
	NSString *domain;
	NSString *type;
	NSString *name;
	NSString *publishedName;
	NSDictionary *txtRecordDictionary;
	
	// Connection management
	NSMutableArray *connections;
	NSMutableArray *webSockets;
	NSLock *connectionsLock;
	NSLock *webSocketsLock;
	
	BOOL isRunning;
}

/**
 * Specifies the document root to serve files from.
 * For example, if you set this to "/Users/<your_username>/Sites",
 * then it will serve files out of the local Sites directory (including subdirectories).
 * 
 * The default value is nil.
 * The default server configuration will not serve any files until this is set.
 * 
 * If you change the documentRoot while the server is running,
 * the change will affect future incoming http connections.
**/
- (NSString *)documentRoot;
- (void)setDocumentRoot:(NSString *)value;

/**
 * The connection class is the class used to handle incoming HTTP connections.
 * 
 * The default value is [HTTPConnection class].
 * You can override HTTPConnection, and then set this to [MyHTTPConnection class].
 * 
 * If you change the connectionClass while the server is running,
 * the change will affect future incoming http connections.
**/
- (Class)connectionClass;
- (void)setConnectionClass:(Class)value;

/**
 * Set what interface you'd like the server to listen on.
 * By default this is nil, which causes the server to listen on all available interfaces like en1, wifi etc.
 * 
 * The interface may be specified by name (e.g. "en1" or "lo0") or by IP address (e.g. "192.168.4.34").
 * You may also use the special strings "localhost" or "loopback" to specify that
 * the socket only accept connections from the local machine.
**/
- (NSString *)interface;
- (void)setInterface:(NSString *)value;

/**
 * The port number to run the HTTP server on.
 * 
 * The default port number is zero, meaning the server will automatically use any available port.
 * This is the recommended port value, as it avoids possible port conflicts with other applications.
 * Technologies such as Bonjour can be used to allow other applications to automatically discover the port number.
 * 
 * Note: As is common on most OS's, you need root privledges to bind to port numbers below 1024.
 * 
 * You can change the port property while the server is running, but it won't affect the running server.
 * To actually change the port the server is listening for connections on you'll need to restart the server.
 * 
 * The listeningPort method will always return the port number the running server is listening for connections on.
 * If the server is not running this method returns 0.
**/
- (UInt16)port;
- (UInt16)listeningPort;
- (void)setPort:(UInt16)value;

/**
 * Bonjour domain for publishing the service.
 * The default value is "local.".
 * 
 * Note: Bonjour publishing requires you set a type.
 * 
 * If you change the domain property after the bonjour service has already been published (server already started),
 * you'll need to invoke the republishBonjour method to update the broadcasted bonjour service.
**/
- (NSString *)domain;
- (void)setDomain:(NSString *)value;

/**
 * Bonjour name for publishing the service.
 * The default value is "".
 * 
 * If using an empty string ("") for the service name when registering,
 * the system will automatically use the "Computer Name".
 * Using an empty string will also handle name conflicts
 * by automatically appending a digit to the end of the name.
 * 
 * Note: Bonjour publishing requires you set a type.
 * 
 * If you change the name after the bonjour service has already been published (server already started),
 * you'll need to invoke the republishBonjour method to update the broadcasted bonjour service.
 * 
 * The publishedName method will always return the actual name that was published via the bonjour service.
 * If the service is not running this method returns nil.
**/
- (NSString *)name;
- (NSString *)publishedName;
- (void)setName:(NSString *)value;

/**
 * Bonjour type for publishing the service.
 * The default value is nil.
 * The service will not be published via bonjour unless the type is set.
 * 
 * If you wish to publish the service as a traditional HTTP server, you should set the type to be "_http._tcp.".
 * 
 * If you change the type after the bonjour service has already been published (server already started),
 * you'll need to invoke the republishBonjour method to update the broadcasted bonjour service.
**/
- (NSString *)type;
- (void)setType:(NSString *)value;

/**
 * Republishes the service via bonjour if the server is running.
 * If the service was not previously published, this method will publish it (if the server is running).
**/
- (void)republishBonjour;

/**
 * 
**/
- (NSDictionary *)TXTRecordDictionary;
- (void)setTXTRecordDictionary:(NSDictionary *)dict;

- (BOOL)start:(NSError **)errPtr;
- (BOOL)stop;
- (BOOL)isRunning;

- (void)addWebSocket:(WebSocket *)ws;

- (NSUInteger)numberOfHTTPConnections;
- (NSUInteger)numberOfWebSocketConnections;

@end
//============================= contents of <cocoahttpserver/HTTPConnection.h>
#import <Foundation/Foundation.h>

@class GCDAsyncSocket;
@class HTTPMessage;
@class HTTPServer;
@class WebSocket;
@protocol HTTPResponse;


#define HTTPConnectionDidDieNotification  @"HTTPConnectionDidDie"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface HTTPConfig : NSObject
{
	HTTPServer *server;
	NSString *documentRoot;
	dispatch_queue_t queue;
}

- (id)initWithServer:(HTTPServer *)server documentRoot:(NSString *)documentRoot;
- (id)initWithServer:(HTTPServer *)server documentRoot:(NSString *)documentRoot queue:(dispatch_queue_t)q;

@property (nonatomic, readonly) HTTPServer *server;
@property (nonatomic, readonly) NSString *documentRoot;
@property (nonatomic, readonly) dispatch_queue_t queue;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface HTTPConnection : NSObject
{
	dispatch_queue_t connectionQueue;
	GCDAsyncSocket *asyncSocket;
	HTTPConfig *config;
	
	BOOL started;
	
	HTTPMessage *request;
	unsigned int numHeaderLines;
	
	BOOL sentResponseHeaders;
	
	NSString *nonce;
	long lastNC;
	
	NSObject<HTTPResponse> *httpResponse;
	
	NSMutableArray *ranges;
	NSMutableArray *ranges_headers;
	NSString *ranges_boundry;
	int rangeIndex;
	
	UInt64 requestContentLength;
	UInt64 requestContentLengthReceived;
	
	NSMutableArray *responseDataSizes;
}

- (id)initWithAsyncSocket:(GCDAsyncSocket *)newSocket configuration:(HTTPConfig *)aConfig;

- (void)start;
- (void)stop;

- (void)startConnection;

- (BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path;
- (BOOL)expectsRequestBodyFromMethod:(NSString *)method atPath:(NSString *)path;

- (BOOL)isSecureServer;
- (NSArray *)sslIdentityAndCertificates;

- (BOOL)isPasswordProtected:(NSString *)path;
- (BOOL)useDigestAccessAuthentication;
- (NSString *)realm;
- (NSString *)passwordForUser:(NSString *)username;

- (NSDictionary *)parseParams:(NSString *)query;
- (NSDictionary *)parseGetParams;

- (NSString *)requestURI;

- (NSArray *)directoryIndexFileNames;
- (NSString *)filePathForURI:(NSString *)path;
- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path;
- (WebSocket *)webSocketForURI:(NSString *)path;

- (void)prepareForBodyWithSize:(UInt64)contentLength;
- (void)processDataChunk:(NSData *)postDataChunk;

- (void)handleVersionNotSupported:(NSString *)version;
- (void)handleAuthenticationFailed;
- (void)handleResourceNotFound;
- (void)handleInvalidRequest:(NSData *)data;
- (void)handleUnknownMethod:(NSString *)method;

- (NSData *)preprocessResponse:(HTTPMessage *)response;
- (NSData *)preprocessErrorResponse:(HTTPMessage *)response;

- (BOOL)shouldDie;
- (void)die;

@end

@interface HTTPConnection (AsynchronousHTTPResponse)
- (void)responseHasAvailableData:(NSObject<HTTPResponse> *)sender;
- (void)responseDidAbort:(NSObject<HTTPResponse> *)sender;
@end
//============================= contents of <cocoahttpserver/HTTPResponse.h>
#import <Foundation/Foundation.h>


@protocol HTTPResponse

/**
 * Returns the length of the data in bytes.
 * If you don't know the length in advance, implement the isChunked method and have it return YES.
**/
- (UInt64)contentLength;

/**
 * The HTTP server supports range requests in order to allow things like
 * file download resumption and optimized streaming on mobile devices.
**/
- (UInt64)offset;
- (void)setOffset:(UInt64)offset;

/**
 * Returns the data for the response.
 * You do not have to return data of the exact length that is given.
 * You may optionally return data of a lesser length.
 * However, you must never return data of a greater length than requested.
 * Doing so could disrupt proper support for range requests.
 * 
 * To support asynchronous responses, read the discussion at the bottom of this header.
**/
- (NSData *)readDataOfLength:(NSUInteger)length;

/**
 * Should only return YES after the HTTPConnection has read all available data.
 * That is, all data for the response has been returned to the HTTPConnection via the readDataOfLength method.
**/
- (BOOL)isDone;

@optional

/**
 * If you need time to calculate any part of the HTTP response headers (status code or header fields),
 * this method allows you to delay sending the headers so that you may asynchronously execute the calculations.
 * Simply implement this method and return YES until you have everything you need concerning the headers.
 * 
 * This method ties into the asynchronous response architecture of the HTTPConnection.
 * You should read the full discussion at the bottom of this header.
 * 
 * If you return YES from this method,
 * the HTTPConnection will wait for you to invoke the responseHasAvailableData method.
 * After you do, the HTTPConnection will again invoke this method to see if the response is ready to send the headers.
 * 
 * You should only delay sending the headers until you have everything you need concerning just the headers.
 * Asynchronously generating the body of the response is not an excuse to delay sending the headers.
 * Instead you should tie into the asynchronous response architecture, and use techniques such as the isChunked method.
 * 
 * Important: You should read the discussion at the bottom of this header.
**/
- (BOOL)delayResponeHeaders;

/**
 * Status code for response.
 * Allows for responses such as redirect (301), etc.
**/
- (NSInteger)status;

/**
 * If you want to add any extra HTTP headers to the response,
 * simply return them in a dictionary in this method.
**/
- (NSDictionary *)httpHeaders;

/**
 * If you don't know the content-length in advance,
 * implement this method in your custom response class and return YES.
 * 
 * Important: You should read the discussion at the bottom of this header.
**/
- (BOOL)isChunked;

/**
 * This method is called from the HTTPConnection class when the connection is closed,
 * or when the connection is finished with the response.
 * If your response is asynchronous, you should implement this method so you know not to
 * invoke any methods on the HTTPConnection after this method is called (as the connection may be deallocated).
**/
- (void)connectionDidClose;

@end


/**
 * Important notice to those implementing custom asynchronous and/or chunked responses:
 * 
 * HTTPConnection supports asynchronous responses.  All you have to do in your custom response class is
 * asynchronously generate the response, and invoke HTTPConnection's responseHasAvailableData method.
 * You don't have to wait until you have all of the response ready to invoke this method.  For example, if you
 * generate the response in incremental chunks, you could call responseHasAvailableData after generating
 * each chunk.  Please see the HTTPAsyncFileResponse class for an example of how to do this.
 * 
 * The normal flow of events for an HTTPConnection while responding to a request is like this:
 *  - Send http resopnse headers
 *  - Get data from response via readDataOfLength method.
 *  - Add data to asyncSocket's write queue.
 *  - Wait for asyncSocket to notify it that the data has been sent.
 *  - Get more data from response via readDataOfLength method.
 *  - ... continue this cycle until the entire response has been sent.
 * 
 * With an asynchronous response, the flow is a little different.
 * 
 * First the HTTPResponse is given the opportunity to postpone sending the HTTP response headers.
 * This allows the response to asynchronously execute any code needed to calculate a part of the header.
 * An example might be the response needs to generate some custom header fields,
 * or perhaps the response needs to look for a resource on network-attached storage.
 * Since the network-attached storage may be slow, the response doesn't know whether to send a 200 or 404 yet.
 * In situations such as this, the HTTPResponse simply implements the delayResponseHeaders method and returns YES.
 * After returning YES from this method, the HTTPConnection will wait until the response invokes its
 * responseHasAvailableData method. After this occurs, the HTTPConnection will again query the delayResponseHeaders
 * method to see if the response is ready to send the headers.
 * This cycle will continue until the delayResponseHeaders method returns NO.
 * 
 * You should only delay sending the response headers until you have everything you need concerning just the headers.
 * Asynchronously generating the body of the response is not an excuse to delay sending the headers.
 * 
 * After the response headers have been sent, the HTTPConnection calls your readDataOfLength method.
 * You may or may not have any available data at this point. If you don't, then simply return nil.
 * You should later invoke HTTPConnection's responseHasAvailableData when you have data to send.
 * 
 * You don't have to keep track of when you return nil in the readDataOfLength method, or how many times you've invoked
 * responseHasAvailableData. Just simply call responseHasAvailableData whenever you've generated new data, and
 * return nil in your readDataOfLength whenever you don't have any available data in the requested range.
 * HTTPConnection will automatically detect when it should be requesting new data and will act appropriately.
 * 
 * It's important that you also keep in mind that the HTTP server supports range requests.
 * The setOffset method is mandatory, and should not be ignored.
 * Make sure you take into account the offset within the readDataOfLength method.
 * You should also be aware that the HTTPConnection automatically sorts any range requests.
 * So if your setOffset method is called with a value of 100, then you can safely release bytes 0-99.
 * 
 * HTTPConnection can also help you keep your memory footprint small.
 * Imagine you're dynamically generating a 10 MB response.  You probably don't want to load all this data into
 * RAM, and sit around waiting for HTTPConnection to slowly send it out over the network.  All you need to do
 * is pay attention to when HTTPConnection requests more data via readDataOfLength.  This is because HTTPConnection
 * will never allow asyncSocket's write queue to get much bigger than READ_CHUNKSIZE bytes.  You should
 * consider how you might be able to take advantage of this fact to generate your asynchronous response on demand,
 * while at the same time keeping your memory footprint small, and your application lightning fast.
 * 
 * If you don't know the content-length in advanced, you should also implement the isChunked method.
 * This means the response will not include a Content-Length header, and will instead use "Transfer-Encoding: chunked".
 * There's a good chance that if your response is asynchronous and dynamic, it's also chunked.
 * If your response is chunked, you don't need to worry about range requests.
**/
//============================= contents of <cocoahttpserver/HTTPAsyncFileResponse.h>
#import <Foundation/Foundation.h>
//embedded #import "HTTPResponse.h"

@class HTTPConnection;

/**
 * This is an asynchronous version of HTTPFileResponse.
 * It reads data from the given file asynchronously via GCD.
 * 
 * It may be overriden to allow custom post-processing of the data that has been read from the file.
 * An example of this is the HTTPDynamicFileResponse class.
**/

@interface HTTPAsyncFileResponse : NSObject <HTTPResponse>
{	
	HTTPConnection *connection;
	
	NSString *filePath;
	UInt64 fileLength;
	UInt64 fileOffset;  // File offset as pertains to data given to connection
	UInt64 readOffset;  // File offset as pertains to data read from file (but maybe not returned to connection)
	
	BOOL aborted;
	
	NSData *data;
	
	int fileFD;
	void *readBuffer;
	NSUInteger readBufferSize;     // Malloced size of readBuffer
	NSUInteger readBufferOffset;   // Offset within readBuffer where the end of existing data is
	NSUInteger readRequestLength;
	dispatch_queue_t readQueue;
	dispatch_source_t readSource;
	BOOL readSourceSuspended;
}

- (id)initWithFilePath:(NSString *)filePath forConnection:(HTTPConnection *)connection;
- (NSString *)filePath;

@end

/**
 * Explanation of Variables (excluding those that are obvious)
 * 
 * fileOffset
 *   This is the number of bytes that have been returned to the connection via the readDataOfLength method.
 *   If 1KB of data has been read from the file, but none of that data has yet been returned to the connection,
 *   then the fileOffset variable remains at zero.
 *   This variable is used in the calculation of the isDone method.
 *   Only after all data has been returned to the connection are we actually done.
 * 
 * readOffset
 *   Represents the offset of the file descriptor.
 *   In other words, the file position indidcator for our read stream.
 *   It might be easy to think of it as the total number of bytes that have been read from the file.
 *   However, this isn't entirely accurate, as the setOffset: method may have caused us to
 *   jump ahead in the file (lseek).
 * 
 * readBuffer
 *   Malloc'd buffer to hold data read from the file.
 * 
 * readBufferSize
 *   Total allocation size of malloc'd buffer.
 * 
 * readBufferOffset
 *   Represents the position in the readBuffer where we should store new bytes.
 * 
 * readRequestLength
 *   The total number of bytes that were requested from the connection.
 *   It's OK if we return a lesser number of bytes to the connection.
 *   It's NOT OK if we return a greater number of bytes to the connection.
 *   Doing so would disrupt proper support for range requests.
 *   If, however, the response is chunked then we don't need to worry about this.
 *   Chunked responses inheritly don't support range requests.
**/
//============================= contents of <cocoahttpserver/HTTPDynamicFileResponse.h>
#import <Foundation/Foundation.h>
//embedded #import "HTTPResponse.h"
//embedded #import "HTTPAsyncFileResponse.h"

/**
 * This class is designed to assist with dynamic content.
 * Imagine you have a file that you want to make dynamic:
 * 
 * <html>
 * <body>
 *   <h1>ComputerName Control Panel</h1>
 *   ...
 *   <li>System Time: SysTime</li>
 * </body>
 * </html>
 * 
 * Now you could generate the entire file in Objective-C,
 * but this would be a horribly tedious process.
 * Beside, you want to design the file with professional tools to make it look pretty.
 * 
 * So all you have to do is escape your dynamic content like this:
 * 
 * ...
 *   <h1>%%ComputerName%% Control Panel</h1>
 * ...
 *   <li>System Time: %%SysTime%%</li>
 * 
 * And then you create an instance of this class with:
 * 
 * - separator = @"%%"
 * - replacementDictionary = { "ComputerName"="Black MacBook", "SysTime"="2010-04-30 03:18:24" }
 * 
 * This class will then perform the replacements for you, on the fly, as it reads the file data.
 * This class is also asynchronous, so it will perform the file IO using its own GCD queue.
**/

@interface HTTPDynamicFileResponse : HTTPAsyncFileResponse
{
	NSData *separator;
	NSDictionary *replacementDict;
}

- (id)initWithFilePath:(NSString *)filePath
         forConnection:(HTTPConnection *)connection
             separator:(NSString *)separatorStr
 replacementDictionary:(NSDictionary *)dictionary;

@end
//============================= contents of <cocoahttpserver/HTTPDataResponse.h>
#import <Foundation/Foundation.h>
//embedded #import "HTTPResponse.h"


@interface HTTPDataResponse : NSObject <HTTPResponse>
{
	NSUInteger offset;
	NSData *data;
}

- (id)initWithData:(NSData *)data;

@end
//============================= contents of <cocoahttpserver/HTTPRedirectResponse.h>
#import <Foundation/Foundation.h>
//embedded #import "HTTPResponse.h"


@interface HTTPRedirectResponse : NSObject <HTTPResponse>
{
	NSString *redirectPath;
}

- (id)initWithPath:(NSString *)redirectPath;

@end
//============================= contents of <src/CLLocationManager+Hijack.h>
//
//  CLLocationManager+Hijack.h
//  SekaiCamera
//
//  Copyright 2011 Tonchidot Corporation. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
//embedded #import "HTTPConnection.h"


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
//============================= contents of <src/CLLocationManager+Hijack.m>
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

//embedded #import "HTTPDynamicFileResponse.h"
//embedded #import "HTTPServer.h"
//embedded #import "HTTPDataResponse.h"

//embedded #import "CLLocationManager+Hijack.h"


#define kControllerHtmlFilePath @"location.html"	//!< the html file in the resource that controls location.
#define kControllerPortNo 12345						//!< the server's port number

#define RETURN_TEXT "<!DOCTYPE html \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">" \
"<html xmlns=\"http://www.w3.org/1999/xhtml\"><body></body></html>";

#define CONTROLLER_HTML \
"<!DOCTYPE html \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">\n" \
"<html xmlns=\"http://www.w3.org/1999/xhtml\">\n" \
"\n" \
"<head>\n" \
"<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\"/>\n" \
"<title>Location Hijack Controller for iPhone development</title> \n" \
"<script src=\"http://maps.google.com/maps/api/js?v=3.2&amp;sensor=true\" type=\"text/javascript\"></script>\n" \
"<script src=\"https://ajax.googleapis.com/ajax/libs/jquery/1.4.4/jquery.min.js\" type=\"text/javascript\"></script>\n" \
"\n" \
"<script type=\"text/javascript\">\n" \
"\n" \
"var map; //!< google map instance\n" \
"var marker_count = 0;	//!< marker count\n" \
"var markers = {};		//!< marker_id - marker instance dictionary\n" \
"var g_infowindow;		//!< information window\n" \
"var g_currentLocationMarker = null;	//!< the marker that represents the current location of the iPhone\n" \
"\n" \
"\n" \
"function initialize()\n" \
"{\n" \
"	var myLatlng = new google.maps.LatLng(35.688250, 139.754489);\n" \
"	var myOptions = {\n" \
"		zoom: 13,\n" \
"		center: myLatlng,\n" \
"		mapTypeId: google.maps.MapTypeId.ROADMAP,\n" \
"		scaleControl: true,\n" \
"	};\n" \
"	map = new google.maps.Map(document.getElementById(\"map_canvas\"), myOptions);\n" \
"	\n" \
"	google.maps.event.addListener(map, \'click\', function(event) {\n" \
"		setCurrentLocationMarker(event.latLng);\n" \
"		setIPhoneLocation(event.latLng);\n" \
"		});\n" \
"	\n" \
"	updateLatlngBoxTo(map.getCenter());\n" \
"}\n" \
"\n" \
"function addMarker(marker) {\n" \
"	var marker_id = \"marker_\" + marker_count;\n" \
"	markers[marker_id] =marker;\n" \
"	marker_count++;\n" \
"	return marker_id;\n" \
"}\n" \
"\n" \
"function deleteMarker(marker_id) {\n" \
"	var marker = markers[marker_id];\n" \
"	if (!marker) return;\n" \
"	marker.setMap(null);\n" \
"	markers[marker_id] = null;\n" \
"}\n" \
"\n" \
"function clearMarkers() {\n" \
"	for(var m in markers) {\n" \
"		if (markers[m]) markers[m].setMap(null);\n" \
"	}\n" \
"	markers = {}\n" \
"}\n" \
"\n" \
"function createCurrentLocationMarker(location) {\n" \
"	var scale = 1.5;\n" \
"	var icon = new google.maps.MarkerImage(\"http://maps.google.com/mapfiles/ms/micons/man.png\"\n" \
"		, null, null, new google.maps.Point(16*scale, 32*scale), new google.maps.Size(32*scale, 32*scale));\n" \
"	var shadow = new google.maps.MarkerImage(\"http://maps.google.com/mapfiles/ms/micons/man.shadow.png\"\n" \
"		, null, null, new google.maps.Point(16*scale, 32*scale), new google.maps.Size(59*scale, 32*scale));\n" \
"	var marker = new google.maps.Marker({\n" \
"		position: location, \n" \
"		map: map,\n" \
"		draggable:true,\n" \
"		icon: icon,\n" \
"		shadow: shadow,\n" \
"	});\n" \
"	marker_id = addMarker(marker);\n" \
"\n" \
"	// click listener\n" \
"	google.maps.event.addListener(marker, \'click\', function() {\n" \
"		openInfoWindowForMarker(marker, marker_id);\n" \
"	});\n" \
"	\n" \
"	// drag end listener\n" \
"	google.maps.event.addListener(marker, \'dragend\', function() {\n" \
"		//infowindow.open(map,marker);\n" \
"		//openInfoWindowForMarker(marker, marker_id);\n" \
"		//updateBounds();\n" \
"		setIPhoneLocationToMarker(marker_id);\n" \
"		updateLatlngBox();\n" \
"	});\n" \
"\n" \
"	// draging listener\n" \
"	google.maps.event.addListener(marker, \'drag\', function() {\n" \
"		//openInfoWindowForMarker(marker, marker_id);\n" \
"		//updateBounds();\n" \
"	});\n" \
"	return marker;\n" \
"}\n" \
"\n" \
"function setCurrentLocationMarker(location) {\n" \
"	if (!g_currentLocationMarker) {\n" \
"		var marker = createCurrentLocationMarker(location);\n" \
"		g_currentLocationMarker = marker;\n" \
"	}\n" \
"	else {\n" \
"		g_currentLocationMarker.setPosition(location);\n" \
"	}\n" \
"	updateLatlngBox();\n" \
"}\n" \
"\n" \
"function updateLatlngBox() {\n" \
"	if (g_currentLocationMarker) {\n" \
"		updateLatlngBoxTo(g_currentLocationMarker.getPosition());\n" \
"	}\n" \
"	else {\n" \
"		$(\"#latlngBox\").val(\"\");\n" \
"	}\n" \
"}\n" \
"\n" \
"function updateLatlngBoxTo(latlng) {\n" \
"	var text = (\'\'+latlng.lat()).substr(0, 10)\n" \
"		+ \",\" + (\'\'+latlng.lng()).substr(0, 10);\n" \
"	$(\"#latlngBox\").val(text);\n" \
"}\n" \
"\n" \
"function openInfoWindowForMarker(marker, marker_id)\n" \
"{\n" \
"	var contentString = \'<div style=\"font-size:small;\">\'\n" \
"	+ \'lat:\' + (\'\'+marker.getPosition().lat()).substr(0, 10)\n" \
"	+ \' lng:\' + (\'\'+marker.getPosition().lng()).substr(0, 10) + \'<br></div>\'\n" \
"	+ \'\';\n" \
"	var infowindow = new google.maps.InfoWindow({\n" \
"		content: contentString\n" \
"	});\n" \
"	if (g_infowindow) {\n" \
"		g_infowindow.close();\n" \
"		g_infowindow = null;\n" \
"	}\n" \
"	marker.infowindow = infowindow;\n" \
"	infowindow.open(map,marker);\n" \
"	g_infowindow = infowindow;\n" \
"}\n" \
"\n" \
"//! send marker location to iphone\n" \
"function setIPhoneLocationToMarker(marker_id) {\n" \
"	var marker = markers[marker_id];\n" \
"	if (!marker) return;\n" \
"	\n" \
"	var latlng = marker.getPosition();\n" \
"	var accuracy = $(\'input:radio[name=accuracy]:checked\').val();\n" \
"	setIPhoneLocation(latlng, 0 + accuracy);\n" \
"}\n" \
"\n" \
"//! set iphone location\n" \
"function setIPhoneLocation(latlng, acc) {\n" \
"	if (acc == null) {\n" \
"		var accuracy = $(\'input:radio[name=accuracy]:checked\').val();\n" \
"		acc = 0 + accuracy;\n" \
"	}\n" \
"	jQuery.get(\"/post_location?lat=\"+latlng.lat()+\"&lon=\"+latlng.lng()+\"&acc=\"+acc);\n" \
"}\n" \
"\n" \
"\n" \
"function onGeocodeSuccess(data, textStatus, jqXHR)\n" \
"{\n" \
"	if (data[\"status\"] == \"OK\") {\n" \
"		var loc = data[\"results\"][\"geometry\"][\"location\"];\n" \
"		var latlng = new google.maps.LatLng(0.0 + loc[\"lat\"], 0.0 + loc[\"lng\"]);\n" \
"		map.setCenter(latlng);\n" \
"	}\n" \
"}\n" \
"\n" \
"function geocode()\n" \
"{\n" \
"	var geocoder = new google.maps.Geocoder();\n" \
"	\n" \
"	var addrname = $(\"#nameForGeocoding\").val();\n" \
"	geocoder.geocode( {\'address\': addrname }, function(results, status) {\n" \
"		if (results.length == 0) {\n" \
"			alert(\"Not found a location for \\\"\"+addrname+\"\\\"\");\n" \
"			return;\n" \
"		}\n" \
"		var item = results[0];\n" \
"		map.setCenter(item.geometry.location);\n" \
"	});\n" \
"}\n" \
"\n" \
"function processLatlngInput()\n" \
"{\n" \
"	var text = $(\"#latlngBox\").val();\n" \
"	var latlngary = text.split(\",\");\n" \
"	if (latlngary.length != 2) {\n" \
"		alert(\"please input latitude and longitude values separated by colon. \\nex: 35.6967544,139.755347\");\n" \
"		return;\n" \
"	}\n" \
"	var latlng = new google.maps.LatLng(latlngary[0],latlngary[1]);\n" \
"	setCurrentLocationMarker(latlng);\n" \
"	setIPhoneLocation(latlng);\n" \
"	map.setCenter(latlng);\n" \
"}\n" \
"\n" \
"\n" \
"\n" \
"</script>\n" \
"\n" \
"</head>\n" \
"\n" \
"<body onload=\"initialize()\">\n" \
"<div style=\"float:left;\">\n" \
"<div id=\"map_canvas\" style=\"width: 600px; height: 450px\"></div>\n" \
"	click or drag <img src=\"http://maps.google.com/mapfiles/ms/micons/man.png\"> on the map to set location for the iPhone.<br>\n" \
"</div>\n" \
"\n" \
"<div style=\"float:left; margin:10px;\">\n" \
"	<p>Location hijack controller for iPhone development.</p>\n" \
"\n" \
"	<input id=\"nameForGeocoding\" type=\"text\" onkeydown=\"if (event.keyCode==13) geocode();\"></input>\n" \
"	<button onclick=\"geocode()\">search for address</button><br>\n" \
"	\n" \
"	<input id=\"latlngBox\" type=\"text\" onkeydown=\"if (event.keyCode==13) processLatlngInput();\"></input>\n" \
"	<button onclick=\"processLatlngInput()\">set location by lat,lon</button><br>\n" \
"	<br>\n" \
"\n" \
"	accuracy: <br>\n" \
"	<input name=\"accuracy\" id=\"accuracy_10\" type=\"radio\" value =\"10\">10</input>\n" \
"	<input name=\"accuracy\" id=\"accuracy_50\" type=\"radio\" value =\"50\" checked >50</input>\n" \
"	<input name=\"accuracy\" id=\"accuracy_100\" type=\"radio\" value =\"100\">100</input>\n" \
"	<input name=\"accuracy\" id=\"accuracy_500\" type=\"radio\" value =\"500\">500</input>\n" \
"	<input name=\"accuracy\" id=\"accuracy_1000\" type=\"radio\" value =\"1000\">1000</input><br>\n" \
"\n" \
"	<br>\n" \
"</div>\n" \
"\n" \
"<!--Debug Info:-->\n" \
"<div style=\"float:right;\"><br>\n" \
"	<div id=\"debugwin\" style=\"width:600px; font-size:small;\"><div id=\"debugwin_centinel\"></div></div>\n" \
"</div>\n" \
"\n" \
"<!--Result Area:-->\n" \
"<div id=\"result_area\" style=\"float:left;\"><br>\n" \
"\n" \
"</div>\n" \
"\n" \
"\n" \
"\n" \
"</body>\n" \
"</html>\n" \



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
#endif // #ifdef DEBUG
