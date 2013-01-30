//
//  MemPatch.c
//  PicrossHDUniversal
//
//  Created by Tod Cunningham on 1/29/13.
//
//

#include <stdlib.h>
#include <string.h>

#define kMemoryBumperSize 64




void *malloc_patch( size_t size )
{
    size_t largerSize = (kMemoryBumperSize * 2) + size;
    
    void *memoryStart = malloc( largerSize );
    void *memory      = memoryStart + kMemoryBumperSize;
    
    return memory;
}




void *realloc_patch( void *memory, size_t size )
{
    if( memory == NULL )
        return NULL;
    
    void  *memoryStart = memory - kMemoryBumperSize;
    size_t largerSize  = (kMemoryBumperSize * 2) + size;

    memoryStart = realloc(memory, largerSize);
    memory      = memoryStart + kMemoryBumperSize;
    
    return memory;
}




void *calloc_patch( size_t num, size_t size )
{
    size_t largerSize = (kMemoryBumperSize * 2) + (size * num);
    
    void *memoryStart = malloc( largerSize );
    void *memory      = memoryStart + kMemoryBumperSize;
    
    return memory;
}




void free_patch( void *memory )
{
    if( memory == NULL )
        return;
    
    void *memoryStart = memory - kMemoryBumperSize;
    
    free( memoryStart );
}




char *strdup_patch( const char *sourceStr )
{
    if( sourceStr == NULL )
        sourceStr = "";
    
    size_t stringSize  = strlen( sourceStr );
    size_t largerSize  = (kMemoryBumperSize * 2) + stringSize;
    void  *memoryStart = malloc( largerSize );
    void  *memory      = memoryStart + kMemoryBumperSize;
    
    memset( memoryStart, 0x00, largerSize );
    memcpy( memory, sourceStr, stringSize );
    
    return memory;
}



