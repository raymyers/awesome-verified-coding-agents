# Dafny Quick Reference Guide

This document provides a comprehensive guide to using Dafny, covering verification, Python compilation, standard library usage, FileIO, JSON handling, and string utilities.

## Table of Contents

1. [Installation](#installation)
2. [Basic Commands](#basic-commands)
3. [Project Configuration](#project-configuration)
4. [Verification](#verification)
5. [Compiling to Python](#compiling-to-python)
6. [Standard Library Overview](#standard-library-overview)
7. [FileIO Operations](#fileio-operations)
8. [JSON Serialization/Deserialization](#json-serializationdeserialization)
9. [String Utilities](#string-utilities)
10. [Wrappers for Error Handling](#wrappers-for-error-handling)
11. [Complete Example](#complete-example)

---

## Installation

Download the latest Dafny release from GitHub:

```bash
# Download and extract (adjust version/platform as needed)
curl -L -o dafny.zip "https://github.com/dafny-lang/dafny/releases/download/v4.11.0/dafny-4.11.0-x64-ubuntu-22.04.zip"
unzip dafny.zip
rm dafny.zip

# Add to PATH
export PATH="$(pwd)/dafny:$PATH"

# Verify installation
dafny --version
```

**Note:** On Linux, you may need `libicu-dev` installed:
```bash
sudo apt-get install -y libicu-dev
```

---

## Basic Commands

### Verify a Dafny program

```bash
dafny verify MyProgram.dfy
```

### Build/Compile to a target language

```bash
# Compile to Python
dafny build --target:py MyProgram.dfy

# Compile to other targets
dafny build --target:cs MyProgram.dfy   # C#
dafny build --target:java MyProgram.dfy # Java
dafny build --target:js MyProgram.dfy   # JavaScript
dafny build --target:go MyProgram.dfy   # Go
```

### Run a Dafny program directly

```bash
dafny run --target:py MyProgram.dfy
```

### Translate without building

```bash
dafny translate py MyProgram.dfy
```

---

## Project Configuration

Create a `dfyconfig.toml` file in your project root:

```toml
[options]
# Enable standard library access
standard-libraries = true

# Optional: other useful options
# enforce-determinism = true
# resource-limit = 1000000
```

With `dfyconfig.toml`, you don't need to pass `--standard-libraries` on each command.

---

## Verification

Dafny is a verification-aware programming language. You write specifications alongside your code.

### Pre/Post Conditions

```dafny
// Method with preconditions and postconditions
method Divide(a: int, b: int) returns (result: int)
  requires b != 0                    // Precondition
  ensures result == a / b            // Postcondition
{
  result := a / b;
}
```

### Function Specifications

```dafny
// Functions can have ensures clauses
function SafeDivide(a: int, b: int): Option<int>
  ensures b == 0 ==> SafeDivide(a, b).None?
  ensures b != 0 ==> SafeDivide(a, b) == Some(a / b)
{
  if b == 0 then None else Some(a / b)
}
```

### Loop Invariants

```dafny
method Sum(arr: seq<int>) returns (sum: int)
{
  sum := 0;
  var i := 0;
  while i < |arr|
    invariant 0 <= i <= |arr|
  {
    sum := sum + arr[i];
    i := i + 1;
  }
}
```

### Running Verification

```bash
# Verify a single file
dafny verify MyProgram.dfy

# Verify with standard libraries
dafny verify --standard-libraries MyProgram.dfy

# Verify with resource limit
dafny verify --resource-limit:1000000 MyProgram.dfy
```

---

## Compiling to Python

### Step 1: Write Your Dafny Code

```dafny
// hello.dfy
module HelloWorld {
  method Main() {
    print "Hello, World!\n";
  }
}
```

### Step 2: Build to Python

```bash
dafny build --target:py hello.dfy
```

This creates a directory `hello-py/` containing:
- `__main__.py` - Entry point
- `HelloWorld.py` - Your module
- `_dafny/` - Dafny runtime support

### Step 3: Run the Python Output

```bash
python3 hello-py/__main__.py
# Or
cd hello-py && python3 .
```

### Using Standard Libraries with Python Target

```bash
# Build with standard libraries (automatically included)
dafny build --standard-libraries --target:py MyProgram.dfy
```

---

## Standard Library Overview

Enable with `--standard-libraries` flag or in `dfyconfig.toml`.

### Available Modules

| Module | Description |
|--------|-------------|
| `Std.Wrappers` | Option, Result, Outcome for error handling |
| `Std.Strings` | String conversion utilities |
| `Std.FileIO` | File read/write operations |
| `Std.JSON.API` | JSON serialization/deserialization |
| `Std.JSON.Values` | JSON value types |
| `Std.Collections` | Sequence, Set, Map operations |
| `Std.Math` | Mathematical functions |
| `Std.Unicode` | Unicode encoding/decoding |
| `Std.BoundedInts` | Fixed-width integer types |

### Importing Standard Library Modules

```dafny
module MyModule {
  import opened Std.Wrappers      // Option, Result, etc.
  import Std.Strings              // String utilities
  import Std.FileIO               // File I/O
  import Std.JSON.API             // JSON API
  import opened Std.JSON.Values   // JSON value types
  import opened Std.Unicode.UnicodeStringsWithUnicodeChar
  
  // Your code here
}
```

---

## FileIO Operations

### Setup

```dafny
module FileExample {
  import Std.FileIO
  import opened Std.Wrappers
```

### Writing Text to a File

```dafny
  method WriteTextFile() {
    var content := "Hello from Dafny!\nLine 2\nLine 3";
    var result := FileIO.WriteUTF8ToFile("output.txt", content);
    
    match result {
      case Pass => print "File written successfully\n";
      case Fail(err) => print "Write failed: ", err, "\n";
    }
  }
```

### Reading Text from a File

```dafny
  method ReadTextFile() {
    var result := FileIO.ReadUTF8FromFile("output.txt");
    
    match result {
      case Success(text) => print "Contents: ", text, "\n";
      case Failure(err) => print "Read failed: ", err, "\n";
    }
  }
```

### Writing Bytes to a File

```dafny
  method WriteBinaryFile() {
    var bytes: seq<bv8> := [0x48, 0x65, 0x6c, 0x6c, 0x6f]; // "Hello"
    var result := FileIO.WriteBytesToFile("data.bin", bytes);
    
    match result {
      case Success(_) => print "Bytes written\n";
      case Failure(err) => print "Write failed: ", err, "\n";
    }
  }
```

### Reading Bytes from a File

```dafny
  method ReadBinaryFile() {
    var result := FileIO.ReadBytesFromFile("data.bin");
    
    match result {
      case Success(data) => print "Read ", |data|, " bytes\n";
      case Failure(err) => print "Read failed: ", err, "\n";
    }
  }
}
```

---

## JSON Serialization/Deserialization

### Setup

```dafny
module JSONExample {
  import Std.JSON.API
  import opened Std.JSON.Values
  import opened Std.Wrappers
  import opened Std.Unicode.UnicodeStringsWithUnicodeChar
```

### JSON Value Types

```dafny
  // Available JSON value constructors:
  // - Null
  // - Bool(b: bool)
  // - String(s: string)
  // - Number(Int(n: int) | Decimal(mantissa: int, exp10: int))
  // - Array(elements: seq<JSON>)
  // - Object(fields: seq<(string, JSON)>)
```

### Creating JSON Values

```dafny
  method CreateJSON() {
    // Simple values
    var nullVal := Null;
    var boolVal := Bool(true);
    var strVal := String("hello");
    var intVal := Number(Int(42));
    var floatVal := Number(Decimal(314, -2)); // 3.14
    
    // Array
    var arr := Array([Number(Int(1)), Number(Int(2)), Number(Int(3))]);
    
    // Object
    var obj := Object([
      ("name", String("Alice")),
      ("age", Number(Int(30))),
      ("active", Bool(true))
    ]);
  }
```

### Serializing to JSON

```dafny
  method SerializeJSON() {
    var person := Object([
      ("name", String("Bob")),
      ("scores", Array([Number(Int(95)), Number(Int(87))]))
    ]);
    
    var result := API.Serialize(person);
    match result {
      case Success(jsonBytes) =>
        var jsonStr := FromUTF8Checked(jsonBytes);
        match jsonStr {
          case Success(s) => print "JSON: ", s, "\n";
          case Failure(e) => print "Encoding error: ", e, "\n";
        }
      case Failure(e) => 
        print "Serialization failed: ", e, "\n";
    }
  }
```

### Deserializing from JSON

```dafny
  method DeserializeJSON() {
    var jsonStr := "{\"name\":\"Alice\",\"age\":30}";
    
    // Convert string to UTF-8 bytes
    var bytesOpt := ToUTF8Checked(jsonStr);
    match bytesOpt {
      case Some(bytes) =>
        var result := API.Deserialize(bytes);
        match result {
          case Success(value) =>
            // value is of type JSON, can pattern match
            match value {
              case Object(fields) => print "Parsed object with ", |fields|, " fields\n";
              case _ => print "Parsed other JSON type\n";
            }
          case Failure(e) => print "Parse error: ", e, "\n";
        }
      case None => 
        print "UTF-8 encoding failed\n";
    }
  }
}
```

---

## String Utilities

### Setup

```dafny
module StringExample {
  import Std.Strings
  import opened Std.Wrappers
```

### Converting Numbers to Strings

```dafny
  method NumberToString() {
    // Integer to string
    var intStr := Strings.OfInt(42);      // "42"
    var negStr := Strings.OfInt(-17);     // "-17"
    
    // Natural number to string
    var natStr := Strings.OfNat(12345);   // "12345"
    
    print "42 as string: ", intStr, "\n";
    print "-17 as string: ", negStr, "\n";
    print "12345 as string: ", natStr, "\n";
  }
```

### Converting Strings to Numbers

```dafny
  method StringToNumber() {
    // String to natural (requires all digits)
    var n := Strings.ToNat("12345");  // 12345
    
    // String to integer (handles negative)
    var i := Strings.ToInt("-42");    // -42
    
    print "Parsed nat: ", Strings.OfNat(n), "\n";
    print "Parsed int: ", Strings.OfInt(i), "\n";
  }
```

### Boolean and Character Conversion

```dafny
  method OtherConversions() {
    // Boolean to string
    var trueStr := Strings.OfBool(true);   // "true"
    var falseStr := Strings.OfBool(false); // "false"
    
    // Character to string
    var charStr := Strings.OfChar('X');    // "X"
    
    print "true as string: ", trueStr, "\n";
    print "false as string: ", falseStr, "\n";
    print "X as string: ", charStr, "\n";
  }
```

### Escaping and Unescaping Quotes

```dafny
  method QuoteHandling() {
    // Escape quotes in a string
    var original := "He said \"Hello\"";
    var escaped := Strings.EscapeQuotes(original);
    print "Escaped: ", escaped, "\n";
    // Output: He said \"Hello\"
    
    // Unescape quotes
    var unescaped := Strings.UnescapeQuotes(escaped);
    match unescaped {
      case Some(s) => print "Unescaped: ", s, "\n";
      case None => print "Unescape failed\n";
    }
  }
}
```

---

## Wrappers for Error Handling

### Option Type

For values that may or may not exist:

```dafny
import opened Std.Wrappers

function FindElement<T(==)>(arr: seq<T>, elem: T): Option<nat> {
  if |arr| == 0 then None
  else if arr[0] == elem then Some(0)
  else 
    var rest := FindElement(arr[1..], elem);
    if rest.Some? then Some(rest.value + 1) else None
}

method UseOption() {
  var maybeIdx := FindElement([1, 2, 3], 2);
  
  // Pattern matching
  match maybeIdx {
    case Some(idx) => print "Found at index ", idx, "\n";
    case None => print "Not found\n";
  }
  
  // Using GetOr for default value
  var idx := maybeIdx.GetOr(999);
}
```

### Result Type

For operations that may fail with an error message:

```dafny
import opened Std.Wrappers

method ProcessData(data: string) returns (r: Result<int, string>) {
  if |data| == 0 {
    return Failure("Empty input");
  }
  // Process data...
  return Success(42);
}

method UseResult() {
  var result := ProcessData("test");
  
  // Pattern matching
  match result {
    case Success(value) => print "Got: ", value, "\n";
    case Failure(error) => print "Error: ", error, "\n";
  }
  
  // Propagate errors with :- operator
  var value :- ProcessData("test");
  // If Failure, method returns immediately with that Failure
  print "Value: ", value, "\n";
}
```

### Outcome Type

For operations that succeed or fail (no success value):

```dafny
import opened Std.Wrappers

method ValidateInput(s: string) returns (r: Outcome<string>) {
  if |s| < 3 {
    return Fail("Input too short");
  }
  return Pass;
}

method UseOutcome() {
  var outcome := ValidateInput("hi");
  
  match outcome {
    case Pass => print "Validation passed\n";
    case Fail(err) => print "Validation failed: ", err, "\n";
  }
}
```

---

## Complete Example

Here's a complete working example that demonstrates all features:

**File: `dfyconfig.toml`**
```toml
[options]
standard-libraries = true
```

**File: `Example.dfy`**
```dafny
module DafnyDemo {
  import opened Std.Wrappers
  import Std.Strings
  import Std.FileIO
  import Std.JSON.API
  import opened Std.JSON.Values
  import opened Std.Unicode.UnicodeStringsWithUnicodeChar

  // Verified function
  function SafeDivide(a: int, b: int): Option<int>
    ensures b == 0 ==> SafeDivide(a, b).None?
    ensures b != 0 ==> SafeDivide(a, b) == Some(a / b)
  {
    if b == 0 then None else Some(a / b)
  }

  method Main() {
    // 1. String utilities
    print "=== String Examples ===\n";
    print "42 as string: ", Strings.OfInt(42), "\n";
    print "true as string: ", Strings.OfBool(true), "\n";
    
    // 2. JSON example
    print "\n=== JSON Example ===\n";
    var person := Object([
      ("name", String("Alice")),
      ("age", Number(Int(30)))
    ]);
    var serialized := API.Serialize(person);
    match serialized {
      case Success(bytes) =>
        match FromUTF8Checked(bytes) {
          case Success(s) => print "JSON: ", s, "\n";
          case Failure(_) => print "Encoding error\n";
        }
      case Failure(e) => print "Serialize error: ", e, "\n";
    }
    
    // 3. FileIO example
    print "\n=== FileIO Example ===\n";
    var writeResult := FileIO.WriteUTF8ToFile("test.txt", "Hello, Dafny!");
    match writeResult {
      case Pass => print "Wrote file successfully\n";
      case Fail(e) => print "Write error: ", e, "\n";
    }
    
    var readResult := FileIO.ReadUTF8FromFile("test.txt");
    match readResult {
      case Success(content) => print "Read: ", content, "\n";
      case Failure(e) => print "Read error: ", e, "\n";
    }
    
    // 4. Verified function
    print "\n=== Verified Function ===\n";
    match SafeDivide(10, 2) {
      case Some(v) => print "10 / 2 = ", Strings.OfInt(v), "\n";
      case None => print "Division by zero\n";
    }
    match SafeDivide(10, 0) {
      case Some(v) => print "10 / 0 = ", Strings.OfInt(v), "\n";
      case None => print "10 / 0 = undefined (correct!)\n";
    }
  }
}
```

### Building and Running

```bash
# Verify the program
dafny verify Example.dfy

# Build to Python
dafny build --target:py Example.dfy

# Run the Python output
python3 Example-py/__main__.py
```

### Expected Output

```
=== String Examples ===
42 as string: 42
true as string: true

=== JSON Example ===
JSON: {"name":"Alice","age":30}

=== FileIO Example ===
Wrote file successfully
Read: Hello, Dafny!

=== Verified Function ===
10 / 2 = 5
10 / 0 = undefined (correct!)
```

---

## Quick Reference Commands

| Task | Command |
|------|---------|
| Verify | `dafny verify --standard-libraries file.dfy` |
| Build to Python | `dafny build --standard-libraries --target:py file.dfy` |
| Run directly | `dafny run --standard-libraries --target:py file.dfy` |
| Build to C# | `dafny build --standard-libraries --target:cs file.dfy` |
| Build to Java | `dafny build --standard-libraries --target:java file.dfy` |
| Build to JS | `dafny build --standard-libraries --target:js file.dfy` |
| Build to Go | `dafny build --standard-libraries --target:go file.dfy` |

---

## Additional Resources

- [Dafny Reference Manual](https://dafny.org/latest/DafnyRef/DafnyRef)
- [Dafny Standard Library Documentation](https://github.com/dafny-lang/dafny/tree/master/Source/DafnyStandardLibraries)
- [Dafny GitHub Repository](https://github.com/dafny-lang/dafny)
