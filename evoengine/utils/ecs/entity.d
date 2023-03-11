module evoengine.utils.ecs.entity;
public import evoengine.utils.ecs.common;
import 
evoengine.utils.memory.componentallocator,
evoengine.utils.memory.blockallocator,
dlib.core.memory,
dlib.container.array;

class EntityManager{
    struct EntityData
    {

        bool isRegistered(size_t componentType)
        {
            return mComponentFlags[componentType];
        }
        size_t opIndex(size_t componentType) 
        {
            debug assert(mComponentFlags[componentType]);
            return this.mEntityArray[componentType];
        }
        void changeComponentId(size_t componentType, size_t componentId)
        {
            debug assert(mComponentFlags[componentType]);
            this.mEntityArray[componentType] = componentId;
        }
        void registrateComponent(size_t componentType, size_t componentId)
        {
            debug assert(!mComponentFlags[componentType]);

            this.mComponentFlags[componentType] = true;

            while(this.mEntityArray.length() <= componentType){
                this.mEntityArray.insertBack(NoneComponent);
            }

            this.mEntityArray[componentType] = componentId;
        }
        void unregistrateComponent(size_t componentType, size_t componentId)
        {
            debug assert(mComponentFlags[componentType]);

            this.mComponentFlags[componentType] = false;
            this.mEntityArray[componentType] = NoneComponentType;

            while(this.mEntityArray[this.mEntityArray.length - 1] == NoneComponent){
                this.mEntityArray.removeBack(1);
            }
        }

        ComponentFlags mComponentFlags;
        Array!ComponentId mEntityArray;
    }

    this(BlockAllocator allocator)
    {
        this.mData = New!(ComponentAllocator!EntityData)(allocator);
    }

    size_t create()
    {
        return this.mData.allocate;
    }

    void destroy(size_t id)
    {
        this.mData.deallocate(id);
    }

    bool isRegistered(size_t entity, size_t componentType)
    {
        return this.mData[entity].isRegistered(componentType);
    }
    void registrateComponent(size_t entity, size_t componentType, size_t componentId)
    {
        this.mData[entity].registrateComponent(componentType, componentId);
    }
    void changeComponentId(size_t entity, size_t componentType, size_t componentId)
    {
        this.mData[entity].changeComponentId(componentType, componentId);
    }
    void unregistrateComponent(size_t entity, size_t componentType)
    {
        this.mData[entity].unregistrateComponent(componentType, componentType);
    }


    ~this()
    {
        Delete(this.mData);
    }

    ComponentAllocator!EntityData mData;
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

    BlockAllocator blockAllocator = New!BlockAllocator;
    EntityManager entityManager = New!(EntityManager)(blockAllocator);
    scope(exit)
    {
        Delete(blockAllocator);
        Delete(entityManager);
    }
    import std.datetime, std.stdio;
    auto start = Clock.currTime;
    foreach(j; 0..10)
    {
        size_t[] entities = new size_t[10_000];

        foreach(ref entity; entities)
        {
            entity = entityManager.create;
        }
        foreach(ref entity; entities)
        {
            entityManager.destroy(entity);
        }
    }
}