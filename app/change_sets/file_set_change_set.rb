# frozen_string_literal: true
class FileSetChangeSet < Valkyrie::ChangeSet
  self.fields = [:title]
  property :files, virtual: true, multiple: true, required: false
  property :viewing_hint, multiple: false, required: false
  delegate :thumbnail_id, to: :model

  def primary_terms
    [:title]
  end

  def file_metadata
    @file_metadata ||=
      begin
        resource.file_metadata.map do |proxy|
          query_service.find_by(id: proxy.proxy.first)
        end
      end
  end

  def query_service
    Valkyrie.config.metadata_adapter.query_service
  end
end
