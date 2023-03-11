module evoengine.utils.memory.componentallocator;

import evoengine.utils.memory.blockallocator;
import evoengine.utils.memory.poolallocator;
import dlib.core.memory;
import dlib.container.array;


class ComponentAllocator(T)
{
    /// UnitPosition struct what contain unit position by block and index
    private struct UnitPosition
    {
        /// Convert inner index to UnitPosition;
        public this(size_t index)
        {
            this.id = cast(uint)index;
            this.block = cast(uint)(index >> (uint.sizeof * 8));
        }
        /// Construct with inner block and id.
        public this(uint block, uint id)
        {
            this.id = id;
            this.block = block;
        }
        /// Cmp this and position
        public int opCmp(ref UnitPosition position) 
        {
            static if(size_t.sizeof == UnitPosition.sizeof){
                long cmp = cast(long)this.opCast - cast(long)position.opCast;
                return cast(int)cmp;
            }
            else{
                uint block = this.block - position.block;
                if(block != 0){
                    return block;
                }
                uint id = this.id - position.id;
                if(id != 0){
                    return id;
                }
                return 0;
            }
        }
        /// Conver this to inner index.
        public size_t opCast()
        {
            return ((cast(size_t)block) << (uint.sizeof * 8)) + id;
        }

        private uint block;
        private uint id;
    }
    
    private struct ComponentsBlock{
        private IPoolAllocator!T poolAllocator;
    }


    /// Default constructor. BlockAllocator needed for allocate big blocks of memory
    public this(BlockAllocator blockAllocator)
    {
        debug assert(blockAllocator !is null, "Block allocator is null");
        this.mBlockAllocator = blockAllocator;
    }

    /// Foreach all components
    public int opApply(scope int delegate(ref T component) dg)      /// WARNING: FOREACH MAY CALLS FOR CLEAR COMPONENT.
    {
        foreach(ref ComponentsBlock block; this.mBlocks){
            auto result = block.poolAllocator.opApply(dg);
            if(result)
                return result;
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
        position.block = -1;  // for position.block++ in end of this method.

        foreach(size_t i, ref ComponentsBlock block; this.mBlocks){
            position.block = cast(uint)i;
            if(block.poolAllocator.avaliable > 0){
                position.id = cast(uint) block.poolAllocator.allocate();
                return this.unitPositionToId(position);
            }
        }
        ComponentsBlock block;
        block.poolAllocator = New!(PoolAllocator!T)(this.mBlockAllocator);
        this.mBlocks ~= block;

        position.id = cast(uint) this.mBlocks[this.mBlocks.length()-1].poolAllocator.allocate();
        position.block++;

        return this.unitPositionToId(position);
    }

    /// Main method for free allocated component by id.
    public void deallocate(size_t id)
    {
        UnitPosition position = this.idToUnitPosition(id);
        debug assert(position.block < this.mBlocks.length, "Id not created by ComponentAllocator");

        this.mBlocks[position.block].poolAllocator.deallocate(position.id);
        
        if(position.block + 1 == this.mBlocks.length && this.mBlocks[this.mBlocks.length-1].poolAllocator.allocated == 0){
            while(this.mBlocks.length > 0 && this.mBlocks[this.mBlocks.length - 1].poolAllocator.allocated == 0){
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


    private BlockAllocator mBlockAllocator;
    
    private Array!ComponentsBlock mBlocks;
}


unittest{
    import evoengine.utils.logging;
    scope(success)
    {
        globalLogger.info("Success");
    }
    scope(failure)
    {
        globalLogger.error("Failure!");
    }

    struct Type
    {
        int i = 0;
    }
    import std.algorithm, dlib.core.memory: New, Delete;

    BlockAllocator blockAllocator = New!BlockAllocator;
    ComponentAllocator!int componentAllocator = New!(ComponentAllocator!int)(blockAllocator);

    scope(exit)
    {
        Delete(blockAllocator);
        Delete(componentAllocator);
    }

    size_t lastId;

    foreach(i; 0..10)
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
    
    foreach(i; 0..10)
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
}