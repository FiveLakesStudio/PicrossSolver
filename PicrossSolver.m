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
    
    /* Initialize the bitstring handling code for puzzles of our size */
    fbit_init(puz->ncolor);
    
    /* preallocate some arrays */
    init_line(puz);

    /* Find Solutions */
    SolutionList *sl            = NULL;
    Solution     *sol           = NULL;
    bool          checkunique   = YES;
    char         *goal          = NULL;  // The correct solution
    char         *altsoln       = NULL;

    // Find the goal
    for( sl = puz->sol; sl != NULL; sl = sl->next )
    {
        if( sl->type == STYPE_GOAL )
        {
            goal = solution_string(puz, &sl->s);
            break;
        }
    }
    
    // Find solutions
    //
    {
        int rc  = 0;
        int isunique = 0;
        int iscomplete = 0;

        /* Start from a blank grid if we didn't start from a saved game */
        if (sol == NULL)
            sol= new_solution(puz);
        
        clue_init(puz, sol);
        init_jobs(puz, sol);
        
        nlines= probes= guesses= backtracks= merges= exh_runs= exh_cells= 0;
        contratests= contrafound= nsprint= 0;
        nplod= 1;
        while (1)
        {
            rc = solve( puz, sol );
            iscomplete= rc && (puz->nsolved == puz->ncells); /* true unless -l */
            if (!checkunique || !rc || puz->nhist == 0 || puz->found != NULL)
            {
                /* Time to stop searching.  Either
                 *  (1) we aren't checking for uniqueness
                 *  (2) the last search didn't find any solution
                 *  (3) the last search involved no guessing
                 *  (4) a previous search found a solution.
                 * The solution we found is unique if (3) is true and (4) is false.
                 */
                isunique= (iscomplete && puz->nhist==0 && puz->found==NULL);
                
                /* If we know the puzzle is not unique, then it is because we
                 * previously found another solution.  If checksolution is true,
                 * and we went on to search more, then the first one must have
                 * been the goal, so this one isn't.
                 */
                if (checksolution && !isunique)
                    altsoln= solution_string(puz,sol);
                break;
            }
            
            /* If we are checking for uniqueness, and we found a solution, but
             * we aren't sure it is unique and we haven't found any others before
             * then we don't know yet if the puzzle is unique or not, so we still
             * have some work to do.  Start by saving the solution we found.
             */
            puz->found= solution_string(puz, sol);
            
            /* If we have the expected goal, check if the solution we found that.
             * if not, we can take non-uniqueness as proven without further
             * searching.
             */
            if (goal != NULL && strcmp(puz->found, goal))
            {
                if (VA) puts("A: FOUND A SOLUTION THAT DOES NOT MATCH GOAL");
                isunique= 0;
                altsoln= puz->found;
                break;
            }
            /* Otherwise, there is nothing to do but to backtrack from the current
             * solution and then resume the search to see if we can find a
             * differnt one.
             */
            if (VA) printf("A: FOUND ONE SOLUTION - CHECKING FOR MORE\n%s",
                           puz->found);
            backtrack(puz,sol);
        }

        // Calculate the totallines
        int totallines= 0;
        for(int i= 0; i < puz->nset; i++)
            totallines+= puz->n[i];
        
        NSLog( @"isunique:%d iscomplete:%d", isunique, iscomplete );

        if( !iscomplete  &&  puz->found == NULL )
            NSLog( @"stalled ");
        else if (rc)
        {
            if( isunique )
            {
                if( nlines <= totallines )
                    NSLog( @"trivial ");
                if (guesses == 0 && probes == 0)
                {
                    if (contrafound > 0)
                        NSLog(@"unique depth-%d ",contradepth);
                    else
                        NSLog(@"unique logical ");
                }
                else
                    NSLog(@"unique ");
            }
            else if (puz->found == NULL)
            {
                NSLog(@"solvable ");
            }
            else
            {
                NSLog(@"multiple ");
            }
        }
        else if (puz->found != NULL)
        {
            NSLog(@"unique ");
        }
        else
            NSLog(@"contradition ");
        
        if( puz->id != NULL )
            printf(" \t %s\n", puz->id);    /* !! TC !! Added */

    }
    
    if (sl != NULL)
        free_solution(sol);

    free( puz );
    puz = NULL;
}


@end
