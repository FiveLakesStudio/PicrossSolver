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

#include <stdio.h>
#include "pbnsolve.h"
#include <libxml/parser.h>
#include <libxml/tree.h>
#include "read.h"


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

    Puzzle *puz = NULL;
    
    // Get a representation of our puzzle in XML form.  We need to rap this in a puzzleset node
    // for the solver.
    //
    FLXMLData *puzzleSet = [[FLXMLData alloc] initElement:@"puzzleset"];
    [puzzleSet addNode:[puzzleDesc solverXMLForPicData:picData]];
    NSString  *puzzleXMLStr = puzzleSet.toXML;
    NSLog( @"doDevButton dump:\n%@", puzzleXMLStr );

    // The solver API is a C based API so convert the XML to a CSTR
    const char *puzzleCStr = [puzzleXMLStr cStringUsingEncoding:NSUTF8StringEncoding];
    if( puzzleCStr == NULL )
        return;
    
    // Parse the C string into an xmlDoc so we can load the puzzle
    xmlDoc *xmlDoc = xmlReadMemory(puzzleCStr, strlen(puzzleCStr), "http://fivelakesstudio.com/picrosshd.xml", NULL, XML_PARSE_DTDLOAD | XML_PARSE_NOBLANKS);
    if( xmlDoc != NULL )
    {
        puz = load_xml_puzzle_from_xmlDoc( xmlDoc, 1 );  // 1 is first puzzle in the puzzleset
        xmlFreeDoc(xmlDoc);
        xmlDoc = NULL;
    }
    
    if( puz == NULL )
        return;
    
    bool terse         = YES;
    bool checkunique   = YES;
    bool checksolution = YES;

    free( puz );
    puz = NULL;
    
}


@end
