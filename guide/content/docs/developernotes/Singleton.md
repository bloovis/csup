---
weight: 3
---

# Singleton Classes

As I mentioned in [Ruby 3 Problems]({{< relref "Ruby3" >}}),
Sup is filled with singleton classes. When I first encountered
this programming pattern, my initial reaction was disgust,
and I vowed never to use such a pattern in my own code.
In fact, singletons do seem to have a bit of controversy around
them, judging from the discussions I see on Stackoverflow.

But trying to port Sup without singletons looked like an
overwhelming task: they're everywhere, and trying to rewrite
them as normal classes was a daunting task.

So the question became: how to implement singletons in Crystal?
In Sup, they are implemented with two things:

* a single instance variable for the one instantiation of the class
* a `method_missing` that redirects every class method to an instance
method

The `method_missing` feature makes clever use of Ruby's dynamic features:
it defines a method with the missing name, and binds that method
to the single instance of the class.
This can't be done in Crystal, in which all methods must be known
at compile time.

My solution was to implement a hack using some macros:

* Each singleton class needs to call the `singleton_class` somewhere near
the top of the class.  This macro sets up the instance variable
and defines some methods (`instance`, `instantiated?`, and `deinstantiate`)
that Sup expected.

* The first line in the class constructor (`initialize`) must be a call
to the macro `singleton_pre_init`, which ensures that there is only
one instance of the class.  The last line in the constructor must be a call
to the macro `singleton_post_init`, which sets the instance variable.

* Each method in the class that is supposed to be treated as a method
for the single instance must be followed by a call to `singleton_method`
macro, which lists the name of the method, along with names of
all of its arguments.  This macro defines a new class method that invokes
the instance method of the same name.

For more details, see the `src/singleton.cr` file in the source repository.

(*Note*: it occurs to me now that it might have been possible to implement
singletons using the `forward_missing_to` macro in Crystal.  I might try
this some time, but I'm not highly motivated to do so, since my
existing hack works well enough.)
