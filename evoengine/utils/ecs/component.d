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

module evoengine.utils.ecs.component;
private import evoengine.utils.ecs.componentarray;

import evoengine.utils.memory.blockallocator,
dlib.core.memory,
dlib.container.array,
dlib.container.dict;

/// TODO: Rewrite on PoolAllocator.
class ComponentManager
{
    this(BlockAllocator blockAllocator)
    {
        this.mBlockAllocator = blockAllocator;

        this.mComponentArrays = dict!(IComponentArray, size_t);
        this.mComponentNameById = dict!(string, size_t);
        this.mComponentIdByName = dict!(size_t, string);
    }

    size_t register(T)()
    {
        debug
        {
            size_t* id = mComponentIdByName.get(T.stringof);
            assert(id == null, "Component " ~ T.stringof ~ " allready registered");
        }

        this.mComponentIdByName[T.stringof] = this.mLastId;
        this.mComponentNameById[this.mLastId] = T.stringof;
        this.mComponentArrays[this.mLastId] = New!(ComponentArray!T)(this.mBlockAllocator);

        return this.mLastId++;
    }

    size_t register(size_t size, string name)
    {
        debug
        {
            size_t* id = mComponentIdByName.get(name);
            assert(id == null, "Component " ~ name ~ " allready registered");
        }

        this.mComponentIdByName[name] = this.mLastId;
        this.mComponentNameById[this.mLastId] = name;
        this.mComponentArrays[this.mLastId] = New!(SizedComponentArray)(this.mBlockAllocator, size);

        return this.mLastId++;
    }

    void unregister(T)()
    {
        debug
        {
            size_t* id = mComponentIdByName.get(T.stringof);
            assert(id != null, "Component " ~ T.stringof ~ " isn't registered");
        }
        size_t id = this.mComponentIdByName[T.stringof];

        this.mComponentIdByName.remove(T.stringof);
        this.mComponentNameById.remove(id);
        this.mComponentArrays.remove(id);
    }

    void unregister(string name)
    {
        size_t id;
        debug
        {
            size_t* tmp = mComponentIdByName.get(name);
            assert(tmp != null, "Component " ~ name ~ " isn't registered");
            id = *tmp;
        }
        else
        {
            id = this.mComponentIdByName[name];
        }

        this.mComponentIdByName.remove(name);
        this.mComponentNameById.remove(id);
        this.mComponentArrays.remove(id);
    }

    void unregister(size_t componentType)
    {
        string name;
        debug
        {
            string* tmp = mComponentNameById.get(componentType);
            assert(tmp != null, "Component " ~ name ~ " isn't registered");
            name = *tmp;
        }
        else
        {
            name = this.mComponentNameById[componentType];
        }

        this.mComponentIdByName.remove(name);
        this.mComponentNameById.remove(componentType);
        this.mComponentArrays.remove(componentType);
    }

    size_t create(T)(size_t entity)
    {
        size_t id;
        debug
        {
            size_t* tmp = mComponentIdByName.get(T.stringof);
            assert(tmp != null, "Component " ~ T.stringof ~ " isn't registered");
            id = *tmp;
        }
        else
        {
            id = this.mComponentIdByName[T.stringof];
        }

        return this.mComponentArrays[id].create(entity);
    }

    size_t create(string name, size_t entity)
    {
        size_t id;
        debug
        {
            size_t* tmp = mComponentIdByName.get(name);
            assert(tmp != null, "Component " ~ name ~ " isn't registered");
            id = *tmp;
        }
        else
        {
            id = this.mComponentIdByName[name];
        }

        return this.mComponentArrays[id].create(entity);
    }

    size_t create(size_t componentType, size_t entity)
    {
        debug
        {
            import std.conv : to;

            IComponentArray* tmp = mComponentArrays.get(componentType);
            assert(tmp != null, "Component type with id " ~ componentType.to!string ~ " isn't registered");

            return (*tmp).create(entity);
        }
        else
        {
            return this.mComponentArrays[componentType].create(entity);
        }
    }

    void destroy(T)(size_t componentId)
    {
        size_t id;
        debug
        {
            size_t* tmp = mComponentIdByName.get(T.stringof);
            assert(tmp != null, "Component " ~ name ~ " isn't registered");
            id = *tmp;
        }
        else
        {
            id = this.mComponentIdByName[T.stringof];
        }

        this.mComponentArrays[id].destroy(componentId);
    }

    void destroy(string name, size_t componentId)
    {
        size_t id;
        debug
        {
            size_t* tmp = mComponentIdByName.get(name);
            assert(tmp != null, "Component " ~ name ~ " isn't registered");
            id = *tmp;
        }
        else
        {
            id = this.mComponentIdByName[name];
        }

        this.mComponentArrays[id].destroy(componentId);
    }

    void destroy(size_t componentType, size_t componentId)
    {
        debug
        {
            import std.conv : to;

            IComponentArray* tmp = mComponentArrays.get(componentType);
            assert(tmp != null, "Component type with id " ~ componentType.to!string ~ " isn't registered");

            (*tmp).destroy(componentId);
        }
        else
        {
            this.mComponentArrays[componentType].destroy(componentId);
        }
    }

    ~this()
    {
        foreach (size_t, ref element; this.mComponentArrays)
        {
            Delete(element);
        }
        Delete(mComponentArrays);
        Delete(mComponentNameById);
        Delete(mComponentIdByName);
    }

    Dict!(IComponentArray, size_t) mComponentArrays;
    Dict!(string, size_t) mComponentNameById;
    Dict!(size_t, string) mComponentIdByName;

    size_t mLastId;
    BlockAllocator mBlockAllocator;
}

unittest
{
    import evoengine.utils.logging;

    struct Test
    {
        int i = 0;
    }

    scope (success)
    {
        globalLogger.info("Success");
    }
    scope (failure)
    {
        globalLogger.error("Failure!");
    }

    BlockAllocator blockAllocator = New!BlockAllocator;
    ComponentManager componentManager = New!ComponentManager(blockAllocator);
    scope (exit)
    {
        Delete(componentManager);
        Delete(blockAllocator);
    }

    componentManager.register!Test;

    size_t entity = 5;
    size_t[] components;
    components.length = 1024;

    foreach (i; 0 .. 10)
    {
        foreach (ref component; components)
        {
            component = componentManager.create!Test(entity);
        }
    }
}

/**
* Copyright: WetGrape 2023.
* License: MIT.
* Authors: Gedert Korney
*/
