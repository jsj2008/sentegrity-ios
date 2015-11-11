//
//  TrustFactor_Dispatch_Wifi.m
//  Sentegrity
//
//  Copyright (c) 2015 Sentegrity. All rights reserved.
//

#import "TrustFactor_Dispatch_Wifi.h"
#import <SystemConfiguration/CaptiveNetwork.h>
#import <ifaddrs.h>
#import <net/if.h>

@implementation TrustFactor_Dispatch_Wifi

// Determine if the connected access point is a SOHO (Small Office/Home Offic) network
+ (Sentegrity_TrustFactor_Output_Object *)highRiskAP:(NSArray *)payload {
    
    // Create the trustfactor output object
    Sentegrity_TrustFactor_Output_Object *trustFactorOutputObject = [[Sentegrity_TrustFactor_Output_Object alloc] init];
    
    // Set the default status code to OK (default = DNEStatus_ok)
    [trustFactorOutputObject setStatusCode:DNEStatus_ok];
    
    // Create the output array
    NSMutableArray *outputArray = [[NSMutableArray alloc] init];
    
    
    // Check if WiFi is disabled
    if([[[Sentegrity_TrustFactor_Datasets sharedDatasets] isWifiEnabled] intValue]==0){
        
        //Not enabled, set DNE and return (penalize)
        [trustFactorOutputObject setStatusCode:DNEStatus_disabled];
        
        // Return with the blank output object
        return trustFactorOutputObject;
        
    }    // If we're enabled, still check if we're tethering and set as unavaialble if we are
    else if([[[Sentegrity_TrustFactor_Datasets sharedDatasets] isTethering] intValue]==1){
        
        //Not enabled, set DNE and return (penalize)
        [trustFactorOutputObject setStatusCode:DNEStatus_unavailable];
        
        // Return with the blank output object
        return trustFactorOutputObject;
        
    }
    
    NSDictionary *wifiInfo = [[Sentegrity_TrustFactor_Datasets sharedDatasets] getWifiInfo];
    
    // Check for a connection
    if (wifiInfo == nil){
        
        // WiFi is enabled but there is no connection (don't penalize)
        [trustFactorOutputObject setStatusCode:DNEStatus_nodata];
        
        // Return with the blank output object
        return trustFactorOutputObject;
        
    }
    
    NSString *gatewayIP = [wifiInfo objectForKey:@"gatewayIP"];
    
    // Get the BSSID
    NSString *bssid = [wifiInfo objectForKey:@"bssid"];
    
    // Validate the gateway IP and BSSID
    if ((gatewayIP == nil && gatewayIP.length == 0) || (bssid == nil && bssid.length == 0)) {
        
        // Set the DNE status code to NODATA
        [trustFactorOutputObject setStatusCode:DNEStatus_nodata];
        
        // Return with the blank output object
        return trustFactorOutputObject;
    }
    
    // Check OUI of connected AP based on BSSID
    NSArray *ouiList;
    
    // Look for our OUI list
    NSString* ouiListPath = [[NSBundle mainBundle] pathForResource:@"oui" ofType:@"list"];
    
    NSString* fileContents =
    [NSString stringWithContentsOfFile:ouiListPath
                              encoding:NSUTF8StringEncoding error:nil];
    
    // If we didn't find our OUI list, fallback on payload list
    if(fileContents == nil) {
        
        // Try payload
        if (![[Sentegrity_TrustFactor_Datasets sharedDatasets] validatePayload:payload]) {
            // Payload is EMPTY
            
            // Set the DNE status code to NODATA
            [trustFactorOutputObject setStatusCode:DNEStatus_error];
            
            // Return with the blank output object
            return trustFactorOutputObject;
            
        } else {
            
            //Use the payload list
            ouiList = payload;
        }
        
    } else {
        
        ouiList =
        [fileContents componentsSeparatedByCharactersInSet:
         [NSCharacterSet newlineCharacterSet]];
    }
    
    bool match = NO;
    // Run through the payload and compare to the BSSID
    for (NSString *oui in ouiList) {
        // Check if the bssid matches one of the OUI's in the payload or IP is 192.168.1.1
        if ([bssid rangeOfString:oui options:NSCaseInsensitiveSearch].location != NSNotFound ) {
            
            //|| [gatewayIP containsString:@"192.168.1.1"]
            // Add the current ssid to the list (we add the SSID to avoid having the TF trigger again if the device roams to a new AP on the same network)
            [outputArray addObject:[wifiInfo objectForKey:@"ssid"]];
            match=YES;
            
            // Break from the for loop
            break;
        }
    }
    
    // If no OUI match resort to IP
    if (!match){
        if([gatewayIP containsString:@"192.168.1.1"]){
            [outputArray addObject:[wifiInfo objectForKey:@"ssid"]];
        }
    }
    
    // Set the trustfactor output to the output array (regardless if empty)
    [trustFactorOutputObject setOutput:outputArray];
    
    // Return the trustfactor output object
    return trustFactorOutputObject;
    
}

