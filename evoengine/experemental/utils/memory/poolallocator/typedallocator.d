module evoengine.experemental.utils.memory.poolallocator.typedallocator;
import evoengine.experemental.utils.memory.poolallocator.common;
import evoengine.utils.memory.blockallocator;
import dlib.container.array;
import std.traits;
import core.atomic;


class PoolAllocator(T, alias blockAllocator = BlockAllocator, alias blockType = BlockType)
    : IPoolAllocator!T
{
    /// Dynamic array is't support for allocation.
    static assert(!isDynamicArray!T,
        "PoolAllocator works only with static array, basics types, structs or class reference");

    private struct Component
    {
        bool mFree;
        union
        {
            uint mNextFree;
            T component;
        }
    }

    this(blockAllocator allocator)
    {
        this.mAllocator = allocator;

        this.mBlock = this.mAllocator.allocate();
        this.mArray = this.mBlock.data.convertationWithTruncation!(void, Component);

        foreach (i, ref Component element; this.mArray)
        {
            element.mFree = true;
            element.mNextFree = cast(uint)i + 1;
        }
        this.mArray[$ - 1].mNextFree = NoneIndex;
    }

    /// Allocate one element and get her index.
    public uint allocate()
    {
        while (true)
        {
            uint firstFree = this.mFirstFree.atomicLoad;

            if (firstFree == NoneIndex)
            {
                return NoneIndex;
            }
            uint nextFree = this.mArray[firstFree].mNextFree;

            if (!cas(&this.mFirstFree, firstFree, nextFree))
            {
                continue;
            }

            this.mAllocated.atomicFetchAdd(1);
            this.mArray[firstFree].mFree = false;
            this.mArray[firstFree].component = T.init;
            return firstFree;
        }
    }
    /// Deallocate one element by her index.
    public void deallocate(uint index)
    {
        import std.conv: to;
        assert(!this.mArray[index].mFree, "Double free detected " ~ index.to!string);
        this.mArray[index].mFree = true;

        while (true)
        {
            uint firstFree = this.mFirstFree.atomicLoad;
            this.mArray[index].mNextFree = firstFree;

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
            uint nextFree = this.mArray[firstFree].mNextFree;

            if (!cas(&this.mFirstFree, firstFree, nextFree))
            {
                continue;
            }

            this.mAllocated.atomicFetchAdd(1);
            this.mArray[firstFree].mFree = false;
            this.mArray[firstFree].component = T.init;

            indexArray ~= firstFree;
        }
        return indexArray;
    }
    /// Deallocate a set of element(D array, so as not to duplicate the array).
    public void deallocate(uint[] deallocate)
    {
        while (deallocate.length != 0)
        {
            uint firstFree = this.mFirstFree.atomicLoad;
            this.mArray[deallocate[0]].mNextFree = firstFree;

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
        return cast(uint)this.mArray.length;
    }
    /// Return avaliable for allocation count of element.
    public uint avaliable()
    {
        return cast(uint) this.mArray.length - this.mAllocated.atomicLoad;
    }
    /// Return count of occupied elements.
    public uint allocated()
    {
        return this.mAllocated.atomicLoad;
    }

    static if (isStaticArray!T)
    {
        ForeachType!T[] opIndex(uint index)
        {
            import std.conv: to;
            assert(!this.mArray[index].mFree, "Try access to deallocated element" ~ index.to!string);
            return this.mArray[index].component;
        }

        public int opApply(scope int delegate(ForeachType!T[] component) dg)
        {
            foreach (ref Component element; this.mArray)
            {
                if (element.mFree)
                {
                    continue;
                }

                auto result = dg(element.component);
                if (result)
                    return result;
            }
            return 0;
        }
    }
    else
    {
        ref T opIndex(uint index)
        {
            import std.conv: to;
            assert(!this.mArray[index].mFree, "Try access to deallocated element" ~ index.to!string);
            return this.mArray[index].component;
        }

        public int opApply(scope int delegate(ref T component) dg)
        {
            foreach (ref Component element; this.mArray)
            {
                if (element.mFree)
                {
                    continue;
                }

                auto result = dg(element.component);
                if (result)
                    return result;
            }
            return 0;
        }
    }

    ~this()
    {
        this.mAllocator.deallocate(this.mBlock);
    }

    private blockAllocator mAllocator;
    private blockType mBlock;

    private Component[] mArray;

    private shared uint mFirstFree = 0;
    private shared uint mAllocated = 0;
}

@("Experemental/PoolAllocator")
unittest
{
    import dlib.core.memory;
    import std.range;
    import std.parallelism;
    import std.stdio;
    import std.datetime;


    BlockAllocator allocator = New!BlockAllocator;

    scope (exit)
    {
        //Delete(poolAllocator);
        Delete(allocator);
    }

    foreach(i; 0..1000)
    {
        IPoolAllocator!int poolAllocator = New!(PoolAllocator!int)(allocator);
        
        scope (exit)
        {
            Delete(poolAllocator);
            //Delete(allocator);
        }

        foreach (i; 100.iota.parallel(10))
        {
            uint[] elements;
            elements.length = poolAllocator.avaliable / 100;

            foreach (ref element; elements)
            {
                element = poolAllocator.allocate;
                poolAllocator[element] = 4;
            }
            foreach (ref element; elements[0 .. $ / 2])
            {
                assert(poolAllocator[element] == 4);
                poolAllocator.deallocate(element);
            }

            foreach (ref element; elements[$ / 2 .. $])
            {
                assert(poolAllocator[element] == 4);
                poolAllocator.deallocate(element);
            }
        }
    }
}