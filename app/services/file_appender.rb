# frozen_string_literal: true
class FileAppender
  attr_reader :files, :change_set_persister
  delegate :persister, :query_service, to: :metadata_adapter
  delegate :storage_adapter, :metadata_adapter, to: :change_set_persister
  def initialize(files:, change_set_persister:)
    @change_set_persister = change_set_persister
    @files = files
  end

  def append_to(resource)
    return [] if files.blank?
    updated_files = update_files(resource, files)
    return updated_files unless updated_files.empty?

    file_sets = build_file_sets || file_nodes
    if file_set?(resource)
      resource.file_metadata += file_sets
    else
      resource.member_ids += file_sets.map(&:id)
      resource.thumbnail_id = file_sets.first.id if resource.thumbnail_id.blank?
    end
    adjust_pending_uploads(resource)
    file_sets
  end

  def file_set?(resource)
    resource.respond_to?(:file_metadata) && !resource.respond_to?(:member_ids)
  end

  def update_files(resource, files)
    files.select { |file| file.is_a?(Hash) }.map do |file|
      proxy = resource.file_metadata.select { |x| x.proxy.first.to_s == file.keys.first }.first
      node = query_service.find_by(id: proxy.proxy.first)
      file_wrapper = UploadDecorator.new(file.values.first, node.original_filename.first)
      new_node = create_node(file_wrapper)
      new_proxy = build_proxy(new_node)
      resource.file_metadata -= [proxy]
      resource.file_metadata += [new_proxy]
      new_proxy
    end
  end

  def build_proxy(node)
    FileMetadataProxy.new(use: node.use, proxy: node.id, file_identifiers: node.file_identifiers)
  end

  def build_file_sets
    return if processing_derivatives?
    file_nodes.each_with_index.map do |node, index|
      file_set = create_file_set(node, files[index])
      file_set
    end
  end

  def adjust_pending_uploads(resource)
    return unless resource.respond_to?(:pending_uploads)
    resource.pending_uploads = [] if resource.pending_uploads.blank?
    resource.pending_uploads = (resource.pending_uploads || []) - files
  end

  def processing_derivatives?
    !file_nodes.first.original_file?
  end

  def file_nodes
    @file_nodes ||=
      begin
        files.map do |file|
          node = create_node(file)
          build_proxy(node)
        end
      end
  end

  def create_node(file)
    node = FileMetadata.for(file: file) # .new(id: SecureRandom.uuid)
    file = storage_adapter.upload(file: file, resource: node)
    existing_node = query_service.find_inverse_references_by(resource: file, property: :file_identifiers).first
    return existing_node if existing_node.present?
    node.file_identifiers = node.file_identifiers + [file.id]
    persister.save(resource: node)
  end

  def create_file_set(file_node, file)
    attributes = {
      title: file.original_filename,
      file_metadata: [file_node]
    }.merge(
      file.try(:container_attributes) || {}
    )
    persister.save(resource: FileSet.new(attributes))
  end
end
