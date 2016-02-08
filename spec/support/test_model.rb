require 'active_record'

class TestModel < ActiveRecord::Base
  include TableRotate
end
