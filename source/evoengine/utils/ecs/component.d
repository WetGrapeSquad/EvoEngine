module evoengine.utils.ecs.component;
public import evoengine.utils.ecs.common;
import 
evoengine.utils.memory.componentallocator,
evoengine.utils.memory.blockallocator,
dlib.core.memory,
dlib.container.array;



struct ComponentItem(T)
{
    size_t entity;
    T data;
}

class ComponentArray(T)
{
    alias ComponentItemType = ComponentItem!T;

    this(BlockAllocator allocator)
    {
        this.mComponents = New!(ComponentAllocator!ComponentItemType)(allocator);
    }

    int opApply(scope int delegate(ref ComponentItemType) dg)
    {
        foreach(ref component; this.mComponents){
            int result = dg(component);
            if(result)
                return result;
        }
        return 0;
    }
    int opApply(scope int delegate(ref size_t) dg)
    {
        foreach(ref component; this.mComponents)
        {
            int result = dg(component.entity);
            if(result)
                return result;
        }
        return 0;
    }
    int opApply(scope int delegate(ref T) dg)
    {
        foreach(ref component; this.mComponents)
        {
            int result = dg(component.data);
            if(result)
                return result;
        }
        return 0;
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

    ~this()
    {
        Delete(this.mComponents);
    }

    ComponentFlags mComponentFlags;
    ComponentAllocator!ComponentItemType mComponents;
}

unittest{
    import evoengine.utils.logging;

    struct TestStruct
    {
        int i = 0;
    }

    scope(success)
    {
        globalLogger.info("Success");
    }
    scope(failure){
        globalLogger.error("Failure!");
    }

    BlockAllocator blockAllocator = New!BlockAllocator;
    ComponentArray!TestStruct componentArray = New!(ComponentArray!TestStruct)(blockAllocator);

    scope(exit)
    {
        Delete(blockAllocator);
        Delete(componentArray);
    }

    size_t entity = 5; // in this test this number can be any constant.
    size_t[] components = new size_t[10_000];

    foreach(j; 0..10)
    {
        foreach(ref component; components)
        {
            component = componentArray.create(entity);
        }
        foreach(ref component; components[0..5_000])
        {
            componentArray.destroy(component);
        }

        size_t componentsCount;

        foreach(ref size_t entity; componentArray)
        {
            componentsCount++;
        }

        assert(componentsCount == 5_000);

        foreach(ref component; components[5_000..$])
        {
            componentArray.destroy(component);
        }
    }
}

// 3_000