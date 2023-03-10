module evoengine.utils.memory.mallocator;

/// TODO: Normal implement!!!

debug
    alias Allocator = DebugWrapper!MallocAllocator;
else 
    alias Allocator = MallocAllocator;

struct MallocAllocator
{
    static T[] alloc(T)(size_t length){
        import core.stdc.stdlib: malloc;
        T[] data = malloc(length * T.sizeof)[0..length];

        static if(!is(T == void)){  /// TODO: Add optimization(memset like).
            foreach(ref el; data){
                el = T.init;
            }
        }
        return data;
    }
    static void free(T)(T[] data)
    {
        import core.stdc.stdlib: free;
        
        free(data.ptr);
    }
}

/// TODO: Add leaks output and normal errors logging.

class DebugWrapper(allocator)
{
    import std.datetime: Clock, SysTime;

    struct AllocationData
    {
        string file;
        string func;
        ulong line;
        bool free;
        SysTime allocTime;
    }

    static T[] alloc(T)(size_t length, string file = __FILE__, string func = __PRETTY_FUNCTION__, ulong line = __LINE__)
    {
        T[] data = allocator.alloc!T(length);
        AllocationData allocationData;

        allocationData.file = file;
        allocationData.func = func;
        allocationData.line = line;
        allocationData.allocTime = Clock.currTime;

        synchronized(DebugWrapper.classinfo){
            this.allocation[cast(size_t) data.ptr] = allocationData;
        }
        return data;
    }

    static void free(T)(T[] data)
    {
        synchronized(DebugWrapper.classinfo){
            AllocationData* record = ((cast(size_t)data.ptr) in this.allocation);

            scope(failure){
                import evoengine.utils.logging;
                globalLogger.error("Memory free error!"); 
            }

            assert(record, "Free not allocated memory!");
            assert(!record.free, "Double free memory!");
            record.free = true;
        }
    }

    static __gshared AllocationData[size_t] allocation;
}

unittest {
    scope(success)
    {
        import evoengine.utils.logging;
        globalLogger.info("Success");
    }
    scope(failure)
    {
        import evoengine.utils.logging;
        globalLogger.error("Failure!");
    }

    void[][] test; 
    test.length = 100_000;
    
    foreach(ref element; test) 
    {
        element = Allocator.alloc!void(128);
    }

    foreach(ref element; test) 
    {
        Allocator.free(element);
    }
}