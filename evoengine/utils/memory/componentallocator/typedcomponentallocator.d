module evoengine.utils.memory.componentallocator.typedcomponentallocator;
import evoengine.utils.memory.componentallocator.common;

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
        return UnitPosition(id);
    }
    /// Help function to convert position(UnitPosition) of component to id 
    private size_t unitPositionToId(UnitPosition position)
    {
        return position.opCast;
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
                return this.unitPositionToId(position);
            }
        }
        ComponentsBlock block;
        block.poolAllocator = New!(PoolAllocator!T)(this.mBlockAllocator);
        this.mBlocks ~= block;

        position.id = cast(uint) this.mBlocks[this.mBlocks.length() - 1].poolAllocator.allocate();
        position.block++;

        return this.unitPositionToId(position);
    }

    /// Main method for free allocated component by id.
    public void deallocate(size_t id)
    {
        UnitPosition position = this.idToUnitPosition(id);
        debug assert(position.block < this.mBlocks.length, "Id not created by ComponentAllocator");

        this.mBlocks[position.block].poolAllocator.deallocate(position.id);

        if (position.block + 1 == this.mBlocks.length && this
            .mBlocks[this.mBlocks.length - 1].poolAllocator.allocated == 0)
        {
            while (this.mBlocks.length > 0 && this.mBlocks[this.mBlocks.length - 1].poolAllocator.allocated == 0)
            {
                Delete(this.mBlocks[this.mBlocks.length - 1].poolAllocator);
                this.mBlocks.removeBack(1);
            }
        }
    }

    /// Get for reference of component by id
    public ref T opIndex(size_t id)
    {
        UnitPosition position = this.idToUnitPosition(id);
        return this.mBlocks[position.block].poolAllocator[position.id];
    }

    ~this()
    {
        foreach (ref ComponentsBlock block; this.mBlocks)
        {
            Delete(block.poolAllocator);
        }
    }

    private BlockAllocator mBlockAllocator;

    private Array!ComponentsBlock mBlocks;
}

@("TypedComponentAllocator")
unittest
{
    import std.algorithm, dlib.core.memory : New, Delete;
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

    foreach (i; 0 .. 100)
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

    foreach (i; 0 .. 100)
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
        }
    }
    writeln(Clock.currTime - start);
}
