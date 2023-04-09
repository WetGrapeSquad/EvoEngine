module evoengine.utils.containers.classregistrator;

import dlib.container.array;
import std.algorithm.sorting;
import std.algorithm.searching;
import std.algorithm.mutation;
import core.internal.spinlock;
import std.range : assumeSorted;

private enum NoneIndex = -1;

/** 
*`ClassRegistrator` - struct that can register object of `BasicClass` 
* by name. When you register object, you get unique id. By this unique
* id you can fast: unregister, get or replace object. You can do it with
* strings, but this operation is slow. You can get object id by string and 
* work with object by id.
*/
struct ClassRegistrator(BasicClass)
{
    /** 
    * `ObjectData` - contain object, nameId for remove string by id and alias for 
    * inner free list. NAME ID MUST BE UPDATE AFTER ALL REGISTER AND UNREGISTER.
    */
    private struct ObjectData
    {
        BasicClass mObject;
        size_t mNameId;
        alias mNextFree = mNameId;
    }

    /** 
    * `ObjectName` - contain name of object and object id. This struct used for create 
    * Set of object names for fast get id by name.
    */
    private struct ObjectName
    {
        bool opEquals(const ref ObjectName other) const
        {
            return this.mName == other.mName;
        }

        int opCmp(const ref ObjectName other) const
        {
            import std.algorithm.comparison;

            return cmp(this.mName, other.mName);
        }

        string mName;
        size_t mIndex;
    }

    /**
    * registering object by name and object.
    * Returns: unique object id. This object id can't be changed.
    * TODO: Refactoring.
    */
    public size_t register(string name, BasicClass object)
    {
        size_t objectId;
        size_t nameId;

        if (this.mFirstFree == NoneIndex)
        {
            ObjectData objectData = ObjectData(object, NoneIndex);
            objectId = this.mObjects.length;

            this.mObjects ~= objectData;
        }
        else
        {
            objectId = this.mFirstFree;
            this.mFirstFree = this.mObjects[this.mActualFreeList].mNextFree;
            mFreeCount--;
        }

        nameId = this.mObjectsName.length -
            assumeSorted(this.mObjectsName.data)
                .upperBound(ObjectName(name)).length;

        assert(nameId == 0 || this.mObjectsName[nameId - 1].mName != name, name ~ " allready registerd!");

        if (nameId == this.mObjectsName.length)
        {
            ObjectData objectData = ObjectData(object, nameId);
            ObjectName objectName = ObjectName(name, objectId);

            this.mObjectsName.insertBack(objectName);
            this.mObjects[objectId] = objectData;
        }
        else
        {
            sortFreeList;
            size_t nextFree = this.mFirstFree;

            foreach (i, ref ObjectData objects; this.mObjects)
            {
                if (nextFree == i)
                {
                    nextFree = objects.mNextFree;
                    continue;
                }
                if (objects.mNameId >= nameId)
                {
                    objects.mNameId++;
                }
            }
            ObjectData objectData = ObjectData(object, nameId);
            ObjectName objectName = ObjectName(name, objectId);

            this.mObjects[objectId] = objectData;
            this.mObjectsName.insertKey(nameId, objectName);
        }
        return objectId;
    }

    private void unregister(size_t objectId, size_t nameId)
    {
        this.mActualFreeList = false;

        this.mObjects[objectId] = ObjectData(null, this.mFirstFree);
        this.mObjectsName.removeKey(nameId);

        foreach (ref ObjectName objectName; this.mObjectsName.data[nameId .. $])
        {
            this.mObjects[objectName.mIndex].mNameId--;
        }

        this.mFreeCount++;
        this.mFirstFree = objectId;
    }

    public void unregister(bool dlibDelete = true)(size_t objectId)
    {
        size_t nameId = this.mObjects[objectId].mNameId;
        
        static if(dlibDelete)
        {
            import dlib.core.memory;
            Delete(this.mObjects[objectId].mObject);
        }

        this.unregister(objectId, nameId);
    }

