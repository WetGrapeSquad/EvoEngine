/** 
* PoolAllocator with index adressation.
* In constructor Pool allocator allocate big block of memory.
* Pool allocator have three implementations:
* first for compile-time type identification, second for real-time size identification,
* third like interface for others, and implement custom PoolAllocator with custom optimizations.
* (two for support scripting languages).
*/
module evoengine.utils.memory.poolallocator;
import evoengine.utils.memory.blockallocator;
import dlib.container.array;
import std.traits;

enum NoneIndex = -1;

size_t typesInBytes(T)(size_t bytes)
{
    return bytes / T.sizeof;
}

T[] convertationWithTruncation(F, T)(F[] from)
{
    return (cast(T*)from.ptr)[0..typesInBytes!T(from.length * F.sizeof)];
}

/// TODO: Add freelist sort stability for allocation(optimize memory usage and etc.)

/// Interface of all PoolAllocator with index adressation.
interface IPoolAllocator(T)
{
    /// Allocate one element and get her index.
    size_t allocate();
    /// Deallocate one element by her index.
    void deallocate(size_t index);
    /// Allocate a set of count of element and return array with indexes(none GC array for optimizations).
    Array!size_t allocate(size_t count);
    /// Deallocate a set of element(D array, so as not to duplicate the array).
    void deallocate(size_t[] deallocate);
    /// Return max count of elements.
    size_t max();
    /// Return avaliable for allocation count of element.
    size_t avaliable();
    /// Return count of occupied elements.
    size_t allocated();
    /** 
    *   For opIndex there are three cases: If static array return dynamic 
    *   array pointing on array in IPoolAllocator, else if array is dynamic
    *   then like in first case returning dynamic array, else return 
    *   reference to the element, becouse that is not array.
    */
    static if(isStaticArray!T){
        ForeachType!T[] opIndex(size_t index);
        public int opApply(scope int delegate(ForeachType!T[] component) dg);
    }
    else static if(isDynamicArray!T){
        T opIndex(size_t index);
        public int opApply(scope int delegate(T component) dg);
    }
    else{
        ref T opIndex(size_t index);
        public int opApply(scope int delegate(ref T component) dg);
    }
}


class PoolAllocator(T, alias blockAllocator = BlockAllocator, alias blockType = BlockType): IPoolAllocator!T{
    /// Dynamic array is't support for allocation.
    static assert(!isDynamicArray!T, 
    "PoolAllocator works only with static array, basics types, structs or class reference");

    /// Inner Component type. In diferend contexts Component can be index of next free componet, or can be component
    private union Component
    {
        size_t mNextFree;
        T component;
    }

    this(blockAllocator allocator)
    {
        this.mAllocator = allocator;

        this.mBlock = this.mAllocator.alloc();
        this.mArray = this.mBlock.data.convertationWithTruncation!(void, Component);
    }


    size_t allocate()
    {
        assert(this.avaliable > 0, "No avaliable elements to allocate!");

        this.actualFreeList = false;
        size_t index;

        if(this.mFirstFree != NoneIndex){
            index = this.mFirstFree;
            this.mFirstFree = this.mArray[this.mFirstFree].mNextFree;
        }else{
            index = this.mLast;
            this.mLast++;
        }
        
        this.mAllocated++;
        return index;
    }
    
    void deallocate(size_t index)
    {
        this.actualFreeList = false;

        debug(memory){
            assert(index < this.mArray.length, "Out of bounds.");
            for(size_t iterator = this.mFirstFree; iterator != NoneIndex; iterator = this.mArray[iterator].mNextFree){
                import std.conv: to;
                assert(iterator != index, "Double free index [" ~ index.to!string ~ "].");
            }
        }
        this.mArray[index].mNextFree = this.mFirstFree;
        this.mFirstFree = index;
        this.mAllocated--;
    }
    
    Array!size_t allocate(size_t count)
    {
        assert(this.avaliable >= count, "No avaliable elements to allocate!");

        this.actualFreeList = false;

        Array!size_t indexArray;
        indexArray.reserve(count);

        while(this.mFirstFree != NoneIndex && indexArray.length < count){
            indexArray ~= this.mFirstFree;
            this.mFirstFree = this.mArray[this.mFirstFree].mNextFree;
        }
        while(indexArray.length < count){
            indexArray ~= this.mLast;
            this.mLast++;
        }

        this.mAllocated += count;

        return indexArray;
    }
    
