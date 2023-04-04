/** 
* PoolAllocator with index adressation.
* In constructor Pool allocator allocate big block of memory.
* Pool allocator have three implementations:
* first for compile-time type identification, second for real-time size identification,
* third like interface for others, and implement custom PoolAllocator with custom optimizations.
* (two for support scripting languages).
*/
module evoengine.experemental.utils.memory.poolallocator;
public import evoengine.utils.memory.poolallocator.common;
public import evoengine.utils.memory.poolallocator.typedallocator;
public import evoengine.utils.memory.poolallocator.sizedallocator;