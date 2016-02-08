//
//  Sentegrity_Activity_Dispatcher.m
//  Sentegrity
//
//  Copyright (c) 2015 Sentegrity. All rights reserved.
//


#import "Sentegrity_Activity_Dispatcher.h"

// Import location dataset
#import "Sentegrity_TrustFactor_Dataset_Location.h"

// Import the datasets
#import "Sentegrity_TrustFactor_Datasets.h"

// DLFCN - Dynamic Loading
#import <dlfcn.h>

// Permissions
#import "ISHPermissionKit.h"
#import "LocationPermissionViewController.h"
#import "ActivityPermissionViewController.h"

@implementation Sentegrity_Activity_Dispatcher

#pragma mark - Additional functions

// Run the Core Detection Activites
- (void)runCoreDetectionActivities {
    
    
    // Start Bluetooth as soon as possible
    [self startBluetoothBLE]; // Also starts classic
    
    // Check if the application has permissions to run the different activities
    ISHPermissionRequest *permissionLocationWhenInUse = [ISHPermissionRequest requestForCategory:ISHPermissionCategoryLocationWhenInUse];
    ISHPermissionRequest *permissionActivity = [ISHPermissionRequest requestForCategory:ISHPermissionCategoryLocationWhenInUse];
    
    // Check if permissions are authorized
    if ([permissionLocationWhenInUse permissionState] != ISHPermissionStateAuthorized || [permissionActivity permissionState] != ISHPermissionStateAuthorized) {
        
        if([permissionLocationWhenInUse permissionState] != ISHPermissionStateAuthorized) {
            // Set location error
            [[Sentegrity_TrustFactor_Datasets sharedDatasets]  setLocationDNEStatus:DNEStatus_unauthorized];
            
        }else{
            // Start location
            [self startLocation];
        }
        
        if([permissionActivity permissionState] != ISHPermissionStateAuthorized) {
            
            // The app isn't authorized to use motion activity support.
            [[Sentegrity_TrustFactor_Datasets sharedDatasets] setActivityDNEStatus:DNEStatus_unauthorized];
        }
        else{
            // Start Activity
            [self startActivity];
        }
    }
    else{
        
        // Start location
        [self startLocation];
        
        // Start Activity
        [self startActivity];
        
    }
    
    // Start Motion
    [self startMotion];
    
}

#pragma mark - Core Detection Activities

// ** GET LOCATION DATA **
- (void)startLocation {
    
    
    // Create the location manager
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    
    
    // check if the hardware has a magnetometer
    if ([CLLocationManager headingAvailable] == NO) {
        // Set magnetic disabled
        [[Sentegrity_TrustFactor_Datasets sharedDatasets]  setMagneticHeadingDNEStatus:DNEStatus_disabled];
    }
    else {
        self.locationManager.headingFilter = kCLHeadingFilterNone;
        magneticHeadingArray = [[NSMutableArray alloc] init];
        [self.locationManager startUpdatingHeading];
    }
    
    
    NSUInteger code = [CLLocationManager authorizationStatus];
    
    // Check if it's enabled
    if (![CLLocationManager locationServicesEnabled]) {
        
        // Set location disabled
        [[Sentegrity_TrustFactor_Datasets sharedDatasets] setLocationDNEStatus:DNEStatus_disabled];
        
        
    } else {
        
        // Check if location is actually allowed
        if (code == kCLAuthorizationStatusNotDetermined && [_locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
            
            // Request location when application is in use
            [self.locationManager requestWhenInUseAuthorization];
            
        }
    }
    
    // Check if the code is authorized
    if (code == kCLAuthorizationStatusAuthorizedWhenInUse) {
        
        // Set the location accuracy to low
        self.locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
        
        // Start updating the location
        [self.locationManager startUpdatingLocation];
        
    } else if (code == kCLAuthorizationStatusDenied) {
        
        // Location status is denied
        
        //Set location unauthorized
        [[Sentegrity_TrustFactor_Datasets sharedDatasets]  setLocationDNEStatus:DNEStatus_unauthorized];
        
        
    } else {
        
        // Unknown Reason why location is denied
        
        // Set location error
        [[Sentegrity_TrustFactor_Datasets sharedDatasets]  setLocationDNEStatus:DNEStatus_unauthorized];
        
    }
}

// ** LOCATION UPDATE **

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    
    // Set the long/lat location
    [[Sentegrity_TrustFactor_Datasets sharedDatasets] setLocation:newLocation];
    
    /* Placemark Removed as TF was removed
     
     // Attempt to obtain geo data for country
     CLGeocoder *reverseGeocoder = [[CLGeocoder alloc] init];
     
     // Get the reverse geocode location when finished
     [reverseGeocoder reverseGeocodeLocation:newLocation completionHandler:^(NSArray *placemarks, NSError *error) {
     
     //// Cancel any future requests
     [reverseGeocoder cancelGeocode];
     
     // Check for any errors
     if (error) {
     
     // Error exists, set DNE error
     [[Sentegrity_TrustFactor_Datasets sharedDatasets] setPlacemarkDNEStatus:DNEStatus_error];
     
     } else {
     
     // No Errors
     
     // Get placemark object
     CLPlacemark *myPlacemark = [placemarks objectAtIndex:0];
     
     // Set the placemark
     [[Sentegrity_TrustFactor_Datasets sharedDatasets] setPlacemark:myPlacemark];
     
     }
     
     
     }];
     */
    
    // Stop all future updates (we only needed one)
    [manager stopUpdatingLocation];
    
}



