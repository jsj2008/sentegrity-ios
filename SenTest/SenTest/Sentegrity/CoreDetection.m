//
//  CoreDetection.m
//  SenTest
//
//  Created by Nick Kramer on 1/31/15.
//  Copyright (c) 2015 Walid Javed. All rights reserved. 
//

#import "CoreDetection.h"
#import "Sentegrity_Constants.h"
#import "Sentegrity_Parser.h"
#import "Sentegrity_Policy.h"
#import "Sentegrity_TrustFactor.h"
//#import "Sentegrity_Classification.h"
//#import "Sentegrity_Subclassification.h"
#import "Sentegrity_TrustFactor_Dispatcher.h"
#import "Sentegrity_TrustFactor_Storage.h"

// Categories
#import "Sentegrity_Classification+Computation.h"
#import "Sentegrity_Subclassification+Computation.h"
#import "Sentegrity_Baseline_Analysis.h"

@interface CoreDetection(Private)

// Parse policy
- (Sentegrity_Policy *)parsePolicy:(NSURL *)policyPath isDefaultPolicy:(BOOL)isDefault withError:(NSError **)error;

// Protect Mode Analysis Callback
- (void)coreDetectionResponse:(BOOL)success withDevice:(BOOL)deviceTrusted withSystem:(BOOL)systemTrusted withUser:(BOOL)userTrusted andComputation:(NSArray *)computationOutput error:(NSError *)error;

@end

@implementation CoreDetection

@synthesize defaultPolicyURLPath;

#pragma mark - Protect Mode Analysis

// Callback block definition
void (^coreDetectionBlockCallBack)(BOOL success, BOOL deviceTrusted, BOOL systemTrusted, BOOL userTrusted, NSArray *computationOutput, NSError *error);

// Start Core Detection
- (void)performCoreDetectionWithPolicy:(Sentegrity_Policy *)policy withTimeout:(int)timeOut withCallback:(coreDetectionBlock)callback {
    
    // Set the callback block to be the block definition
    coreDetectionBlockCallBack = callback;
    
    // Create the error to use
    NSError *error = nil;
    
    
    // Make sure policy.trustFactors are set
    if (!policy || policy.trustFactors.count < 1 || !policy.trustFactors) {
        // Error out, no trustfactors set
        NSMutableDictionary *errorDetails = [NSMutableDictionary dictionary];
        [errorDetails setValue:@"No TrustFactors found to analyze" forKey:NSLocalizedDescriptionKey];
        error = [NSError errorWithDomain:@"Sentegrity" code:SANoTrustFactorsSetToAnalyze userInfo:errorDetails];
        
        // Don't return anything
        [self coreDetectionResponse:NO withDevice:NO withSystem:NO withUser:NO andComputation:nil error:error];
        return;
    }
    

    // ******************************************************************
    // Start Dispatcher (executes trustfactors and populates output objects)
    // ******************************************************************
    
    NSArray *trustFactorOutputObjects = [Sentegrity_TrustFactor_Dispatcher performTrustFactorAnalysis:policy.trustFactors withError:&error];
    
    // Check for valid trustFactorOutputObjects
    if (!trustFactorOutputObjects || trustFactorOutputObjects == nil || trustFactorOutputObjects.count < 1) {
        // Error out, no trustfactors output
        NSMutableDictionary *errorDetails = [NSMutableDictionary dictionary];
        [errorDetails setValue:@"No TrustFactors outputs returned from dispatchere" forKey:NSLocalizedDescriptionKey];
        error = [NSError errorWithDomain:@"Sentegrity" code:SANoTrustFactorsSetToAnalyze userInfo:errorDetails];
        
        // Don't return anything
        [self coreDetectionResponse:NO withDevice:NO withSystem:NO withUser:NO andComputation:nil error:error];
        return;
    }

    // ******************************************************************
    // Perform Baseline Analysis (get stored trustfactor objects and compare)
    // ******************************************************************
    
    // Retrieve storedTrustFactorObjects & attach to trustFactorOutputObjects
    Sentegrity_Baseline_Analysis *baselineAnalysisResults = [Sentegrity_Baseline_Analysis performBaselineAnalysisUsing:trustFactorOutputObjects forPolicy:policy withError:&error];
    
    // Check that we have objects for computation
    if (!baselineAnalysisResults.trustFactorOutputObjectsForComputation || baselineAnalysisResults.trustFactorOutputObjectsForComputation == nil || baselineAnalysisResults.trustFactorOutputObjectsForComputation.count < 1) {
        // Error out, no trustfactors for computation
        NSMutableDictionary *errorDetails = [NSMutableDictionary dictionary];
        [errorDetails setValue:@"No trustFactorOutputObjects available for computation" forKey:NSLocalizedDescriptionKey];
        error = [NSError errorWithDomain:@"Sentegrity" code:SANoTrustFactorOutputObjectsForComputation userInfo:errorDetails];

        [self coreDetectionResponse:NO withDevice:NO withSystem:NO withUser:NO andComputation:nil error:error];
        return;
    }
    
    
    // ******************************************************************
    // Perform TrustScore Computation (generates scores)
    // ******************************************************************

    Sentegrity_TrustScore_Computation *computationResults = [Sentegrity_TrustScore_Computation performTrustFactorComputationWithPolicy:policy withTrustFactorOutputObjects:baselineAnalysisResults.trustFactorOutputObjectsForComputation withError:&error];
    
    // Validate the computation
    if (!computationResults || computationResults == nil) {
        // Error out, no computation object
        NSMutableDictionary *errorDetails = [NSMutableDictionary dictionary];
        [errorDetails setValue:@"No computation object returned, error during computation" forKey:NSLocalizedDescriptionKey];
        error = [NSError errorWithDomain:@"Sentegrity" code:SAErrorDuringComputation userInfo:errorDetails];
        
        [self coreDetectionResponse:NO withDevice:NO withSystem:NO withUser:NO andComputation:nil error:error];
        return;
    }

    // ******************************************************************
    // Save Stores (write assertion stores to disk)
    // ******************************************************************
    
    //write the assertion stores
    [self saveStoresForPolicy:policy withError:&error];
    

    
    // ******************************************************************
    // Protect Mode Analysis (take actions outlined in policy as result of scores)
    // ******************************************************************
    
    //Jason needs to finish this, we may need a new structure to hold the history data for each run that gets written out....
    [self protectModeAnalysisWithPolicy:policy withComputationResults:computationResults withBaselineAnalysisResults:baselineAnalysisResults error:error];
    
    
    
}


