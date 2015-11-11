//
//  TrustFactor_Dispatch_Activity.m
//  Sentegrity
//
//  Copyright (c) 2015 Sentegrity. All rights reserved.
//

#import "TrustFactor_Dispatch_Motion.h"

@implementation TrustFactor_Dispatch_Motion

// Get motion using gyroscope
+ (Sentegrity_TrustFactor_Output_Object *)grip:(NSArray *)payload {
    
    // Create the trustfactor output object
    Sentegrity_TrustFactor_Output_Object *trustFactorOutputObject = [[Sentegrity_TrustFactor_Output_Object alloc] init];
    
    // Set the default status code to OK (default = DNEStatus_ok)
    [trustFactorOutputObject setStatusCode:DNEStatus_ok];
    
    // Validate the payload
    if (![[Sentegrity_TrustFactor_Datasets sharedDatasets] validatePayload:payload]) {
        // Payload is EMPTY
        
        // Set the DNE status code to NODATA
        [trustFactorOutputObject setStatusCode:DNEStatus_nodata];
        
        // Return with the blank output object
        return trustFactorOutputObject;
    }
    
    // Create the output array
    NSMutableArray *outputArray = [[NSMutableArray alloc] initWithCapacity:payload.count];
    
    // Make sure device is steady enough to take a reading
    
    // Get motion dataset
    NSArray *gyroRads;
    
    // Check if error was already determined when motion was started
    if ([[Sentegrity_TrustFactor_Datasets sharedDatasets] gyroMotionDNEStatus] != 0 ){
        // Set the DNE status code to what was previously determined
        [trustFactorOutputObject setStatusCode:[[Sentegrity_TrustFactor_Datasets sharedDatasets] gyroMotionDNEStatus]];
        
        // Return with the blank output object
        return trustFactorOutputObject;
        
    } else { // No known errors occured previously, try to get dataset and check our object
        
        // Attempt to get motion data
        gyroRads = [[Sentegrity_TrustFactor_Datasets sharedDatasets] getGyroRadsInfo];
        
        // Check if error from dataset (expired)
        if ([[Sentegrity_TrustFactor_Datasets sharedDatasets] gyroMotionDNEStatus] != 0 ){
            // Set the DNE status code to what was previously determined
            [trustFactorOutputObject setStatusCode:[[Sentegrity_TrustFactor_Datasets sharedDatasets] gyroMotionDNEStatus]];
            
            // Return with the blank output object
            return trustFactorOutputObject;
        }
        
        // Check motion dataset has something
        if (!gyroRads || gyroRads == nil ) {
            
            [trustFactorOutputObject setStatusCode:DNEStatus_unavailable];
            // Return with the blank output object
            return trustFactorOutputObject;
        }
    }
    
    // Detect if its moving
    if([[[Sentegrity_TrustFactor_Datasets sharedDatasets] isMoving] intValue] == 1){
        
        [trustFactorOutputObject setStatusCode:DNEStatus_unavailable];
        // Return with the blank output object
        return trustFactorOutputObject;
        
    }
    
    // Get motion dataset
    NSArray *pitchRoll;
    
    // Attempt to get motion data
    pitchRoll = [[Sentegrity_TrustFactor_Datasets sharedDatasets] getGyroPitchInfo];
    
    // Check motion dataset has something
    if (!pitchRoll || pitchRoll == nil ) {
        
        [trustFactorOutputObject setStatusCode:DNEStatus_unavailable];
        // Return with the blank output object
        return trustFactorOutputObject;
    }
    
    // Total of all samples based on pitch/roll
    float pitchTotal = 0.0;
    float rollTotal = 0.0;
    
    // Averages calculated across all samples
    float pitchAvg = 0.0;
    float rollAvg = 0.0;
    
    float counter = 1.0;
    
    // Run through all the sample we got prior to stopping motion
    for (NSDictionary *sample in pitchRoll) {
        
        // Get the accelerometer data
        float pitch = [[sample objectForKey:@"pitch"] floatValue];
        float roll = [[sample objectForKey:@"roll"] floatValue];
        
        pitchTotal = pitchTotal + pitch;
        rollTotal = rollTotal + roll;
        
        counter++;
        
    }
    
    // Calculate averages and take abs since we're adding the orientation anyhow (makes block sizes easier to calculate)
    pitchAvg = fabs(pitchTotal/counter);
    rollAvg = fabs(rollTotal/counter);
    
    // Rounding from policy
    float blockSize = [[[payload objectAtIndex:0] objectForKey:@"blockSize"] intValue];
    
    // Check motion dataset has something
    if (blockSize == 0) {
        
        [trustFactorOutputObject setStatusCode:DNEStatus_error];
        // Return with the blank output object
        return trustFactorOutputObject;
    }
    
    // if(pitchAvg > 1.0){
    //  pitchAvg = 0.99;
    //}
    
    //if(rollAvg > 1.0){
    //  rollAvg = 0.99;
    //}
    
    
    //Figure blocks
    int pitchBlock = ceilf(pitchAvg / (1/blockSize));
    int rollBlock = ceilf(rollAvg / (1/blockSize));
    
    
    //[outputArray addObject:[NSString stringWithFormat:@"pitch_%.*f,roll_%.*f",decimalPlaces,pitchAvg,decimalPlaces,rollAvg]];
    
    //Combine into tuple
    NSString *motionTuple = [NSString stringWithFormat:@"pitch_%d,roll_%d",pitchBlock,rollBlock];
    
    
    [outputArray addObject:motionTuple];
    
    // Set the trustfactor output to the output array (regardless if empty)
    [trustFactorOutputObject setOutput:outputArray];
    
    // Return the trustfactor output object
    return trustFactorOutputObject;
    
}

