module evoengine.utils.containers.binary;
import evoengine.utils.containers.common;
import dlib.container.array;
import std.traits;

/** 
 * Write/Read ordering.
 */
enum Order
{
    FILO,   /// `F`irst `I`n `L`ast `O`ut
    FIFO    /// `F`irst `I`n `F`irst `O`ut
}
/** 
 * Interface for all serializable data types working with BinaryBuffer. 
 * In the future it will be used as the main tool for saving/loading scenes, 
 * models, etc.
 */
interface Serializable
{
    /// Serialize data into BinaryBuffer.
    void serialize(Order order)(ref BinaryBuffer!order buffer);
    /// Deserialize data from BinaryBuffer.
    void deserialize(Order order)(ref BinaryBuffer!order buffer);
}

/** 
 * `BinaryBuffer` implement binary serialization structure. This structure
 *  have only one template argument - `order`. If `order = Order.FIFO`, then the 
 *  order of reading should be the reverse of writing(`F`irst `I`n `L`ast `O`ut).
 *  Else order of reading should be the order of writing(`F`irst `I`n `F`irst `O`ut).
 */
struct BinaryBuffer(Order order = Order.FILO)
{
    /// Help raw write method. Only write one variable to inner data buffer.
    private void rawWrite(T)(const ref T data)
    if(!isArray!T && !isCompositeType!T)
    {
        ubyte[] buffer = (cast(ubyte*)&data)[0..T.sizeof];
        this.mBuffer ~= buffer;
    }
    /// Help raw write method. Only write one-dimensional array to inner data buffer.(ONE-DIMENSIONAL)
    private void rawWrite(T)(const ref T[] data)
    if(!isArray!T && !isCompositeType!T)
    {
        ubyte[] buffer = (cast(ubyte*)data.ptr)[0..T.sizeof*data.length];
        this.mBuffer ~= buffer;
    }
    /// Help raw read method. Only read one variable from inner data buffer.
    private T rawRead(T)()
    if(!isArray!T && !isCompositeType!T)
    {
        assert(this.mBuffer.length >= T.sizeof);
        Unqual!T ret;
        ubyte[] buffer = (cast(ubyte*)&ret)[0..T.sizeof];

        static if(order == Order.FILO)
        {
            buffer[0..$] = this.mBuffer.data[$-T.sizeof..$];
            this.mBuffer.removeBack(T.sizeof);
        }
        else
        {
            buffer[0..$] = this.mBuffer.data[0..T.sizeof];
            this.mBuffer.removeFront(T.sizeof);
        }

        return cast(T)ret;
    }
    /// Help raw read method. Only read one-dimensional array from inner data buffer.(ONE-DIMENSIONAL)
    private toArrayType!T rawRead(T)(size_t length)
    if(isArray!T && !isCompositeType!T)
    {
        assert(this.mBuffer.length >= (ForeachType!T).sizeof*length);

        toArrayType!T buffer;
        buffer.reserve(length);

        static if(order == Order.FILO)
        {
            buffer ~= cast(T)(this.mBuffer.data[$ - ((ForeachType!T).sizeof*length)..$]);
            this.mBuffer.removeBack(cast(uint)((ForeachType!T).sizeof*length));
        }
        else
        {
            buffer ~= cast(T)(this.mBuffer.data[0..((ForeachType!T).sizeof*length)]);
            this.mBuffer.removeFront(cast(uint)((ForeachType!T).sizeof*length));
        }

        return buffer;
    }
    /// Inner wrap method on top rawWrite. Allow use multidimensional arrays.
    private void innerWrite(T)(const ref T data)
    if(!isCompositeType!T)
    {
        static if(isArray!T)
        {
            static if(order == Order.FILO)
            {
                static if(isArray!(ForeachType!T))
                {
                    foreach(ref element; data)
                    {
                        this.innerWrite(element);
                    }
                }
                else
                {
                    rawWrite(data);
                }
                auto length = data.length;
                rawWrite(length);
            }
            else
            {
                auto length = data.length;
                rawWrite(length);
                static if(isArray!(ForeachType!T))
                {
                    foreach(ref element; data)
                    {
                        this.innerWrite(element);
                    }
                }
                else
                {
                    rawWrite(data);
                }
            }
        }
        else
        {
            this.rawWrite!T(data);
        }
    }

