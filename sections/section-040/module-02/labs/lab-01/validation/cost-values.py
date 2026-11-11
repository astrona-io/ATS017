"""Parse OpenCost allocations and compare finite, nonnegative costs."""
import json
import math
import sys


def number(value):
    if isinstance(value, bool):
        raise ValueError('a boolean is not a measurement')
    result = float(value)
    if not math.isfinite(result) or result < 0:
        raise ValueError('measurement must be finite and nonnegative')
    return result


def allocation(document, name, field):
    rows = document['data']
    if len(rows) != 1:
        raise ValueError('expected one allocation window')
    entry = rows[0][name]
    if entry['name'] != name:
        raise ValueError('allocation name differs from its key')
    value = entry[field]
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        raise ValueError('allocation measurement must be a JSON number')
    return number(value)


def within(reported, expected, floor):
    reported, expected, floor = map(number, (reported, expected, floor))
    return abs(reported - expected) <= max(expected * 0.15, floor)


if __name__ == '__main__':
    try:
        command, *args = sys.argv[1:]
        if command == 'field':
            print(allocation(json.load(sys.stdin), *args))
        elif command == 'number':
            number(args[0])
        elif command == 'within':
            sys.exit(0 if within(*args) else 1)
        elif command == 'sum':
            print(number(sum(number(value) for value in args)))
        else:
            raise ValueError(f'unknown cost operation: {command}')
    except (ValueError, KeyError, TypeError, IndexError, OverflowError) as error:
        sys.exit(f'ERROR: cost evidence: {error}')
