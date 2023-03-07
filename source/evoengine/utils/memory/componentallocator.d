module evoengine.utils.memory.componentallocator;
import evoengine.utils.memory.blockallocator;
import dlib.container.array;


size_t typesInBytes(T)(size_t bytes){
    return bytes / T.sizeof;
}

T[] convertationWithTruncation(F, T)(F[] from){
    return (cast(T*)from.ptr)[0..typesInBytes!T(from.length * F.sizeof)];
}

class ComponentAllocator(T){
    struct UnitPosition{
        private size_t block;
        private size_t id;
    }
    struct ClearFlagsBlock{
        private UnitPosition[] positions;
        private BlockType block;
    }
    struct ComponentsBlock{
        private T[] components;
        private BlockType block;
    }

    this(BlockAllocator blockAllocator){
        debug assert(blockAllocator !is null, "Block allocator is null");
        this.mBlockAllocator = blockAllocator;

        this.mClearFlagsInBlock = blockAllocator.blockSize.typesInBytes!UnitPosition;
        this.mComponentsInBlock = blockAllocator.blockSize.typesInBytes!T;
    }

    public int opApply(scope int delegate(ref T component) dg){     /// WARNING: FOREACH MAY CALLS FOR CLEAR COMPONENT.
        foreach(i, ref block; this.mComponents){
            foreach(j, ref element; block.components){
                if(i >= this.mNextComponent.block && j >= this.mNextComponent.id)
                    return 0;
                int result = dg(element);
                if(result)
                    return result;
            }
        }
        return 0;
    }

    private void putToClear(UnitPosition position){
        if(mNextClearFlag.block == this.mClearFlags.length){
            ClearFlagsBlock newBlock;
            
            newBlock.block = this.mBlockAllocator.alloc;
            newBlock.positions = newBlock.block.data.convertationWithTruncation!(void, UnitPosition);

            this.mClearFlags ~= newBlock;
        }

        mClearFlags[this.mNextClearFlag.block].positions[this.mNextClearFlag.id] = position;

        this.mNextClearFlag.id++;

        if(this.mNextClearFlag.id == this.mClearFlagsInBlock){
            this.mNextClearFlag.id = 0;
            this.mNextClearFlag.block++;
        }
    }

    private UnitPosition takeFromClear(){
        assert(this.haveClear, "Cannot take clear flag, becouse no one exists!");

        UnitPosition selectPosition = this.mNextClearFlag;
        if(selectPosition.id == 0){
            selectPosition.block--;
            selectPosition.id = this.mClearFlagsInBlock - 1;
        }else selectPosition.id--;

        UnitPosition retPosition = this.mClearFlags[selectPosition.block].positions[selectPosition.id];
        this.mNextClearFlag = selectPosition;

        if(selectPosition.id == 0){
            this.mBlockAllocator.free(this.mClearFlags[this.mClearFlags.length - 1].block);
            this.mClearFlags.removeBack(1);
        }

        return retPosition;
    }
    private bool haveClear(){
        return (this.mNextClearFlag.block > 0 || this.mNextClearFlag.id > 0);
    }

    private UnitPosition idToUnitPosition(size_t id){
        return UnitPosition(id / this.mComponentsInBlock, id % this.mComponentsInBlock);
    }
    private size_t unitPositionToId(UnitPosition position){
        return position.block * this.mComponentsInBlock + position.id;
    }

    size_t alloc(){
        if(this.haveClear){
            UnitPosition position = this.takeFromClear;
            return this.unitPositionToId(position);
        }
        if(this.mNextComponent.block == this.mComponents.length){
            ComponentsBlock newBlock;
            
            newBlock.block = this.mBlockAllocator.alloc;
            newBlock.components = newBlock.block.data.convertationWithTruncation!(void, T);

            this.mComponents ~= newBlock;
        }
        auto position = this.mNextComponent;
        this.mNextComponent.id++;

        if(this.mNextComponent.id == this.mComponentsInBlock){
            this.mNextComponent.id = 0;
            this.mNextComponent.block++;
        }
        return this.unitPositionToId(position);
    }

    void free(size_t id){
        debug assert(this.idToUnitPosition(id).block < this.mComponents.length, "Id not created by ComponentAllocator");
        this.putToClear(this.idToUnitPosition(id));
    }
    ref T opIndex(size_t id){
        auto position = this.idToUnitPosition(id);
        return this.mComponents[position.block].components[position.id];
    }


    BlockAllocator mBlockAllocator;

    Array!ClearFlagsBlock mClearFlags;
    UnitPosition mNextClearFlag;
    const size_t mClearFlagsInBlock;
    
    Array!ComponentsBlock mComponents;
    UnitPosition mNextComponent;
    const size_t mComponentsInBlock;
}





unittest{
    struct Type{
        int i = 0;
    }

    scope(success){
        import evoengine.utils.logging;
        globalLogger.info("Success");
    }
    scope(failure){
        import evoengine.utils.logging;
        globalLogger.error("Failure!");
    }
    import dlib.core.memory: New, Delete;

    BlockAllocator blockAllocator = New!BlockAllocator;
    ComponentAllocator!int componentAllocator = New!(ComponentAllocator!int)(blockAllocator);

    scope(exit){
        Delete(blockAllocator);
        Delete(componentAllocator);
    }
    size_t lastId;
    import std.algorithm;
    foreach(i; 0..10){
        size_t[128] id1;
        size_t[128] id2;
        size_t[128] id3;

        foreach(ref id; id1){
            id = componentAllocator.alloc();
        }
        foreach(ref id; id2){
            id = componentAllocator.alloc();
        }
        foreach(ref id; id1){
            componentAllocator.free(id);
        }
        foreach(ref id; id3){
            id = componentAllocator.alloc();
        }
        foreach(ref id; id1){
            id = componentAllocator.alloc();
        }
        foreach(ref id; id1){
            componentAllocator.free(id);
        }
        foreach(ref id; id2){
            componentAllocator.free(id);
        }
        foreach(ref id; id3){
            componentAllocator.free(id);
        }
    }
    foreach(i; 0..10){
        size_t[128] id1;
        foreach(ref id; id1){
            id = componentAllocator.alloc();
        }
        foreach(ref id; id1){
            componentAllocator[id] = 5;
        }
        foreach(ref id; id1){
            import std.stdio;
            assert(componentAllocator[id] == 5, "Assignment and/or getting value by id is't working!");
        }
    }
}