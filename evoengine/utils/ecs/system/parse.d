module evoengine.utils.ecs.system.parse;
import evoengine.utils.ecs.system.common;
import evoengine.utils.ecs.common;
import std.traits;
import std.meta;
import std.uni;
import std.container.rbtree;

template includeTypes(Args...)
{
    alias includeTypes = AliasSeq!();
    static foreach(arg; Args)
    {
        static assert(isInstanceOf!(EntityInclude, arg)||isInstanceOf!(EntityExclude, arg),
        "Type of component for EntityGroup must be wrapped by EntityInclude or EntityExclude!");
        
        static if(isInstanceOf!(EntityInclude, arg))
        {
            includeTypes = AliasSeq!(includeTypes, TemplateArgsOf!(arg)[0]);
        }
    }
}
template excludeTypes(Args...)
{
    alias excludeTypes = AliasSeq!();
    static foreach(arg; Args)
    {
        static assert(isInstanceOf!(EntityInclude, arg)||isInstanceOf!(EntityExclude, arg),
        "Type of component for EntityGroup must be wrapped by EntityInclude or EntityExclude!");
        
        static if(isInstanceOf!(EntityExclude, arg))
        {
            excludeTypes = AliasSeq!(excludeTypes, TemplateArgsOf!(arg)[0]);
        }
    }
}

struct EntityGroup(Args...)
{
    alias include = includeTypes!(Args);
    alias exclude = excludeTypes!(Args);
    
    static assert(is(NoDuplicates!(include, exclude) == AliasSeq!(include, exclude)),
    "Entity group have type duplicate. Fix it!");

    RedBlackTree!(EntityInfo!(include)) Entities;
}

struct EntityInfo(ComponentTypes...)
{
    /// TODO: add systemManager for getting all pointers to components.
    this(EntityId entity)
    {
        this.entity = entity;
        static foreach(componentType; ComponentTypes)
        {
            import std.conv: to;
            mixin("get" ~ componentType.stringof.asCapitalized.to!string ~ " = cast(componentType*)null;\n");
        }
    }

    long opCmp(const ref EntityInfo entityInfo) const
    {
        return cast(long)this.entity - entityInfo.entity;
    }
    bool opEquals(const ref EntityInfo entityInfo) const
    {
        return this.entity == entityInfo.entity;
    }

    EntityId entity;

    static foreach(componentType; ComponentTypes)
    {
        import std.conv: to;
        mixin("componentType* get" ~ componentType.stringof.asCapitalized.to!string ~ ";\n");
    }
}