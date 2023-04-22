module evoengine.utils.memory.componentallocator.typedallocator;
import evoengine.utils.memory.componentallocator.common;
import core.internal.spinlock;

shared class ComponentAllocator(T)
{
    private struct ComponentsBlock
    {
        private IPoolAllocator!T poolAllocator;
    }

    /// Default constructor. BlockAllocator needed for allocate big blocks of memory
    public this(BlockAllocator blockAllocator)
    {
        debug assert(blockAllocator !is null, "Block allocator is null");
        this.mBlockAllocator = blockAllocator;
        this.spinLocker = SpinLock(SpinLock.Contention.brief);
    }

    /// Foreach all components
    public int opApply(scope int delegate(ref T component) dg) /// WARNING: FOREACH MAY CALLS FOR CLEAR COMPONENT.
    {
        foreach (ref ComponentsBlock block; cast(Array!ComponentsBlock) this.mBlocks)
        {
            auto result = block.poolAllocator.opApply(dg);
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
            IPoolAllocator!T block;
            spinLocker.lock();
            {
                if (position.block < (cast(Array!ComponentsBlock) this.mBlocks).length)
                {
                    block = (cast(Array!ComponentsBlock) this.mBlocks)[position.block]
                        .poolAllocator;
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
            while ((cast(Array!ComponentsBlock) this.mBlocks).length <= position.block)
            {
                ComponentsBlock block;
                block.poolAllocator = New!(PoolAllocator!T)(this.mBlockAllocator);
                (cast(Array!ComponentsBlock) this.mBlocks) ~= block;
            }
        }
        spinLocker.unlock();

        position.id = (cast(
                Array!ComponentsBlock) this.mBlocks)[position.block].poolAllocator.allocate();
        assert(position.id != NoneIndex);
        return this.unitPositionToId(position);
    }

    /// Main method for free allocated component by id.
    public void deallocate(size_t id)
    {
        UnitPosition position;
        position.fullIndex = id;
        assert(position.block < (cast(Array!ComponentsBlock) this.mBlocks)
                .length, "Id not created by ComponentAllocator");

        (cast(Array!ComponentsBlock) this.mBlocks)[position.block].poolAllocator.deallocate(
            position.id);
    }

    public void reduceMemoryUsage()
    {
        if ((cast(Array!ComponentsBlock) this.mBlocks)[(cast(Array!ComponentsBlock) this.mBlocks)
                .length - 1].poolAllocator.allocated == 0)
        {
            spinLocker.lock();

            {
                while ((cast(Array!ComponentsBlock) this.mBlocks).length > 1 && (
                        cast(Array!ComponentsBlock) this.mBlocks)[(cast(Array!ComponentsBlock) this.mBlocks)
                            .length - 2].poolAllocator.allocated == 0)
                {
                    Delete((cast(Array!ComponentsBlock)this.mBlocks)[(cast(Array!ComponentsBlock)this.mBlocks).length - 1].poolAllocator);
                    (cast(Array!ComponentsBlock)this.mBlocks).removeBack(1);
                }
            }

            spinLocker.unlock();
        }
    }

    ~this()
    {
        foreach (ref ComponentsBlock block; (cast(Array!ComponentsBlock)this.mBlocks))
        {
            Delete(block.poolAllocator);
        }
    }

    /// Get for reference of component by id
    public ref T opIndex(size_t id)
    {
        UnitPosition position = this.idToUnitPosition(id);
        return (cast(Array!ComponentsBlock)this.mBlocks)[position.block].poolAllocator[position.id];
    }

    private BlockAllocator mBlockAllocator;
    private Array!ComponentsBlock mBlocks;
    private SpinLock spinLocker;
}

@("Experemental/TypedComponentAllocator")
unittest
{
    import std.algorithm, dlib.core.memory : New, Delete;
    import std.parallelism, std.range;
    import evoengine.utils.memory.blockallocator;

    BlockAllocator blockAllocator = New!BlockAllocator;
    ComponentAllocator!int componentAllocator = New!(ComponentAllocator!int)(blockAllocator);

    scope (exit)
    {
        Delete(componentAllocator);
        Delete(blockAllocator);
    }

    foreach (i; 100.iota.parallel)
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

        foreach (ref id; id1)
        {
            id = componentAllocator.allocate();
        }
        foreach (ref id; id1)
        {
            componentAllocator[id] = 5;
        }
    }
}
