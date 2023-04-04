module evoengine.utils.memory.poolallocator.common;
import evoengine.utils.containers.binary;
import dlib.container.array;
import std.traits;

enum NoneIndex = -1;

uint typesInBytes(T)(uint bytes)
{
    return bytes / T.sizeof;
}

T[] convertationWithTruncation(F, T)(F[] from)
{
    return (cast(T*) from.ptr)[0 .. typesInBytes!T(cast(uint) from.length * F.sizeof)];
}

uint shrink(uint size, uint alignment)
{
    for (uint i = 1; true; i++)
    {
        if (size <= i * alignment)
        {
            return i * alignment;
        }
    }
}

immutable(uint) shrink(uint size, uint alignment)()
{
    for (uint i = 1; true; i++)
    {
        if (size <= i * alignment)
        {
            return i * alignment;
        }
    }
}

/// Interface of all PoolAllocator with index adressation.
interface IPoolAllocator(T): Serializable
{
    /// Allocate one element and get her index.
    uint allocate();
    /// Deallocate one element by her index.
    void deallocate(uint index);
    /// Allocate a set of count of element and return array with indexes(none GC array for optimizations).
    Array!uint allocate(uint count);
    /// Deallocate a set of element(D array, so as not to duplicate the array).
    void deallocate(uint[] deallocate);
    /// Return max count of elements.
    uint max();
    /// Return avaliable for allocation count of element.
    uint avaliable();
    /// Return count of occupied elements.
    uint allocated();
    /** 
    *   For opIndex there are three cases: If static array return dynamic 
    *   array pointing on array in IPoolAllocator, else if array is dynamic
    *   then like in first case returning dynamic array, else return 
    *   reference to the element, becouse that is not array.
    */
    static if (isStaticArray!T)
    {
        ForeachType!T[] opIndex(uint index);
        public int opApply(scope int delegate(ForeachType!T[] component) dg);
    }
    else static if (isDynamicArray!T)
    {
        T opIndex(uint index);
        public int opApply(scope int delegate(T component) dg);
    }
    else
    {
        ref T opIndex(uint index);
        public int opApply(scope int delegate(ref T component) dg);
    }
}
union ComponentIndex
{
    this(ulong index)
    {
        this.fullIndex = index;
    }

    this(uint operations, uint index)
    {
        this.operations = operations;
        this.index = index;
    }

    struct
    {
        uint operations;
        uint index;
    }
    ulong fullIndex;
}