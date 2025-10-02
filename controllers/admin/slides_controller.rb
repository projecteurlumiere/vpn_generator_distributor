class Admin::SlidesController < ApplicationController
  include AdminHelpers

  def self.routes
    []
  end

  def call
    @state_controller, @substate, @filename = current_user.state_array
    
    if @state_controller == self.class.name
      case @substate
      in "upload"
        handle_upload_yml
      in "review"
        handle_slide_edit
      else
        raise RoutingError
      end
    else
      raise RoutingError
    end

  end

  def menu
    msg = <<~TXT
      Можно отредактировать следующие слайды.

      Не редактируйте действия-кнопки (actions) слайдов! 
      Бот не знает, куда будут вести эти кнопки.
    TXT

    slides = Slides.instance.paths.map do |path| 
      { File.basename(path, File.extname(path)) => callback_name("actions", File.basename(path)) }
    end

    reply_with_inline_buttons(msg, [
      admin_menu_inline_button,
      *slides
    ]) 
  end

  def actions(filename)
    path = "./data/slides/#{filename}"
    
    unless File.exist?(path)
      reply("Файл не найден: #{path}")
      menu
      return
    end

    msg = <<~TXT
      Выберите действия для #{ File.basename(path, File.extname(path))}
    TXT

    reply_with_inline_buttons(msg, [
      { "К другим слайдам" => callback_name("menu") },
      { "Скачать" => callback_name("download", filename) },
      { "Редактировать" => callback_name("edit", filename) }
    ])
  end

  def download(filename)
    path = File.join("./data/slides", filename)

    unless File.exist?(path)
      reply("Файл не найден: #{filename}")
      menu
      return
    end

    bot.api.send_document(
      chat_id:,
      document: Faraday::UploadIO.new(path, 'application/x-yaml'),
      caption: "Инструкция: #{filename}"
    )
  end

  def edit(filename)
    path = "./data/slides/#{filename}"
    
    unless File.exist?(path)
      reply("Файл не найден: #{path}")
      menu
      return
    end

    reply("Загрузите новый yml #{File.basename(path, File.extname(path))}")
    current_user.update(state: [self.class.name, "upload", filename].join("|"))
  end

  private

  def review_slide
    slide = YAML.load_file("./tmp/slides/#{@filename}", symbolize_names: true)
    reply_with_buttons(slide[:text], [
      ["Принять", "Убрать изображения", "Отклонить"]
    ], photos: slide[:images])

    reply("Или загрузите фотографию", reply_markup: nil)
  end

  def handle_upload_yml
    if message.document.nil? || !message.document.file_name.match?(/\.(ya?ml)\z/i)
      reply("Пожалуйста, загрузите файл с расширением .yml или .yaml")
    else
      dest_path = File.join("./tmp/slides", message.document.file_name)
      path = download_attachment(message.document.file_id, dest_path)

      if Slides.instance.errors_for(path) in [:invalid, { errors: errors} ]
        msg = <<~TXT
          Файл-слайд не действителен. Были обнаружены следущие ошибки:

          #{errors.join("\n")}
        TXT

        FileUtils.rm_f(path)

        reply(msg)
        return
      end

      new_path = File.join(File.dirname(path), @filename)
      FileUtils.mv(path, new_path) unless File.expand_path(path) == File.expand_path(new_path)
      
      state = "#{self.class.name}|review|#{@filename}"
      current_user.update(state:)
      
      review_slide
    end
  end

  def handle_slide_edit
    path = "./tmp/slides/#{@filename}"

    case message.text
    in nil if message.photo
      image_id = message.photo.last.file_id

      $mutex.sync do
        slide = YAML.load_file(path, symbolize_names: true)
        slide[:images] ||= []
        slide[:images] << image_id

        File.write(path, slide.to_yaml)
      end

      review_slide
    in "Отклонить"
      FileUtils.rm_f(path) if File.exist?(path)
      menu
    in "Принять"
      new_path = "./data/slides/#{@filename}"
      FileUtils.mv(path, new_path)
      Slides.instance.load!
      reply("Слайд обновлён")
      menu
    in "Убрать изображения"
      $mutex.sync do
        slide = YAML.load_file(path, symbolize_names: true)
        slide.delete(:images)

        File.write(path, slide.to_yaml)
      end

      reply("Изображения удалены")
      review_slide
    else
      raise RoutingError
    end
  end
end
