# frozen_string_literal: true
class PlumImporterJob < ApplicationJob
  def perform(id)
    logger.info "Importing #{id} from Plum"
    output = PlumImporter.new(id: id).import!
    logger.info "Imported #{id} from plum: #{output.id}"
  end
end
