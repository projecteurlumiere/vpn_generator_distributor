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

class Admin::BaseController < ApplicationController
  def self.routes
    [
      "/admin",
      "/admin instructions",
      "/admin upload_instruction",
      "/admin versions",
      "/admin rollback"
    ]
  end

  def call
    case message.text
    in "/admin" | "/admin help"
      help
    end
  end

  def help
    reply(<<~TXT
      Доступны следующие команды
      /admin help
      /admin instructions
      /admin upload_instruction
      /admin versions
      /admin rollback
    TXT
    )
  end

  def instructions
    reply(<<~TXT
      Загружены следующие инструкции:
      #{Instructions.instance.titles.join("\n")}
    TXT
    )
  end
end
