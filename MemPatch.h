//
//  MemPatch.h
//  PicrossHDUniversal
//
//  Created by Tod Cunningham on 1/29/13.
//
//
#ifndef PicrossHDUniversal_MemPatch_h
#define PicrossHDUniversal_MemPatch_h


void *malloc_patch( size_t size );
void *realloc_patch( void *memory, size_t size );
void *calloc_patch( size_t num, size_t size );
void free_patch( void *memory );
char *strdup_patch( const char *sourceStr );

#endif