/* removed, motion check is now only inside the grip rule, means we can't relay a suggestion but thats OK
 
 + (Sentegrity_TrustFactor_Output_Object *)moving:(NSArray *)payload {
 
 // Create the trustfactor output object
 Sentegrity_TrustFactor_Output_Object *trustFactorOutputObject = [[Sentegrity_TrustFactor_Output_Object alloc] init];
 
 // Set the default status code to OK (default = DNEStatus_ok)
 [trustFactorOutputObject setStatusCode:DNEStatus_ok];
 
 // Validate the payload
 if (![[Sentegrity_TrustFactor_Datasets sharedDatasets] validatePayload:payload]) {
 // Payload is EMPTY
 
 // Set the DNE status code to NODATA
 [trustFactorOutputObject setStatusCode:DNEStatus_nodata];
 
 // Return with the blank output object
 return trustFactorOutputObject;
 }
 
 // Create the output array
 NSMutableArray *outputArray = [[NSMutableArray alloc] initWithCapacity:payload.count];
 
 // Get motion dataset
 NSArray *gryoRads;
 
 
 // Check if error was already determined when motion was started
 if ([[Sentegrity_TrustFactor_Datasets sharedDatasets] gyroMotionDNEStatus] != 0 ){
 // Set the DNE status code to what was previously determined
 [trustFactorOutputObject setStatusCode:[[Sentegrity_TrustFactor_Datasets sharedDatasets] gyroMotionDNEStatus]];
 
 // Return with the blank output object
 return trustFactorOutputObject;
 } else { // No known errors occured previously, try to get dataset and check our object
 
 // Attempt to get motion data
 gryoRads = [[Sentegrity_TrustFactor_Datasets sharedDatasets] getGyroRadsInfo];
 
 // Check if error from dataset
 if ([[Sentegrity_TrustFactor_Datasets sharedDatasets] gyroMotionDNEStatus] != 0 ){
 // Set the DNE status code to what was previously determined
 [trustFactorOutputObject setStatusCode:[[Sentegrity_TrustFactor_Datasets sharedDatasets] gyroMotionDNEStatus]];
 
 // Return with the blank output object
 return trustFactorOutputObject;
 }
 
 // Check motion dataset has something
 if (!gryoRads || gryoRads == nil ) {
 
 [trustFactorOutputObject setStatusCode:DNEStatus_unavailable];
 // Return with the blank output object
 return trustFactorOutputObject;
 }
 }
 
 // Blocksize to smooth dataset
 float xThreshold = [[[payload objectAtIndex:0] objectForKey:@"xThreshold"] floatValue];
 float yThreshold = [[[payload objectAtIndex:0] objectForKey:@"yThreshold"] floatValue];
 float zThreshold = [[[payload objectAtIndex:0] objectForKey:@"zThreshold"] floatValue];
 
 if (xThreshold == 0 || yThreshold == 0 || zThreshold == 0) {
 
 [trustFactorOutputObject setStatusCode:DNEStatus_error];
 // Return with the blank output object
 return trustFactorOutputObject;
 }
 
 float xDiff = 0.0;
 float yDiff = 0.0;
 float zDiff = 0.0;
 
 
 float lastX = 0.0;
 float lastY = 0.0;
 float lastZ = 0.0;
 
 // Run through all the sample we got prior to stopping motion
 for (NSDictionary *sample in gryoRads) {
 
 float x = [[sample objectForKey:@"x"] floatValue];
 float y = [[sample objectForKey:@"y"] floatValue];
 float z = [[sample objectForKey:@"z"] floatValue];
 
 // this is the first sample, just record last and go to next
 if(lastX==0.0){
 lastX = x;
 lastY = y;
 lastZ = z;
 continue;
 }
 // Add up differences to detect motion, take absolute value to prevent
 
 xDiff = xDiff + fabsf((lastX - x));
 yDiff = yDiff + fabsf((lastY - y));
 zDiff = zDiff + fabsf((lastZ - z));
 
 }
 
 // Check against thesholds?
 if(xDiff > xThreshold || yDiff > yThreshold || zDiff > zThreshold){
 [outputArray addObject:@"motion"];
 
 }
 
 
 // Set the trustfactor output to the output array (regardless if empty)
 [trustFactorOutputObject setOutput:outputArray];
 
 // Return the trustfactor output object
 return trustFactorOutputObject;
 
 }
 
 */

// Get's the device's orientation
+ (Sentegrity_TrustFactor_Output_Object *)orientation:(NSArray *)payload {
    
    // Create the trustfactor output object
    Sentegrity_TrustFactor_Output_Object *trustFactorOutputObject = [[Sentegrity_TrustFactor_Output_Object alloc] init];
    
    // Set the default status code to OK (default = DNEStatus_ok)
    [trustFactorOutputObject setStatusCode:DNEStatus_ok];
    
    // Create the output array
    NSMutableArray *outputArray = [[NSMutableArray alloc] initWithCapacity:payload.count];
    
    [outputArray addObject:[[Sentegrity_TrustFactor_Datasets sharedDatasets] getDeviceOrientation]];
    
    // Set the trustfactor output to the output array (regardless if empty)
    [trustFactorOutputObject setOutput:outputArray];
    
    // Return the trustfactor output object
    return trustFactorOutputObject;
    
}





@end