    public void unregister(bool dlibDelete = true)(string name)
    {
        size_t nameId = this.mObjectsName.length -
            assumeSorted(this.mObjectsName.data)
                .find(ObjectName(name, NoneIndex)).length;
        import std.conv : to;
        assert(nameId < this.mObjectsName.length, name ~ " isn't exist.\n");

        size_t objectId = this.mObjectsName[nameId].mIndex;
        
        static if(dlibDelete)
        {
            import dlib.core.memory;
            Delete(this.mObjects[objectId].mObject);
        }

        this.unregister(objectId, nameId);
    }
    
    int opApply(scope int delegate(ref BasicClass) dg)
    {
        int result = 0;
        size_t free = this.mFirstFree;

        foreach (i, ref ObjectData objectData; this.mObjects.data)
        {
            if(i == free)
            {
                free = objectData.mNextFree;
                continue;
            }

            result = dg(objectData.mObject);
            if (result)
                break;
        }
    
        return result;
    }

    size_t getId(string name)
    {
        size_t nameId = this.mObjectsName.length -
            assumeSorted(this.mObjectsName.data)
                .find(ObjectName(name, NoneIndex)).length;
        import std.conv : to;
        assert(nameId < this.mObjectsName.length, name ~ " isn't exist.\n");

        return this.mObjectsName[nameId].mIndex;
    }

    BasicClass opIndex(size_t index)
    {
        debug
        {
            import std.conv : to;
            assert(index < this.mObjects.length, "Out of bounds: " ~ index.to!string ~ ">=" ~
                    this.mObjects.length.to!string);

            sortFreeList;

            for(auto i = this.mFirstFree; i != NoneIndex && i < index; i = this.mObjects[i].mNextFree)
            {
                assert(i != index, "Object by id " ~ i.to!string ~ " allready unregistered!");
            }
        }
        return this.mObjects[index].mObject;
    }
    BasicClass opIndex(string name)
    {
        size_t nameId = this.mObjectsName.length -
            assumeSorted(this.mObjectsName.data)
                .find(ObjectName(name, NoneIndex)).length;
        import std.conv : to;
        assert(nameId < this.mObjectsName.length, name ~ " isn't exist.\n");

        return this.mObjects[this.mObjectsName[nameId].mIndex].mObject;
    }

    private void sortFreeList()
    {
        if (!this.mActualFreeList)
        {
            import std.algorithm.sorting;

            if (this.mFirstFree == NoneIndex) /// If freelist is empty then freelist allready sorted.
            {
                this.mActualFreeList = true;
                return;
            }

            /// Create and reserve array for sorting freearray
            Array!size_t sortedFreeList;
            sortedFreeList.reserve(this.mFreeCount);

            /// converting freelist to freearray
            size_t index = this.mFirstFree;
            while (index != NoneIndex)
            {
                sortedFreeList ~= index;
                index = this.mObjects[index].mNextFree;
            }

            /// sorting.
            sort(sortedFreeList.data);

            /// converting sorted freearray to freelist
            this.mFirstFree = sortedFreeList[0];
            for (size_t rightIndex = 1; rightIndex < sortedFreeList.length; rightIndex++)
            {
                this.mObjects.data[sortedFreeList[rightIndex - 1]].mNextFree = sortedFreeList[rightIndex];
            }
            this.mObjects.data[sortedFreeList[sortedFreeList.length - 1]].mNextFree = NoneIndex;

            /// mark that freelist is actual sorted
            this.mActualFreeList = true;
        }
    }

    private Array!ObjectData mObjects;
    private Array!ObjectName mObjectsName;

    private size_t mFirstFree = NoneIndex;
    private size_t mFreeCount;
    private bool mActualFreeList = false;
}

@("ClassRegistrator")
unittest
{
    import dlib.core.memory;
    class Test
    {

    }

    ClassRegistrator!Object test;
    test.register("test1", New!Test);
    test.register("test2", New!Test);
    test.register("test3", New!Test);
    test.register("test4", New!Test);

    test.unregister!(true)("test1");
    test.unregister!(true)("test2");
    test.unregister!(true)("test3");
    test.unregister!(true)("test4");
}
