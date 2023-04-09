module evoengine.utils.memory.common;


/** 
* None index value. 
*/
enum LockFreeIndex NoneIndex = LockFreeIndex(0, cast(uint)-1);

/** 
* Implementation index type for lock-free structures.
*/
union LockFreeIndex
{
    this(string fullIndex)
    {
        import std.format: formattedRead;

        string range = fullIndex;
        formattedRead(range, "%d[operations:%d|index:%d]", this.fullIndex, this.operations, this.index);
        assert(fullIndex == this.toString(), "Invalid LockFreeIndex string!");
    }
    this(ulong fullIndex)
    {
        this.fullIndex = fullIndex;
    }
    this(uint operations, uint index)
    {
        this.operations = operations;
        this.index = index;
    }

    auto opAssign(ulong fullIndex)
    {
        this.fullIndex = fullIndex;

        return this;
    }
    auto opAssign(uint operations, uint index)
    {
        this.operations = operations;
        this.index = index;

        return this;
    }

    const ulong opCast()
    {
        if(this.index == -1)
        {
            return -1;
        }
        return this.fullIndex;
    }

    string toString()
    {
        import std.format;
        return "%d[operations:%d|index:%d]".format(fullIndex, operations, index);
    }

    ulong fullIndex;        /// Contain operations count with real index for cas operations

    struct
    {
        uint operations;    /// Count of operations with element.
        uint index;         /// Real index.
    }
}

unittest
{
    import std.stdio;

    LockFreeIndex index;
    index.operations = 3;
    index.index = 24;

    index = LockFreeIndex(index.toString);

    assert(index == LockFreeIndex(3, 24));
}