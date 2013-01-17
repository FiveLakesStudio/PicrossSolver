//
//  PicrossSolver.h
//  PicrossHDUniversal
//
//  Created by Tod Cunningham on 1/17/13.
//
//
#import <Foundation/Foundation.h>
#import "PicPuzzleDescription.h"

@interface PicrossSolver : NSObject

+ (PicrossSolver *)defaultSolver;

- (void)analysePicData:(PicData *)picData withPuzzleDescritpion:(PicPuzzleDescription *)puzzleDesc;

@end