// ** LOCATION MAGNETOMETER HEADING UPDATE **

// This Magnetometer reading is calibrated for the device's interference but it does not work when location is not authorized

// This delegate method is invoked when the location manager has heading data.
- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)heading {
    // Update the labels with the raw x, y, and z values.
    
    
    // Create an array of headings samples
    NSArray *ItemArray = [NSArray arrayWithObjects:[NSNumber numberWithDouble:heading.magneticHeading],[NSNumber numberWithDouble:heading.x], [NSNumber numberWithDouble:heading.y],[NSNumber numberWithDouble:heading.z], nil];
    
    // Create an array of keys
    NSArray *KeyArray = [NSArray arrayWithObjects:@"heading",@"x", @"y", @"z", nil];
    
    // Create the dictionary
    NSDictionary *dict = [[NSDictionary alloc] initWithObjects:ItemArray forKeys:KeyArray];
    
    // Add sample to array
    [magneticHeadingArray addObject:dict];
    
    [[Sentegrity_TrustFactor_Datasets sharedDatasets] setMagneticHeading: magneticHeadingArray];
    
    if (magneticHeadingArray.count > 5) {
        
        [manager stopUpdatingHeading];

    }
    
}

// This delegate method is invoked when the location managed encounters an error condition.
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    if ([error code] == kCLErrorDenied) {
        // This error indicates that the user has denied the application's request to use location services.
        [manager stopUpdatingHeading];
    } else if ([error code] == kCLErrorHeadingFailure) {
        // This error indicates that the heading could not be determined, most likely because of strong magnetic interference.
    }
}

// ** GET HISTORICAL ACTIVITY DATA **
- (void)startActivity {
    
    // Check if the motion activity manager is available
    if (![CMMotionActivityManager isActivityAvailable]) {
        
        // Not supported
        [[Sentegrity_TrustFactor_Datasets sharedDatasets] setActivityDNEStatus:DNEStatus_unsupported];
        
    } else {
        
        // Create the motion manager
        CMMotionActivityManager *manager = [[CMMotionActivityManager alloc] init];
        
        // Get motion activity data
        [manager queryActivityStartingFromDate:[NSDate dateWithTimeIntervalSinceNow:-(60*5)] toDate:[NSDate date] toQueue:[NSOperationQueue new] withHandler:^(NSArray *activities, NSError *error) {
            
            // Check for errors
            if (error != nil && (error.code == CMErrorMotionActivityNotAuthorized || error.code == CMErrorMotionActivityNotEntitled)) {
                
                // The app isn't authorized to use motion activity support.
                [[Sentegrity_TrustFactor_Datasets sharedDatasets] setActivityDNEStatus:DNEStatus_unauthorized];
                
            } else {
                
                // Set activities array
                [[Sentegrity_TrustFactor_Datasets sharedDatasets] setPreviousActivities:activities];
                
            }
            
            // Stop future updates as this only gets called once
            [manager stopActivityUpdates];
            
        }];
        
    }
    
}

