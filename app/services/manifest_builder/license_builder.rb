# frozen_string_literal: true
class ManifestBuilder
  class LicenseBuilder
    attr_reader :resource

    ##
    # @param [Valhalla::Resource] resource the Resource being viewed
    def initialize(resource)
      @resource = RootNode.new(resource)
    end

    ##
    # Append the metadata to the IIIF Manifest
    # @param [IIIF::Presentation::Manifest] manifest the IIIF manifest being
    # @return [IIIF::Presentation::Manifest]
    def apply(manifest)
      manifest.license = license
      manifest
    end

    private

      def license
        statements = @resource.decorate.rights_statement.map(&:value)
        statements.empty? ? nil : statements.first
      rescue
        nil
      end
  end
end
