module evoengine.utils.memory.blockallocator;
import evoengine.utils.memory.mallocator;
import std.typecons : Tuple;
import dlib.container.array;

struct BlockType
{
    private size_t id;
    public void[] data;
}

class BlockAllocator
{
    private enum BlockSize = 128 * 1024;
    private enum NoneBlock = -1;
    public this()
    {
    }

    public BlockType allocate()
    {
        BlockType block;

        if (this.mFreeBlock == NoneBlock)
        {
            BlockType newBlock;
            newBlock.data = Allocator.allocate!void(BlockSize);
            newBlock.id = NoneBlock;

            block.id = this.mBlocks.length;
            block.data = newBlock.data;

            this.mBlocks ~= newBlock;
        }
        else
        {
            size_t freeBlock = this.mFreeBlock;
            this.mFreeBlock = this.mBlocks[freeBlock].id;

            block.id = freeBlock;
            block.data = this.mBlocks[freeBlock].data;
        }

        return block;
    }

    public void deallocate(const BlockType block)
    {
        BlockType tmp = this.mBlocks[block.id];
        tmp.id = this.mFreeBlock;
        this.mBlocks[block.id] = tmp;

        this.mFreeBlock = block.id;
    }

    size_t blocksCount() pure
    {
        return this.mBlocks.length;
    }

    size_t allocatedMemory() pure
    {
        return this.blocksCount * BlockSize;
    }

    size_t blockSize() pure nothrow
    {
        return BlockSize;
    }

    ~this()
    {
        import evoengine.utils.memory.mallocator;

        debug
        {
            size_t freeCount;
            for (size_t index = this.mFreeBlock; index != NoneBlock; index = this.mBlocks[index].id)
            {
                freeCount++;
            }
            if (freeCount != this.mBlocks.length())
            {
                import evoengine.utils.logging;

                globalLogger.warn("Leaks Detected!", freeCount, this.mBlocks.length);
            }
        }
        foreach (block; this.mBlocks)
        {
            Allocator.deallocate(block.data);
        }
    }

    private Array!BlockType mBlocks;
    private size_t mFreeBlock = NoneBlock;
}

unittest
{
    scope (success)
    {
        import evoengine.utils.logging;

        globalLogger.info("Success");
    }
    scope (failure)
    {
        import evoengine.utils.logging;

        globalLogger.error("Failure!");
    }
    import dlib.core.memory : New, Delete;

    BlockAllocator blockAllocator = New!BlockAllocator;
    BlockType[] blocks;
    blocks.length = 100;

    scope (exit)
    {
        Delete(blockAllocator);
    }

    foreach (i; 0 .. 10)
    {
        foreach (ref block; blocks) // [0..$]
        {
            block = blockAllocator.allocate;
        }
        foreach (ref block; blocks[0 .. $ / 2]) // [$/2..$]
        {
            blockAllocator.deallocate(block);
        }
        foreach (ref block; blocks[$ / 4 .. $ / 2]) // [$/4..$]
        {
            block = blockAllocator.allocate;
        }
        foreach (ref block; blocks[$ / 2 .. $]) // [$/4 .. $/2]
        {
            blockAllocator.deallocate(block);
        }
        foreach (ref block; blocks[0 .. $ / 4]) // [0 .. $/2]
        {
            block = blockAllocator.allocate;
        }
        foreach (ref block; blocks[$ / 2 .. $]) // [0..$]
        {
            block = blockAllocator.allocate;
        }
        foreach (ref block; blocks) // [0..0]
        {
            blockAllocator.deallocate(block);
        }
    }

    import std.conv : to;

    size_t blocksCount = blockAllocator.blocksCount;
    assert(blocksCount == blocks.length, "Blocks count equal " ~ blocksCount.to!string ~ " that more than " ~ blocks
            .length.to!string);
}
