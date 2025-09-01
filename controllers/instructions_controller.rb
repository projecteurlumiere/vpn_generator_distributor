class InstructionsController < ApplicationController
  def self.routes
    Instructions.instance.all.map do |_file_name, content|
      [
        content[:title], # instruction titles
        content[:steps].filter_map { |step| step[:actions] }
      ]
    end.flatten.uniq
  end

  def call
    if instruction_name = Instructions.instance.instruction_name_by_title(message.text)
      current_user.update(state: "instruction:#{instruction_name}:0")
    end

    if current_user.state.nil?
      reply_with_buttons(
        "Похоже, вы потеряли инструкции. Вот они:",
        Instructions.instance.titles.map { |title| [title] }
      )
      return
    end

    current_user.state.split(":") => [controller, instruction_name, step]
    current_instruction = Instructions.instance[instruction_name]
    step = step.to_i

    if step >= current_instruction[:steps].size
      current_user.update(state: nil)
      reply_success
      return
    end

    reply_instruction_step(current_instruction, step)

    step += 1 
    current_user.update(state: [controller, instruction_name, step.to_i].join(":"))
  end

  private

  def reply_instruction_step(current_instruction, step)
    step = current_instruction[:steps][step]

    reply_with_buttons(
      step[:message],
      step[:actions].map { |a| [a] }
    )
  end

  def reply_success
    reply_with_buttons(
      "Вы успешно прошли инструкцию! Можете пройти ещё одну:",
      Instructions.instance.titles.map { |title| [title] }
    )
  end
end
