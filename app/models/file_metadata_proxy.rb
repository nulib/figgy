# frozen_string_literal: true
class FileMetadataProxy < Valhalla::Resource
  attribute :use
  attribute :proxy
  attribute :file_identifiers

  def original_file?
    use.include?(Valkyrie::Vocab::PCDMUse.OriginalFile)
  end

  def derivative?
    use.include?(Valkyrie::Vocab::PCDMUse.ServiceFile)
  end

  def file_identifier
    file_identifiers.first
  end
end
