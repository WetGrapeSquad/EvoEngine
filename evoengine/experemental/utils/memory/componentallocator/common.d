module evoengine.experemental.utils.memory.componentallocator.common;;
public import evoengine.utils.memory.blockallocator;
public import evoengine.experemental.utils.memory.poolallocator;
public import dlib.core.memory;
public import dlib.container.array;
import core.int128;

/// In current time not support 32-bits systems.
struct UnitPosition
{
    /// Convert inner index to UnitPosition;
    public this(size_t index, size_t sizing)
    {
        this.fullIndex = index;
    }
    /// Construct with inner block and id.
    public this(uint block, uint id)
    {
        this.id = id;
        this.block = block;
    }

    /// Cmp this and position
    public long opCmp(ref UnitPosition position)
    {
        long compare = this.block - position.block;

        if(compare == 0)
            compare = this.id - position.id;

        return compare;
    }

    union
    {
        size_t fullIndex;
        struct 
        {
            uint block;
            uint id;
        }
    }
}
