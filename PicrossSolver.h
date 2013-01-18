//
//  PicrossSolver.h
//  PicrossHDUniversal
//
//  Created by Tod Cunningham on 1/17/13.
//
//
#import <Foundation/Foundation.h>
#import "PicPuzzleDescription.h"

#define SOLVER_STATUS_UNKNOWN    0x00000000

#define SOLVER_STATUS_ERROR      0x80000000
#define SOLVER_STATUS_STALLED    0x40000000
#define SOLVER_STATUS_NOSOLUTION 0x20000000
#define SOLVER_STATUS_MULTIPLE   0x10000000  // Multiple solutions

#define SOLVER_STATUS_TRIVIAL    0x00000001
#define SOLVER_STATUS_CONTRA     0x00000002  // Contradiction found
#define SOLVER_STATUS_UNIQUE     0x00000004
#define SOLVER_STATUS_LOGICAL    0x00000008





@interface PicrossSolver : NSObject

+ (PicrossSolver *)defaultSolver;

- (unsigned long)analysePicData:(PicData *)picData withPuzzleDescritpion:(PicPuzzleDescription *)puzzleDesc;

@end