// Captive Portal Unencrypted AP Check - Not available
/* DEPRECATED
 + (Sentegrity_TrustFactor_Output_Object *)captivePortal:(NSArray *)payload {
 
 // Create the trustfactor output object
 Sentegrity_TrustFactor_Output_Object *trustFactorOutputObject = [[Sentegrity_TrustFactor_Output_Object alloc] init];
 
 // Set the default status code to OK (default = DNEStatus_ok)
 [trustFactorOutputObject setStatusCode:DNEStatus_ok];
 
 // Create the output array
 NSMutableArray *outputArray = [[NSMutableArray alloc] initWithCapacity:1];
 
 //No connection, check if WiFi is enabled
 if([[Sentegrity_TrustFactor_Datasets sharedDatasets] isWifiEnabled]==NO){
 
 //Not enabled, set DNE and return (penalize)
 [trustFactorOutputObject setStatusCode:DNEStatus_disabled];
 
 // Return with the blank output object
 return trustFactorOutputObject;
 }
 
 NSDictionary *wifiInfo = [[Sentegrity_TrustFactor_Datasets sharedDatasets] getWifiInfo];
 
 // Check for a connection
 if (wifiInfo == nil){
 
 //WiFi is enabled but there is no connection (don't penalize)
 [trustFactorOutputObject setStatusCode:DNEStatus_nodata];
 
 // Return with the blank output object
 return trustFactorOutputObject;
 
 }
 
 NSString *ssid = [wifiInfo objectForKey:@"ssid"];
 
 
 //Perform WISPR check
 NSString *url =@"http://www.apple.com/library/test/success.html";
 NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc]
 initWithURL:[NSURL URLWithString:[url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
 
 [urlRequest setValue:@"CaptiveNetworkSupport/1.0 wispr" forHTTPHeaderField:@"User-Agent"];
 
 NSData *data = [ NSURLConnection sendSynchronousRequest:urlRequest returningResponse: nil error: nil ];
 NSString *returnDataWispr = [[NSString alloc] initWithBytes: [data bytes] length:[data length] encoding: NSUTF8StringEncoding];
 
 //Perform Blank page check
 url =@"http://www.google.com/blank.html";
 urlRequest = [[NSMutableURLRequest alloc]
 initWithURL:[NSURL URLWithString:[url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
 
 data = [ NSURLConnection sendSynchronousRequest:urlRequest returningResponse: nil error: nil ];
 NSString *returnDataBlank = [[NSString alloc] initWithBytes: [data bytes] length:[data length] encoding: NSUTF8StringEncoding];
 
 // Check if WISPR return something other than "Success" HTML AND if the AP returns a login page instead of blank during google check
 if(![returnDataWispr containsString:@"Success"] || [returnDataBlank length] > 1)
 {
 [outputArray addObject:ssid];
 }
 
 
 
 // Set the trustfactor output to the output array (regardless if empty)
 [trustFactorOutputObject setOutput:outputArray];
 
 // Return the trustfactor output object
 return trustFactorOutputObject;
 
 return 0;
 }
 
 */

// Unknown SSID Check - Get the current AP SSID
+ (Sentegrity_TrustFactor_Output_Object *)SSID:(NSArray *)payload {
    
    // Create the trustfactor output object
    Sentegrity_TrustFactor_Output_Object *trustFactorOutputObject = [[Sentegrity_TrustFactor_Output_Object alloc] init];
    
    // Set the default status code to OK (default = DNEStatus_ok)
    [trustFactorOutputObject setStatusCode:DNEStatus_ok];
    
    // Create the output array
    NSMutableArray *outputArray = [[NSMutableArray alloc] initWithCapacity:1];
    
    //Ceck if WiFi is disabled
    if([[[Sentegrity_TrustFactor_Datasets sharedDatasets] isWifiEnabled] intValue]==0){
        
        //Not enabled, set DNE and return (penalize)
        [trustFactorOutputObject setStatusCode:DNEStatus_disabled];
        
        // Return with the blank output object
        return trustFactorOutputObject;
        
    }    //If we're enabled, still check if we're tethering and set as unavaialble if we are
    else if([[[Sentegrity_TrustFactor_Datasets sharedDatasets] isTethering] intValue]==1){
        
        //Not enabled, set DNE and return (penalize)
        [trustFactorOutputObject setStatusCode:DNEStatus_unavailable];
        
        // Return with the blank output object
        return trustFactorOutputObject;
        
    }
    
    NSDictionary *wifiInfo = [[Sentegrity_TrustFactor_Datasets sharedDatasets] getWifiInfo];
    
    // Check for a connection
    if (wifiInfo == nil){
        
        //WiFi is enabled but there is no connection (don't penalize)
        [trustFactorOutputObject setStatusCode:DNEStatus_nodata];
        
        // Return with the blank output object
        return trustFactorOutputObject;
    }
    
    // Get the current Access Point SSID
    NSString *ssid = nil;
    
    ssid = [wifiInfo objectForKey:@"ssid"];
    
    // Validate the SSID
    if (ssid != nil && ssid.length > 0) {
        
        // Add the ssid to the output
        [outputArray addObject:ssid];
        
    } else {
        
        //WiFi is enabled but there is no connection (don't penalize)
        [trustFactorOutputObject setStatusCode:DNEStatus_nodata];
        
        // Return with the blank output object
        return trustFactorOutputObject;
        
    }
    // Set the trustfactor output to the output array (regardless if empty)
    [trustFactorOutputObject setOutput:outputArray];
    
    // Return the trustfactor output object
    return trustFactorOutputObject;
}

