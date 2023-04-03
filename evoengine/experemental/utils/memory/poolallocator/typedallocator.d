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
        shared uint mOperations;
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
            element.mNextFree = cast(uint) i + 1;
        }
        this.mArray[$ - 1].mNextFree = NoneIndex;
    }

    /// Allocate one element and get index.
    public uint allocate()
    {
        while (true)
        {
            ulong firstFree = this.mFirstFree.atomicLoad;

            if ((cast(uint) firstFree) == NoneIndex)
            {
                return NoneIndex;
            }
            ulong nextFree = this.mArray[cast(uint) firstFree].mNextFree;

            if ((cast(uint) nextFree) != NoneIndex)
            {
                nextFree = nextFree + (
                    (cast(ulong) this.mArray[nextFree].mOperations.atomicLoad + 1) << 32);
            }

            if (cas(&this.mFirstFree, firstFree, nextFree))
            {
                this.mAllocated.atomicFetchAdd(1);
                this.mArray[cast(uint) firstFree].mOperations.atomicFetchAdd(1);
                this.mArray[cast(uint) firstFree].mFree = false;
                this.mArray[cast(uint) firstFree].component = T.init;

                return cast(uint) firstFree;
            }
        }
    }

    /// Deallocate one element by index.
    public void deallocate(uint index)
    {
        import std.conv : to;

        assert(!this.mArray[index].mFree, "Double free detected " ~ index.to!string);
        this.mArray[index].mFree = true;

        while (true)
        {
            ulong firstFree = this.mFirstFree.atomicLoad;
            this.mArray[index].mNextFree = cast(uint) firstFree;

            ulong newFree = index + ((cast(ulong) this.mArray[index].mOperations.atomicLoad + 1) << 32);
            if (cas(&this.mFirstFree, firstFree, newFree))
            {
                this.mArray[index].mOperations.atomicFetchAdd(1);
                this.mAllocated.atomicFetchSub(1);
                return;
            }
        }
    }

    /// Allocate a set of count of element and return array with indexes(none GC array for optimizations).
    public Array!uint allocate(uint count)
    {
        Array!uint indexArray;
        indexArray.reserve(count);

        while (indexArray.length < count)
        {
            ulong firstFree = this.mFirstFree.atomicLoad;

            if (firstFree == NoneIndex)
            {
                break;
            }
            ulong nextFree = this.mArray[cast(uint) firstFree].mNextFree;
            if ((cast(uint) nextFree) != NoneIndex)
            {
                nextFree = nextFree + (
                    (cast(ulong) this.mArray[nextFree].mOperations.atomicLoad + 1) << 32);
            }

            if (cas(&this.mFirstFree, firstFree, nextFree))
            {
                this.mAllocated.atomicFetchAdd(1);
                this.mArray[cast(uint) firstFree].mOperations.atomicFetchAdd(1);
                this.mArray[cast(uint) firstFree].mFree = false;
                this.mArray[cast(uint) firstFree].component = T.init;
                indexArray ~= cast(uint) firstFree;
            }
        }
        return indexArray;
    }

    /// Deallocate a set of element(D array, so as not to duplicate the array).
    public void deallocate(uint[] deallocate)
    {
        import std.conv : to;

        while (deallocate.length != 0)
        {
            assert(!this.mArray[deallocate[0]].mFree, "Double free detected " ~ deallocate[0]
                .to!string);
            this.mArray[deallocate[0]].mFree = true;

            ulong firstFree = this.mFirstFree.atomicLoad;
            this.mArray[deallocate[0]].mNextFree = cast(uint) firstFree;

            ulong newFree = deallocate[0] + (
                (cast(ulong) this.mArray[deallocate[0]].mOperations.atomicLoad + 1) << 32);

            if (cas(&this.mFirstFree, firstFree, newFree))
            {
                this.mAllocated.atomicFetchSub(1);
                this.mArray[deallocate[0]].mOperations.atomicFetchAdd(1);
                return;
            }
        }
    }
    /// Return max count of elements.
    public uint max()
    {
        return cast(uint) this.mArray.length;
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
            import std.conv : to;

            assert(!this.mArray[index].mFree, "Try access to deallocated element " ~ index
                .to!string);
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
            import std.conv : to;

            assert(!this.mArray[index].mFree, "Try access to deallocated element " ~ index
                .to!string);
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

    private shared ulong mFirstFree = 0;
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
    IPoolAllocator!int poolAllocator = New!(PoolAllocator!int)(allocator);

    scope (exit)
    {
        Delete(poolAllocator);
        Delete(allocator);
    }

    foreach (i; 0 .. 10)
    {
        foreach (i; 10.iota.parallel(10))
        {
            uint[] elements;
            elements.length = poolAllocator.avaliable / 10;

            foreach (ref element; elements)
            {
                element = poolAllocator.allocate;
                assert(element != NoneIndex);
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
