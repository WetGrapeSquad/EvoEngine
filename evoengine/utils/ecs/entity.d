module evoengine.utils.ecs.entity;
public import evoengine.utils.ecs.common;
import evoengine.utils.memory.componentallocator,
evoengine.utils.memory.blockallocator,
dlib.core.memory,
dlib.container.array,
core.internal.spinlock;

class EntityManager
{
    struct EntityData
    {
        bool isRegistered(ComponentTypeId componentType)
        {
            spinLock.lock();
            scope(exit)
            {
                spinLock.unlock();
            }
            
            return mComponentFlags[componentType];
        }

        size_t opIndex(ComponentTypeId componentType)
        {
            spinLock.lock();
            scope(exit)
            {
                spinLock.unlock();
            }

            debug assert(mComponentFlags[componentType]);
            return this.mEntityArray[componentType];
        }

        void changeComponentId(ComponentTypeId componentType, ComponentId componentId)
        {
            spinLock.lock();
            scope(exit)
            {
                spinLock.unlock();
            }

            debug assert(mComponentFlags[componentType]);
            this.mEntityArray[componentType] = componentId;
        }

        void registrateComponent(ComponentTypeId componentType, ComponentId componentId)
        {
            spinLock.lock();
            scope(exit)
            {
                spinLock.unlock();
            }

            debug assert(!mComponentFlags[componentType]);

            this.mComponentFlags[componentType] = true;

            while (this.mEntityArray.length() <= componentType)
            {
                this.mEntityArray.insertBack(NoneComponent);
            }

            this.mEntityArray[componentType] = componentId;
        }

        void unregistrateComponent(ComponentTypeId componentType, ComponentId componentId)
        {
            spinLock.lock();
            scope(exit)
            {
                spinLock.unlock();
            }

            debug assert(mComponentFlags[componentType]);

            this.mComponentFlags[componentType] = false;
            this.mEntityArray[componentType] = NoneComponentType;

            while (this.mEntityArray[this.mEntityArray.length - 1] == NoneComponent)
            {
                this.mEntityArray.removeBack(1);
            }
        }

        SpinLock spinLock = SpinLock(SpinLock.Contention.brief);
        ComponentFlags mComponentFlags;
        Array!ComponentTypeId mEntityArray;
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

    bool isRegistered(EntityId entity, ComponentTypeId componentType)
    {
        return this.mData[entity].isRegistered(componentType);
    }

    void registrateComponent(EntityId entity, ComponentTypeId componentType, ComponentId componentId)
    {
        this.mData[entity].registrateComponent(componentType, componentId);
    }

    void changeComponentId(EntityId entity, ComponentTypeId componentType, ComponentId componentId)
    {
        this.mData[entity].changeComponentId(componentType, componentId);
    }

    void unregistrateComponent(EntityId entity, ComponentTypeId componentType)
    {
        this.mData[entity].unregistrateComponent(componentType, componentType);
    }

    ~this()
    {
        Delete(this.mData);
    }

    ComponentAllocator!EntityData mData;
}

@("ECS/EntityManager")
unittest
{
    BlockAllocator blockAllocator = New!BlockAllocator;
    EntityManager entityManager = New!(EntityManager)(blockAllocator);

    scope (exit)
    {
        Delete(entityManager);
        Delete(blockAllocator);
    }

    foreach (j; 0 .. 10)
    {
        size_t[] entities = new size_t[10_000];

        foreach (ref entity; entities)
        {
            entity = entityManager.create;
        }
        foreach (ref entity; entities)
        {
            entityManager.destroy(entity);
        }
    }
}
