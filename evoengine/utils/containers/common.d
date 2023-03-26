module evoengine.utils.containers.common;
import dlib.container.array;
import std.traits;

template isClass(T)
{
    enum isClass = is(T == class);
}
template isInterface(T)
{
    enum isInterface = is(T == interface);
}
template isStruct(T)
{
    enum isStruct = is(T == struct);
}
template isCompositeType(T)
{
    enum isCompositeType = isClass!T || isInterface!T || isStruct!T;
}
template toArrayType(T)
{
    static if(isArray!T)
    {
        alias toArrayType = Array!(toArrayType!(ForeachType!T));
    }
    else
    {
        alias toArrayType = Unconst!T;
    }
}

toArrayType!T toDlibArray(T)(T array)
{
    static assert(isArray!(T), "T must be array!");

    toArrayType!T ret;

    static if(isArray!(ForeachType!T))
    {
        ret.reserve = array.length;
        foreach(ref element; array)
        {
            ret ~= toDlibArray(element);
        }
    }
    else
    {
        ret.resize(array.length, ForeachType!T.init);
        (cast(ForeachType!T[])ret.data)[0..$] = array[0..$];
    }
    return ret;
}