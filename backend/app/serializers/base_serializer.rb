# frozen_string_literal: true

# Simple serializer base class for object serialization
# Replaces dependency on active_model_serializers gem
class BaseSerializer
  attr_reader :object, :options

  def initialize(object, options = {})
    @object = object
    @options = options
  end

  def serialize
    raise NotImplementedError, "Subclasses must implement #serialize"
  end

  def as_json(options = nil)
    serialize
  end

  protected

  def attributes(*names)
    names.each_with_object({}) do |name, hash|
      hash[name] = object.send(name)
    end
  end
end
