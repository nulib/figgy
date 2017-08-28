# frozen_string_literal: true
require 'rails_helper'

RSpec.describe PlumImporter do
  subject(:importer) { described_class.new(id: id) }
  let(:id) { "ps7529f137" }
  before do
    import_plum_record(id)
    stub_bibdata(bib_id: "10068705")
  end
  it "imports a Scanned Resource" do
    allow(FileUtils).to receive(:mv).and_call_original
    output = importer.import!
    expect(output.id).not_to be_blank
    expect(output.depositor).to eq ["rmunoz"]
    expect(output.source_metadata_identifier).to eq ["10068705"]
    expect(output.title[0].to_s).to eq "Catalog, McLoughlin Bros., Inc., 1943 : children's reading, activity and novelty books"
    expect(output.member_ids.length).to eq 2

    members = query_service.find_members(resource: output).to_a
    expect(members[1].replaces).to eq ["p7w62j794r"]
    expect(members[0].replaces).to eq ["p73669555b"]
    expect(members[0].original_file.width).to eq ["4686"]
    expect(members[0].original_file.height).to eq ["7200"]
    expect(members[0].derivative_file).not_to be_blank
    expect(members[0].derivative_file.file_identifiers[0].to_s).to include("/derivatives/")
    expect(FileUtils).not_to have_received(:mv)

    # Ensure logical order works.
    expect(output.logical_structure[0]["label"]).to eq ["Logical"]
    expect(output.logical_structure[0].nodes[0].label).to eq ["Chapter 1"]
    expect(output.logical_structure[0].nodes[1].label).to eq ["Chapter 2"]
    expect(output.logical_structure[0].nodes[0].nodes[0].proxy).to eq [members[1].id]
  end

  def query_service
    Valkyrie.config.metadata_adapter.query_service
  end
end
