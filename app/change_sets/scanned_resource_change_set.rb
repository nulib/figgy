# frozen_string_literal: true
class ScannedResourceChangeSet < Valkyrie::ChangeSet
  delegate :human_readable_type, to: :model
  property :title, multiple: true, required: true, default: []
  property :source_metadata_identifier, required: true, multiple: false
  property :rights_statement, multiple: false, required: true, default: "http://rightsstatements.org/vocab/NKC/1.0/", type: ::Types::URI
  property :rights_note, multiple: false, required: false
  property :viewing_hint, multiple: false, required: false, default: "individuals"
  property :pdf_type, multiple: false, required: false, default: "gray"
  property :holding_location, multiple: false, required: false, type: ::Types::URI
  property :viewing_direction, multiple: false, required: false
  property :portion_note, multiple: false, required: false
  property :nav_date, multiple: false, required: false
  property :visibility, multiple: false, default: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
  property :local_identifier, multiple: true, required: false, default: []
  property :member_ids, multiple: true, required: false, type: Types::Strict::Array.member(Valkyrie::Types::ID)
  property :thumbnail_id, multiple: false, required: false, type: Valkyrie::Types::ID
  property :start_canvas, multiple: false, type: Valkyrie::Types::ID
  property :member_of_collection_ids, multiple: true, required: false, type: Types::Strict::Array.member(Valkyrie::Types::ID)
  property :logical_structure, multiple: true, required: false, type: Types::Strict::Array.member(Structure), default: [Structure.new(label: "Logical", nodes: [])]
  property :state, multiple: false, required: true, default: BookWorkflow.aasm.initial_state.to_s
  property :read_groups, multiple: true, required: false
  property :workflow_note, multiple: true, required: false, default: []
  property :file_metadata, multiple: true, required: false, default: []
  # Virtual Attributes
  property :refresh_remote_metadata, virtual: true, multiple: false
  property :files, virtual: true, multiple: true, required: false
  property :pending_uploads, multiple: true, required: false
  # Necessary for SimpleForm to show the nested record.
  property :new_workflow_note_attributes, virtual: true

  validates_with StateValidator
  validates_with ViewingDirectionValidator
  validates_with ViewingHintValidator
  validate :source_metadata_identifier_or_title
  validate :source_metadata_identifier_valid
  validates :visibility, :rights_statement, presence: true

  def primary_terms
    [
      :title,
      :source_metadata_identifier,
      :rights_statement,
      :rights_note,
      :local_identifier,
      :holding_location,
      :pdf_type,
      :portion_note,
      :nav_date,
      :member_of_collection_ids,
      :append_id
    ]
  end

  def new_workflow_note_attributes=(attributes)
    return unless new_workflow_note.validate(attributes)
    new_workflow_note.sync
    workflow_note << new_workflow_note.model
  end

  # Default is set this way so that the WorkflowNoteChangeSet validations don't
  # show in the nested form.
  def new_workflow_note
    @new_workflow_note ||= DynamicChangeSet.new(WorkflowNote.new)
  end

  def visibility=(visibility)
    super.tap do |_result|
      case visibility
      when Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
        self.read_groups = [Hydra::AccessControls::AccessRight::PERMISSION_TEXT_VALUE_PUBLIC]
      when Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_AUTHENTICATED
        self.read_groups = [Hydra::AccessControls::AccessRight::PERMISSION_TEXT_VALUE_AUTHENTICATED]
      when Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
        self.read_groups = []
      end
    end
  end

  # Validate that either the source_metadata_identifier or the title is set.
  def source_metadata_identifier_or_title
    return if source_metadata_identifier.present? || Array.wrap(title).first.present?
    errors.add(:title, "You must provide a source metadata id or a title")
    errors.add(:source_metadata_identifier, "You must provide a source metadata id or a title")
  end

  def source_metadata_identifier_valid
    return unless apply_remote_metadata?
    return if RemoteRecord.retrieve(Array(source_metadata_identifier).first).success?
    errors.add(:source_metadata_identifier, "Error retrieving metadata")
  end

  def apply_remote_metadata?
    source_metadata_identifier.present? && (!persisted? || refresh_remote_metadata == "1")
  end

  def workflow
    workflow_class.new(state.first)
  end

  def workflow_class
    BookWorkflow
  end

  def state_changed?
    # conditional assignment makes this true if it has ever been true, to allow seeing the change after sync
    @state_changed ||= changed?(:state) && !old_state.nil? && old_state != new_state
  end

  def new_state
    Array.wrap(state).first
  end

  def old_state
    Array.wrap(model.state).first
  end
end
