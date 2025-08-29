class StopController < ApplicationController
  def self.routes
    ["/stop"]
  end

  def call
    reply("bye")
  end
end