    void deallocate(size_t[] deallocate)
    {
        this.actualFreeList = false;

        debug(memory)
        {
            foreach(ref index; deallocate){
                assert(index < this.mArray.length, "Out of bounds.");
                for(size_t iterator = this.mFirstFree; iterator != NoneIndex; iterator = this.mArray[iterator].mNextFree)
                {
                    import std.conv: to;
                    assert(iterator != index, "Double free index [" ~ index.to!string ~ "].");
                }
            }
        }

        foreach(ref index; deallocate)
        {
            this.mArray[index].mNextFree = this.mFirstFree;
            this.mFirstFree = index;
        }
        this.mAllocated -= deallocate.length;
    }
    
    size_t max()
    {
        return this.mArray.length;
    }   
    
    size_t avaliable()
    {
        return this.mArray.length - this.mAllocated;
    }
    
    size_t allocated()
    {
        return this.mAllocated;
    }
    
    private void sortFreeList(){
        if(!this.actualFreeList){
            import std.algorithm.sorting;

            this.sortedFreeList.resize(0, 0);
            this.sortedFreeList.reserve(this.mLast - this.mAllocated);

            size_t index = this.mFirstFree;

            while(index != NoneIndex){
                this.sortedFreeList ~= index;
                index = this.mArray[index].mNextFree;
            }

            sort(this.sortedFreeList.data);
            this.actualFreeList = true;
        }
    }

    // See IPoolAllocator. Dynamic array aren't supported.
    static if(isStaticArray!T){
        ForeachType!T[] opIndex(size_t index){
            return this.mArray[index].component;
        }
        public int opApply(scope int delegate(ForeachType!T[] component) dg){
            this.sortFreeList;
            size_t freeIndex = 0;

            foreach(i, ref Component element; this.mArray){
                if(freeIndex < this.sortedFreeList.length() && this.sortedFreeList[freeIndex] == i){
                    freeIndex++;
                    continue;
                }
                if(i >= this.mLast)
                    break;
                
                auto result = dg(element.component);
                if(result)
                    return result;
            }
            return 0;
        }
    }
    else{
        ref T opIndex(size_t index){
            return this.mArray[index].component;
        }
        public int opApply(scope int delegate(ref T component) dg){
            this.sortFreeList;
            size_t freeIndex = 0;

            foreach(i, ref Component element; this.mArray){
                if(freeIndex < this.sortedFreeList.length() && this.sortedFreeList[freeIndex] == i){
                    freeIndex++;
                    continue;
                }
                if(i >= this.mLast)
                    break;

                int result = dg(element.component);
                if(result)
                    return result;
            }
            return 0;
        }
    }
    
    blockAllocator mAllocator;
    blockType mBlock;

    Component[] mArray;
    Array!size_t sortedFreeList;
    bool actualFreeList = true;

    size_t mFirstFree = NoneIndex;  // First for allocation index in free list.
    size_t mAllocated = 0;          // Count of allocated element.
    size_t mLast = 0;               // Index of last element is don't touched block of memory.
}

class SizedPoolAllocator(alias blockAllocator = BlockAllocator, alias blockType = BlockType): IPoolAllocator!(ubyte[]){

    this(blockAllocator allocator, size_t size)
    {
        import std.algorithm.comparison: max;

        debug assert(allocator !is null, "Block allocator is null");
        this.mAllocator = allocator;

        this.mBlock = this.mAllocator.alloc();
        this.mArray = this.mBlock.data.convertationWithTruncation!(void, ubyte);

        this.mElementSize = max(size_t.sizeof, size);
        this.mLength = this.mArray.length / this.mElementSize;
    }


    private ref size_t componentIndex(size_t index){
        size_t* indexPointer = cast(size_t*) &this.mArray[index*this.mElementSize];
        return *indexPointer;
    }
    
    private ubyte[] componentByIndex(size_t index){
        const size_t start = index * this.mElementSize;
        return this.mArray[start .. start + this.mElementSize];
    }


    size_t allocate()
    {
        assert(this.avaliable > 0, "No avaliable elements to allocate!");
        size_t index;
        if(this.mFirstFree != NoneIndex){
            index = this.mFirstFree;
            this.mFirstFree = this.componentIndex(index);
        }
        else{
            index = this.mLast;
            this.mLast++;
        }
        this.mAllocated++;
        return index;
    }
    