// ** GET MOTION PITCH/ROLL, MOVEMENT, ORIENTATION DATA **
- (void)startMotion {
    
    // Create the motion manager
    CMMotionManager *manager = [[CMMotionManager alloc] init];
    
    // Allocate all the pith/roll array
    pitchRollArray = [[NSMutableArray alloc] init];

    
    // Check if the gryo is available
    if (![manager isGyroAvailable] || manager == nil) {
        
        // Gyro not available
        [[Sentegrity_TrustFactor_Datasets sharedDatasets] setGyroMotionDNEStatus:DNEStatus_unsupported];
        
        // Magnetometer not available
        [[Sentegrity_TrustFactor_Datasets sharedDatasets] setMagneticHeadingDNEStatus:DNEStatus_unsupported];
        
    } else {
        
        // Gyro is available get user grip
        manager.deviceMotionUpdateInterval = .001f;
        
        // Get the device motion updates
        [manager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXMagneticNorthZVertical toQueue:[NSOperationQueue currentQueue] withHandler:^(CMDeviceMotion  *motion, NSError *error) {

                
                // Create an array of motion samples
                NSArray *itemArray = [NSArray arrayWithObjects:[NSNumber numberWithFloat:motion.attitude.pitch], [NSNumber numberWithFloat:motion.attitude.roll], nil];
                
                // Create an array of keys
                NSArray *keyArray = [NSArray arrayWithObjects:@"pitch", @"roll", nil];
                
                // Create the dictionary
                NSDictionary *dict = [[NSDictionary alloc] initWithObjects:itemArray forKeys:keyArray];
                
                // Add sample to array
                [pitchRollArray addObject:dict];
                
                // Set the gyro roll pictch
                [[Sentegrity_TrustFactor_Datasets sharedDatasets] setGyroRollPitch:pitchRollArray];
            
                // Keep updating until we stop
                // We want a minimum of 3 samples before we average them inside the TF
                // its possible we will get more as this handler gets called additional times prior to
                // the TF needing the dataset, but we don't want to cause it to wait therefore we stick with a minimum of 3. If we get more it will continue to update
                if (pitchRollArray.count > 3){
                    [manager stopDeviceMotionUpdates];
                }
                
            //}
            
        }];
        
        
        // ** GET ENTIRE MOTION DATA **
        
        // New motion manager. We do not want to use CMAttitudeReferenceFrameXMagneticNorthZVertical (because it needs calibration), and do not want to stop observing once pitchRollArray is filled
        CMMotionManager *manager2 = [[CMMotionManager alloc] init];

        // Allocate all the motion array
        motionArray = [[NSMutableArray alloc] init];
        
        // Check if the gryo is available
        if (![manager2 isGyroAvailable] || manager2 == nil) {
            
            // Gyro not available
            [[Sentegrity_TrustFactor_Datasets sharedDatasets] setGyroMotionDNEStatus:DNEStatus_unsupported];
            
            
        } else {
            manager2.accelerometerUpdateInterval = 0.01f;
            manager2.gyroUpdateInterval = 0.01f;
            
            //neccessary to detect device orientation
            [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
            
            
            // get device motion update
            [manager2 startDeviceMotionUpdatesToQueue:[NSOperationQueue currentQueue] withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
                
                
                [motionArray addObject:motion];
                [[Sentegrity_TrustFactor_Datasets sharedDatasets] setMotionTotal:motionArray];
                
                // bigger array capacity will increase precission
                if (motionArray.count > 50)
                    [manager2 stopDeviceMotionUpdates];
            }];
            
        }

        
        
        
        // ** GET MAGNETOMETER DATA **
        
        // If location was denied, get magnetometer reading via raw as this does not require permissions
        
        if([[Sentegrity_TrustFactor_Datasets sharedDatasets]  locationDNEStatus] == DNEStatus_unauthorized)
        {

            manager.magnetometerUpdateInterval = .001;
            headingsArray = [[NSMutableArray alloc] init];
            [manager startMagnetometerUpdatesToQueue:[NSOperationQueue currentQueue]  withHandler:^(CMMagnetometerData  *magnetometer, NSError *error) {
    
                
                // Create an array of headings samples
                NSArray *ItemArray = [NSArray arrayWithObjects:[NSNumber numberWithDouble:magnetometer.magneticField.x], [NSNumber numberWithDouble:magnetometer.magneticField.y],[NSNumber numberWithDouble:magnetometer.magneticField.z], nil];
                
                // Create an array of keys
                NSArray *KeyArray = [NSArray arrayWithObjects:@"x", @"y", @"z", nil];
                
                // Create the dictionary
                NSDictionary *dict = [[NSDictionary alloc] initWithObjects:ItemArray forKeys:KeyArray];
                
                // Add sample to array
                [headingsArray addObject:dict];
                
                [[Sentegrity_TrustFactor_Datasets sharedDatasets] setMagneticHeading:headingsArray];
                
                if (headingsArray.count > 5) {
                    
                    [manager stopMagnetometerUpdates];
                    
                }
                
            }];

            
        }

        
        // ** GET MOVEMENT DATA **
        
        // Attempt to detect large movements using Gyro

        // Allocate the gyro array
        gyroRadsArray = [[NSMutableArray alloc] init];
        
        manager.gyroUpdateInterval = .001f;
        [manager startGyroUpdatesToQueue:[NSOperationQueue currentQueue] withHandler:^(CMGyroData  *gyroData, NSError *error) {
            
            // Check for errors
            if (error != nil && (error.code == CMErrorMotionActivityNotAuthorized || error.code == CMErrorMotionActivityNotEntitled)) {
                
                // The app isn't authorized to use motion activity support.
                [[Sentegrity_TrustFactor_Datasets sharedDatasets] setGyroMotionDNEStatus:DNEStatus_unauthorized];
                
            } else {
                
                // Create an array of gyro samples
                NSArray *itemArray = [NSArray arrayWithObjects:[NSNumber numberWithFloat:gyroData.rotationRate.x], [NSNumber numberWithFloat:gyroData.rotationRate.y], [NSNumber numberWithFloat:gyroData.rotationRate.z], nil];
                
                // Create an array of keys
                NSArray *keyArray = [NSArray arrayWithObjects:@"x", @"y", @"z", nil];
                
                // Create the dictionary
                NSDictionary *dict = [[NSDictionary alloc] initWithObjects:itemArray forKeys:keyArray];
                
                // Add sample to array
                [gyroRadsArray addObject:dict];
                
                // Set the gyro radians
                [[Sentegrity_TrustFactor_Datasets sharedDatasets] setGyroRads:gyroRadsArray];
                
                
                // We want a minimum of 3 samples before we average them inside the TF
                // its possible we will get more as this handler gets called additional times prior to
                // the TF needing the dataset, but we don't want to cause it to wait therefore we stick with a minimum of 3. If we get more it will continue to update
                
                // Keep updating until we stop
                if (gyroRadsArray.count > 3){
                    [manager stopGyroUpdates];
                }
                
            }
            
        }];
        
    }
    
    
    // ** GET ACCEL DATA **
    
    // Allocate the accel array
    accelRadsArray = [[NSMutableArray alloc] init];
    
    // Check if the accelerometer is available
    if (![manager isAccelerometerAvailable] || manager == nil) {
        
        // Accelerometer is not available
        [[Sentegrity_TrustFactor_Datasets sharedDatasets] setAccelMotionDNEStatus:DNEStatus_unsupported];
        
    } else {
        
        // Accelerometer is available
        
        // Used to detect orientation
        manager.accelerometerUpdateInterval = .001f;
        [manager startAccelerometerUpdatesToQueue:[NSOperationQueue currentQueue] withHandler:^(CMAccelerometerData  *accelData, NSError *error) {
            
            // Check if an error occured
            if (error != nil && (error.code == CMErrorMotionActivityNotAuthorized || error.code == CMErrorMotionActivityNotEntitled)) {
                
                // The app isn't authorized to use motion activity support.
                [[Sentegrity_TrustFactor_Datasets sharedDatasets] setGyroMotionDNEStatus:DNEStatus_unauthorized];
                
            } else {
                
                // Create an array of accelerometer samples
                NSArray *itemArray = [NSArray arrayWithObjects:[NSNumber numberWithFloat:accelData.acceleration.x], [NSNumber numberWithFloat:accelData.acceleration.y], [NSNumber numberWithFloat:accelData.acceleration.z], nil];
                
                // Create an array of keys
                NSArray *keyArray = [NSArray arrayWithObjects:@"x", @"y", @"z", nil];
                
                // Create the dictionary
                NSDictionary *dict = [[NSDictionary alloc] initWithObjects:itemArray forKeys:keyArray];
                
                // Add sample to array
                [accelRadsArray addObject:dict];
                
                // Update dataset
                [[Sentegrity_TrustFactor_Datasets sharedDatasets] setAccelRads:accelRadsArray];
                
                // We want a minimum of 3 samples before we average them inside the TF
                // its possible we will get more as this handler gets called additional times prior to
                // the TF needing the dataset, but we don't want to cause it to wait therefore we stick with a minimum of 3. If we get more it will continue to update
                
                // Keep updating until we stop
                if (accelRadsArray.count > 3){
                    [manager stopAccelerometerUpdates];
                }
                
            }
            
        }];
        
    }
    
}


