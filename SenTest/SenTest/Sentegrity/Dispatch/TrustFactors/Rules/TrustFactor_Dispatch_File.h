//
//  TrustFactor_Dispatch_File.h
//  SenTest
//
//  Created by Walid Javed on 1/28/15.
//  Copyright (c) 2015 Walid Javed. All rights reserved.
//

#import "Sentegrity_TrustFactor_Rule.h"

@interface TrustFactor_Dispatch_File : Sentegrity_TrustFactor_Rule

// BadFiles check
+ (Sentegrity_TrustFactor_Output_Object *)knownBad:(NSArray *)payload;

// FileSizeChange check
+ (Sentegrity_TrustFactor_Output_Object *)sizeChange:(NSArray *)payload;

@end
