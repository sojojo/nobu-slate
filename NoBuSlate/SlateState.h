//
//  SlateState.h
//  NoBuSlate
//
//  Created by Matthew McKenna on 6/3/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface SlateState : NSManagedObject

@property (nonatomic, retain) NSString * audioFileName;
@property (nonatomic, retain) NSString * audioLeftChannel;
@property (nonatomic, retain) NSString * audioRightChannel;
@property (nonatomic, retain) NSString * productionName;
@property (nonatomic, retain) NSNumber * sceneNumber;
@property (nonatomic, retain) NSNumber * takeNumber;

@end
