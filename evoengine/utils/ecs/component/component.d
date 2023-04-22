module evoengine.utils.ecs.component.component;
private import evoengine.utils.ecs.component.componentarray,
evoengine.utils.containers.classregistrator;

import evoengine.utils.memory.blockallocator,
dlib.core.memory,
dlib.container.array,
dlib.container.dict;

/// TODO: Rewrite on PoolAllocator and optimize algorithm.
class ComponentManager
{
    this(BlockAllocator blockAllocator)
    {
        this.mBlockAllocator = blockAllocator;
    }

    size_t register(T)()
    {
        return this.mComponentArrays.register(T.stringof, New!(shared ComponentArray!T)(
                this.mBlockAllocator));
    }

    size_t register(size_t size, string name)
    {
        return this.mComponentArrays.register(name, New!(shared SizedComponentArray)(
                this.mBlockAllocator, size));
    }

    void unregister(T)()
    {
        this.mComponentArrays.unregister(T.stringof);
    }

    void unregister(string name)
    {
        this.mComponentArrays.unregister(name);
    }

    void unregister(size_t componentType)
    {
        this.mComponentArrays.unregister(componentType);
    }

    size_t create(T)(size_t entity)
    {
        return this.mComponentArrays[T.stringof].create(entity);
    }

    size_t create(string name, size_t entity)
    {
        return this.mComponentArrays[name].create(entity);
    }

    size_t create(size_t componentType, size_t entity)
    {
        return this.mComponentArrays[componentType].create(entity);
    }

    void destroy(T)(size_t componentId)
    {
        this.mComponentArrays[T.stringof].destroy(componentId);
    }

    void destroy(string name, size_t componentId)
    {
        this.mComponentArrays[name].destroy(componentId);
    }

    void destroy(size_t componentType, size_t componentId)
    {
        this.mComponentArrays[componentType].destroy(componentId);
    }

    size_t getComponentType(T)()
    {
        return this.mComponentArrays.getId(T.stringof);
    }

    ref T get(T)(size_t componentId)
    {   
        IComponentArray componentArray = this.mComponentArrays[T.stringof];
        return (cast(ComponentArray!T)componentArray)[componentId];
    }

    ref T get(T)(size_t componentType, size_t componentId)
    {
        IComponentArray componentArray = this.mComponentArrays[componentType];
        return (cast(ComponentArray!T)componentArray)[componentId];
    }

    ubyte[] get(size_t componentType, size_t componentId)
    {
        IComponentArray componentArray = this.mComponentArrays[componentType];
        return (cast(SizedComponentArray)componentArray)[componentId];
    }


    ~this()
    {
        foreach (ref shared IComponentArray element; this.mComponentArrays)
        {
            Delete(cast(IComponentArray)element);
        }
    }

    ClassRegistrator!(shared IComponentArray) mComponentArrays;

    size_t mLastId;
    BlockAllocator mBlockAllocator;
}

@("ECS/Component")
unittest
{
    import std.range, std.parallelism;

    struct Test
    {
        int i = 0;
    }

    BlockAllocator blockAllocator = New!BlockAllocator;
    ComponentManager componentManager = New!ComponentManager(blockAllocator);
    scope (exit)
    {
        Delete(componentManager);
        Delete(blockAllocator);
    }

    size_t componentType = componentManager.register!Test;

    
    foreach (i; 100.iota.parallel)
    {
        size_t entity = 5;
        size_t[] components;
        components.length = 1024;

        foreach (ref component; components)
        {
            component = componentManager.create(componentType, entity);
        }
        foreach (ref component; components)
        {
            componentManager.destroy(componentType, component);
        }
    }
}