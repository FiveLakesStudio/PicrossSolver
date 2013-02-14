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



long nlines, probes, guesses, backtracks, merges, nsprint, nplod;
long exh_runs, exh_cells;
long contratests, contrafound;

int verb[NVERB];
int cachelines= 0;
int checksolution= 0;
int checkunique= 0;
int contradepth= 2;
int maybacktrack= 1, mayexhaust= 1, maycontradict= 0, maycache= 1;
int mayguess= 1, mayprobe= 1, mergeprobe= 0, maylinesolve= 1;




void fail(const char *fmt, ...)
{
    fprintf(stderr, "PicrossSolver Fail Called!\n" );
    
    va_list ap;
    va_start( ap,fmt );
    vfprintf( stderr, fmt, ap );
    va_end(ap);
}




void resetPicrossSolverGlobals()
{
    nlines = 0;
    probes = 0;
    guesses = 0;
    backtracks = 0;
    merges = 0;
    nsprint = 0;
    nplod = 0;
    exh_runs = 0;
    exh_cells = 0;
    contratests = 0;
    contrafound = 0;
    
    memset( verb, 0x00, sizeof(verb) );
    
    cachelines = 0;
    checksolution = 0;
    checkunique = 0;
    contradepth = 2;
    maybacktrack = 1, mayexhaust = 1, maycontradict = 0, maycache = 1;
    mayguess = 1, mayprobe = 1, mergeprobe = 0, maylinesolve = 1;
}





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



- (unsigned long)analysePicData:(PicData *)picData withPuzzleDescritpion:(PicPuzzleDescription *)puzzleDesc
{
    @synchronized( self )
    {
        if( picData == nil  ||  puzzleDesc == nil )
            return SOLVER_STATUS_ERROR;
        
        resetPicrossSolverGlobals();
        
        Puzzle *puz = NULL; 
        
        // Get a representation of our puzzle in XML form.  We need to rap this in a puzzleset node
        // for the solver.
        //
        FLXMLData *puzzleSet = [[FLXMLData alloc] initElement:@"puzzleset"];
        [puzzleSet addNode:[puzzleDesc solverXMLForPicData:picData]];
        NSString  *puzzleXMLStr = puzzleSet.toXML;
        //NSLog( @"doDevButton dump:\n%@", puzzleXMLStr );
        
        // The solver API is a C based API so convert the XML to a CSTR
        const char *puzzleCStr = [puzzleXMLStr cStringUsingEncoding:NSUTF8StringEncoding];
        if( puzzleCStr == NULL )
            return SOLVER_STATUS_ERROR;
        
        // Parse the C string into an xmlDoc so we can load the puzzle
        xmlDoc *xmlDoc = xmlReadMemory(puzzleCStr, strlen(puzzleCStr), "picrosshd.xml", NULL, XML_PARSE_DTDLOAD | XML_PARSE_NOBLANKS);
        if( xmlDoc != NULL )
        {
            puz = load_xml_puzzle_from_xmlDoc( xmlDoc, 1 );  // 1 is first puzzle in the puzzleset
            xmlFreeDoc(xmlDoc);
            xmlCleanupParser();
            xmlDoc = NULL;
        }
        
        if( puz == NULL )
            return SOLVER_STATUS_ERROR;
        
        /* Initialize the bitstring handling code for puzzles of our size */
        fbit_init(puz->ncolor);
        
        if (mergeprobe) init_merge(puz);
        
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
        
        unsigned long solutionStatus = SOLVER_STATUS_UNKNOWN;
        
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
                iscomplete = rc && (puz->nsolved == puz->ncells); /* true unless -l */
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
                if (VA) printf("A: FOUND ONE SOLUTION - CHECKING FOR MORE\n%s", puz->found);
                backtrack(puz,sol);
            }
            
            // Calculate the totallines
            int totallines= 0;
            for(int i= 0; i < puz->nset; i++)
                totallines+= puz->n[i];
            
            // Figure out the puzzle solution status
            //
            if( !iscomplete  &&  puz->found == NULL )
            {
                solutionStatus = SOLVER_STATUS_STALLED;
            }
            else if( rc )
            {
                if( isunique )
                {
                    if( nlines <= totallines )
                    {
                        solutionStatus |= SOLVER_STATUS_TRIVIAL;
                    }
                    if( guesses == 0  &&  probes == 0 )
                    {
                        if( contrafound > 0 )
                            solutionStatus |= SOLVER_STATUS_CONTRA;         // NSLog(@"unique depth-%d ",contradepth);
                        else
                            solutionStatus |= SOLVER_STATUS_UNIQUE | SOLVER_STATUS_LOGICAL;
                    }
                    else
                        solutionStatus |= SOLVER_STATUS_UNIQUE;
                }
                else if (puz->found == NULL)
                {
                    solutionStatus |= SOLVER_STATUS_NOSOLUTION;
                }
                else
                {
                    solutionStatus |= SOLVER_STATUS_MULTIPLE;
                }
            }
            else if (puz->found != NULL)
            {
                solutionStatus |= SOLVER_STATUS_UNIQUE;
            }
            else
                solutionStatus |= SOLVER_STATUS_CONTRA;
        }
        
        if( sol != NULL )
            free_solution( sol );
        sol = NULL;
        
        safefree( goal );     goal    = NULL;
        free_puzzle( puz );   puz     = NULL;   altsoln = NULL;
        
        //if( solutionStatus & SOLVER_STATUS_ERROR )      NSLog( @"Picross Solution Error" );
        //if( solutionStatus & SOLVER_STATUS_STALLED )    NSLog( @"Picross Solution SOLVER_STATUS_STALLED" );
        //if( solutionStatus & SOLVER_STATUS_NOSOLUTION ) NSLog( @"Picross Solution SOLVER_STATUS_NOSOLUTION" );
        //if( solutionStatus & SOLVER_STATUS_MULTIPLE )   NSLog( @"Picross Solution SOLVER_STATUS_MULTIPLE" );
        //if( solutionStatus & SOLVER_STATUS_TRIVIAL )    NSLog( @"Picross Solution SOLVER_STATUS_TRIVIAL" );
        //if( solutionStatus & SOLVER_STATUS_CONTRA )     NSLog( @"Picross Solution SOLVER_STATUS_CONTRA" );
        //if( solutionStatus & SOLVER_STATUS_UNIQUE )     NSLog( @"Picross Solution SOLVER_STATUS_UNIQUE" );
        //if( solutionStatus & SOLVER_STATUS_LOGICAL )    NSLog( @"Picross Solution SOLVER_STATUS_LOGICAL" );
        
        return solutionStatus;
    }
}


@end
