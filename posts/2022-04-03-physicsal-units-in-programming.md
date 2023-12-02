---
title: Physical units in programming languages
tags: F#, Python, Ada, physics
toc: true
...

Long time ago I read an article about Ada programming language, which included
a demonstration showing how to use Ada's strong type system for checking
physical units of variables in a similar way how we rely on
a compiler to check common data types. However the support of [dimensional
analysis](https://en.wikipedia.org/wiki/Dimensional_analysis) and physical
units in programming languages improved significantly in the meantime, and now
one can find good support for it not just in "serious" languages like Ada. In
this post we will see how to work with units on two simple examples, one for
negative and the other for a positive use case, (re)implemented in Ada, F# and
Python.

<!--more-->

## Ada

The example from [the old article about
Ada](https://www.root.cz/clanky/bezpecne-programovani-ala-ada/) (2003, in Czech
language) looked something like this:

``` ada
type Meters is new Float;
type Meters_Squared is new Float;

-- Overloading multiplication operator on Meters data type so
-- that it will return Meters_Squared.
function "*" (Left, Right : Meters) return Meters_Squared is
begin
  return Meters_Squared(Float(Left)*Float(Right));
  -- to avoid recursion, operands of the multiplication were
  -- overloaded to Float, this way we force compiler to use
  -- standard Float multiplication
end;

declare
  height : Meters := 10.0;
  width  : Meters := 15.0;
  surface_a : Meters_Squared;
  surface_b : Meters;
begin
  surface_a := height*width; -- this is ok
  surface_b := height*width; -- causes compile time error
end;
```

I recall that this really impressed me.
But back then I wasn't familiar with lot of programming languages, neither I
was looking into this further.
Unfortunately I also had a wrong impression for a while that such features are
possible only with some strongly typed languages such as Ada. Which is not
really the case as we will see later in this post.

When I revisited the example and wanted to try it out (GNU/Linux distributions
like Fedora or Debian provides package for GNU Ada compiler
[GNAT](https://en.wikipedia.org/wiki/GNAT)), it turned out that the code needs
few changes for it to actually work. Which in this particular case means that
it will end up with a compile time error showing that the unit checking
works as expected :-)

``` ada
procedure Example1 is
  type Meters is new Float;
  type Meters_Squared is new Float;
  function "*" (Left, Right : Meters) return Meters_Squared is
  begin
    return Meters_Squared(Float(Left)*Float(Right));
  end;
  function "*" (Left, Right : Meters) return Meters is abstract;
  len_a : Meters := 10.0;
  len_b : Meters := 15.0;
  surface : Meters_Squared;
  len_sum : Meters;
begin
  len_sum := len_a + len_b; -- ok
  surface := len_a * len_b; -- ok
  len_sum := len_a * len_b; -- invalid
end Example1;
```

Besides polishing required to turn it into a standalone Ada program, it was
necessary to make `function "*" (Left, Right : Meters) return Meters` abstract
to [supresses this function to be inherited from multiplication on
type `Float`](https://stackoverflow.com/questions/67141246/naive-unit-checking-via-strong-typing-and-operator-overloading).
And then Ada compiler will really catch the error in dimension as expected,
even though the error message doesn't look very intuitive (tried with
`gcc-gnat-11.2.1-7` on Fedora 35):

```
$ gnatmake -q example1.adb
example1.adb:16:20: expected type "Meters" defined at line 2
example1.adb:16:20: found type "Meters" defined at line 2
gnatmake: "example1.adb" compilation error
```

Representing physical units in this way may not be straightforward nor
practical.
But for simple cases when we don't need full dimensional analysis,
this approach can work nicely, as we can see in [strong typing example for
handling meters and miles
](https://learn.adacore.com/courses/intro-to-ada/chapters/strongly_typed_language.html#strong-typing)
from course [Introduction to
Ada](https://learn.adacore.com/courses/intro-to-ada/index.html).

In a nice and extensive overview of [dimensional analysis in programming
languages](https://gmpreussner.com/research/dimensional-analysis-in-programming-languages#ada),
we will learn that this was already clear in the 80s, when dimensional analysis
for Ada started to be investigated.
Eg. [N. H. Gehani in a paper from
1985](https://doi.org/10.1002/spe.4380150604) explains usage of a type system
with operator overloading (as done in the example above) and concludes
that it doesn't generally work:

> Derived types only partially solve the problem of detecting the inconsistent
> usage of objects; some valid usages of objects are also not allowed.
> Moreover, the solution is inelegant and inconvenient to use.

Besides further compiler research, focus was also given to design of libraries
which defines data structures holding both value and it's physical dimension
along with functions operating on them.
Something like this could be implemented in any language. That said
guarantees given to a programmer and it's cost will be constrained by chosen
approach and design of a particular programming language. Sheer data structure
library approach without using any additional language features (eg. type
system extensions or compile-time macros) leads to impractical run-time checks.
In an ideal case we want the dimension checks to performed during compilation
to avoid additional run-time cost.

Nowadays Ada compiler [GNAT provides native support for compile-time
dimensional
analysis](https://gcc.gnu.org/onlinedocs/gnat_ugn/Performing-Dimensionality-Analysis-in-GNAT.html).
It uses [*aspect clauses* from Ada 2012
standard](https://en.wikibooks.org/wiki/Ada_Programming/Aspects)
to implement [`Dimension`
aspect](https://docs.adacore.com/gnat_rm-docs/html/gnat_rm/gnat_rm/implementation_defined_aspects.html#aspect-dimension)
which can be used to define dimensions for numeric types. GNAT library
[`System.Dim.Mks`](https://github.com/gcc-mirror/gcc/blob/master/gcc/ada/libgnat/s-digemk.ads)
uses it to define unit system according to
[SI](https://en.wikipedia.org/wiki/International_System_of_Units) standard.
That said it puzzles me a bit that the library is called Mks, because
[MKS system](https://en.wikipedia.org/wiki/MKS_system_of_units) defines just a
subset of SI units.

When we rewrite the previous example utilizing this GNAT feature, we use unit
symbol `m` for meters and dimension types `Length` and `Area`. All these types
and symbols are defined in `System.Dim.Mks` library.

``` ada
with System.Dim.Mks; use System.Dim.Mks;
procedure Example2 is
  len_a : Length := 10.0*m;
  len_b : Length := 15.0*m;
  surface : Area;
  len_sum : Length;
begin
  len_sum := len_a + len_b; -- ok
  surface := len_a * len_b; -- ok
  len_sum := len_a * len_b; -- invalid
end Example2;
```

And as we can see, the compiler reports an error as expected, which is clearly
explained (`L` is a dimension symbol for `Length` as defined in
`System.Dim.Mks` library):

```
$ gnatmake -q -gnat2012 example2.adb
example2.adb:10:11: dimensions mismatch in assignment
example2.adb:10:11: left-hand side has dimension [L]
example2.adb:10:11: right-hand side has dimension [L**2]
gnatmake: "example2.adb" compilation error
```

Such support is a combination of direct implementation in a language
(`Dimension` aspects) and a library (`System.Dim.Mks`) and having such
support in a language and GNAT standard library makes it easier for dimensions
to be part of a public API.

But let's explore another more interesting (but still simple) example. Assume
we have 1.2 volt 3000 [mAh](https://en.wikipedia.org/wiki/Ampere_hour) battery,
and wonder how much energy in joules is stored there. Since we know that energy
E equals charge Q times voltage U, this is no problem:

``` ada
with System.Dim.Mks; use System.Dim.Mks;
with System.Dim.Mks_IO; use System.Dim.Mks_IO;
with Ada.Text_IO; use Ada.Text_IO;

procedure Example3 is
  U_b : Electric_Potential_Difference := 1.2*V;
  Q_b : Electric_Charge := 3000.0*mA*hour;
  E_b : Energy := U_b * Q_b;
begin
  Put("charge = ");
  Put(Q_b, Aft => 2, Exp => 0);
  Put_Line("");
  Put("energy = ");
  Put(E_b, Aft => 2, Exp => 0);
  Put_Line("");
end Example3;
```

When we compile and run the program, we see that it provides expected results:

```
$ gnatmake -q -gnat2012 example3.adb
$ ./example3
charge = 10800.00 C
energy = 12960.00 J
```

Note that we see units for both values, since this information is available
during runtime. That said we need to use `Put` from `System.Dim.Mks_IO`,
standard functions from `Ada.Text_IO` are not able to work with dimensional
quantities.
And even though we haven't explicitly done any unit conversion, we see that
the charge is reported in coloumbs when printed to stdout, thanks
to dimensional analysis and unit conversions performed during compilation.
And last but not least we can be sure that we
haven't done any stupid mistake in units or computation itself, since
the GNAT compiler haven't reported any error.

## F\#

Another language which is known for it's good support for dimensional analysis
is multi paradigm (functional/object oriented) language
[F#](https://en.wikipedia.org/wiki/F_Sharp_(programming_language)).
I learned about it's [Units of
Measure](https://docs.microsoft.com/en-us/dotnet/fsharp/language-reference/units-of-measure)
system [in 2015 on Hacker
News](https://news.ycombinator.com/item?id=9212329), but it
[was introduced back in 2008](https://docs.microsoft.com/en-us/archive/blogs/andrewkennedy/units-of-measure-in-f-part-one-introducing-units) and so it's the first non experimental
programming language with full builtin support for tracking of physical units.

Our previous simple example converted into F# would look like this:

``` fsharp
[<Measure>] type m // declaration of unit of measure "m" representing meters

let len_a = 10.0<m>
let len_b = 15.0<m>
let len_sum : float<m>   = len_a + len_b // ok
let surface : float<m^2> = len_a * len_b // ok
let len_c   : float<m>   = len_a * len_b // invalid
```

In the first line we declare unit of measure `m`, which can be used in both
numeric type declarations and numeric values. So `float<m>` is a type
of float numbers of unit `m`, while `float` or `float<1>` denotes a unitless
float value and `10.0<m>` is a value of type `float<m>`. Note that we are
unable to explicitly specify a dimension of the variable: we don't state "this
is a length specified as float meters", but just "this is float meters".

When we try to compile it, we will end up with expected unit of measure error:

```
$ dotnet run
/home/martin/projects/hello-fsharp/Program.fs(7,36): error FS0001: The unit of measure 'm' does not match the unit of measure 'm ^ 2' [/home/martin/projects/hello-fsharp/hello-fsharp.fsproj]

The build failed. Fix the build errors and run again.
```

This is very convenient way of representing units. That said, since we are
working with standardized physical units, it's crucial to not declare our own
unit of measure for meters (as we did in the example above) and use standard
definition from
[`FSharp.Data.UnitSystems.SI`](https://fsharp.github.io/fsharp-core-docs/reference/fsharp-data-unitsystems-si-unitsymbols.html)
library instead.

When we fix our simple example accordingly, we will end up with:

``` fsharp
type [<Measure>] m = FSharp.Data.UnitSystems.SI.UnitNames.metre

let len_a = 10.0<m>
let len_b = 15.0<m>
let len_sum : float<m>   = len_a + len_b // ok
let surface : float<m^2> = len_a * len_b // ok
let len_c   : float<m>   = len_a * len_b // invalid
```

Now let's have a look at the more interesting example. Note that because F# SI
library doesn't define any derived units for unit quantities (such as SI
prefixed unit mA), we have to convert miliamps to amperes and hours to seconds
themselves.

``` fsharp
type [<Measure>] V = FSharp.Data.UnitSystems.SI.UnitNames.volt
type [<Measure>] A = FSharp.Data.UnitSystems.SI.UnitNames.ampere
type [<Measure>] s = FSharp.Data.UnitSystems.SI.UnitNames.second
type [<Measure>] J = FSharp.Data.UnitSystems.SI.UnitNames.joule

let u_b = 1.2<V>
let q_b = 3.0*3600.0<A*s>
let e_b : float<J> = u_b * q_b

printfn "charge = %.2f" q_b
printfn "energy = %.2f" e_b
```

And when we compile and run the program, we get the expected results:

```
$ dotnet run
charge = 10800.00
energy = 12960.00
```

Note that there is no way to get unit of a value since [information
about units is completelly lost during compilation](https://stackoverflow.com/questions/4359767/how-do-you-print-the-resulting-units-using-units-of-measure-in-f#4359907).
On one hand this is not necessary for dimensional analysis and validation
itself, as it happens during compile time anyway. But on the other hand, it
means you can't implement any functionality which takes unit into account
during runtime. To have the unit reported like in the previous Ada example, we
would have to manually specify it like this:

``` fsharp
printfn "energy = %.2f J" e_b
```

Which is obviously not verified by the compiler.

## Python

There are quite a few [python libraries for physical unit
handling](https://gmpreussner.com/research/dimensional-analysis-in-programming-languages#python).
For the purpose of this blogpost, we are going to use
[Pint](https://pint.readthedocs.io/en/stable/), which provides nice
way to work with physical quantities with integration for packages like
[NumPy](https://numpy.org/), [Pandas](https://pandas.pydata.org/) and
[uncertainties](https://pythonhosted.org/uncertainties/).
That said I don't want to claim that Pint is the best option in all use cases,
as I haven't tested the alternatives.

We need to change our simple example a bit more for it to work in Python.
Even though Python has a type system, it's not possible to assign a type to
a variable, so instead of our attempt to assign meters squared value into
variable of length type, we will try to just sum meters with meters squared
instead:

``` python
import pint

ureg = pint.UnitRegistry()

len_a = 10 * ureg.m
len_b = 15 * ureg.m
len_sum = len_a + len_b # ok
surface = len_a * len_b # ok
len_c = surface + len_b # invalid
```

So when we try to execute the script, we see an error as expected:

```
$ python example1.py
Traceback (most recent call last):
  File "/home/martin/projects/units/example1.py", line 9, in <module>
    len_c = surface + len_b # invalid
  File "/usr/lib/python3.10/site-packages/pint/quantity.py", line 1079, in __add__
    return self._add_sub(other, operator.add)
  File "/usr/lib/python3.10/site-packages/pint/quantity.py", line 115, in wrapped
    return f(self, *args, **kwargs)
  File "/usr/lib/python3.10/site-packages/pint/quantity.py", line 989, in _add_sub
    raise DimensionalityError(
pint.errors.DimensionalityError: Cannot convert from 'meter ** 2' ([length] ** 2) to 'meter' ([length])
```

Of course another difference compared to previous examples in Ada or F# is that
it's a runtime error. For obvious reasons, pint is just a library providing
classes like
[Quantity](https://pint.readthedocs.io/en/stable/developers_reference.html#pint.Quantity),
which can be used to express and work with values and their physical units.
That said if we really cared a lot about catching such errors during compile
time, we won't be using Python anyway.

To look at the more interesting example, we need to adapt it in a similar way
as we did with the 1st python example. But here, we will explicitly convert the
energy value `e_b` to joules (to make sure our assumption holds):

``` python
import pint

ureg = pint.UnitRegistry()

u_b = 1.2 * ureg.V
q_b = 3000 * ureg.mA * ureg.hour
e_b = (u_b * q_b).to(ureg.J)

print(f"charge {q_b}")
print(f"energy {e_b:.2f}")
```

So that we get this result:

```
$ ipython

In [1]: %run example2.py
charge 3000 hour * milliampere
energy 12960.00 joule
```

Note that charge `q_b` wasn't converted into coulombs, since we haven't
performed any operation which would require that. But we can do such conversion
explicitly as we did for energy `e_b`:

```
In [2]: q_b.to(ureg.C)
Out[2]: 10799.999999999998 <Unit('coulomb')>
```

Or we can check whether the quantity matches expected unit:

```
In [3]: q_b.check(ureg.C)
Out[3]: True
```

## Conclusion

GNAT Ada or F# comes with very nice builtin support for work with physical
quantities and dimensional analysis. And even though there are some limitations
in both cases (which we haven't looked into as as we just scratched
the surface on few simple examples), overall both solutions are ready to be
used for serious tasks. While run-time solutions can be implemented in any
language, such solutions have additional cpu and memory overhead which makes
them impractical. However for scripting languages or particular use cases,
such cost can be justified, as we see for Python and Pint.
If you work with physical quantities, usage of language feature and/or library
for units it's worth considering. And if you find this topic interesting, you
may like already mentioned overview of [Dimensional Analysis in Programming
Languages](https://gmpreussner.com/research/dimensional-analysis-in-programming-languages),
which covers this area in more detail and lists much more programming
languages.

## References

Links listed here are already present in text the post, but I'm highlighting
them here again:

- [Dimensional Analysis in Programming Languages](https://gmpreussner.com/research/dimensional-analysis-in-programming-languages) (a survey of existing designs and implementations from 2018)
- [Performing Dimensionality Analysis in
  GNAT](https://gcc.gnu.org/onlinedocs/gnat_ugn/Performing-Dimensionality-Analysis-in-GNAT.html), [Physical Units with GNAT](http://archive.adaic.com/tools/CKWG/Dimension/Physical_units_with_GNAT_GPL_2013-AUJ35.1.pdf)
  (Ada)
- [Units of
  Measure](https://docs.microsoft.com/en-us/dotnet/fsharp/language-reference/units-of-measure)
  (F#)
- [Pint Tutorial](https://pint.readthedocs.io/en/stable/tutorial.html) (Python)
