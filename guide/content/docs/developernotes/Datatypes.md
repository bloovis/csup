---
weight: 5
---

# Dealing With Arbitrary Data Types

Sup is full of arrays and hashes that contain arbitrary data types.
It's common to see declarations like these:

    @accounts = {}
    @users = []

In Ruby, hashes can have keys of just about any possible type.  Arrays
can have elements of just about any possible type, for example:

    [[:editing_frozen_text_color, line]]

This often makes it difficult to know exactly what's being stored
in these hashes and arrays, because the types can change at any
time.  This is Ruby feature that is both wonderful and terrible.

In Crystal, one has to be careful to specifiy exactly what's
being stored in variables.  You can declare union types in those
cases where you want a variable to have multiple possible types.
But even with union types, you still need to be precise, or you'll
get compile-time type errors.

It's often helpful to declare alias types to make the nature of
complicated data structures more clear.  For example, in Sup, a text
buffer consists of an array of lines, and each line can be one of
two things:

* a simple string, which is displayed using a default color
* an array of "widgets", each of which is a (color, string) pair

The array example above shows what a simple, single-element widget array
looks like in Sup.

The Sup code that displays text can be confusing, because it's not always
clear whether the text line is a string or a widget array, and the nested array
brackets tend to obscure the data structure hierarchy.

I chose to make this more clear in Csup by using the following alias
declarations to describe text lines:

```
alias Widget = Tuple(Symbol, String)
alias WidgetArray = Array(Widget)
alias Text = WidgetArray | String
alias TextLines = Array(Text)
```

Here we can see that a widget in Sup is a tuple, not an array.
This allows the compiler to insure that the first element
of a widget is always a symbol, and the second element is always a string.
This kind of type checking is possible in Ruby only at run time, and
the Sup code did not bother to check that widgets were correctly
constructed.  In Csup, the above widget example now looks like:

    [{:editing_frozen_text_color, line}]

It's now a tiny bit more clear that this structure is an array with a single element,
and that element is a widget, i.e. a (color, string) pair.