    /// Inner wrap method on top rawRead. Allow use multidimensional arrays.
    private toArrayType!T innerRead(T)()
    if(!isCompositeType!T)
    {
        static if(isArray!T)
        {
            toArrayType!T buffer;

            size_t length = this.rawRead!size_t;
            buffer.resize(length, ForeachType!(typeof(buffer)).init);

            static if(isArray!(ForeachType!T))
            {
                static if(order == Order.FILO)
                {
                    foreach_reverse(ref element; buffer)
                    {
                        element = innerRead!(ForeachType!T);
                    }
                }
                else
                {
                    foreach(ref element; buffer)
                    {
                        element = innerRead!(ForeachType!T);
                    }
                }
            }
            else 
            {
                buffer = rawRead!(ForeachType!(typeof(buffer))[])(length);
            }

            return buffer;
        }
        else
        {
            return this.rawRead!T;
        }
    }
    
    /// Wrap on top innerWrite. Enable debuging/checking in `BinaryBuffer`.
    public void write(T)(T data)
    if(!isCompositeType!T)
    {
        debug{
            string type = T.stringof;
            static if(order == Order.FILO)
            {
                this.innerWrite(cast(const T)data);    
                this.innerWrite(type);
            }
            else
            {
                this.innerWrite!(string)(type);
                this.innerWrite(cast(const T)data);    
            }
        }
        else
        {
            this.innerWrite(cast(const T)data);   
        }
    }
    public void write(T)(T obj)
    if(is(T == Serializable))
    {
        debug{
            string type = T.stringof;
            static if(order == Order.FILO)
            {
                obj.serialize(*this);  
                this.innerWrite(type);
            }
            else
            {
                this.innerWrite(type);
                obj.serialize(*this);    
            }
        }
        else
        {
            obj.serialize(*this);
        }
    }

    /// Wrap on top innerRead. Enable debuging/checking in `BinaryBuffer`.
    public toArrayType!T read(T)()
    if(!isCompositeType!T)
    {
        debug
        {
            string str = this.innerRead!(string).data.idup;
            assert(str == T.stringof, str ~ " != " ~ T.stringof);
        }
        return this.innerRead!T;
    }
    public void read(T)(T obj)
    if(is(T == Serializable))
    {
        debug
        {
            string str = this.innerRead!(string).data.idup;
            assert(str == T.stringof, str ~ " != " ~ T.stringof);
        }
        obj.deserialize(this);
    }

    ubyte[] data()
    {
        return this.mBuffer.data;
    }

    Array!ubyte mBuffer;
}


@("BinaryBuffer")
unittest
{
    import std.stdio;
    
    static foreach(order; [Order.FIFO, Order.FILO])
    {
        {
            BinaryBuffer!(order) buffer;

            buffer.write(123);
            buffer.write("test");
            buffer.write([[1, 2], [3, 4]]);
            buffer.write(321);


            debug assert(buffer.data.length == 111);
            static if(order == Order.FIFO)
            {
                assert(buffer.read!int == 123);
                assert(cast(string)buffer.read!string.data() == "test");
                assert(buffer.read!(int[][]) == toDlibArray([[1, 2], [3, 4]]));
                assert(buffer.read!int == 321);
            }
            else
            {
                assert(buffer.read!int == 321);
                assert(buffer.read!(int[][]) == toDlibArray([[1, 2], [3, 4]]));
                assert(cast(string)buffer.read!string.data() == "test");
                assert(buffer.read!int == 123);
            }
            debug assert(buffer.data.length == 0);
        }
    }
}