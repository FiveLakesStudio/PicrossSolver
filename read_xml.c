/* Copyright 2007 Jan Wolter
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef NOXML

#include <libxml/parser.h>
#include <libxml/tree.h>
#include "pbnsolve.h"
#include "read.h"

/* MEASURE XML SOLUTION - given an solution image, figure out it's dimensions,
 * and store them in sol->n[].
 */

void measure_xml_solution(Puzzle *puz, Solution *sol, char *p)
{
    int inrow, inbrace;
    line_t r=0, c=0, c0=0;
    char *q;
    
    if (puz->type == PT_TRID)
    	fail("measurement of triddler solutions not yet implemented\n");
    
    /* Figure the size of the puzzle */
    inrow= 0;
    inbrace= 0;
    r= 0;
    for (q= p; *q != '\0'; q++)
    {
        if (isspace(*q)) continue;
        if (inbrace)
        {
            if (*q == ']') inbrace= 0;
            continue;
        }
        
    	if (inrow)
        {
            if (*q == '|')
            {
                inrow= 0;
                if (r == 1) c0= c;
                if (c != c0)
                    fail("Rows of solution are different lengths\n");
            }
            else
            {
                c++;
                if (*q == '[') inbrace= 1;
            }
        }
        else
        {
            if (*q == '|')
            {
                r++;
                c= 0;
                inrow= 1;
            }
            else
                fail("Characters between rows in solution image\n");
        }
    }
    if (inbrace) fail("Unclosed [ in solution image\n");
    if (inrow) fail("Last row of solution does not end with |\n");
    
    sol->n[D_ROW]= r;
    sol->n[D_COL]= c;
}


void parse_xml_solutionimage(Puzzle *puz, Solution *sol, char *p)
{
    line_t i,j;
    color_t color;
    //int inrow;
    Cell *cell;
    //char *q;
    
    if (puz->type == PT_TRID)
    	fail("parsing of triddler solutions not yet implemented\n");
    
    /* Set sol->n[] based on the string representation of the puzzle */
    measure_xml_solution(puz, sol, p);
    
    /* Initialize grid.  Start all cells set to no color */
    init_solution(puz, sol, 0);
    
    i= j= 0;
    while (*p != '\0')
    {
        cell= sol->line[D_ROW][i][j];
        
        /* Ignore white space and delimiter characters.  We got everything
         * we need from the delimiters during measure_xml_solution() */
        while (*p != '\0' && (isspace(*p) || *p == '|'))
            p++;
        
    	if (*p == '[')
        {
            while (*(++p) != ']')
            {
                if (*p == '\0')
                    fail("Unclosed [ in solution\n");
                color= find_color_char(puz,*p);
                if (color == -1)
                    fail("Unknown color character %c in solution\n", *p);
                bit_set(cell->bit, color);
                cell->n++;
            }
        }
        else if (*p == '?')
        {
            /* Cell can be any color */
            for (color= 0; color < puz->ncolor; color++)
                bit_set(cell->bit, color);
            cell->n= puz->ncolor;
        }
        else
        {
            color= find_color_char(puz,*p);
            if (color == -1)
                fail("Unknown color character '%c' in solution\n", *p);
            bit_set(cell->bit, color);
            cell->n= 1;
        }
        
        p++;
        if (++j >= sol->n[D_COL])
        {
            j= 0;
            if (++i >= sol->n[D_ROW])
                break;
        }
    }
}

void parse_xml_solution(xmlNode *root, Puzzle *puz, SolutionList *sl)
{
    xmlNode *node;
    char *val;
    int gotimage= 0;
    
    sl->note= NULL;
    
    for (node= root->children; node != NULL; node= node->next)
    {
        if (!strcasecmp((char *)node->name,"image"))
        {
            if (gotimage)
                fail("Multiple <image> tags in a <solution> tag\n");
            gotimage= 1;
            val= (char *)xmlNodeGetContent(node);
            if (val != NULL)
            {
                parse_xml_solutionimage(puz, &sl->s, val);
                xmlFree( val );
                val = NULL;
            }
        }
        else if (!strcasecmp((char *)node->name,"note"))
        {
            if (sl->note != NULL)
                free(sl->note);
            
            xmlChar *noteNode = xmlNodeGetContent(node);
            sl->note= safedup((char *)noteNode);
            if( noteNode != NULL )
            {
                xmlFree( noteNode );
                noteNode = NULL;
            }
        }
    }
    if (!gotimage)
    	fail("No <image> tag in <solution> tag\n");
}


