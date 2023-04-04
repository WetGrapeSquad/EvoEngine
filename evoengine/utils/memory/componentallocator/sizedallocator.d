module evoengine.utils.memory.componentallocator.sizedallocator;
import evoengine.utils.memory.componentallocator.common;
import core.internal.spinlock;

class SizedComponentAllocator
{
    private struct ComponentsBlock
    {
        private SizedPoolAllocator!() sizedAllocator;
    }

    /// Default constructor. BlockAllocator needed for allocate big blocks of memory
    public this(BlockAllocator blockAllocator, uint size)
    {
        debug assert(blockAllocator !is null, "Block allocator is null");
        this.mBlockAllocator = blockAllocator;
        this.spinLocker = SpinLock(SpinLock.Contention.brief);
        this.mSize = size;
    }

    /// Foreach all components
    public int opApply(scope int delegate(ubyte[] component) dg) /// WARNING: FOREACH MAY CALLS FOR CLEAR COMPONENT.
    {
        foreach (ref ComponentsBlock block; this.mBlocks)
        {
            auto result = block.sizedAllocator.opApply(dg);
            if (result)
            {
                return result;
            }
        }
        return 0;
    }

    /// Help function to convert id of component to UnitPostion 
    private UnitPosition idToUnitPosition(size_t id)
    {
        UnitPosition position;
        position.fullIndex = id;
        return position;
    }

    /// Help function to convert position(UnitPosition) of component to id 
    private size_t unitPositionToId(UnitPosition position)
    {
        return position.fullIndex;
    }

    /// Main method to allocate and get id of component
    public size_t allocate()
    {
        import core.atomic;

        UnitPosition position;
        position.block = 0; // for position.block++ in end of this method.

        while (true)
        {
            SizedPoolAllocator!() block;
            spinLocker.lock();
            {
                if (position.block < this.mBlocks.length)
                {
                    block = this.mBlocks[position.block].sizedAllocator;
                }
                else
                {
                    spinLocker.unlock();
                    break;
                }
            }
            spinLocker.unlock();

            position.id = block.allocate();

            if (position.id != NoneIndex)
            {
                return position.fullIndex;
            }
            position.block++;
        }
        position.block++;

        spinLocker.lock();
        {
            while (this.mBlocks.length <= position.block)
            {
                ComponentsBlock block;
                block.sizedAllocator = New!(SizedPoolAllocator!())(this.mBlockAllocator, this.mSize);
                this.mBlocks ~= block;
            }
        }
        spinLocker.unlock();

        position.id = this.mBlocks[position.block].sizedAllocator.allocate();
        assert(position.id != NoneIndex);
        return this.unitPositionToId(position);
    }

    /// Main method for free allocated component by id.
    public void deallocate(size_t id)
    {
        UnitPosition position;
        position.fullIndex = id;
        assert(position.block < this.mBlocks.length, "Id not created by ComponentAllocator");

        this.mBlocks[position.block].sizedAllocator.deallocate(position.id);
    }

    public void reduceMemoryUsage()
    {
        if (this.mBlocks[this.mBlocks.length - 1].sizedAllocator.allocated == 0)
        {
            spinLocker.lock();

            {
                while (this.mBlocks.length > 1 && this.mBlocks[this.mBlocks.length - 2].sizedAllocator.allocated == 0)
                {
                    Delete(this.mBlocks[this.mBlocks.length - 1].sizedAllocator);
                    this.mBlocks.removeBack(1);
                }
            }

            spinLocker.unlock();
        }
    }

    ~this()
    {
        foreach (ref ComponentsBlock block; this.mBlocks)
        {
            Delete(block.sizedAllocator);
        }
    }

    /// Get for reference of component by id
    public ubyte[] opIndex(size_t id)
    {
        UnitPosition position = this.idToUnitPosition(id);
        return this.mBlocks[position.block].sizedAllocator[position.id];
    }

    private BlockAllocator mBlockAllocator;
    private Array!ComponentsBlock mBlocks;
    private SpinLock spinLocker;

    private const uint mSize;
}

@("Experemental/SizedComponentAllocator")
unittest
{
    import std.range, std.array, std.algorithm, dlib.core.memory : New, Delete;
    import evoengine.utils.memory.blockallocator;

    BlockAllocator blockAllocator = New!BlockAllocator;
    SizedComponentAllocator componentAllocator = New!(SizedComponentAllocator)(blockAllocator, 24);

    scope (exit)
    {
        Delete(componentAllocator);
        Delete(blockAllocator);
    }

    size_t lastId;

    foreach (i; 0 .. 10)
    {
        size_t[128] id1;
        size_t[128] id2;
        size_t[128] id3;

        foreach (ref id; id1)
        {
            id = componentAllocator.allocate();
        }
        foreach (ref id; id2)
        {
            id = componentAllocator.allocate();
        }
        foreach (ref id; id1)
        {
            componentAllocator.deallocate(id);
        }
        foreach (ref id; id3)
        {
            id = componentAllocator.allocate();
        }
        foreach (ref id; id1)
        {
            id = componentAllocator.allocate();
        }
        foreach (ref id; id1)
        {
            componentAllocator.deallocate(id);
        }
        foreach (ref id; id2)
        {
            componentAllocator.deallocate(id);
        }
        foreach (ref id; id3)
        {
            componentAllocator.deallocate(id);
        }
    }

    ubyte[] testData = (ubyte(24)).iota.array[0 .. 24];

    foreach (i; 0 .. 10)
    {
        size_t[128] id1;
        foreach (ref id; id1)
        {
            id = componentAllocator.allocate();
        }
        foreach (ref id; id1)
        {
            componentAllocator[id][0 .. 24] = testData[0 .. 24];
        }
        foreach (ref id; id1)
        {
            import std.stdio;

            assert(componentAllocator[id][0 .. 24] == testData[0 .. 24], "Assignment and/or getting value by id is't working!");
        }
    }
}
