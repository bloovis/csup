# Macros to simulate the Singleton class used in Sup.

# Use this macro at the start of the class, passing it the class name.
macro singleton_class(klass)
  @@initialized = false
  @@instance : {{klass}}?

  def self.instance
    inst = @@instance
    if inst
      return inst
    else
      raise "{{klass}} not instantiated!"
    end
  end
end

# Use this macro at the beginning of the initialize method.
macro singleton_pre_init
    raise self.class.name + " : only one instance can be created" if @@initialized
    @@initialized = true
end

# Use this macro at the end of the initialize method.
macro singleton_post_init
    @@instance = self
end

# Use this macro to define a class method that invokes the corresponding instance method.
macro singleton_method(klass, name, *args)
  def {{klass}}.{{name}}(*args)
    self.instance.{{name}} *args
  end
end
