module Cypress
  class Cat3Calculator
    attr_accessor :correlation_id, :measure, :bundle, :mre, :qr

    # TODO: R2P: use patient model throughout
    def initialize(measure_ids, bundle, effective_date_override = nil)
      @correlation_id = BSON::ObjectId.new
      filter = { :hqmf_id.in => measure_ids, :bundle_id => bundle.id }
      @measure = HealthDataStandards::CQM::Measure.top_level.where(filter).first
      @bundle = bundle
      # The effective date can be overwritten with a date other than the one in the bundle
      @effective_date = effective_date_override || bundle.effective_date
    end

    # Generates the QRDA/CDA header, using the header info above
    def generate_header(provider = nil)
      cda_header = { identifier: { root: 'CypressRoot', extension: 'CypressExtension' },
                     authors:       [{ ids: [{ root: 'authorRoot', extension: 'authorExtension' }],
                                       device: { name: 'deviceName', model: 'deviceModel' },
                                       addresses: [], telecoms: [], time: nil,
                                       organization: { ids: [{ root: 'authorsOrganizationRoot', extension: 'authorsOrganizationExt' }], name: '' } }],
                     custodian: { ids: [{ root: 'custodianRoot', extension: 'custodianExt' }],
                                  person: { given: '', family: '' }, organization: { ids: [{ root: 'custodianOrganizationRoot',
                                                                                             extension: 'custodianOrganizationExt' }], name: '' } },
                     legal_authenticator: { ids: [{ root: 'legalAuthenticatorRoot', extension: 'legalAuthenticatorExt' }], addresses: [],
                                            telecoms: [], time: nil,
                                            person: { given: nil, family: nil },
                                            organization: { ids: [{ root: 'legalAuthenticatorOrgRoot', extension: 'legalAuthenticatorOrgExt' }],
                                                            name: '' } } }

      header = Qrda::Header.new(cda_header)

      header.identifier.root = UUID.generate
      header.authors.each { |a| a.time = Time.current }
      header.legal_authenticator.time = Time.current
      header.performers << provider

      header
    end

    def generate_oid_dictionary
      valuesets = @bundle.value_sets.in(oid: @measure.oids)
      js = {}
      valuesets.each do |vs|
        js[vs.oid] = cached_value(vs)
      end
      js.to_json
    end

    def cached_value(vs)
      @loaded_valuesets ||= {}
      return @loaded_valuesets[vs.oid] if @loaded_valuesets[vs.oid]
      js = {}
      vs.concepts.each do |con|
        name = con.code_system_name
        js[name] ||= []
        js[name] << con.code.downcase unless js[name].index(con.code.downcase)
      end
      @loaded_valuesets[vs.oid] = js
      js
    end

    def import_cat1_zip(zip)
      Zip::ZipFile.open(zip.path) do |zip_file|
        zip_file.entries.each do |entry|
          doc = zip_file.read(entry)
          import_cat1_file(doc)
        end
      end
    end

    def import_cat1_file(doc)
      doc = Nokogiri::XML(doc)
      doc.root.add_namespace_definition('cda', 'urn:hl7-org:v3')
      doc.root.add_namespace_definition('sdtc', 'urn:hl7-org:sdtc')
      record = HealthDataStandards::Import::Cat1::PatientImporter.instance.parse_cat1(doc)
      record.test_id = @correlation_id
      record.medical_record_number = rand(1_000_000_000_000_000)
      record.save
    end

    def generate_cat3
      ex_opts = { test_id: @correlation_id, effective_date: @effective_date,
                  enable_logging: false, enable_rationale: false }
      filter = { hqmf_id: @measure.hqmf_id }
      HealthDataStandards::CQM::Measure.where(filter).each do |measure|
        qr = QME::QualityReport.find_or_create(measure.hqmf_id, measure.sub_id, ex_opts)
        qr.calculate({ 'prefilter' => { test_id: @correlation_id }, oid_dictionary: generate_oid_dictionary, bundle_id: @bundle.id }, false)
      end
      exporter = HealthDataStandards::Export::Cat3.new(@bundle.qrda3_version)
      end_date = Time.at(@effective_date.to_i).in_time_zone
      xml = exporter.export(HealthDataStandards::CQM::Measure.top_level.where(hqmf_id: @measure.hqmf_id, bundle_id: @bundle.id),
                            generate_header,
                            @effective_date.to_i,
                            end_date.years_ago(1) + 1,
                            end_date,
                            @bundle.qrda3_version,
                            nil,
                            @correlation_id)
      clean_up
      xml
    end

    def generate_cat3_for_test(correlation_id)
      exporter = HealthDataStandards::Export::Cat3.new(@bundle.qrda3_version)
      end_date = Time.at(@effective_date.to_i).in_time_zone
      xml = exporter.export(HealthDataStandards::CQM::Measure.top_level.where(hqmf_id: @measure.hqmf_id, bundle_id: @bundle.id),
                            generate_header,
                            @effective_date.to_i,
                            end_date.years_ago(1) + 1,
                            end_date,
                            @bundle.qrda3_version,
                            nil,
                            correlation_id)
      xml
    end

    def clean_up
      QME::PatientCache.where(test_id: @correlation_id).destroy_all
      HealthDataStandards::CQM::QueryCache.where(test_id: @correlation_id).destroy_all
    end
  end
end
