class ProcessImportUrlWorker

  include Sidekiq::Worker
  sidekiq_options unique: true

  def perform class_name, method, *arguments
    klass = Object.const_get(class_name)
    klass.send(method, *arguments)
  end

end