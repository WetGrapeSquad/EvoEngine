module evoengine.experemental.utils.memory.blockallocator;
import std.experimental.allocator;
import std.typecons;
import std.experimental.allocator.mmap_allocator;
import evoengine.utils.memory.blockallocator;
import core.internal.spinlock;
import dlib.container.queue;

class BlockAllocator : IAllocator
{
    enum BlockSize = 128 * MmapAllocator.alignment;
    struct Node 
    {
        this(const ref Node node)
        {
            this.memoryBlock = cast(void[])node.memoryBlock;
            this.memoryUnits = cast(void[128][])node.memoryUnits;
            this.freeFlags = node.freeFlags;
            this.freeCount = node.freeCount;
        }

        void[] memoryBlock;
        void[128][] memoryUnits;
        bool[128] freeFlags;
        size_t freeCount = 128;
    }
    this()
    {
        this.mMmapAllocator = MmapAllocator.instance;
    }

    /**
        Returns the alignment offered.
    */
    override nothrow @property uint alignment()
    {
        return this.mMmapAllocator.alignment;
    }

    /**
    Returns the good allocation size.
    */
    override nothrow size_t goodAllocSize(size_t s)
    {
        size_t allocSize;
        allocSize = s / this.mMmapAllocator.alignment;
        if(s / this.mMmapAllocator.alignment > 0)
        {
            allocSize++;
        }
        return allocSize * this.mMmapAllocator.alignment;
    }

    /**
    Allocates `n` bytes of memory.
    */
    override nothrow void[] allocate(size_t n, TypeInfo ti = null)
    {
        if(ti is null)
        {
            return this.alignedAllocate(n, 1);
        }
        return this.alignedAllocate(n, cast(uint)ti.talign);
    }

    /**
    Allocates `n` bytes of memory with specified alignment `a`. Implementations
    that do not support this primitive should always return `null`.
    */
    override nothrow void[] alignedAllocate(size_t n, uint a)
    {
        return null;
    }

    /**
    Allocates and returns all memory available to this allocator.
    Implementations that do not support this primitive should always return
    `null`.
    */
    override nothrow void[] allocateAll()
    {
        return null;
    }

    /**
    Expands a memory block in place and returns `true` if successful.
    Implementations that don't support this primitive should always return
    `false`.
    */
    override nothrow bool expand(ref void[], size_t)
    {
        return false;
    }

    /// Reallocates a memory block.
    override nothrow bool reallocate(ref void[] b, size_t n)
    {
        return this.alignedReallocate(b, n, 1);
    }

    /// Reallocates a memory block with specified alignment.
    override nothrow bool alignedReallocate(ref void[] b, size_t size, uint alignment)
    {
        return false;
    }

    /**
    Returns `Ternary.yes` if the allocator owns `b`, `Ternary.no` if
    the allocator doesn't own `b`, and `Ternary.unknown` if ownership
    cannot be determined. Implementations that don't support this primitive
    should always return `Ternary.unknown`.
    */
    override nothrow Ternary owns(void[] b)
    {
        return Ternary.unknown;
    }

    /**
    Resolves an internal pointer to the full block allocated. Implementations
    that don't support this primitive should always return `Ternary.unknown`.
    */
    override nothrow Ternary resolveInternalPointer(const void* p, ref void[] result)
    {
        return Ternary.unknown;
    }

    /**
    Deallocates a memory block. Implementations that don't support this
    primitive should always return `false`. A simple way to check that an
    allocator supports deallocation is to call `deallocate(null)`.
    */
    override nothrow bool deallocate(void[] b)
    {
        return false;
    }

    /**
    Deallocates all memory. Implementations that don't support this primitive
    should always return `false`.
    */
    override nothrow bool deallocateAll()
    {
        return false;
    }

    /**
    Returns `Ternary.yes` if no memory is currently allocated from this
    allocator, `Ternary.no` if some allocations are currently active, or
    `Ternary.unknown` if not supported.
    */
    override nothrow Ternary empty()
    {
        return Ternary.unknown;
    }

    /**
    Increases the reference count of the concrete class that implements this
    interface.

    For stateless allocators, this does nothing.
    */
    override nothrow @safe @nogc pure
    void incRef()
    {}

    /**
    Decreases the reference count of the concrete class that implements this
    interface.
    When the reference count is `0`, the object self-destructs.

    Returns: `true` if the reference count is greater than `0` and `false` when
    it hits `0`. For stateless allocators, it always returns `true`.
    */
    override nothrow @safe @nogc pure
    bool decRef()
    {return false;}

    const(shared(MmapAllocator)) mMmapAllocator;
    shared(Queue!(Node)) blocks;
    shared(SpinLock) mLock = SpinLock(SpinLock.Contention.brief);
}