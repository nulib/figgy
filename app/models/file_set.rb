# frozen_string_literal: true
class FileSet < Valhalla::Resource
  include Valkyrie::Resource::AccessControls
  attribute :id, Valkyrie::Types::ID.optional
  attribute :title, Valkyrie::Types::Set
  attribute :file_metadata, Valkyrie::Types::Set.member(FileMetadata.optional)
  attribute :viewing_hint
  attribute :depositor
  attribute :replaces

  def thumbnail_id
    id
  end

  def derivative_file
    file_metadata.find(&:derivative?)
  end

  def original_file
    file_metadata.find(&:original_file?)
  end
end
