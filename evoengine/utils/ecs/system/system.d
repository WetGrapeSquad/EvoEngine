module evoengine.utils.ecs.system.system;
private import evoengine.utils.ecs.system.parse;
import evoengine.utils.ecs.common;

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

/// SystemSettings contain all system settings for SystemsController. 
struct SystemSettings
{

}

class SystemManager
{

}

class SystemsController
{
    
}