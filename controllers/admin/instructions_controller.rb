# AdminController
#
# Commands:
# /admin instructions
#   - List all instruction sets (windows, mac, etc.)
# /admin upload_instruction
#   - YAML file to upload
# /admin versions
#   - Show git history
# /admin rollback <version>
#   - Go to a backup version
# /admin upload_images_for <instruction_name>
#   - Guided: per-step, prompt for file(s), save images by step.     
#
# Images: upload as files (not photos). Filenames preserved.
# Guided uploads link files to steps live; no post-facto missing check needed.
# All changes git-versioned. Only track state during guided sessions.
require "fileutils"

class Admin::InstructionsController < ApplicationController
  def self.routes
    [
      "/admin instructions",
      "/admin upload_instruction",
      "Следующий шаг",
      "Предыдущий шаг"
    ]
  end

  def call
    current_user.state&.split("|") in [state_controller, state_substate, *]
    current_user.state&.split("|") in [_, _, file_path, step]
    step = step.to_i

    if message.document && state_controller == self.class.name
      case state_substate
      in "instruction_upload"
        unless message.document.file_name =~ /\.(ya?ml)\z/i
          reply("Пожалуйста, загрузите файл с расширением .yml или .yaml")
          return
        end

        binding.irb

        upload_instruction(state_controller, state_substate)

        return
      in "instruction_review" if file_path && step

        # ...
      end
    end

    # Handle text commands
    case message.text
    in "/admin instructions"
      instructions
    in "/admin upload_instruction"
      current_user.update(state: "#{self.class.name}|instruction_upload")
      reply("Пожалуйста, прикрепите YAML файл с инструкцией.")
    in * if file_path && step
      next_instruction_step(step + 1)
      current_user.update(state: [state_controller, state_substate, file_path, step + 1].join("|"))
    end
  end

  def instructions
    reply(<<~TXT
      Загружены следующие инструкции:
      #{Instructions.instance.titles.join("\n")}
    TXT
    )
  end


  private

  def upload_instruction(state_controller, state_substate)
    dest_path = File.join("./tmp", message.document.file_name)
    path = download_attachment(message.document.file_id, dest_path)
    instruction = YAML.load_file(path, symbolize_names: true)
    new_title = instruction[:title].downcase
    new_path = File.join(File.dirname(path), "#{new_title}.yml")
    FileUtils.mv(path, new_path)

    current_user.update(state: "#{self.class.name}|instructions_review|#{new_path}|0")
    next_instruction_step(new_path, 0)
  end

  def next_instruction_step(path, step)
    YAML.load_file(path, symbolize_names: true)
    step = current_instruction[:steps][step]

    reply_with_buttons(
      step[:message],
      step[:actions].map { |a| [a] }
    )
  end
end
