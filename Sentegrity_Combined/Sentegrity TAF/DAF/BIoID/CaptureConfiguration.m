//
//  CaptureConfiguration.m
//  BioIDSample
//
//  Copyright (c) 2015 BioID. All rights reserved.
//

#import "CaptureConfiguration.h"
#import <CommonCrypto/CommonDigest.h>


NSString * const BWS_INSTANCE_NAME = @"bws";
NSString * const CLIENT_APP_ID = @"1823507026.11298.app.bioid.com";
NSString * const CLIENT_APP_SECRET = @"eKQ5bfJVXui4cQTkY10XPzHm";
NSString * const BCIDprefix = @"bws.11298.";

// CHALLENGE RESPONSE SHOULD BE USED ONLY FOR VERIFICATION
BOOL challenge;

@implementation CaptureConfiguration


// create fullBCID with classID generated from string (email)
- (void) updateWithClassIDString: (NSString *) string {
    _BCID = [NSString stringWithFormat:@"%@%d", BCIDprefix, [self integerHashFromString:string]];
}


//create 32-bit integer from string (first 4 bytes of SHA-1 hash)
- (int32_t) integerHashFromString: (NSString *) string {
    
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    
    CC_SHA1(data.bytes, (CC_LONG) data.length, digest);
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    
    for (int i = 0; i < 4; i++)
    {
        [output appendFormat:@"%02x", digest[i]];
    }
    
    unsigned result = 0;
    NSScanner *scanner = [NSScanner scannerWithString:output];
    
    [scanner scanHexInt:&result];
    
    return (int32_t) result;
}



// Default init for verification and without challenge
-(id)init {
    if (self = [super init]) {
        _bwsToken = nil;
        _performEnrollment = false;
        _bwsInstance = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@.bioid.com/extension/", BWS_INSTANCE_NAME]];
        challenge = false;
    }
    return self;
}

-(id)initForEnrollment {
    if (self = [super init]) {
        _bwsToken = nil;
        _performEnrollment = true;
        _bwsInstance = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@.bioid.com/extension/", BWS_INSTANCE_NAME]];
        challenge = false;
    }
    return self;
}

-(id)initForVerification:(BOOL)enableChallenge {
    if (self = [super init]) {
        _bwsToken = nil;
        _performEnrollment = false;
        _bwsInstance = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@.bioid.com/extension/", BWS_INSTANCE_NAME]];
        challenge = enableChallenge;
    }
    return self;
}

-(void)ensureToken:(void (^)(NSError *))callbackBlock {
    if(_bwsToken.length > 0) {
        callbackBlock(nil);
        return;
    }

    if(_performEnrollment) {
        [self fetchBWSToken:@"enroll" onCompletion:^(NSString *token, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                _bwsToken = token;
                callbackBlock(error);
            });
        }];
    }
    else {
        [self fetchBWSToken:@"verify" onCompletion:^(NSString *token, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                _bwsToken = token;
                callbackBlock(error);
            });
        }];
    }
}

- (void)fetchBWSToken:(NSString*) bwsTask onCompletion:(void (^)(NSString *, NSError *))callbackBlock {
    // Create BWS Extension URL
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@.bioid.com/extension/token?id=%@&bcid=%@&task=%@&challenge=%@&autoenroll=true", BWS_INSTANCE_NAME, CLIENT_APP_ID, self.BCID, bwsTask, challenge ? @"true" : @"false"]];
    NSLog(@"URL %@", [url absoluteString]);
    
    // Create the authentication header for Basic Authentication
    NSData *authentication = [[NSString stringWithFormat:@"%@:%@", CLIENT_APP_ID, CLIENT_APP_SECRET] dataUsingEncoding:NSASCIIStringEncoding];
    NSString *base64String = [authentication base64EncodedStringWithOptions:0];
    NSString *authorizationHeader = [NSString stringWithFormat:@"Basic %@", base64String];
    
    // Create single request object for a series of URL load requests
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60.0];
    
    // Request a BWS token to be used for authorization for BWS Extension Web API
    [request setValue:authorizationHeader forHTTPHeaderField:@"Authorization"];
    
    NSLog(@"Get BWS token %@", request);
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *connectionError) {
        if (connectionError) {
            NSLog(@"Connection error: %@", connectionError.localizedDescription);
            callbackBlock(nil, connectionError);
        }
        else {
            NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
            if (statusCode == 200) {
                NSLog(@"Get BWS token");
                NSString *bwsToken = [[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding];
                callbackBlock(bwsToken, nil);
            }
            else {
                NSLog(@"Get BWS token failed with status code: %ld", (long)statusCode);
                callbackBlock(nil, [[NSError alloc] initWithDomain:@"BioIDServiceError" code:statusCode userInfo:nil]);
            }
        }
    }];    
    [dataTask resume];
}

@end