- (void)protectModeAnalysisWithPolicy:(Sentegrity_Policy *)policy withComputationResults:(Sentegrity_TrustScore_Computation *)computationResults withBaselineAnalysisResults:(Sentegrity_Baseline_Analysis *)baselineAnalysisResults error:(NSError *)error {
    
    // Check if the system, user, and device are trusted
    BOOL systemTrusted, userTrusted, deviceTrusted;
    NSLog(@"System Threshold: %ld User Threshold: %ld", policy.systemThreshold.integerValue, policy.userThreshold.integerValue);
    // Check for
    if (computationResults.systemScore < policy.systemThreshold.integerValue) {
        // System is not trusted
        systemTrusted = NO;
        //trigger
        
    } else {
        // System is trusted
        systemTrusted = YES;
    }
    
    // Check the user
    if (computationResults.userScore < policy.userThreshold.integerValue) {
        // User is not trusted
        userTrusted = NO;
    } else {
        // User is trusted
        userTrusted = YES;
    }
    
    // Check the device
    if (!systemTrusted || !userTrusted) {
        // Device is not trusted
        deviceTrusted = NO;
    } else {
        // Device is trusted
        deviceTrusted = YES;
    }
    
    // Return through the block callback
    [self coreDetectionResponse:YES withDevice:deviceTrusted withSystem:systemTrusted withUser:userTrusted andComputation:computationResults.triggeredTrustFactorOutputObjects error:error];
    
    if(!deviceTrusted) //device not trusted
    {
        if(!userTrusted) //user untrusted
        {
            
            //determine attributing classification (user anomaly or policy violation?)
            
            //write the history file w/ scores, current protect mode, and cooresponding whitelist assertion array (held in baselineAnalysis object)
            //[device score, device trusted, system score, system trusted, user score, user trusted, assertions to whitelist]
            
            //take classification's cooresponding protect mode action (show screen for Beta2)
            
        }
        else //system untrusted
        {
            //determine attributing classification (system anomaly or breach indicator?)
            
            //write the history file w/ scores, current protect mode, and cooresponding whitelist assertion array (held in baselineAnalysis object)
            //[device score, device trusted, system score, system trusted, user score, user trusted, assertions to whitelist]
            
            //take classification's cooresponding protect mode action
            
        }
    }
    else //device trusted
    {
        
        //write the history file w/ scores, current protect mode
        //[device score, device trusted, system score, system trusted, user score, user trusted, assertions to whitelist]
        
        //show dashboard
    }
    
}
// Callback function for core detection
- (void)coreDetectionResponse:(BOOL)success withDevice:(BOOL)deviceTrusted withSystem:(BOOL)systemTrusted withUser:(BOOL)userTrusted andComputation:(NSArray *)computationOutput error:(NSError *)error {
    // Block callback
    coreDetectionBlockCallBack(success, deviceTrusted, systemTrusted, userTrusted, computationOutput, error);
}

