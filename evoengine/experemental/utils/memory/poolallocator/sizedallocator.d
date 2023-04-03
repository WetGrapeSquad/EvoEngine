module evoengine.experemental.utils.memory.poolallocator.sizedallocator;
import evoengine.experemental.utils.memory.poolallocator.common;
import evoengine.utils.memory.blockallocator;
import dlib.container.array;
import std.traits;
import core.atomic;


class SizedPoolAllocator(alias blockAllocator = BlockAllocator, alias blockType = BlockType)
    : IPoolAllocator!(ubyte[])
{

    /*  
    *   Structure of block element. Structure size multiple uint.sizeof.
    *   mFree -> 0 byte
    *   mNextFree -> uint.sizeof byte
    *   memory -> uint.sizeof byte
    *
    *   struct Component
    *   {
    *       bool mFree;
    *       union
    *       {
    *           uint mNextFree;
    *           ubyte[size] memory;
    *       }
    *   }
    */

    this(blockAllocator allocator, uint size)
    {
        this.mAllocator = allocator;

        this.mBlock = this.mAllocator.allocate();
        this.mArray = cast(ubyte[]) this.mBlock.data;

        this.mComponentSize = size;
        this.mElementSize = shrink(cast(uint)(uint.sizeof * 2) + size, cast(uint)uint.sizeof);
        this.mLength = cast(uint) mArray.length / this.mElementSize;

        for (uint i = 0; i < this.mLength; i++)
        {
            this.getFreeFlag(i) = true;
            this.getNextFree(i) = i + 1;
        }
        this.getNextFree(this.mLength - 1) = NoneIndex;
    }

    final pragma(inline) private ref uint getNextFree(uint index)
    {
        uint* indexPointer = cast(uint*)(&this.mArray[index * this.mElementSize + cast(uint)uint.sizeof]);
        return *indexPointer;
    }

    final pragma(inline) private ref bool getFreeFlag(uint index)
    {
        bool* freeFlag = cast(bool*)(&this.mArray[index * this.mElementSize]);
        return *freeFlag;
    }

    final pragma(inline) private ubyte[] getComponent(uint index)
    {
        ubyte* component = cast(ubyte*)(&this.mArray[index * this.mElementSize + uint.sizeof]);
        return component[0 .. this.mComponentSize];
    }

    /// Allocate one element and get her index.
    public uint allocate()
    {
        if (this.avaliable == 0)
        {
            return NoneIndex;
        }

        while (true)
        {
            uint firstFree = this.mFirstFree.atomicLoad;

            if (firstFree == NoneIndex)
            {
                return NoneIndex;
            }
            uint nextFree = this.getNextFree(firstFree);

            if (!cas(&this.mFirstFree, firstFree, nextFree))
            {
                continue;
            }

            this.mAllocated.atomicFetchAdd(1);
            this.getFreeFlag(firstFree) = false;
            return firstFree;
        }
    }
    /// Deallocate one element by her index.
    public void deallocate(uint index)
    {
        assert(!this.getFreeFlag(index), "Double free detected");
        this.getFreeFlag(index) = true;

        while (true)
        {
            uint firstFree = this.mFirstFree.atomicLoad;
            this.getNextFree(index) = firstFree;

            if (cas(&this.mFirstFree, firstFree, index))
            {
                this.mAllocated.atomicFetchSub(1);
                return;
            }
        }
    }
    /// Allocate a set of count of element and return array with indexes(none GC array for optimizations).
    public Array!uint allocate(uint count)
    {
        if (this.avaliable == 0)
        {
            return Array!uint.init;
        }

        Array!uint indexArray;
        indexArray.reserve(count);

        while (indexArray.length < count)
        {
            uint firstFree = this.mFirstFree.atomicLoad;

            if (firstFree == NoneIndex)
            {
                break;
            }
            uint nextFree = this.getNextFree(firstFree);

            if (!cas(&this.mFirstFree, firstFree, nextFree))
            {
                continue;
            }

            this.mAllocated.atomicFetchAdd(1);
            this.getFreeFlag(firstFree) = false;

            indexArray ~= firstFree;
        }
        return indexArray;
    }
    /// Deallocate a set of element(D array, so as not to duplicate the array).
    public void deallocate(uint[] deallocate)
    {
        foreach (index; deallocate)
        {
            this.getFreeFlag(index) = true;
        }
        while (deallocate.length != 0)
        {
            uint firstFree = this.mFirstFree.atomicLoad;
            this.getNextFree(deallocate[0]) = firstFree;

            if (cas(&this.mFirstFree, firstFree, deallocate[0]))
            {
                this.mAllocated.atomicFetchSub(1);
                deallocate = deallocate[1 .. $];
            }
        }
    }
    /// Return max count of elements.
    public uint max()
    {
        return this.mLength;
    }
    /// Return avaliable for allocation count of element.
    public uint avaliable()
    {
        return this.mLength - this.mAllocated.atomicLoad;
    }
    /// Return count of occupied elements.
    public uint allocated()
    {
        return this.mAllocated.atomicLoad;
    }

    ubyte[] opIndex(uint index)
    {
        assert(!this.getFreeFlag(index), "Try access to deallocated element");
        return this.getComponent(index);
    }

    public int opApply(scope int delegate(ubyte[] component) dg)
    {
        foreach (uint index; 0 .. this.mLength)
        {
            if (this.getFreeFlag(index))
            {
                continue;
            }

            ubyte[] component = this.getComponent(index);
            auto result = dg(component);

            if (result)
            {
                return result;
            }
        }
        return 0;
    }

    ~this()
    {
        this.mAllocator.deallocate(this.mBlock);
    }

    private blockAllocator mAllocator;
    private blockType mBlock;

    private ubyte[] mArray;

    private const uint mElementSize; /// Structure shrink size.
    private const uint mComponentSize; /// Component size(allocation target size).
    private const uint mLength; /// Components count.

    private shared uint mFirstFree = 0;
    private shared uint mAllocated = 0;
}

@("Experemental/SizedPoolAllocator")
unittest
{
    import dlib.core.memory;
    import std.range;
    import std.parallelism;

    BlockAllocator allocator = New!BlockAllocator;
    IPoolAllocator!(ubyte[]) sizedPoolAllocator = New!(SizedPoolAllocator!())(allocator, 16);

    scope (exit)
    {
        Delete(sizedPoolAllocator);
        Delete(allocator);
    }

    immutable(ubyte[]) templateData = ubyte(16).iota.array;
    foreach (i; 100.iota.parallel)
    {
        import std.array : array;
        import std.range : iota;

        uint[] elements;
        elements.length = sizedPoolAllocator.avaliable / 100;

        foreach (ref element; elements)
        {
            element = sizedPoolAllocator.allocate;
            sizedPoolAllocator[element][0 .. $] = templateData[0 .. $];
        }
        foreach (ref element; elements[0 .. $ / 2])
        {
            assert(sizedPoolAllocator[element][0 .. $] == templateData[0 .. $]);
            sizedPoolAllocator.deallocate(element);
        }

        foreach (ref element; elements[$ / 2 .. $])
        {
            assert(sizedPoolAllocator[element][0 .. $] == templateData[0 .. $]);
            sizedPoolAllocator.deallocate(element);
        }
    }
}