// ** BLUETOOTH 4.0 SCANNING **
- (void)startBluetoothBLE {
    
    // Set the start time
    startTime = CFAbsoluteTimeGetCurrent();
    
    // Create the bluetooth manager options
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], CBCentralManagerOptionShowPowerAlertKey, nil];
    
    // Start the manager
    mgr = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:options];
    
}


// ** BLUETOOTH CLASSIC **
- (void)startBluetoothClassic {
    
    // Start Bluetooth Manager
    [[MDBluetoothManager sharedInstance] registerObserver:self];
    
}


// ** BLUETOOTH 4.0 DISCOVERED DEVICES **

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    
    // Add the device dictionary to the list
    [discoveredBLEDevices addObject:[NSString stringWithFormat:@"%@", peripheral.identifier.UUIDString]];
    
    // Update the datasets
    [[Sentegrity_TrustFactor_Datasets sharedDatasets] setDiscoveredBLEDevices:discoveredBLEDevices];
    
    // Update timer with current time
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    
    // Stop scanning after 2 seconds (this has no bearing on CD execution time)
    if ((currentTime-startTime) > 2.0){
        
        // Scanning stopped
        NSLog(@"Bluetooth scanning stopped");
        [mgr stopScan];
        
    }
    
}

// ** BLUETOOTH 4.0 STATE UPDATE **
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    
    // Check which state the bluetooth manager is in
    switch (central.state) {
        case CBCentralManagerStateUnknown:
        {
            //messtoshow=[NSString stringWithFormat:@"State unknown, update imminent."];
            
            // Wait
            break;
        }
        case CBCentralManagerStateResetting:
        {
            //messtoshow=[NSString stringWithFormat:@"The connection with the system service was momentarily lost, update imminent."];
            
            // Wait
            break;
        }
        case CBCentralManagerStateUnsupported:
        {
            
            [[Sentegrity_TrustFactor_Datasets sharedDatasets] setDiscoveredBLESDNEStatus:DNEStatus_unsupported];
            
            // We also set classic here since it uses private API this is more reliable
            [[Sentegrity_TrustFactor_Datasets sharedDatasets] setConnectedClassicDNEStatus:DNEStatus_unsupported];
            
            break;
        }
        case CBCentralManagerStateUnauthorized:
        {
            //messtoshow=[NSString stringWithFormat:@"The app is not authorized to use Bluetooth Low Energy"];
            
            // Update the dataset to unauthorized
            [[Sentegrity_TrustFactor_Datasets sharedDatasets] setDiscoveredBLESDNEStatus:DNEStatus_unauthorized];
            [[Sentegrity_TrustFactor_Datasets sharedDatasets] setConnectedClassicDNEStatus:DNEStatus_unauthorized];
            
            break;
        }
        case CBCentralManagerStatePoweredOff:
        {
            //messtoshow=[NSString stringWithFormat:@"Bluetooth is currently powered off."];
            
            // Update the dataset to disabled
            [[Sentegrity_TrustFactor_Datasets sharedDatasets] setDiscoveredBLESDNEStatus:DNEStatus_disabled];
            [[Sentegrity_TrustFactor_Datasets sharedDatasets] setConnectedClassicDNEStatus:DNEStatus_disabled];
            break;
        }
        case CBCentralManagerStatePoweredOn:
        {
            
            // Create the bluetooth array
            discoveredBLEDevices = [[NSMutableArray alloc] init];
            
            
            // Set timer to eventually stop scanning (otherwise if we don't find any it will keep trying during app use and kill battery)
            startTime = CFAbsoluteTimeGetCurrent();
            
            // Start scanning for any peripheral bluetooth devices
            [mgr scanForPeripheralsWithServices:nil options:nil];
            
            // Also start classic BT
            [self startBluetoothClassic];
            
            // Done
            break;
        }
            
    }
    
}

