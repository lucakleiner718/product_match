class ProcessImportUrlWorker

  include Sidekiq::Worker

  def perform class_name, method, arguments
    klass = Object.const_get(class_name)
    klass.send(method, arguments)
  end

end