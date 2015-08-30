//
//  TrustFactor_Dispatch_Route.h
//  SenTest
//
//  Created by Walid Javed on 1/28/15.
//  Copyright (c) 2015 Walid Javed. All rights reserved.
//

#import "Sentegrity_TrustFactor_Datasets.h"
#import "Sentegrity_TrustFactor_Output_Object.h"

@interface TrustFactor_Dispatch_Route : NSObject 


// 15
+ (Sentegrity_TrustFactor_Output_Object *)vpnUp:(NSArray *)payload;

// 16
+ (Sentegrity_TrustFactor_Output_Object *)noRoute:(NSArray *)payload;

@end
