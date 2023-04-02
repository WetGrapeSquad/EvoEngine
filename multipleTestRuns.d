#!/usr/bin/env rdmd

import std.stdio;
import std.process;

int main()
{
    auto build = execute(["dub", "test", "--compiler=ldc2"]);

    if(build.status != 0)
    {
        writeln("Compilation failed:\n", build.output);
        return build.status;
    }
    writeln("Compilation complited!");    

    size_t testNumber = 1;
    while(true)
    {
        auto test = execute(["./evoengine-test-library"]);
        
        if(test.status != 0)
        {
            writeln("Unittest failed:\n", test.output);
            return test.status;
        }
        writeln("test #", testNumber++, " complited!");
    }
}