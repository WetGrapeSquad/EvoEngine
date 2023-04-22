module evoengine.utils.ecs.system.system;
import evoengine.utils.ecs.component;
import evoengine.utils.ecs.entity;
import evoengine.utils.ecs.common;
import evoengine.utils.ecs.system.common;
import evoengine.utils.ecs.system.parse;
import std.traits;
import std.meta;

template isEcsSystem(T)
{
    static if(!is(T == class) || is(T == Object))
    {
        enum isEcsSystem = false;
    }
    static if(is(T == IEcsSystem))
    {
        enum isEcsSystem = true;
    }
    else static if(!is(T == Object))
    {
        enum isEcsSystem = isEcsSystem!(BaseClassesTuple!(T)[0]);
    }
}

template getEntityGroupsTypes(System)
{
    alias getEntityGroupsTypes = AliasSeq!();
    static foreach(arg; FieldTypeTuple!(System))
    {
        static if(isInstanceOf!(EntityGroup, arg))
        {
            getEntityGroupsTypes = AliasSeq!(getEntityGroupsTypes, arg);
        }
    }
}
template getEntityGroupsNames(System)
{
    alias getEntityGroupsNames = AliasSeq!();
    static foreach(i, arg; FieldNameTuple!(System))
    {
        static if(isInstanceOf!(EntityGroup, arg))
        {
            getEntityGroupsNames = AliasSeq!(getEntityGroupsNames, FieldNameTuple!System[i]);
        }
    }
}

/**
* SystemSettings generate and contain all system settings in compile-time for SystemsController.
*/
struct SystemSettings(System)
{
    static assert(isEcsSystem!System, System.stringof ~ " is not inherited from IEcsSystem");
    alias entityGroupTypes = getEntityGroupsTypes!System;
    alias entityGroupNames = getEntityGroupsNames!System;
}

/// Abstract class for declaration all Systems in Ecs.
abstract class IEcsSystem
{
    /// for Message about initialize this System.
    void init(SystemManager manager){}      
    /// for Message about new entity by ComponentFlag signature.
    void newEntity(SystemManager manager, EntityId entity){}
    /// for Message about entity what "disappeared" from the field of view of this system.
    void disappEntity(SystemManager manager, EntityId entity){}
    /// for Message about destroying this System.
    void destroy(SystemManager manager){}
}

unittest
{
    import std.stdio;

    struct TestIncludeComponent1 {}
    struct TestIncludeComponent2 {}
    struct TestExcludeComponent {}
    class TestSystem: IEcsSystem
    {
        EntityGroup!(
            EntityInclude!(TestIncludeComponent1), 
            EntityInclude!(TestIncludeComponent2),
            EntityExclude!(TestExcludeComponent)
            ) 
        group1;
    }

    SystemSettings!(TestSystem) test;

    static assert(is(test.entityGroupTypes[0].include == AliasSeq!(TestIncludeComponent1, TestIncludeComponent2)));
    static assert(is(test.entityGroupTypes[0].exclude == AliasSeq!(TestExcludeComponent)));
}

class SystemManager
{
    this(EntityManager entityManager, ComponentManager componentManager)
    {
        this.mEntityManager = entityManager;
        this.mComponentManager = componentManager;
    }

    private EntityManager mEntityManager;
    private ComponentManager mComponentManager;
}