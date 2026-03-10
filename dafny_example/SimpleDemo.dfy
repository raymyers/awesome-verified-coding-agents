/*
  Simple Dafny Demo - testing all features documented in DAFNY_LLM.md
*/
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