void parse_xml_clue(xmlNode *root, Puzzle *puz, Clue *clue)
{
    xmlNode *node;
    char *val, *col;
    int i;
    
    /* First, just count the children */
    clue->n= 0;
    for (node= root->children; node != NULL; node= node->next)
    {
        if (!strcasecmp((char *)node->name,"count"))
            (clue->n)++;
    }
    
    /* Now allocate memory */
    clue->s= clue->n;
    clue->length= (line_t *)malloc( clue->n * sizeof(line_t));
    clue->color= (color_t *)malloc( clue->n * sizeof(color_t));
    
    /* Now load the clue values */
    for (node= root->children, i= 0; node != NULL; node= node->next, i++)
    {
        if (!strcasecmp((char *)node->name,"count"))
        {
            val= (char *)xmlNodeGetContent(node);
            if (val == NULL || !isdigit(val[0]))
                fail("expected number in <count> tag on line %d\n",node->line);
            clue->length[i]= atoi(val);
            
            col= (char *)xmlGetProp(node,(xmlChar *)"color");
            clue->color[i]= (col == NULL) ? 1 : find_or_add_color(puz, col);
            
            if( col != NULL ) xmlFree( col ); col = NULL;
            if( val != NULL ) xmlFree( val ); col = NULL;
        }
    }
    
#ifdef LINEWATCH
    clue->watch= 0;
#endif
}


void parse_xml_clues(xmlNode *root, Puzzle *puz, int k)
{
    xmlNode *node;
    //Clue *clues;
    int i;
    
    /* First, just count the children */
    puz->n[k]= 0;
    for (node= root->children; node != NULL; node= node->next)
    {
        if (!strcasecmp((char *)node->name,"line"))
            puz->n[k]++;
    }
    
    /* Now allocate memory */
    puz->clue[k]= (Clue *)calloc(puz->n[k], sizeof(Clue));
    
    for (node= root->children, i= 0; node != NULL; node= node->next, i++)
    {
        if (!strcasecmp((char *)node->name,"line"))
            parse_xml_clue(node, puz, &puz->clue[k][i]);
    }
}




