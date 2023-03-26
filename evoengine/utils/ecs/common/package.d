module evoengine.utils.ecs.common;
import evoengine.utils.containers.flagarray;

alias ComponentFlags = FlagArray;
alias ComponentTypeId = size_t;
alias EntityId = size_t;
alias ComponentId = size_t;
alias SystemId = size_t;

enum NoneComponentType = -1;
enum NoneComponent = -1;
enum NoneEntity = -1;
