module evoengine.utils.memory.mallocator;

/// TODO: Normal implement!!!

debug
alias Allocator = DebugWrapper!MallocAllocator;
else alias Allocator = MallocAllocator;

struct MallocAllocator
{
    static T[] allocate(T)(size_t length)
    {
        import core.stdc.stdlib : malloc;

        T[] data = malloc(length * T.sizeof)[0 .. length];

        static if (!is(T == void))
        { /// TODO: Add optimization(memset like).
            foreach (ref el; data)
            {
                el = T.init;
            }
        }
        return data;
    }

    static void deallocate(T)(T[] data)
    {
        import core.stdc.stdlib : free;

        free(data.ptr);
    }
}

/// TODO: Add leaks output and normal errors logging.

class DebugWrapper(allocator)
{
    import std.datetime : Clock, SysTime;

    struct AllocationData
    {
        string file;
        string func;
        ulong line;
        bool free;
        SysTime allocTime;
    }

    static T[] allocate(T)(size_t length, string file = __FILE__, string func = __PRETTY_FUNCTION__, ulong line = __LINE__)
    {
        T[] data = allocator.allocate!T(length);
        AllocationData allocationData;

        allocationData.file = file;
        allocationData.func = func;
        allocationData.line = line;
        allocationData.allocTime = Clock.currTime;

        synchronized (DebugWrapper.classinfo)
        {
            this.gAllocations[cast(size_t) data.ptr] = allocationData;
        }
        return data;
    }

    static void deallocate(T)(T[] data)
    {
        synchronized (DebugWrapper.classinfo)
        {
            AllocationData* record = ((cast(size_t) data.ptr) in this.gAllocations);

            scope (failure)
            {
                import evoengine.utils.logging;

                globalLogger.error("Memory free error!");
            }

            assert(record, "Free not allocated memory!");
            assert(!record.free, "Double free memory!");
            record.free = true;
        }

        allocator.deallocate!T(data);
    }

    shared static ~this()
    {
        foreach (i, ref AllocationData data; gAllocations)
        {
            if (!data.free)
            {
                import evoengine.utils.logging;

                globalLogger.warn!(string)("Leaks detected!", data.file, data.file, data.line, "", data.func, data
                        .func);
            }
        }
    }

    static __gshared AllocationData[size_t] gAllocations;
}

@("MallocAllocator")
unittest
{
    void[][] test;
    test.length = 100_000;

    foreach (ref element; test)
    {
        element = Allocator.allocate!void(128);
    }

    foreach (ref element; test)
    {
        Allocator.deallocate(element);
    }
}
