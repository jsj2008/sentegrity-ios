//
//  Sentegrity_LoginAction.h
//  Sentegrity
//
//  Copyright (c) 2015 Sentegrity. All rights reserved.
//

/*!
 *  Login action activates the different login actions and sets trustfactors to whitelist
 */

#import <Foundation/Foundation.h>

// Sentegrity Policy
#import "Sentegrity_Policy.h"

// Login Response Object
#import "Sentegrity_LoginResponse_Object.h"


@interface Sentegrity_LoginAction : NSObject

/*!
 *  sharedLogin
 *
 *  @return Singleton Instance
 */
+ (id)sharedLogin;

#pragma mark - Pre Auth function
/*!
 *  attempt login returns the decrypted master key for transparent auth and interactive
 *
 *  @param action specifies what to do
 *
 *  @return Whether the protect mode was deactived or not
 */
- (Sentegrity_LoginResponse_Object *)attemptLoginWithUserInput:(NSString *)Userinput andError:(NSError **)error;

@end
