
module Cypress
class ScoopAndFilter
    def initialize(measures)
        @relevant_codes = codes_in_measures(measures)
        @hqmf_oids_for_measures = []
        @hqmf_oids_for_measures = get_all_hqmf_oids_definition_and_status(measures)


    end

    # return an array of all of the concepts in all of the valueset for the measure
    def codes_in_measures(measures)
        valuesets = []
        code_list = []
        measures.each do |measure|
            measure['value_set_oid_version_objects'].each do |valueset|
                valuesets.concat(HealthDataStandards::SVS::ValueSet.where(oid: valueset.oid, version: valueset.version).to_a)
            end
        end
        valuesets.each do |valueset|
          code_list.concat(valueset.concepts)
        end
        code_list.map { |cl| { code: cl.code, codeSystem: cl.code_system_name } }
    end

    def get_all_hqmf_oids_definition_and_status(measures)
        all_hqmf_oids = []
        measures.each do |measure|
            measure.source_data_criteria.each do |key, criteria|
                all_hqmf_oids.concat(get_all_hqmf_oids(criteria['definition'], criteria['status']))
            end
        end
        all_hqmf_oids.uniq!
    end

    def get_all_hqmf_oids(definition, status)
        hqmf_oids =[]
        [{version: 'r1', negation: false},{version: 'r1', negation: true},{version: 'r2', negation: false},{version: 'r2cql', negation: false}].each do |obj|
        hqmf_oids << HQMF::DataCriteria.template_id_for_definition(definition, status, obj.negation, obj.version)
        end 
        hqmf_oids
    end

    def scoop_and_filter(patient)
        demographic_oids = ['2.16.840.1.113883.10.20.28.3.55', '2.16.840.1.113883.10.20.28.3.59', '2.16.840.1.113883.10.20.28.3.56']

        demographic_criteria = patient.dataElements.where(:hqmfOid => { '$in' => demographic_oids })
        patient.dataElements.keep_if { |data_element| @hqmf_oids_for_measures.include? data_element.hqmfOid }

        patient.dataElements.each do |data_element|
            # keep if data_element code and codesystem is in one of the relevant_codes
            data_element.dataElementCodes.keep_if { |data_element_code| @relevant_codes.include?(:code=>data_element_code.code, :codeSystem=>data_element_code.codeSystem) }
        end
        
        # keep data element if codes is not empty
        patient.dataElements.keep_if { |data_element| !data_element.dataElementCodes.blank? }

        patient.dataElements.concat(demographic_criteria)

        patient
    end

end
end