// Known BSSID - Get the current BSSID of the AP
+ (Sentegrity_TrustFactor_Output_Object *)BSSID:(NSArray *)payload {
    
    
    // Create the trustfactor output object
    Sentegrity_TrustFactor_Output_Object *trustFactorOutputObject = [[Sentegrity_TrustFactor_Output_Object alloc] init];
    
    // Set the default status code to OK (default = DNEStatus_ok)
    [trustFactorOutputObject setStatusCode:DNEStatus_ok];
    
    // Create the output array
    NSMutableArray *outputArray = [[NSMutableArray alloc] initWithCapacity:payload.count];
    
    //Ceck if WiFi is disabled
    if([[[Sentegrity_TrustFactor_Datasets sharedDatasets] isWifiEnabled] intValue]==0){
        
        //Not enabled, set DNE and return (penalize)
        [trustFactorOutputObject setStatusCode:DNEStatus_disabled];
        
        // Return with the blank output object
        return trustFactorOutputObject;
        
    }    //If we're enabled, still check if we're tethering and set as unavaialble if we are
    else if([[[Sentegrity_TrustFactor_Datasets sharedDatasets] isTethering] intValue]==1){
        
        //Not enabled, set DNE and return (penalize)
        [trustFactorOutputObject setStatusCode:DNEStatus_unavailable];
        
        // Return with the blank output object
        return trustFactorOutputObject;
        
    }
    
    NSDictionary *wifiInfo = [[Sentegrity_TrustFactor_Datasets sharedDatasets] getWifiInfo];
    
    // Check for a connection
    if (wifiInfo == nil){
        
        //WiFi is enabled but there is no connection (don't penalize)
        [trustFactorOutputObject setStatusCode:DNEStatus_nodata];
        
        // Return with the blank output object
        return trustFactorOutputObject;
        
    }
    
    // Get the current Access Point BSSID
    NSString *bssid = nil;
    
    // Get the current Access Point SSID
    NSString *ssid = nil;
    
    ssid = [wifiInfo objectForKey:@"ssid"];
    
    bssid = [wifiInfo objectForKey:@"bssid"];
    
    // Validate the BSSID and SSID
    if ((bssid != nil && bssid.length > 0) && (ssid != nil && ssid.length > 0)) {
        
        // Add the current bssid to the list
        [outputArray addObject:[[ssid stringByAppendingString:@","] stringByAppendingString:bssid]];
    }else{
        
        [trustFactorOutputObject setStatusCode:DNEStatus_nodata];
        
        return trustFactorOutputObject;
        
    }
    
    // Set the trustfactor output to the output array (regardless if empty)
    [trustFactorOutputObject setOutput:outputArray];
    
    
    // Return the trustfactor output object
    return trustFactorOutputObject;
}

// Unknown SSID Check - Get the current AP SSID
+ (Sentegrity_TrustFactor_Output_Object *)hotspotEnabled:(NSArray *)payload {
    
    // Create the trustfactor output object
    Sentegrity_TrustFactor_Output_Object *trustFactorOutputObject = [[Sentegrity_TrustFactor_Output_Object alloc] init];
    
    // Set the default status code to OK (default = DNEStatus_ok)
    [trustFactorOutputObject setStatusCode:DNEStatus_ok];
    
    // Create the output array
    NSMutableArray *outputArray = [[NSMutableArray alloc] initWithCapacity:1];
    
    if([[[Sentegrity_TrustFactor_Datasets sharedDatasets] isTethering] intValue]==1){
        
        [outputArray addObject:@"hotspotOn"];
        
    }
    
    // Set the trustfactor output to the output array (regardless if empty)
    [trustFactorOutputObject setOutput:outputArray];
    
    // Return the trustfactor output object
    return trustFactorOutputObject;
}

@end
