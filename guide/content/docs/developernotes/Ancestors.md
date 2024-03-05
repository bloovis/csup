---
weight: 4
---

# Class Ancestors and Key Bindings

One difficult problem I ran into was the way Sup implements key bindings.
Modes in Sup are implemented as a hierarchy of classes.  For example,
the SearchResultsMode has this hierarchy:

* SearchResultsMode
* ThreadIndexMode
* LineCursorMode
* ScrollMode

Each of these modes has its own key bindings.  When the user types a key,
Sup looks down the Mode hierarchy, starting with the most-derived class,
for a mode that has a command bound to that key.  So in example above,
Sup first looks at the key bindings for SearchResultsMode, then ThreadIndexMode,
and so on.

Sup implements this key binding search using the Ruby `ancestors` method
to determine the class hierarchy.  There is no equivalent function
in Crystal.

Furthermore, Sup invokes the appropriate
command for a given key by getting the associated method name from the
key binding table, then using `send` to invoke that method on the particular
Mode object.  There is no equivalent to `send` in Crystal, because all
methods must be known at compile time.

So this meant two problems had to be solved: creating the ancestors list,
and creating a `send` equivalent.  This is done with macros.

First, there is an `action` macro that takes as arguments the names
of one or more methods.  It creates a `send` method that takes
a method name as a parameter (either a string or a symbol), and invokes that method via a large
`case` statement.  it also creates a `respond_to?` method that
returns true if the passed-in method name is in the list of names.

Then there is a `mode_class` macro that must be invoked near
the top of any class derived from Mode.  The arguments to
the macro are the names of all functions that the Mode expects
to be invoked via `send`.  In other words, the arguments to `mode_class`
are passed directly to `action`.  Additionally, `mode_class` defines
an `ancestors` method that, when invoked, returns an array of class
names that represents the class hierarchy.

For more details, see the `src/mode.cr` file in the source repository.
