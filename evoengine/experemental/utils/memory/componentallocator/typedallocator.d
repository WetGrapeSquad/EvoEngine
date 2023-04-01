module evoengine.experemental.utils.memory.componentallocator.typedallocator;
import evoengine.experemental.utils.memory.componentallocator.common;
import core.internal.spinlock;

class ComponentAllocator(T)
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
        foreach (ref ComponentsBlock block; this.mBlocks)
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
        UnitPosition position;
        position.block = -1; // for position.block++ in end of this method.

        foreach (size_t i, ref ComponentsBlock block; this.mBlocks)
        {
            position.block = cast(uint) i;
            if (block.poolAllocator.avaliable > 0)
            {
                position.id = cast(uint) block.poolAllocator.allocate();
                if(position.id != NoneIndex)
                {
                    return position.fullIndex;
                }
            }
        }
        position.block++;

        spinLocker.lock();

        {
            if(this.mBlocks.length <= position.block)
            {
                ComponentsBlock block;
                block.poolAllocator = New!(PoolAllocator!T)(this.mBlockAllocator);
                this.mBlocks ~= block;
            }
        }

        spinLocker.unlock();

        position.id = cast(uint) this.mBlocks[this.mBlocks.length() - 1].poolAllocator.allocate();
        return this.unitPositionToId(position);
    }

    /// Main method for free allocated component by id.
    public void deallocate(size_t id)
    {
        UnitPosition position;
        position.fullIndex = id;
        assert(position.block < this.mBlocks.length, "Id not created by ComponentAllocator");

        this.mBlocks[position.block].poolAllocator.deallocate(position.id);
    }

    public void reduceMemoryUsage()
    {
        if (this.mBlocks[this.mBlocks.length - 1].poolAllocator.allocated == 0)
        {
            spinLocker.lock();

            while (this.mBlocks.length > 1 && this.mBlocks[this.mBlocks.length - 2].poolAllocator.allocated == 0)
            {
                Delete(this.mBlocks[this.mBlocks.length - 1].poolAllocator);
                this.mBlocks.removeBack(1);
            }

            spinLocker.unlock();
        }
    }

    ~this()
    {
        foreach (ref ComponentsBlock block; this.mBlocks)
        {
            Delete(block.poolAllocator);
        }
    }

    /// Get for reference of component by id
    public ref T opIndex(size_t id)
    {
        UnitPosition position = this.idToUnitPosition(id);
        return this.mBlocks[position.block].poolAllocator[position.id];
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
    import std.datetime, std.stdio;
    auto start = Clock.currTime;

    BlockAllocator blockAllocator = New!BlockAllocator;
    ComponentAllocator!int componentAllocator = New!(ComponentAllocator!int)(blockAllocator);

    scope (exit)
    {
        Delete(componentAllocator);
        Delete(blockAllocator);
    }

    size_t lastId;

    foreach (i; 10000.iota.parallel)
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

    foreach (i; 10000.iota.parallel)
    {
        size_t[128] id1;
        foreach (ref id; id1)
        {
            id = componentAllocator.allocate();
        }
        foreach (ref id; id1)
        {
            componentAllocator[id] = 5;
        }
        foreach (ref id; id1)
        {
            import std.stdio;

            assert(componentAllocator[id] == 5, "Assignment and/or getting value by id is't working!");
            componentAllocator.deallocate(id);
        }
    }
    writeln(Clock.currTime - start);
    componentAllocator.reduceMemoryUsage;
}

/** 
✗ .typedallocator Experemental/TypedComponentAllocator
core.exception.AssertError thrown from evoengine/experemental/utils/memory/poolallocator/typedallocator.d on line 73: Double free detected
--- Stack trace ---
??:? _d_assert_msg [0x559f07c06bb8]
evoengine/experemental/utils/memory/poolallocator/typedallocator.d:73 void evoengine.experemental.utils.memory.poolallocator.typedallocator.PoolAllocator!(int, evoengine.utils.memory.blockallocator.BlockAllocator, evoengine.utils.memory.blockallocator.BlockType).PoolAllocator.deallocate(uint) [0x559f07b592a2]
evoengine/experemental/utils/memory/componentallocator/typedallocator.d:92 void evoengine.experemental.utils.memory.componentallocator.typedallocator.ComponentAllocator!(int).ComponentAllocator.deallocate(ulong) [0x559f07b56f6d]
evoengine/experemental/utils/memory/componentallocator/typedallocator.d:187 int evoengine.experemental.utils.memory.componentallocator.typedallocator.__unittest_L132_C1().__foreachbody5(int) [0x559f07b5692c]
/usr/include/dlang/dmd/std/parallelism.d-mixin-4102:4148 void std.parallelism.ParallelForeach!(std.range.iota!(int, int).iota(int, int).Result).ParallelForeach.opApply(scope int delegate(int)).doIt() [0x559f07b572dc]
??:? void std.parallelism.run!(void delegate()).run(void delegate()) [0x559f07c26d87]
??:? void std.parallelism.Task!(std.parallelism.run, void delegate()).Task.impl(void*) [0x559f07c26867]
??:? void std.parallelism.AbstractTask.job() [0x559f07c4efa6]
??:? void std.parallelism.TaskPool.doJob(std.parallelism.AbstractTask*) [0x559f07c253af]
??:? void std.parallelism.TaskPool.executeWorkLoop() [0x559f07c2551e]
??:? void std.parallelism.TaskPool.startWorkLoop() [0x559f07c254c7]
??:? void core.thread.context.Callable.opCall() [0x559f07c1c2c8]
??:? thread_entryPoint [0x559f07c1bbde]
??:? [0x7f318c119bb4]
??:? [0x7f318c19bd8f]  
*/