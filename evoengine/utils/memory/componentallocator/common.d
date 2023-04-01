module evoengine.utils.memory.componentallocator.common;

public import evoengine.utils.memory.blockallocator;
public import evoengine.utils.memory.poolallocator;
public import dlib.core.memory;
public import dlib.container.array;


/// UnitPosition struct what contain unit position by block and index
struct UnitPosition
{
    /// Convert inner index to UnitPosition;
    public this(size_t index)
    {
        this.id = cast(uint) index;
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
        static if (size_t.sizeof == UnitPosition.sizeof)
        {
            long cmp = cast(long) this.opCast - cast(long) position.opCast;
            return cast(int) cmp;
        }
        else
        {
            uint block = this.block - position.block;
            if (block != 0)
            {
                return block;
            }
            uint id = this.id - position.id;
            if (id != 0)
            {
                return id;
            }
            return 0;
        }
    }
    /// Conver this to inner index.
    public size_t opCast()
    {
        return ((cast(size_t) block) << (uint.sizeof * 8)) + id;
    }

    public uint block;
    public uint id;
}