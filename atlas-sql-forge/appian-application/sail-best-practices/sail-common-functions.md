# SAIL Common Functions Reference

Quick reference for the most frequently used SAIL functions with examples. For complete grammar, see `sail-grammar.md`.

## Table of Contents
- [Text Functions](#text-functions)
- [Date and Time Functions](#date-and-time-functions)
- [Array Functions](#array-functions)
- [Logical Functions](#logical-functions)
- [Conversion Functions](#conversion-functions)
- [Mathematical Functions](#mathematical-functions)
- [Looping Functions](#looping-functions)
- [Informational Functions](#informational-functions)

---

## Text Functions

### text() - Format values as text
```sail
text(value, format)
```
**Examples:**
```sail
text(today(), "MM/DD/YYYY")           /* "02/15/2026" */
text(1234.56, "$#,##0.00")            /* "$1,234.56" */
text(0.75, "0%")                      /* "75%" */
```

### concat() - Concatenate text
```sail
concat(text1, text2, ...)
```
**Examples:**
```sail
concat("Hello", " ", "World")         /* "Hello World" */
concat(local!firstName, " ", local!lastName)
```

### upper() / lower() - Change case
```sail
upper("hello")                        /* "HELLO" */
lower("WORLD")                        /* "world" */
```

### trim() - Remove whitespace
```sail
trim("  hello  ")                     /* "hello" */
```

### len() - String length
```sail
len("Hello")                          /* 5 */
```

### search() - Find substring
```sail
search(searchString, textToSearch, startPosition)
```
**Examples:**
```sail
search("world", "Hello world")        /* 7 */
search("test", "Hello world")         /* -1 (not found) */
```

### substitute() - Replace text
```sail
substitute(text, oldText, newText)
```
**Examples:**
```sail
substitute("Hello World", "World", "SAIL")  /* "Hello SAIL" */
```

### left() / right() / mid() - Extract substrings
```sail
left("Hello", 2)                      /* "He" */
right("Hello", 2)                     /* "lo" */
mid("Hello", 2, 3)                    /* "ell" */
```

---

## Date and Time Functions

### today() / now() - Current date/time
```sail
today()                               /* Current date */
now()                                 /* Current datetime */
```

### date() / datetime() - Create date/time
```sail
date(year, month, day)
datetime(year, month, day, hour, minute, second)
```
**Examples:**
```sail
date(2026, 2, 15)                     /* Date: 2026-02-15 */
datetime(2026, 2, 15, 14, 30, 0)      /* DateTime: 2026-02-15 14:30:00 */
```

### year() / month() / day() - Extract components
```sail
year(today())                         /* 2026 */
month(today())                        /* 2 */
day(today())                          /* 15 */
```

### a!addDateTime() / a!subtractDateTime() - Date arithmetic
```sail
a!addDateTime(
  startDateTime: now(),
  days: 7,
  hours: 2
)

a!subtractDateTime(
  startDateTime: now(),
  months: 1
)
```

### datevalue() / timevalue() - Parse text to date/time
```sail
datevalue("02/15/2026")               /* Date */
timevalue("14:30:00")                 /* Time */
```

---

## Array Functions

### index() - Access array elements
```sail
index(array, index, default)
```
**Examples:**
```sail
index({10, 20, 30}, 2, null)          /* 20 */
index({10, 20, 30}, 5, 0)             /* 0 (default) */
index({10, 20, 30}, {1, 3}, {})       /* {10, 30} */
```

### append() - Add to array
```sail
append({1, 2}, 3)                     /* {1, 2, 3} */
append({1, 2}, {3, 4})                /* {1, 2, 3, 4} */
```

### union() - Combine arrays (unique values)
```sail
union({1, 2}, {2, 3})                 /* {1, 2, 3} */
```

### intersection() - Common elements
```sail
intersection({1, 2, 3}, {2, 3, 4})    /* {2, 3} */
```

### difference() - Elements in first but not second
```sail
difference({1, 2, 3}, {2, 3, 4})      /* {1} */
```

### length() - Array size
```sail
length({1, 2, 3})                     /* 3 */
length({})                            /* 0 */
```

### where() - Find indices matching condition
```sail
where({true, false, true, false})     /* {1, 3} */
```
**Example with filtering:**
```sail
a!localVariables(
  local!numbers: {1, 2, 3, 4, 5},
  local!evenIndices: where(mod(local!numbers, 2) = 0),
  index(local!numbers, local!evenIndices, {})  /* {2, 4} */
)
```

### sort() - Sort array
```sail
sort(array, ascending)
```
**Examples:**
```sail
sort({3, 1, 2}, true)                 /* {1, 2, 3} */
sort({3, 1, 2}, false)                /* {3, 2, 1} */
```

---

## Logical Functions

### and() / or() / not() - Boolean logic
**CRITICAL: These are FUNCTIONS, not operators**
```sail
and(condition1, condition2, ...)
or(condition1, condition2, ...)
not(condition)
```
**Examples:**
```sail
and(local!isValid, local!isActive)
or(isnull(local!value), local!value = "")
not(local!isDisabled)
```

### if() - Conditional
```sail
if(condition, valueIfTrue, valueIfFalse)
```
**Examples:**
```sail
if(local!score > 90, "A", "B")
if(
  isnull(local!input),
  "No value",
  tostring(local!input)
)
```

### a!match() - Case-style matching
```sail
a!match(
  value: local!status,
  equals: "pending",
  then: "⏳ Pending",
  equals: "approved",
  then: "✅ Approved",
  equals: "rejected",
  then: "❌ Rejected",
  default: "Unknown"
)
```

### choose() - Select by index
```sail
choose(index, choice1, choice2, ...)
```
**Examples:**
```sail
choose(2, "First", "Second", "Third")  /* "Second" */
```

---

## Conversion Functions

### tostring() - Convert to text
```sail
tostring({1, 2, 3})                   /* "1; 2; 3" */
tostring(today())                     /* "2026-02-15" */
```

### touniformstring() - Convert array elements
```sail
touniformstring({1, 2, 3})            /* {"1", "2", "3"} */
```

### tointeger() - Convert to integer
```sail
tointeger("123")                      /* 123 */
tointeger({"3", "4"})                 /* {3, 4} */
```

### todecimal() - Convert to decimal
```sail
todecimal("3.6")                      /* 3.6 */
todecimal("string")                   /* null */
```

### todate() / todatetime() - Convert to date/time
```sail
todate("2026-02-15")                  /* Date */
todatetime("2026-02-15 14:30:00")     /* DateTime */
```

### cast() - Cast to specific type
```sail
cast(typeNumber, value)
```
**Example:**
```sail
cast(typeof(0), "123")                /* Cast to integer type */
```

---

## Mathematical Functions

### abs() - Absolute value
```sail
abs(-5)                               /* 5 */
```

### round() - Round number
```sail
round(number, numDigits)
```
**Examples:**
```sail
round(3.14159, 2)                     /* 3.14 */
round(123.456, 0)                     /* 123 */
```

### ceiling() / floor() - Round up/down
```sail
ceiling(7.32, 0.5)                    /* 7.5 */
floor(7.32, 0.5)                      /* 7.0 */
```

### mod() - Modulo (remainder)
**CRITICAL: Use mod() function, NOT % operator**
```sail
mod(10, 3)                            /* 1 */
mod(15, 4)                            /* 3 */
```

### sum() / average() - Aggregate functions
```sail
sum({1, 2, 3, 4, 5})                  /* 15 */
average({1, 2, 3, 4, 5})              /* 3 */
```

### min() / max() - Find extremes
```sail
min({5, 2, 8, 1})                     /* 1 */
max({5, 2, 8, 1})                     /* 8 */
```

---

## Looping Functions

### a!forEach() - Iterate over array
**Use this for UI components (not apply/reduce)**
```sail
a!forEach(
  items: {1, 2, 3},
  expression: fv!item * 2
)
/* Returns: {2, 4, 6} */
```

**Available loop variables:**
- `fv!item` - Current item
- `fv!index` - Current index (1-based)
- `fv!isFirst` - True for first item
- `fv!isLast` - True for last item
- `fv!itemCount` - Total count

**Example with UI components:**
```sail
a!forEach(
  items: local!users,
  expression: a!textField(
    label: "User " & fv!index,
    value: fv!item.name,
    saveInto: fv!item.name
  )
)
```

### apply() - Map function over array
**Cannot be used for UI components**
```sail
apply(
  function: fn!upper,
  array: {"hello", "world"}
)
/* Returns: {"HELLO", "WORLD"} */
```

### reduce() - Accumulate values
```sail
reduce(
  function: fn!sum,
  initial: 0,
  list: {1, 2, 3, 4, 5}
)
/* Returns: 15 */
```

### reject() - Filter out items
```sail
reject(
  array: {1, 2, 3, 4, 5},
  expression: mod(fv!item, 2) = 0
)
/* Returns: {1, 3, 5} (odd numbers) */
```

---

## Informational Functions

### isnull() - Check for null
**CRITICAL: Use isnull(), NOT = null**
```sail
isnull(local!value)                   /* true/false */
```

### a!isNullOrEmpty() - Check null or empty
```sail
a!isNullOrEmpty("")                   /* true */
a!isNullOrEmpty({})                   /* true */
a!isNullOrEmpty(null)                 /* true */
a!isNullOrEmpty("text")               /* false */
```

### a!defaultValue() - Return first non-null
```sail
a!defaultValue(local!input, "Default")
```

### typeof() - Get type number
```sail
typeof(123)                           /* Type number for Integer */
typeof("text")                        /* Type number for Text */
```

### typename() - Get type name
```sail
typename(typeof(123))                 /* "Number (Integer)" */
```

---

## Common Patterns

### Safe null handling
```sail
if(
  isnull(ri!input),
  "No value provided",
  tostring(ri!input)
)
```

### Array filtering
```sail
a!localVariables(
  local!data: {1, 2, 3, 4, 5},
  local!filtered: where(local!data > 2),
  index(local!data, local!filtered, {})
)
/* Returns: {3, 4, 5} */
```

### Conditional formatting
```sail
a!match(
  value: local!priority,
  equals: "High",
  then: "🔴 High",
  equals: "Medium",
  then: "🟡 Medium",
  equals: "Low",
  then: "🟢 Low",
  default: "Unknown"
)
```

### Building dynamic lists
```sail
a!forEach(
  items: enumerate(5) + 1,
  expression: "Item " & fv!item
)
/* Returns: {"Item 1", "Item 2", "Item 3", "Item 4", "Item 5"} */
```

---

## Quick Tips

1. **Always use function syntax for logic**: `and()`, `or()`, `not()` are functions
2. **Use `&` for string concatenation**, not `+`
3. **Check nulls with `isnull()`**, not `= null`
4. **Use `mod()` function for modulo**, `%` is percentage (divides by 100)
5. **Use `a!forEach()` for UI components**, not `apply()` or `reduce()`
6. **Index arrays with `index()`**, not bracket notation
7. **Format dates with `text()`**, not custom functions

For complete function reference and grammar rules, see `sail-grammar.md`.