// ** BLUETOOTH CLASSIC NOTIFICATION **
- (void)receivedBluetoothNotification:(MDBluetoothNotification)bluetoothNotification {
    
    // Unregister bluetooth
    [[MDBluetoothManager sharedInstance] unregisterObserver:self];
    
    // Get the bluetoothManager class from a string
    Class bluetoothManagerClass = NSClassFromString(@"BluetoothManager");
    
    // Check if the class exists
    if (bluetoothManagerClass == nil) {
        
        // Open the BluetoothManager private framework with dlopen
        void *handle = dlopen("/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager", RTLD_NOW);
        
        // Check if it was able to open
        if (handle) {
            
            // Get the class again
            bluetoothManagerClass = NSClassFromString(@"BluetoothManager");
            
            // Make sure it's valid
            assert(bluetoothManagerClass);
        }
    }
    
    // Get the connected devices
    NSArray * __unsafe_unretained tempConnectedDevices;
    NSArray *connectedDevices;
    
    // Get the selector
    SEL selector = NSSelectorFromString(@"connectedDevices");
    
    // Check if the class responds
    if ([[bluetoothManagerClass sharedInstance] respondsToSelector:selector]) {
        
        // Create the invocation
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
                                    [[[bluetoothManagerClass sharedInstance] class] instanceMethodSignatureForSelector:selector]];
        
        // Set the selector
        [invocation setSelector:selector];
        
        // Set the target
        [invocation setTarget:[bluetoothManagerClass sharedInstance]];
        
        // Call the method
        [invocation invoke];
        
        // Get the return value
        [invocation getReturnValue:&tempConnectedDevices];
        
        // Set the Connected Devices
        connectedDevices = tempConnectedDevices;
    }
    
    // Create the mutablearray if needed
    // Allocate the connectedBTDevices array
    connectedBTDevices = [[NSMutableArray alloc] init];
    
    // Run through all found devices information
    for (id device in connectedDevices) {
        NSLog(@"Connected Device: %@", device);
        // Add the device to the list
        [connectedBTDevices addObject:[NSString stringWithFormat:@"%@", [device address]]];
        
    }
    
    // Set the dataset
    [[Sentegrity_TrustFactor_Datasets sharedDatasets] setConnectedClassicBTDevices:connectedBTDevices];
    
}



@end