#pragma mark Singleton Methods

// Singleton shared instance
+ (id)sharedDetection {
    static CoreDetection *sharedMyDetection = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyDetection = [[self alloc] init];
    });
    return sharedMyDetection;
}

// Init (Defaults)
- (id)init {
    if (self = [super init]) {
        // Set defaults here if need be
        [self setDefaultPolicyURLPath:nil];
    }
    return self;
}

#pragma mark - Outside methods

// Parse Default Policy
- (Sentegrity_Policy *)parseDefaultPolicy:(NSError **)error {
    return [self parsePolicy:defaultPolicyURLPath isDefaultPolicy:YES withError:error];
}

// Parse a Custom Policy
- (Sentegrity_Policy *)parseCustomPolicy:(NSURL *)customPolicyPath withError:(NSError **)error {
    return [self parsePolicy:customPolicyPath isDefaultPolicy:NO withError:error];
}



// write assertion store changes back to disc
- (void)saveStoresForPolicy:(Sentegrity_Policy *)policy withError:(NSError **)error {
    
    
    Sentegrity_Assertion_Store *localStore = [[Sentegrity_Assertion_Store alloc] init];
    Sentegrity_Assertion_Store *globalStore = [[Sentegrity_Assertion_Store alloc] init];
    
    localStore = [[Sentegrity_TrustFactor_Storage sharedStorage] setLocalStore:localStore forAppID:policy.appID.stringValue overwrite:YES withError:error];
    globalStore = [[Sentegrity_TrustFactor_Storage sharedStorage] setGlobalStore:globalStore overwrite:YES withError:error];
    

}

#pragma mark - Main Methods

// Parse policy
- (Sentegrity_Policy *)parsePolicy:(NSURL *)policyPath isDefaultPolicy:(BOOL)isDefault withError:(NSError **)error {
    // Start by creating the parser
    Sentegrity_Parser *parser = [[Sentegrity_Parser alloc] init];
    
    // Get the policy
    Sentegrity_Policy *policy;
    
    // Parse the policy with the parser
    if ([policyPath.pathExtension isEqualToString:@"plist"]) {
        // Parse plist
        policy = [parser parsePolicyPlistWithPath:policyPath withError:error];
    } else if ([policyPath.pathExtension isEqualToString:@"json"]) {
        // Parse json
        policy = [parser parsePolicyJSONWithPath:policyPath withError:error];
    }
    
    // Error check the policy
    if (!policy && *error != nil) {
        // Error!
        return policy;
    } else if (!policy && *error == nil) {
        // Unknown Error (something is really wrong)
        NSMutableDictionary *errorDetails = [NSMutableDictionary dictionary];
        [errorDetails setValue:@"Unable to parse policy, unknown error" forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"Sentegrity" code:SAUknownError userInfo:errorDetails];
        
        // Don't return anything
        return nil;
    }
    
    // Set if the policy is the default policy or not
    [policy setIsDefault:isDefault];
    
    // Return the policy
    return policy;
}

#pragma mark - Setters

// Check if the user wants to set it
- (void)setDefaultPolicyURLPath:(NSURL *)adefaultPolicyURLPath {
    // Set it to the supplied path
    if (adefaultPolicyURLPath || adefaultPolicyURLPath != nil) {
        defaultPolicyURLPath = adefaultPolicyURLPath;
        // Return
        return;
    }
    
    // Otherwise, set the path to the documents directory, if it exists, or the resource bundle
    
    // Search for the documents directory
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    // Get the documents directory
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    // Get the default policy plist path from the documents directory
    NSString *defaultPolicyDocumentsPath = [documentsDirectory stringByAppendingPathComponent:@"Default_Policy.plist"];
    
    // Get the default policy plist path from the resources
    NSString *defaultPolicyPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Default_Policy.plist"];
    
    // Make sure it exists and set it
    if ([[NSFileManager defaultManager] fileExistsAtPath:defaultPolicyDocumentsPath]) {
        
        // Default policy exists in the documents directory, use this one
        defaultPolicyURLPath = [[NSURL alloc] initFileURLWithPath:defaultPolicyDocumentsPath];
        
    } else if ([[NSFileManager defaultManager] fileExistsAtPath:defaultPolicyPath]) {
        
        // No default policy found in the documents directory, use the one included with the application
        defaultPolicyURLPath = [[NSURL alloc] initFileURLWithPath:defaultPolicyPath];
        
    }
}

@end
