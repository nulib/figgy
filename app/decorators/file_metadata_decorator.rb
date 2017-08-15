# frozen_string_literal: true
class FileMetadataDecorator < Valkyrie::ResourceDecorator
  def content_type
    mime_type.first
  end

  def path
    file.io.path
  end

  def original_filename
    super.first
  end

  def file
    @file ||= Valkyrie::StorageAdapter.find_by(id: file_identifiers.first)
  end
end