    void deallocate(size_t index)
    {
        assert(index < this.mArray.length, "Out of bounds.");
        debug(memory){
            for(size_t iterator = this.mFirstFree; iterator != NoneIndex; iterator = this.componentIndex(iterator)){
                import std.conv: to;
                assert(iterator != index, "Double free index [" ~ index.to!string ~ "].");
            }
        }
        this.componentIndex(index) = this.mFirstFree;
        this.mFirstFree = index;
        this.mAllocated--;
    }


    Array!size_t allocate(size_t count)
    {
        assert(this.avaliable >= count, "No avaliable elements to allocate!");

        Array!size_t indexArray;
        indexArray.reserve(count);

        while(this.mFirstFree != NoneIndex && indexArray.length < count){
            indexArray ~= this.mFirstFree;
            this.mFirstFree = this.componentIndex(this.mFirstFree);
        }
        while(indexArray.length < count){
            indexArray ~= this.mLast;
            this.mLast++;
        }

        this.mAllocated += count;

        return indexArray;
    }
    
    void deallocate(size_t[] deallocate)
    {
        debug(memory)
        {
            foreach(ref index; deallocate){
                assert(index < this.mArray.length, "Out of bounds.");
                for(size_t iterator = this.mFirstFree; iterator != NoneIndex; iterator = this.componentIndex(iterator))
                {
                    import std.conv: to;
                    assert(iterator != index, "Double free index [" ~ index.to!string ~ "].");
                }
            }
        }

        foreach(ref index; deallocate)
        {
            this.componentIndex(index) = this.mFirstFree;
            this.mFirstFree = index;
        }
        this.mAllocated -= deallocate.length;
    }

    
    size_t max()
    {
        return this.mLength;
    }   

    size_t avaliable()
    {
        return this.mLength - this.mAllocated;
    }

    size_t allocated()
    {
        return this.mAllocated;
    }

    ubyte[] opIndex(size_t index){
        return this.componentByIndex(index);
    }

    public int opApply(scope int delegate(ubyte[] component) dg){
        foreach(size_t index; 0..this.mLast){
            ubyte[] component = this.componentByIndex(index);
            auto result = dg(component);
            if(result)
                return result;
        }
        return 0;
    }


    blockAllocator mAllocator;
    blockType mBlock;

    ubyte[] mArray;
    const size_t mElementSize;      // Contain max(size_t.sizeof, size of element).
    const size_t mLength;           // Calculated count of elements which can be stored.

    size_t mFirstFree = NoneIndex;  // First for allocation index in free list.
    size_t mAllocated = 0;          // Count of allocated element.
    size_t mLast = 0;               // Index of last element is don't touched block of memory.
}

unittest {
    import dlib.core.memory, std.stdio, std.datetime;
    scope(success)
    {
        import evoengine.utils.logging;
        globalLogger.info("Success");
    }
    scope(failure)
    {
        import evoengine.utils.logging;
        globalLogger.error("Failure!");
    }

    BlockAllocator allocator = New!BlockAllocator;
    IPoolAllocator!int poolAllocator = New!(PoolAllocator!int)(allocator);
    IPoolAllocator!(ubyte[]) sizedPoolAllocator = New!(SizedPoolAllocator!())(allocator, cast(size_t)16);

    size_t[] elements;
    elements.length = poolAllocator.avaliable;

    foreach(i; 0..10)
    {
        foreach(ref element; elements)
        {
            element = poolAllocator.allocate;
            poolAllocator[element] = 4;
        }
        foreach(ref element; elements)
        {
            assert(poolAllocator[element] == 4);
            poolAllocator.deallocate(element);
        }
    }

    elements.length = sizedPoolAllocator.avaliable;
    elements[0..$] = 0;

    foreach(i; 0..10)
    {
        import std.array: array;
        import std.range: iota;

        immutable(ubyte[]) templateData = ubyte(16).iota.array;

        foreach(ref element; elements)
        {
            element = sizedPoolAllocator.allocate;
            sizedPoolAllocator[element][0..$] = templateData[0..$];
        }
        foreach(ref element; elements)
        {
            assert(sizedPoolAllocator[element][0..$] == templateData[0..$]);
            sizedPoolAllocator.deallocate(element);
        }
    }
}