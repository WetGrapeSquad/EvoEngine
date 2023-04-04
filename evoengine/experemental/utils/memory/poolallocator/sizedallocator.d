module evoengine.experemental.utils.memory.poolallocator.sizedallocator;
import evoengine.experemental.utils.memory.poolallocator.common;
import evoengine.utils.memory.blockallocator;
import dlib.container.array;
import std.traits;
import core.atomic;

class SizedPoolAllocator(alias blockAllocator = BlockAllocator, alias blockType = BlockType)
    : IPoolAllocator!(ubyte[])
{
    struct Component
    {
        bool mFree = false;
        shared uint mOperations = 0;
        uint mNextFree;
    }

    this(BlockAllocator allocator, uint size)
    {
        this.mAllocator = allocator;
        this.mBlock = this.mAllocator.allocate();
        this.mArray = cast(ubyte[]) this.mBlock.data;

        this.mComponentFullSize = cast(uint) Component.sizeof + size;
        this.mDataSize = size;
        this.mLength = cast(uint)(this.mArray.length / this.mComponentFullSize);

        foreach (i; 0 .. this.mLength - 1)
        {
            this.getComponent(i) = Component(false, 0, i + 1);
        }
        this.getComponent(this.mLength - 1) = Component(false, 0, NoneIndex);
    }

    pragma(inline) private ref Component getComponent(uint index)
    {
        Component* component = cast(Component*)&this.mArray[index * this.mComponentFullSize];
        return *component;
    }

    pragma(inline) private ubyte[] getData(uint index)
    {
        ubyte* data = cast(ubyte*)&this.mArray[index * this.mComponentFullSize + Component.sizeof];
        return data[0 .. this.mDataSize];
    }

    /// Allocate one element and get index.
    public uint allocate()
    {
        while (true)
        {
            ComponentIndex firstFree = this.mFirstFree.atomicLoad;

            if (firstFree.index == NoneIndex)
            {
                return NoneIndex;
            }
            ComponentIndex nextFree;
            nextFree.index = this.getComponent(firstFree.index).mNextFree;

            if (nextFree.index != NoneIndex)
            {
                nextFree.operations = this.getComponent(nextFree.index).mOperations.atomicLoad + 1;
            }

            if (cas(&this.mFirstFree, firstFree.fullIndex, nextFree.fullIndex))
            {
                this.mAllocated.atomicFetchAdd(1);

                Component* comp = &this.getComponent(firstFree.index);
                comp.mOperations.atomicFetchAdd(1);
                comp.mFree = false;

                return firstFree.index;
            }
        }
    }

    /// Deallocate one element by index.
    public void deallocate(uint index)
    {
        import std.conv : to;

        Component* toFree = &this.getComponent(index);

        assert(!toFree.mFree, "Double free detected " ~ index.to!string);
        toFree.mFree = true;

        while (true)
        {
            ComponentIndex firstFree = this.mFirstFree.atomicLoad;
            toFree.mNextFree = firstFree.index;

            ComponentIndex newFree;
            newFree.index = index;
            newFree.operations = toFree.mOperations.atomicLoad + 1;

            if (cas(&this.mFirstFree, firstFree.fullIndex, newFree.fullIndex))
            {
                toFree.mOperations.atomicFetchAdd(1);
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
            ComponentIndex firstFree = this.mFirstFree.atomicLoad;

            if (firstFree.index == NoneIndex)
            {
                break;
            }
            ComponentIndex nextFree;
            nextFree.index = this.getComponent(firstFree.index).mNextFree;

            if (nextFree.index != NoneIndex)
            {
                nextFree.operations = this.getComponent(nextFree.index).mOperations.atomicLoad + 1;
            }

            if (cas(&this.mFirstFree, firstFree.fullIndex, nextFree.fullIndex))
            {
                this.mAllocated.atomicFetchAdd(1);
                Component* comp = &this.getComponent(firstFree.index);
                comp.mOperations.atomicFetchAdd(1);
                comp.mFree = false;

                indexArray ~= firstFree.index;
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
            import std.conv : to;

            Component* toFree = &this.getComponent(deallocate[0]);

            assert(!toFree.mFree, "Double free detected " ~ deallocate[0].to!string);
            toFree.mFree = true;

            while (true)
            {
                ComponentIndex firstFree = this.mFirstFree.atomicLoad;
                toFree.mNextFree = firstFree.index;

                ComponentIndex newFree;
                newFree.index = deallocate[0];
                newFree.operations = toFree.mOperations.atomicLoad + 1;

                if (cas(&this.mFirstFree, firstFree.fullIndex, newFree.fullIndex))
                {
                    toFree.mOperations.atomicFetchAdd(1);
                    this.mAllocated.atomicFetchSub(1);
                    deallocate = deallocate[1 .. $];
                    break;
                }
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
        return this.mLength - this.allocated;
    }
    /// Return count of occupied elements.
    public uint allocated()
    {
        return this.mAllocated.atomicLoad;
    }

    ubyte[] opIndex(uint index)
    {
        import std.conv : to;

        assert(!this.getComponent(index).mFree, "Try access to deallocated element " ~ index
                .to!string);
        return this.getData(index);
    }

    public int opApply(scope int delegate(ubyte[] component) dg)
    {
        foreach (index; 0 .. this.mLength)
        {
            if (this.getComponent(cast(uint) index).mFree)
            {
                continue;
            }

            auto result = dg(this.getData(cast(uint) index));
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

    private const uint mDataSize; /// Structure shrink size.
    private const uint mComponentFullSize; /// Component size(allocation target size).
    private const uint mLength; /// Components count.

    private shared ulong mFirstFree = 0;
    private shared uint mAllocated = 0;
}

@("Experemental/SizedPoolAllocator")
unittest
{
    import dlib.core.memory;
    import std.range;
    import std.parallelism;

    BlockAllocator allocator = New!BlockAllocator;

    scope (exit)
    {
        Delete(allocator);
    }

    immutable(ubyte[16]) templateData = ubyte(16).iota.array;

    foreach (i; 0 .. 1_000)
    {
        SizedPoolAllocator!() sizedPoolAllocator = New!(SizedPoolAllocator!())(allocator, 16);
        scope (exit)
        {
            Delete(sizedPoolAllocator);
        }

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
}

/*
Unittest failed:
core.exception.ArrayIndexError@evoengine/experemental/utils/memory/poolallocator/sizedallocator.d(59): index [1412963332] is out of bounds for array of length 131072
----------------
??:? onArrayIndexError [0x7efe5e36a36d]
??:? _d_arraybounds_index [0x7efe5e36a98d]
evoengine/experemental/utils/memory/poolallocator/sizedallocator.d:58 [0x55fc4ee41667]
evoengine/experemental/utils/memory/poolallocator/sizedallocator.d:90 [0x55fc4ee417ad]
evoengine/experemental/utils/memory/poolallocator/sizedallocator.d:272 [0x55fc4ee410bb]
/usr/include/dlang/ldc/std/parallelism.d-mixin-4093:4139 [0x55fc4ee43ade]
??:? void std.parallelism.TaskPool.executeWorkLoop() [0x7efe5e07804f]
??:? thread_entryPoint [0x7efe5e392509]
??:? [0x7efe5db96bb4]
??:? [0x7efe5dc18d8f]
 ✓ .utils.containers.flagarray FlagArray
 ✓ .utils.containers.binary BinaryBuffer
 ✓ .utils.memory.classregistrator ClassRegistrator
 ✓ .ecs.component.componentarray ECS/ComponentArray
 ✓ .utils.memory.blockallocator BlockAllocator
5 ms, 822 μs, and 9 hnsecs
 ✓ .sizedcomponentallocator SizedComponentAllocator
 ✓ .typedcomponentallocator TypedComponentAllocator
 ✓ .sizedAllocator Experemental/SizedComponentAllocator
 ✓ .utils.memory.poolallocator PoolAllocator
 ✓ .poolallocator.typedallocator Experemental/PoolAllocator
 ✓ .utils.ecs.component.component ECS/Component
 ✓ evoengine.utils.ecs.entity ECS/EntityManager
 ✓ .utils.memory.mallocator MallocAllocator
4 secs, 464 ms, 8 μs, and 9 hnsecs
 ✓ .typedallocator Experemental/TypedComponentAllocator
Aborting from core/sync/mutex.d(149) Error: pthread_mutex_destroy failed.
*/