void parse_xml_puzzle(xmlNode *root, Puzzle *puz)
{
    char *type = NULL, *defaultcolor = NULL, *backgroundcolor = NULL;
    SolutionList *lastsol= NULL, *sl;
    Solution *goalsol= NULL;
    xmlNode *node;
    int c, k;
    int haveclues= 0;
    
    if ((type= (char *)xmlGetProp(root,(xmlChar *)"type")) == NULL)
    	type= strdup("grid");
    
    if (!strcasecmp(type,"grid"))
    {
    	puz->type= PT_GRID;
        puz->nset= 2;
    }
    else if (!strcasecmp(type,"triddler"))
    {
    	puz->type= PT_TRID;
        puz->nset= 3;
    }
    else
    	fail("Unknown puzzle type %s\n",type);
    
    /* Get background color and put it into color table.  Since this is
     * the first color loaded, it will always be color 0.
     */
    
    if ((backgroundcolor= (char *)xmlGetProp(root,(xmlChar *)"backgroundcolor")) == NULL)
    	backgroundcolor= strdup("white");
    if (find_or_add_color(puz,backgroundcolor) != 0)
    	fail("Internal error - background color is not zero\n");
    
    /* Get default color and load it in the color table.  This will
     * always be color 1.
     */
    
    if ((defaultcolor= (char *)xmlGetProp(root,(xmlChar *)"defaultcolor")) == NULL)
    	defaultcolor= strdup("black");
    if (find_or_add_color(puz,defaultcolor) > 1)
    	fail("Internal error - default color is not one\n");
    
    for (node= root->children; node != NULL; node= node->next)
    {
    	if (!strcasecmp((char *)node->name,"author"))
        {
            if (puz->author != NULL) free(puz->author);
            puz->author = ((char *)xmlNodeGetContent(node));
        }
        else if (!strcasecmp((char *)node->name,"title"))
        {
            if (puz->title != NULL) free(puz->title);
            puz->title = ((char *)xmlNodeGetContent(node));
        }
        else if (!strcasecmp((char *)node->name,"copyright"))
        {
            if (puz->copyright != NULL) free(puz->copyright);
            puz->copyright = ((char *)xmlNodeGetContent(node));
        }
        else if (!strcasecmp((char *)node->name,"description"))
        {
            if (puz->description != NULL) free(puz->description);
            puz->description = ((char *)xmlNodeGetContent(node));
        }
        else if (!strcasecmp((char *)node->name,"source"))
        {
            if (puz->source != NULL) free(puz->source);
            puz->source = ((char *)xmlNodeGetContent(node));
        }
        else if (!strcasecmp((char *)node->name,"id"))
        {
            if (puz->puzzleid != NULL) free(puz->puzzleid);
            puz->puzzleid = ((char *)xmlNodeGetContent(node));
        }
        else if (!strcasecmp((char *)node->name,"color"))
        {
            char *name= (char *)xmlGetProp(node, (xmlChar *)"name");
            if (name == NULL)
                fail("Color tag without a name attribute");
            char *chp= (char *)xmlGetProp(node, (xmlChar *)"char");
            
            xmlChar *nodeContent = xmlNodeGetContent(node);
            add_color(puz, name, (char *)nodeContent, (chp == NULL) ? '\0' : chp[0]);
            
            if( name != NULL )
            {
                xmlFree( name );
                name = NULL;
            }
            
            if( chp != NULL )
            {
                xmlFree( chp );
                chp = NULL;
            }
            
            if( nodeContent != NULL )
            {
                xmlFree( nodeContent );
                nodeContent = NULL;
            }

        }
        else if (!strcasecmp((char *)node->name,"clues"))
        {
            char *cluetype= (char *)xmlGetProp(node,(xmlChar *)"type");
            if (puz->type == PT_GRID)
            {
                if (!strcasecmp(cluetype,"rows"))
                    parse_xml_clues(node, puz, D_ROW);
                else if (!strcasecmp(cluetype,"columns"))
                    parse_xml_clues(node, puz, D_COL);
                else
                    fail("Unknown clue type %s\n",cluetype);
            }
            else
            {
                fail("Haven't implemented this yet!\n");
            }
            haveclues= 1;
            
            if( cluetype != NULL )
            {
                xmlFree( cluetype );
                cluetype = NULL;
            }
            
        }
        else if (!strcasecmp((char *)node->name,"solution"))
        {
            SolutionList *sl= (SolutionList *)malloc(sizeof(SolutionList));
            char *id= (char *)xmlGetProp(node, (xmlChar *)"id");
            char *type= (char *)xmlGetProp(node, (xmlChar *)"type");
            
            if (lastsol == NULL)
                puz->sol= sl;
            else
                lastsol->next= sl;
            sl->next= NULL;
            lastsol= sl;
            
            sl->id= safedup(id);
            if (type == NULL || !strcasecmp(type,"goal"))
            {
                sl->type= STYPE_GOAL;
                goalsol= &sl->s;
            }
            else if (!strcasecmp(type,"solution"))
                sl->type= STYPE_SOLUTION;
            else if (!strcasecmp(type,"saved"))
                sl->type= STYPE_SAVED;
            else
                fail("Unknown type in <SOLUTION> tag (%s)\n", type);
            
            parse_xml_solution(node, puz, sl);
            
            if( id != NULL )
            {
                xmlFree( id );
                id = NULL;
            }

            if( type != NULL )
            {
                xmlFree( type );
                type = NULL;
            }
        }
    }
    
    /* Define black and white if they have been referenced but not defined */
    if ((c= find_color(puz,"white") >= 0) &&
        puz->color[c].rgb == NULL &&
        puz->color[c].ch == '\0')
    {
        puz->color[c].rgb= strdup("fff");
        puz->color[c].ch= '.';
    }
    
    if ((c= find_color(puz,"black") >= 0) &&
        puz->color[c].rgb == NULL &&
        puz->color[c].ch == '\0')
    {
        puz->color[c].rgb= strdup("000");
        puz->color[c].ch= 'X';
    }
    
    /* If we have a goal, but no clues, generate the clues from the goal */
    if (!haveclues)
    {
    	if (goalsol == NULL)
            fail("Puzzle contains neither clues nor goal\n");
        make_clues(puz,goalsol);
    }
    
    /* Check that all the solutions have the same dimensions as the
     * puzzle clues.
     */
    for (sl= puz->sol; sl != NULL; sl= sl->next)
    	for (k= 0; k < puz->nset; k++)
            if (sl->s.n[k] != puz->n[k])
                fail("Solution dimensions do not match puzzle dimensions\n");
    
    if( type != NULL)            xmlFree(type);  type = NULL;
    if( backgroundcolor != NULL) xmlFree(backgroundcolor); backgroundcolor = NULL;
    if( defaultcolor != NULL)    xmlFree(defaultcolor); defaultcolor = NULL;
}


