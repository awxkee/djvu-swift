//
//  NSString+UUID.m
//  DjvuViewer
//
//  Created by Alex Martynov on 2/13/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NSString+UUID.h"

@implementation NSString(UUID)

+ (NSString *)UUID
{
    return [[NSUUID UUID] UUIDString];
}

@end
