//
//  PicrossSolver.m
//  PicrossHDUniversal
//
//  Created by Tod Cunningham on 1/17/13.
//
//  ./pbnsolve -b -u -c -n$index "$1"
//
#import "PicrossSolver.h"
#import "FLXML.h"

@implementation PicrossSolver




+ (PicrossSolver *)defaultSolver
{
	static PicrossSolver *gSolver = nil;
    
	@synchronized( self )
	{
		if( gSolver == nil )
        {
            gSolver = [[PicrossSolver alloc] init];
        }
	}
	
	return gSolver;
}




- (id)init
{
    self = [super init];
	if( self != nil )
    {
	}
	return self;
}




- (void)dealloc
{
}



- (void)analysePicData:(PicData *)picData withPuzzleDescritpion:(PicPuzzleDescription *)puzzleDesc
{
    if( picData == nil  ||  puzzleDesc == nil )
        return;
    
    FLXMLData *xmlData = [puzzleDesc solverXMLForPicData:picData];
    NSLog( @"doDevButton dump:\n%@", xmlData.toXML );

}


@end
