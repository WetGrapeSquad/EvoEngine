module evoengine.utils.containers.redGreenRange;

/** 
* The task of this data structures is to effectively color any 
* limited range in red or green, as well as to give quick answers 
* to any query. For example: give me a range suitable for 5 green 
* elements or more. Painting 5 elements of this green range in red.
* also, its main task is to try to avoid fragmentation of colored 
* ranges, looking for ranges from the beginning of the array.
*/

enum RangeColor
{
    Red,
    Green,
}

struct Range
{
    this(size_t start, size_t end, RangeColor color = RangeColor.Red)
    {
        this.start = start;
        this.end = end;
        this.color = color;
    }

    int opCmp(size_t index) const
    {
        if (end < index)
        {
            return -1;
        }
        if (start > index)
        {
            return 1;
        }
        return 0;
    }

    bool contain(size_t index) const
    {
        if (end > index && index >= start)
        {
            return true;
        }
        return false;
    }

    auto opAssign(Range range)
    {
        this.start = range.start;
        this.end = range.end;
        this.color = range.color;
        return this;
    }

    size_t start, end;
    RangeColor color = RangeColor.Red;
}

struct RedGreenRange
{
    struct RangeId
    {
        size_t id;
    }

    enum NoneRange = RangeId(-1);

    this(Range range)
    {
        this.mRanges = [range].dup;
    }

    private RangeId getRange(uint unit)
    {
        assert(unit < this.mRanges[$ - 1].end, "Out of bounds");
        assert(this.mRanges != null, "Empty range");

        RangeId colorRange = NoneRange;
        size_t begin = 0;
        size_t end = this.mRanges.length - 1;

        if (this.mRanges[begin].contain(unit))
        {
            colorRange = RangeId(0);
            return colorRange;
        }
        if (this.mRanges[end].contain(unit))
        {
            colorRange = RangeId(end);
            return colorRange;
        }
        while (begin != end)
        {
            size_t mid = (begin + end) / 2;
            int cmp = this.mRanges[mid].opCmp(unit);

            switch (cmp)
            {
            case -1:
                begin = mid;
                break;
            case 1:
                end = mid;
                break;
            default:
                colorRange = RangeId(mid);
                return colorRange;
            }
        }
        return NoneRange;
    }

    void paint(uint unit, RangeColor color)
    {
        RangeId range = this.getRange(unit);
        auto colorRange = this.mRanges[range.id].color;

        assert(range != NoneRange, "internal error");
        assert(colorRange != color);

        Range[] ranges;
        bool first = this.mRanges[range.id].start == unit;
        bool last = this.mRanges[range.id].end - 1 == unit;

        if (first && last)
        {
            this.mRanges[range.id].color = color;
            if (range.id > 0 && this.mRanges[range.id - 1].color == color)
            {
                this.mergeWithLeft(range.id);
                range.id--;
            }
            if (range.id + 1 < this.mRanges.length && this.mRanges[range.id + 1].color == color)
            {
                this.mergeWithRight(range.id);
            }
            return;
        }
        else if (first)
        {
            ranges = [
                Range(unit, unit + 1, color),
                Range(unit + 1, this.mRanges[range.id].end, colorRange)
            ];
        }
        else if (last)
        {
            ranges = [
                Range(this.mRanges[range.id].start, unit, colorRange),
                Range(unit, unit + 1, color)
            ];
        }
        else
        {
            ranges = [
                Range(this.mRanges[range.id].start, unit, colorRange),
                Range(unit, unit + 1, color),
                Range(unit + 1, this.mRanges[range.id].end, colorRange)
            ];
        }

        this.mRanges = this.mRanges[0 .. range.id] ~ ranges ~ this.mRanges[range.id + 1 .. $];
    }

    RangeColor color(uint unit)
    {
        return this.mRanges[getRange(unit).id].color;
    }

    void paint(RangeId range, RangeColor color)
    {
        assert(this.mRanges[range.id].color != color);
        this.mRanges[range.id].color = color;
    }

