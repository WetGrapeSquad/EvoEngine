/**
* Implementation Component classes for ECS.
*
* Description:
* This module contain classes for allocate and deallocate components for
* enttities in ECS. ComponentArray isn't thread-safty and needed in thread synchronizations.
* ECS is built so that it works as a separate thread - synchronizations using in communicating 
* with him and communication with the systems inside.
*
*/

module evoengine.utils.ecs.component.component;
private import evoengine.utils.ecs.component.componentarray,
evoengine.utils.memory.classregistrator;

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
        return this.mComponentArrays.register(T.stringof, New!(ComponentArray!T)(
                this.mBlockAllocator));
    }

    size_t register(size_t size, string name)
    {
        return this.mComponentArrays.register(name, New!(SizedComponentArray)(
                this.mBlockAllocator, size));
    }

    void unregister(T)()
    {
        size_t id = this.mComponentArrays.getId(T.stringof);
        Delete(this.mComponentArrays[id]);
        this.mComponentArrays.unregister(id);
    }

    void unregister(string name)
    {
        size_t id = this.mComponentArrays.getId(name);
        Delete(this.mComponentArrays[id]);
        this.mComponentArrays.unregister(id);
    }

    void unregister(size_t componentType)
    {
        Delete(this.mComponentArrays[componentType]);
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

    ~this()
    {
        foreach (ref IComponentArray element; this.mComponentArrays)
        {
            Delete(element);
        }
    }

    ClassRegistrator!IComponentArray mComponentArrays;

    size_t mLastId;
    BlockAllocator mBlockAllocator;
}

@("ECS/Component")
unittest
{
    import std.stdio, std.datetime;

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

    size_t entity = 5;
    size_t[] components;
    components.length = 1024;
    
    foreach (i; 0 .. 100)
    {
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
/**
* Copyright: WetGrape 2023.
* License: MIT.
* Authors: Gedert Korney
*/
