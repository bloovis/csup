# Macros to simulate the Singleton class used in Sup.

# Use this macro at the start of the class.
macro singleton_class
  CLASSNAME = {{@type.stringify}}
  @@instance : {{@type}}?

  def self.instance
    inst = @@instance
    if inst
      return inst
    else
      raise "#{CLASSNAME} not instantiated!"
    end
  end

  def self.instantiated?
    !@@instance.nil?
  end

  def self.deinstantiate!
    @@instance = nil
  end
end

# Use this macro at the beginning of the initialize method.
macro singleton_pre_init
    raise self.class.name + " : only one instance can be created" if @@instance
end

# Use this macro at the end of the initialize method.
macro singleton_post_init
    @@instance = self
end

# Use this macro to define a class method that invokes the corresponding instance method.
macro singleton_method(name, *args)
  def {{ parse_type("CLASSNAME").resolve.id }}.{{name}}(*args)
    self.instance.{{name}}(*args)
  end
end
