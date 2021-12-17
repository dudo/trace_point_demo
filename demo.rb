require_relative 'point_trace'

class Demo
  def self.boom(string: '')
    raise "bang bang niner gang #{string}"
  end

  def initialize(thing: 1)
    @thing = thing
  end

  def foo
    bar
  end

  def bar
    @thing
  end

  def json
    Oj.dump({ 'one' => 1, 'array' => [true, false] })
  end
end

d = Demo.new
d.foo
d.json
Demo.boom
