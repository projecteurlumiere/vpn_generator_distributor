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
      current_user.update(instruction: instruction_name, instruction_step: 0)
    end

    if current_user.instruction.nil?
      reply_with_start_menu(
        "Похоже, вы потеряли инструкции. Вот они:",
        Instructions.instance.titles.map { |title| [title] }
      )
    end

    if last_instruction_step?
      current_user.update(instruction: nil, instruction_step: nil)
      reply_success
      return
    end

    reply_instruction_step
    current_user.update(instruction_step: current_user.instruction_step + 1)
  end

  private

  def reply_instruction_step
    step = current_instruction[:steps][current_user.instruction_step]

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

  def last_instruction_step?
    current_user.instruction_step >= current_instruction[:steps].size
  end

  def current_instruction
    Instructions.instance[current_user.instruction]
  end
end