/* LOAD_XML_PUZZLE - load a puzzle in xml format from the current source.
 * If the source contains multiple puzzle, index tells which to load (1 is
 * the first one).
 */
Puzzle *load_xml_puzzle_from_xmlDoc(xmlDoc *xml, int index)
{
    xmlNode *root, *node;
    Puzzle *puz;
    int n;
    
    if (xml == NULL)
    	fail( "Could not load puzzle\n" );
    
    root= xmlDocGetRootElement(xml);
    if (strcasecmp((char *)root->name,"puzzleset"))
    	fail("Expected root node to be <puzzleset> not <%s>\n",root->name);
    
    puz= new_puzzle();
    
    /* Loop through children of <puzzleset> */
    n= 0;
    for (node= root->children; node != NULL; node= node->next)
    {
    	if (!strcasecmp((char *)node->name,"author"))
        {
            if (puz->author == NULL)
                puz->author = ((char *)xmlNodeGetContent(node));
        }
        else if (!strcasecmp((char *)node->name,"title"))
        {
            if (puz->seriestitle != NULL) free(puz->seriestitle);
            puz->seriestitle = ((char *)xmlNodeGetContent(node));
        }
        else if (!strcasecmp((char *)node->name,"copyright"))
        {
            if (puz->copyright == NULL)
                puz->copyright = ((char *)xmlNodeGetContent(node));
        }
        else if (!strcasecmp((char *)node->name,"source"))
        {
            if (puz->source == NULL)
                puz->source= ((char *)xmlNodeGetContent(node));
        }
        else if (!strcasecmp((char *)node->name,"puzzle"))
        {
            if (++n == index)
                parse_xml_puzzle(node, puz);
        }
    }
    
    return puz;
}

/*
Puzzle *load_xml_puzzle(int index)
{
    xmlDoc *xml;
    
    if (srcfp != NULL)
        xml= xmlReadFd(fileno(srcfp), srcname, NULL,
                       XML_PARSE_DTDLOAD | XML_PARSE_NOBLANKS);
    else
    	xml= xmlReadDoc((xmlChar *)srcimg, srcname, NULL,
                        XML_PARSE_DTDLOAD | XML_PARSE_NOBLANKS);
    
    Puzzle *puz = load_xml_puzzle_from_xmlDoc(xml, index);
    
    xmlFreeDoc(xml);
    
    return puz;
}
*/

#endif
