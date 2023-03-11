module evoengine.utils.containers.bitarray;
import dlib.container.array;
import dlib.core.bitio;

struct FlagArray
{
    bool opIndexAssign(bool flag, size_t index) @property
    {
        uint block = cast(uint) index / size_t.sizeof, bit;
        while (block >= this.data.length)
            this.data.insertBack(0);

        bit = index % size_t.sizeof;

        size_t tmp = this.data[block];
        tmp = setBit(tmp, bit, flag);
        this.data[block] = tmp;

        if (!flag)
        {
            while (this.data[this.data.length - 1] == 0 && this.data.length > 0)
            {
                this.data.removeBack(1);
            }
        }

        return flag;
    }

    bool opIndex(size_t index) @property
    {
        uint block = cast(uint) index / size_t.sizeof, bit;
        if (block >= this.data.length)
            return false;

        bit = index % size_t.sizeof;

        return data[block].getBit(bit);
    }

    bool containAll(FlagArray array)
    {
        if (this.data.length < array.data.length)
            return false;
        foreach (i, element; array.data)
        {
            if ((this.data[i] & element) != element)
                return false;
        }
        return true;
    }

    bool containAny(FlagArray array)
    {
        import std.algorithm.comparison;

        size_t length = min(this.data.length, array.data.length);

        foreach (i; 0 .. length)
        {
            if (this.data[i] & array.data[i])
                return true;
        }
        return false;
    }

    private Array!size_t data;
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

    FlagArray array1, array2, array3;
    
    array1[1] = true;
    array1[3] = true;
    array1[15] = true;

    array2[15] = true;
    array2[16] = true;

    array3[1] = true;
    array3[15] = true;

    assert(!array1.containAll(array2));
    assert(array1.containAny(array2));
    assert(array1.containAll(array3));
    assert(array1.containAny(array3));
}
