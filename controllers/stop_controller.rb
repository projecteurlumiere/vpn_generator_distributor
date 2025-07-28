class StopController < ApplicationController
  def call
    reply("bye")
  end
end
