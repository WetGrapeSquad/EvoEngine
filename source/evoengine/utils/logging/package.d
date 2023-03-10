module evoengine.utils.logging;
import gogga;

__gshared GoggaLogger globalLogger;

shared static this()
{
     globalLogger = new GoggaLogger();
}