    Range paint(RangeId rangeId, uint size, RangeColor color)
    {
        Range retRange;
        Range* range = &this.mRanges[rangeId.id];
        RangeColor colorRange = this.mRanges[rangeId.id].color;

        assert(range.color != color);
        assert(range.end - range.start <= size);

        bool checkLeft;
        bool checkRight;

        Range[] ranges;
        size_t mod;

        if (rangeId.id > 0)
        {
            checkLeft = this.mRanges[rangeId.id - 1].color == color;
        }
        if (rangeId.id + 1 < this.mRanges.length)
        {
            checkRight = this.mRanges[rangeId.id + 1].color == color;
        }

        if ((range.end - range.start + 1) == size)
        {
            range.color = color;
            return *range;
        }
        if (checkLeft || !checkRight)
        {
            size_t start = this.mRanges[rangeId.id].start;
            ranges = [
                Range(start, start + size, color),
                Range(start + size, this.mRanges[rangeId.id].end, colorRange)
            ];
            retRange = Range(start, start + size, color);
            checkRight = false;
        }
        else if (checkRight)
        {
            size_t end = this.mRanges[rangeId.id].end;
            ranges = [
                Range(this.mRanges[rangeId.id].start, end - size, colorRange),
                Range(end - size, end, color)
            ];
            retRange = Range(end - size, end, color);
            checkLeft = false;
            mod++;
        }

        this.mRanges = this.mRanges[0 .. rangeId.id] ~ ranges ~ this.mRanges[rangeId.id + 1 .. $];

        if (checkLeft)
        {
            this.mergeWithLeft(rangeId.id + mod);
        }
        if (checkRight)
        {
            this.mergeWithRight(rangeId.id + mod);
        }

        return retRange;
    }

    private void mergeWithLeft(size_t id)
    {
        this.mRanges[id - 1].end = this.mRanges[id].end;
        this.mRanges = this.mRanges[0 .. id] ~ this.mRanges[id + 1 .. $];
    }

    private void mergeWithRight(size_t id)
    {
        this.mRanges[id + 1].start = this.mRanges[id].start;
        this.mRanges = this.mRanges[0 .. id] ~ this.mRanges[id + 1 .. $];
    }

    RangeId findSequence(uint minSize, RangeColor color)
    {
        foreach (i, ref Range range; this.mRanges)
        {
            if (range.color != color || range.end - range.start <= minSize)
            {
                continue;
            }
            return RangeId(i);
        }
        return NoneRange;
    }

    void consoleDump()
    {
        import std.stdio;

        string log;
        foreach (Range range; this.mRanges)
        {
            switch (range.color)
            {
            case RangeColor.Green:
                {
                    log ~= "\033[3;42;30m";
                    foreach (i; range.start .. range.end)
                    {
                        log ~= ' ';
                    }
                }
                break;
            default:
            case RangeColor.Red:
                {
                    log ~= "\033[3;41;30m";
                    foreach (i; range.start .. range.end)
                    {
                        log ~= ' ';
                    }
                }
                break;
            }
            log ~= "\033[0m";
        }
        writeln(log);
    }

    size_t rangesCount()
    {
        return this.mRanges.length;
    }

    Range[] mRanges;
}
/// TODO: implement normal test for this trash
/// TODO: make nogc.
/// TODO: implement test on fragmentations.
/// TODO: try to break it :)

unittest
{
    import std.stdio;

    RedGreenRange ranges = Range(0, 100);

    ranges.consoleDump();

    foreach (i; 0 .. 20)
    {
        ranges.paint(5 * i, RangeColor.Green);
        if (i != 0 && (4 * i) % 5 != 0)
        {
            ranges.paint(4 * i, RangeColor.Green);
        }
        ranges.consoleDump();
    }
    foreach (i; 0 .. 20)
    {
        ranges.paint(5 * i, RangeColor.Red);
        if (i != 0 && (4 * i) % 5 != 0)
        {
            ranges.paint(4 * i, RangeColor.Red);
        }
        ranges.consoleDump();
    }
    writeln("Ranges count:", ranges.rangesCount);
}
