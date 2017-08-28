# frozen_string_literal: true
class PlumImporter
  attr_reader :id
  delegate :persister, :query_service, to: :metadata_adapter
  def initialize(id:)
    @id = id
  end

  def import!
    output = nil
    change_set_persister.buffer_into_index do |buffered_change_set_persister|
      output = buffered_change_set_persister.save(change_set: change_set)
      members = query_service.find_members(resource: output)
      members.each do |member|
        file_change_set = FileSetChangeSet.new(member)
        file_change_set.prepopulate!
        file_change_set.files = [derivative(member)]
        derivative_change_set_persister = PlumChangeSetPersister.new(metadata_adapter: buffered_change_set_persister.metadata_adapter, storage_adapter: derivative_storage_adapter)
        derivative_change_set_persister.save(change_set: file_change_set)
      end
      output = update_structure(output, members, buffered_change_set_persister)
    end
    output
  end

  def update_structure(resource, members, change_set_persister)
    change_set = ScannedResourceChangeSet.new(resource).tap(&:prepopulate!)
    structure = document.structure
    members.each do |member|
      structure = structure.gsub(member.replaces[0], member.id.to_s)
    end
    change_set.validate(logical_structure: [MultiJson.load(structure, symbolize_keys: true)])
    change_set.sync
    change_set_persister.save(change_set: change_set)
  end

  def change_set
    @change_set ||= ScannedResourceChangeSet.new(resource).tap do |change_set|
      change_set.prepopulate!
      change_set.validate(change_set_attributes)
      change_set.sync
    end
  end

  def resource
    @resource ||= ScannedResource.new(document.attributes)
  end

  def metadata_adapter
    Valkyrie::MetadataAdapter.find(:indexing_persister)
  end

  def storage_adapter
    Valkyrie::StorageAdapter.find(:plum_storage)
  end

  def derivative_storage_adapter
    Valkyrie::StorageAdapter.find(:plum_derivatives)
  end

  def derivative(member)
    PlumDerivative.new(member, document).file
  end

  def change_set_persister
    @change_set_persister ||= PlumChangeSetPersister.new(metadata_adapter: metadata_adapter, storage_adapter: storage_adapter, characterize: false)
  end

  def change_set_attributes
    {
      files: document.files
    }
  end

  def plum_solr
    @plum_solr ||= RSolr.connect(url: Figgy.config["plum_solr_url"])
  end

  def document
    @document ||= PlumDocument.new(plum_solr.get("select", params: { q: "id:#{id}", rows: 1 })["response"]["docs"].first)
  end

  class PlumDerivative
    attr_reader :file_set, :parent_document
    def initialize(file_set, parent_document)
      @file_set = file_set
      @parent_document = parent_document
    end

    def file
      IngestableFile.new(
        file_path: file_set_document.derivative_path,
        mime_type: "image/jp2",
        original_filename: "intermediate_file.jp2",
        use: [Valkyrie::Vocab::PCDMUse.ServiceFile],
        copyable: true
      )
    end

    def file_set_document
      @file_set_document ||= parent_document.file_set_documents.find { |x| x.id == file_set.replaces[0] }
    end
  end

  class PlumDocument
    attr_reader :solr_doc
    def initialize(solr_doc)
      @solr_doc = solr_doc
    end

    def attributes
      {
        depositor: solr_doc["depositor_ssim"],
        source_metadata_identifier: solr_doc["source_metadata_identifier_ssim"].first
      }
    end

    def files
      file_set_documents.map do |file_set|
        IngestableFile.new(
          file_path: file_set.file_path,
          mime_type: "image/tiff",
          original_filename: file_set.original_filename,
          container_attributes: { replaces: file_set.id },
          node_attributes: file_set.file_attributes,
          copyable: true
        )
      end
    end

    def structure
      solr_doc["logical_order_tesim"][0]
    end

    def file_set_documents
      @file_set_documents ||= raw_file_set_docs.map { |x| FileSetDocument.new(x) }.sort_by { |x| ordered_ids.index(x.id) }
    end

    def raw_file_set_docs
      plum_solr.get("select", params: {
                      rows: 10_000,
                      q: "{!join from=ordered_targets_ssim to=id}id:\"#{solr_doc['id']}/list_source\""
                    })["response"]["docs"]
    end

    def ordered_ids
      @ordered_ids ||= plum_solr.get("select", params: { rows: 1, q: "id:\"#{solr_doc['id']}/list_source\"" })["response"]["docs"].first.fetch("ordered_targets_ssim", [])
    end

    def plum_solr
      @plum_solr ||= RSolr.connect(url: Figgy.config["plum_solr_url"])
    end
  end

  class FileSetDocument
    attr_reader :solr_doc
    def initialize(solr_doc)
      @solr_doc = solr_doc
    end

    def file_path
      PlumFilePath.new(self).binary
    end

    def derivative_path
      PlumFilePath.new(self).derivative
    end

    def original_filename
      solr_doc["label_tesim"].first
    end

    def id
      solr_doc["id"]
    end

    def file_attributes
      {
        width: solr_doc["width_is"].to_s,
        height: solr_doc["height_is"].to_s
      }
    end
  end

  class PlumFilePath
    attr_reader :file_set_document
    delegate :id, :original_filename, to: :file_set_document
    def initialize(file_set_document)
      @file_set_document = file_set_document
    end

    def binary
      plum_binary_path.join(*buckets).join(id).join(original_filename)
    end

    def derivative
      plum_derivative_path.join(*buckets).join("#{last_pair}-intermediate_file.jp2")
    end

    def last_pair
      id.chars.each_slice(2).map(&:join).last
    end

    def buckets
      id.chars.each_slice(2).map(&:join)[0..-2]
    end

    def plum_binary_path
      Pathname.new(Figgy.config["plum_binary_path"])
    end

    def plum_derivative_path
      Pathname.new(Figgy.config["plum_derivative_path"])
    end
  end
end
