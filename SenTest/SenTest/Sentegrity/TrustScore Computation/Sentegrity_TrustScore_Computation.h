//
//  Sentegrity_TrustScore_Computation.h
//  SenTest
//
//  Created by Kramer on 4/8/15.
//  Copyright (c) 2015 Walid Javed. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Sentegrity_Policy.h"

@interface Sentegrity_TrustScore_Computation : NSObject

// TODO: BETA2 Change the way scores are computed
// TODO: BETA2 Establish learning mode

// System Score
@property (nonatomic) NSInteger systemScore;
// User Score
@property (nonatomic) NSInteger userScore;
// Device Score
@property (nonatomic) NSInteger deviceScore;

// Classification information
@property (nonatomic,retain) NSArray *classificationInformation;

// Triggered trustFactorOutputObjects
@property (nonatomic,retain) NSMutableArray *triggeredTrustFactorOutputObjects;

// trustFactorOutputObjects to be whitelisted during protect mode deactivation
@property (nonatomic,retain) NSMutableArray *protectModeDeactivationTrustFactorOutputObjects;

// Compute the systemScore and the UserScore from the trust scores and the assertion storage objects
+ (instancetype)performTrustFactorComputationWithPolicy:(Sentegrity_Policy *)policy withTrustFactorOutputObjects:(NSArray *)trustFactorAssertions withError:(NSError **)error;



@end
