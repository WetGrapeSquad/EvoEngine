module evoengine.utils.containers.lowLockQueue;
import core.atomic;
import dlib.core.memory;
import core.internal.spinlock;
import std.typecons;

shared struct LowLockQueue(T)
{
    private struct Node
    {
        this(ref T data)
        {
            this.mData = data;
        }

        Node* mNext = null;
        T mData;
    }
    void put(T data)
    {
        Node* node = new Node(data);
        
        spinLock.lock();
        scope(exit)
        {
            spinLock.unlock();
        }

        node.mNext = cast(Node*)this.nextNode;
        this.nextNode = cast(shared(Node*))node;
    }

    Tuple!(T, bool) take()
    {
        spinLock.lock();
        scope(exit)
        {
            spinLock.unlock();
        }

        Node* node = (cast(Node*)this.nextNode);
        if(node == null)
        {
            return tuple(T.init, false);
        }

        T data = node.mData;
        *(cast(Node**)&this.nextNode) = (*(cast(Node**)&this.nextNode.mNext));

        return tuple(data, true);
    }

    SpinLock spinLock = SpinLock(SpinLock.Contention.brief);
    private shared(Node*) nextNode = null;
}

unittest
{
    import std.range;
    import std.parallelism;
    import std.datetime;
    import std.stdio;

    LowLockQueue!int lowLockQueue;
    foreach(i; 1000.iota.parallel)
    {
        lowLockQueue.put(123);
    }

    foreach(i; 1000.iota.parallel)
    {
        assert(lowLockQueue.take[0] == 123);
    }

    assert(lowLockQueue.take[1] == false);
}