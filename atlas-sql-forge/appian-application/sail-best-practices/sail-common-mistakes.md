# SAIL Common Mistakes and Anti-Patterns

This document highlights critical mistakes to avoid when writing SAIL code. These are the most common errors that cause syntax errors or unexpected behavior.

## Critical Rules

### 1. ONLY Use Functions Defined in SAIL Grammar
**CRITICAL**: SAIL has a specific set of functions. Do not invent or assume functions exist.
- ❌ WRONG: `formatDate(myDate, "MM/DD/YYYY")`
- ✅ RIGHT: `text(myDate, "MM/DD/YYYY")`

### 2. Logical Operators - Use Functions, Not Operators
SAIL does NOT support `and` or `or` as infix operators. You MUST use function syntax.

**AND operator:**
- ❌ WRONG: `if(a and b, ...)`
- ❌ WRONG: `if(a && b, ...)`
- ✅ RIGHT: `if(and(a, b), ...)`

**OR operator:**
- ❌ WRONG: `if(a or b, ...)`
- ❌ WRONG: `if(a || b, ...)`
- ✅ RIGHT: `if(or(a, b), ...)`

**Multiple conditions:**
- ❌ WRONG: `if(a and b and c, ...)`
- ✅ RIGHT: `if(and(a, b, c), ...)`

### 3. Local Variable Reuse in Same Block
Each local variable in the same `a!localVariables` block MUST have a unique name.

**Single block:**
- ❌ WRONG: `a!localVariables(local!x: 1, local!x: 2)`
- ✅ RIGHT: `a!localVariables(local!x: 1, local!y: 2)`

**Variable updates:**
- ❌ WRONG: `a!localVariables(local!x: 1, local!x: local!x + 1, local!x)`
- ✅ RIGHT: `a!localVariables(local!x: 1, local!y: local!x + 1, local!y)`

**Scope rule**: Each local variable is visible to subsequently defined variables in the same block.

### 4. save!value Usage
`save!value` can ONLY be used inside the `value` parameter of `a!save()`.

**Conditional saves:**
- ❌ WRONG: `if(save!value, a!save(...), {})`
- ✅ RIGHT: `a!save(value: if(save!value, newVal, oldVal))`

**Accessing save value:**
- ❌ WRONG: Using `save!value` outside `a!save()`
- ✅ RIGHT: Only reference `save!value` within the `value` parameter

### 5. String Concatenation
Use `&` operator for string concatenation, NOT `+`.

**Concatenation:**
- ❌ WRONG: `"Hello" + " " + "World"` (this does arithmetic: casts to numbers)
- ✅ RIGHT: `"Hello" & " " & "World"`

**Note**: `+` operator casts strings to numbers first:
- `"123" + "4"` returns `127` (not `"1234"`)

### 6. Null Checking
Use `isnull()` function for null checking, NOT `=` operator.

**Null checks:**
- ❌ WRONG: `if(myVar = null, ...)`
- ✅ RIGHT: `if(isnull(myVar), ...)`

**Reason**: `=` does case-insensitive comparison for text and may not work as expected with null.

### 7. Percentage Operator
`%` divides by 100, it is NOT a modulo operator.

**Percentage:**
- `25%` equals `0.25`
- ❌ WRONG: `10 % 3` (expecting modulo result)
- ✅ RIGHT: `mod(10, 3)` (use `mod()` function for modulo)

### 8. String Escaping
Double-quote characters are escaped by doubling them, NOT using backslash.

**String literals:**
- ❌ WRONG: `"He said, \"Hello\"."`
- ✅ RIGHT: `"He said, ""Hello""."`

### 9. Type Comparisons
Comparisons should be made between the same type. Do not rely on automatic casting.

**Type safety:**
- ❌ RISKY: `"123" = 123` (may not work as expected)
- ✅ RIGHT: `tointeger("123") = 123` or `"123" = tostring(123)`

### 10. Array Operations
Arithmetic operators work on arrays element-wise.

**Array arithmetic:**
- `{1, 10} + 3` returns `{4, 13}`
- `{1, 10} + {3, 5}` returns `{4, 15}`
- `{1, 10} * 3` returns `{3, 30}`

**Division by zero:**
- Scalar: `1.0 / 0` throws exception "Denominator may not be zero (0)"
- Array: `{1.0, 2.0, 3.0} / {4.0, 0.0, 5.0}` returns `{0.25, infinity(), 0.6}`

### 11. Function Side Effects
ALL SAIL functions are side-effect free. They only return results.

**No side effects:**
- Functions do not modify variables
- Functions do not change state
- Functions only return values to be acted upon by the caller

### 12. Type System
SAIL supports these types:
- 32-bit integers
- 64-bit double floating-point (decimal)
- Strings (Text)
- Booleans
- Maps
- Dictionaries (maps with values wrapped in Variant/Any Type)
- Arrays
- CDTs (Complex Data Types)

## Quick Reference: Common Patterns

### Conditional Logic
```sail
/* Multiple conditions */
if(
  and(
    not(isnull(local!value)),
    local!value > 0,
    local!isValid
  ),
  "Valid",
  "Invalid"
)
```

### Local Variables
```sail
a!localVariables(
  local!firstName: "John",
  local!lastName: "Doe",
  local!fullName: local!firstName & " " & local!lastName,
  local!fullName
)
```

### Safe Null Handling
```sail
if(
  isnull(ri!input),
  "No value provided",
  tostring(ri!input)
)
```

### Array Filtering
```sail
a!localVariables(
  local!numbers: {1, 2, 3, 4, 5},
  local!evenNumbers: where(mod(local!numbers, 2) = 0),
  index(local!numbers, local!evenNumbers, {})
)
```

## When in Doubt

1. **Check the grammar** - Verify the function exists in `sail-grammar.md`
2. **Use functions for logic** - `and()`, `or()`, `not()` are functions, not operators
3. **Unique variable names** - Never reuse local variable names in the same block
4. **Type safety** - Cast explicitly, don't rely on automatic conversion
5. **Test incrementally** - Build complex expressions step by step
