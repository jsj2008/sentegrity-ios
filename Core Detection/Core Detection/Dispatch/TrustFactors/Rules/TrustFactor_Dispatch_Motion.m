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
    

    
    // Get pitch/roll motion dataset
    NSArray *pitchRoll;
    
    // Attempt to get motion data
    pitchRoll = [[Sentegrity_TrustFactor_Datasets sharedDatasets] getGyroPitchInfo];
    
    // Check motion dataset has something
    if (!pitchRoll || pitchRoll == nil ) {
        
        [trustFactorOutputObject setStatusCode:DNEStatus_unavailable];
        // Return with the blank output object
        return trustFactorOutputObject;
    }
    
    // Get movement dataset
    float movement=0.0;
    movement = [[[Sentegrity_TrustFactor_Datasets sharedDatasets] getGripMovement] floatValue];
    
    if(!movement || movement == 0.0 ){
        
        [trustFactorOutputObject setStatusCode:DNEStatus_unavailable];
        // Return with the blank output object
        return trustFactorOutputObject;
        
    }
    
    // Process pitch/roll
    
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
    pitchAvg = pitchTotal/counter;
    rollAvg = rollTotal/counter;
    
    // Rounding from policy
    float pitchBlockSize = [[[payload objectAtIndex:0] objectForKey:@"pitchBlockSize"] floatValue];
    float rollBlockSize = [[[payload objectAtIndex:0] objectForKey:@"rollBlockSize"] floatValue];

    // Calculate blocks
    int pitchBlock = round(pitchAvg / pitchBlockSize);
    int rollBlock = round(rollAvg / rollBlockSize);
    
    //[outputArray addObject:[NSString stringWithFormat:@"pitch_%.*f,roll_%.*f",decimalPlaces,pitchAvg,decimalPlaces,rollAvg]];
    
    //Combine into tuple
    NSString *motionTuple = [NSString stringWithFormat:@"pitch_%d,roll_%d",pitchBlock,rollBlock];
    
    
    // Process movement
    int movementBlock = round(movement / 0.1);
    
    // Combine with tuple

    // Do not allow a grip that indicates the device is sitting on something
    if(pitchBlock==0 && movementBlock==0){
        
        [trustFactorOutputObject setStatusCode:DNEStatus_invalid];
        // Return with the blank output object
        return trustFactorOutputObject;
        
    }
    
    [outputArray addObject:motionTuple];
    
    // Set the trustfactor output to the output array (regardless if empty)
    [trustFactorOutputObject setOutput:outputArray];
    
    // Return the trustfactor output object
    return trustFactorOutputObject;
    
}

// Get motion using gyroscope
+ (Sentegrity_TrustFactor_Output_Object *)movement:(NSArray *)payload {
    
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
    
    
    // Check if error was determined by user movement in the app delegate
    if ([[Sentegrity_TrustFactor_Datasets sharedDatasets]  userMovementDNEStatus] != 0 ){
        
        // Set the DNE status code to what was previously determined
        [trustFactorOutputObject setStatusCode:[[Sentegrity_TrustFactor_Datasets sharedDatasets]  userMovementDNEStatus]];
        
        // Return with the blank output object
        return trustFactorOutputObject;
    }
    
    // Get device movement dataset
    float gripMovement=0.0;
    gripMovement = [[[Sentegrity_TrustFactor_Datasets sharedDatasets] getGripMovement] floatValue];
    
    if(!gripMovement || gripMovement == 0.0 ){
        
        [trustFactorOutputObject setStatusCode:DNEStatus_unavailable];
        // Return with the blank output object
        return trustFactorOutputObject;
        
    }
    
    float movementBlockSize = [[[payload objectAtIndex:0] objectForKey:@"movementBlockSize"] floatValue];
    
    // Process movement
    int movementBlock = round(gripMovement / movementBlockSize);
    

    // Get user movement dataset
    NSString *userMovement = [[Sentegrity_TrustFactor_Datasets sharedDatasets] getUserMovement];

    //Combine into tuple
    NSString *motionTuple = [NSString stringWithFormat:@"gripMovement_%d,device_Movement%@",movementBlock,userMovement];
    
    [outputArray addObject:motionTuple];
    
    // Set the trustfactor output to the output array (regardless if empty)
    [trustFactorOutputObject setOutput:outputArray];
    
    // Return the trustfactor output object
    return trustFactorOutputObject;
    
}


/* Old/Archived
 
 + (Sentegrity_TrustFactor_Output_Object *)moving:(NSArray *)payload {
     
     // Create the trustfactor output object
     Sentegrity_TrustFactor_Output_Object *trustFactorOutputObject = [[Sentegrity_TrustFactor_Output_Object alloc] init];
     
     // Set the default status code to OK (default = DNEStatus_ok)
     [trustFactorOutputObject setStatusCode:DNEStatus_ok];
     
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
     if([[[Sentegrity_TrustFactor_Datasets sharedDatasets] movement] intValue] == 1){
         
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
    
    NSString *orientation = [[Sentegrity_TrustFactor_Datasets sharedDatasets] getDeviceOrientation];
    
    [outputArray addObject:orientation];
    
    // Do not allow a grip that indicates the device is sitting on something
    if([orientation isEqual:@"Face_Up"] || [orientation isEqual: @"Face_Down"] || [orientation  isEqual: @"unknown"]){
        
        [trustFactorOutputObject setStatusCode:DNEStatus_invalid];
        // Return with the blank output object
        return trustFactorOutputObject;
        
    }
    
    // Set the trustfactor output to the output array (regardless if empty)
    [trustFactorOutputObject setOutput:outputArray];
    
    // Return the trustfactor output object
    return trustFactorOutputObject;
    
}





@end