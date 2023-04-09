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
public import evoengine.utils.ecs.component.component;

/**
* Copyright: WetGrape 2023.
* License: MIT.
* Authors: Gedert Korney
*/
