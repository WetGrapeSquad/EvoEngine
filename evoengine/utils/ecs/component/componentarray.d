module evoengine.utils.ecs.component.componentarray;
public import evoengine.utils.ecs.common;
import evoengine.utils.memory.componentallocator,
evoengine.utils.memory.blockallocator,
dlib.core.memory,
dlib.container.array,
dlib.container.dict;
import core.internal.gc.impl.conservative.gc;

struct ComponentItem(T)
{
    size_t entity;
    T data;
}

interface IComponentArray
{
    size_t create(size_t entity);
    void destroy(size_t componentId);
}

class ComponentArray(T) : IComponentArray
{
    alias ComponentItemType = ComponentItem!T;

    this(BlockAllocator allocator)
    {
        this.mComponents = New!(ComponentAllocator!ComponentItemType)(allocator);
    }

    size_t create(size_t entity)
    {
        size_t componentId = this.mComponents.allocate;
        this.mComponents[componentId].entity = entity;
        return componentId;
    }

    void destroy(size_t componentId)
    {
        this.mComponents[componentId].entity = NoneEntity;
        this.mComponents.deallocate(componentId);
    }

    ref T opIndex(size_t index)
    {
        return this.mComponents[index].data;
    }

    int opApply(scope int delegate(ref ComponentItemType) dg)
    {
        foreach (ref component; this.mComponents)
        {
            int result = dg(component);
            if (result)
                return result;
        }
        return 0;
    }

    int opApply(scope int delegate(ref size_t) dg)
    {
        foreach (ref component; this.mComponents)
        {
            int result = dg(component.entity);
            if (result)
                return result;
        }
        return 0;
    }

    int opApply(scope int delegate(ref T) dg)
    {
        foreach (ref component; this.mComponents)
        {
            int result = dg(component.data);
            if (result)
                return result;
        }
        return 0;
    }

    ~this()
    {
        Delete(this.mComponents);
    }

    ComponentTypeId componentType;
    ComponentAllocator!ComponentItemType mComponents;
}

class SizedComponentArray : IComponentArray
{
    alias ComponentItemType = ComponentItem!(ubyte[]);

    this(BlockAllocator allocator, size_t size)
    {
        this.mComponents = New!(ComponentAllocator!ComponentItemType)(allocator);
    }

    size_t create(size_t entity)
    {
        size_t componentId = this.mComponents.allocate;
        this.mComponents[componentId].entity = entity;
        return componentId;
    }

    void destroy(size_t componentId)
    {
        this.mComponents[componentId].entity = NoneEntity;
        this.mComponents.deallocate(componentId);
    }

    ubyte[] opIndex(size_t index)
    {
        return this.mComponents[index].data;
    }

    int opApply(scope int delegate(ref ComponentItemType) dg)
    {
        return this.mComponents.opApply(dg);
    }

    int opApply(scope int delegate(ref size_t) dg)
    {
        foreach (ref component; this.mComponents)
        {
            int result = dg(component.entity);
            if (result)
            {
                return result;
            }
        }
        return 0;
    }

    int opApply(scope int delegate(ubyte[]) dg)
    {
        foreach (ref component; this.mComponents)
        {
            int result = dg(component.data);
            if (result)
            {
                return result;
            }
        }
        return 0;
    }

    ~this()
    {
        Delete(this.mComponents);
    }

    ComponentTypeId componentType;
    ComponentAllocator!ComponentItemType mComponents;
}

@("ECS/ComponentArray")
unittest
{
    struct TestStruct
    {
        int i = 0;
    }

    BlockAllocator blockAllocator = New!BlockAllocator;
    ComponentArray!TestStruct componentArray = New!(ComponentArray!TestStruct)(blockAllocator);

    scope (exit)
    {
        Delete(componentArray);
        Delete(blockAllocator);
    }

    size_t entity = 5; // in this test this number can be any constant.
    size_t[] components = new size_t[1_000];

    foreach (j; 0 .. 10)
    {
        foreach (ref component; components)
        {
            component = componentArray.create(entity);
        }
        foreach (ref component; components)
        {
            componentArray.destroy(component);
        }
    }
}
