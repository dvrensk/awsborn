# Copied from ActiveSupport and modified
class Proc #:nodoc:
  def bind (object, basename = nil)
    block, time = self, Time.now
    (class << object; self end).class_eval do
      method_name = "__#{basename || 'bind'}_#{time.to_i}_#{time.usec}"
      define_method(method_name, &block)
      method = instance_method(method_name)
      remove_method(method_name)
      method
    end.bind(object)
  end
end
