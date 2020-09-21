require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::LndChannelStatusAgent do
  before(:each) do
    @valid_options = Agents::LndChannelStatusAgent.new.default_options
    @checker = Agents::LndChannelStatusAgent.new(:name => "LndChannelStatusAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
