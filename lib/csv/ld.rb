$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..')))
require 'json-ld'

module CSV
  ##
  # **`CSV::LD`** is an extension to the `JSON::LD` gem.
  #
  # @example Requiring the `CSV::LD` module
  #   require 'csv/ld'
  #
  # @example Transforming CSV to JSON-LD
  #   CSV::LD.open(filename, mapping_frame, options) do |expanded|
  #     JSON::LD::API.compact(jsonld, context, options) do |compacted|
  #       puts compacted.to_json
  #     end
  #   end
  #
  # @see https://www.w3.org/2013/csvw/wiki/CSV-LD
  #
  # @author [Gregg Kellogg](http://greggkellogg.net/)
  class LD
    # Map of header fields to column numbers
    # @return [Hash{String => Integer}]
    attr_reader :header_map

    # Context from mapping template
    # @return [JSON::LD::Context]
    attr_reader :context

    ##
    # Open a CSV using a path yield an expanded JSON-LD document.
    # Also, retrieve a mapping file via link header
    #
    # @param  [String, #to_s] filename
    # @param [String, #read, Hash, Array] mapping_frame
    #   The mapping frame used to transform the input document into JSON-LD.
    # @param  [Hash{Symbol => Object}] options
    #   any additional options (see {CSV::LD#initialize})
    # @yield jsonld
    # @yieldparam [Array<Hash>] jsonld
    #   The expanded JSON-LD document
    # @return [Array<Hash>]
    #   The expanded JSON-LD document
    def self.open(filename, options = {}, &block)
      doc_info = get_doc_info(filename, options)
      options[:mapping_frame] ||= doc_info[:mapping_frame]
      options[:row_sep] = "\t" if doc_info[:content_type] == "text/tsv"
      enum = CSV.enum_for(:foreach, filename, options)
      CSV::LD.new(enum, mapping_frame, options, &block)
    end

    ##
    # Transform a CSV file to expanded JSON-LD
    #
    # @param [#to_enum] input
    #   The CSV as an array or arrays, or an enumerable yielding each array of fields.
    # @param [String, #read, Hash, Array] mapping_frame
    #   The mapping frame used to transform the input document into JSON-LD.
    # @param  [Hash{Symbol => Object}] options
    #   any additional options (see {CSV::LD#initialize})
    # @yield jsonld
    # @yieldparam [Array<Hash>] jsonld
    #   The expanded JSON-LD document
    # @return [Array<Hash>]
    #   The expanded JSON-LD document
    # @option options [String, #to_s] :base
    #   The Base IRI to use when expanding the document. This overrides the value of `input` if it is a _IRI_. If not specified and `input` is not an _IRI_, the base IRI defaults to the current document IRI if in a browser context, or the empty string if there is no document context.
    #   If not specified, and a base IRI is found from `input`, options[:base] will be modified with this value.
    # @option options [Proc] :documentLoader
    #   The callback of the loader to be used to retrieve remote documents and mapping frames. If specified, it must be used to retrieve remote documents and mapping frames; otherwise, if not specified, the processor's built-in loader must be used. See {documentLoader} for the method signature.
    # @option options [Boolean] :useNativeTypes (false)
    #   If set to `true`, the JSON-LD processor will use native datatypes for expression xsd:integer, xsd:boolean, and xsd:double values, otherwise, it will use the expanded form.
    # @option options [Boolean] :rename_bnodes (true)
    #   Rename bnodes as part of expansion, or keep them the same.
    # @yield jsonld
    # @yieldparam [Array<Hash>] jsonld
    #   The expanded JSON-LD document
    # @return [Array<Hash>]
    #   The expanded JSON-LD document
    def initialize(input, mapping_frame, options = {})
      # input is an enumerator responding to #each.
      enum = input.to_enum
      header = enum.next

      # Read the first record from table as header.

      # If the first field of the header is @map, the second references a mapping frame; use this in place of any existing mapping frame. And initialize header from the next record.
      if header.first == '@map'
        # Use second column as mapping_frame
        mapping_frame = header[1]
        header = enum.next
      end

      # Construct header map as an index from each header field to its corresponding field index within each record.
      @header_map = {}
      header.each_with_index {|n, i| header_map[n] = i}

      # If the first field after of the first record after header is @map, the second field references a mappin frame; use this in place of any existing mapping frame and skip to the next record.
      if enum.peek[0] == '@map'
        mapping_frame = enum.peek[1]
        enum.next
      end

      # If mapping frame is empty, or is not a valid JSON-LD document in [compacted document form](http://www.w3.org/TR/json-ld/#compacted-document-form), the algorithm may not proceed.
      # Note: this could cause an implicit mapping frame to be created.

      # Initialize result as a new JSON-LD document with @context set from the mapping frame, and @graph referencing an empty array.
      # XXX perhaps use a keyword form of @graph from the context.
      result = {}

      # Create template as a copy of mapping_frame without @context
      template = mapping_frame.dup
      template.delete('@context')

      # Extract the @context from the mapping frame using _Context Processing Algorithm from [[JSON-LD-API]].
      JSON::LD.new(mapping_frame, options) do |api|
        @context = api.context
        result['@context'] = context.serialize
        result['@graph'] = []

        # For each record from the table, invoke the _Map Record_ algorithm, passing record, template, and the value of @graph in result
        enum.each do |record|
          map_record(record, template, options) do |r|
            result['@graph'] << r
          end
        end
      end

      # Return result as the complete mapping of the table to JSON-LD
      result
    end

    ##
    # Map Record
    # Takes an input record and template
    #
    # @param [Array<String>] record
    # @param [Hash] template
    # @param  [Hash{Symbol => Object}] options
    #   any additional options
    # @option options [Boolean] split_id
    # @yield result
    # @yieldparam [Hash] result
    def map_record(record, template, options = {split_id: true}, &block)
      # If element is an array

      # Otherwise, element is a JSON object.
      # Initialize result as an empty JSON object
      result = {}

      # If the split id flag is true, and result has a key whos term definition value in context is @id and container is @set and header_map contains an entry for the associated term definition
      if options[:split_id] &&
        (term = context.term_definitions.detect {|td| td.id == '@id' && td.container_mapping == '@set'}) &&
        header_map.has_key?(term.term)
        # Set field to the value from result associated with the term definition
        field = record[header_map[term.term]].to_s

        # For each sub-record from field found by splitting the value on the intra-record term separator
        field.split(',').map(&:trim).each do |f|
          # Create a copy of record with the field associated with the term definition replaced by sub-record.
          r = record.dup
          r[header_map[term.term]] = f

          # Invoke this algorithm recursively passing the copy of record, template, header_map, context and setting the split_id flag to false
          map_record(r, template, options.merge({split_id: false}), &block)
        end
        return
      end

      # Otherwise, for each key and value in template
      template.each do |key, value|
        # If key is a pattern, replace key with the result of substituting each field reference with associated values from record.
        if is_pattern(key, header_map)
          key = apply_pattern(key, header_map)
          # XXX make sure key is either a term in context or a valid IRI
        end

        # XXX consider array, scalar, object or string results
      end
    end

    ##
    # Is a value a pattern containing "{field reference}" where _field reference_ is a field in the header
    # @param [String] pattern
    # @return [Boolean]
    def is_pattern(pattern)
      header_map.keys.any? {|fr| pattern.include?("{#{fr}}")}
    end

    ##
    # Apply the a record to a pattern.
    #
    # @param [String] pattern
    # @return [String] returns the result of substituting each field reference with associated values from record
    def apply_pattern(pattern, record)
      header_map.each do |fr, i|
        pattern.gsub("{#{fr}}", record[i])
      end
      pattern
    end

    ##
    # Return information about a remote document. This typically is done through an HTTP HEAD request on the document IRI.
    #
    # @param [RDF::URI, String] url
    # @param [Hash<Symbol => Object>] options
    # @return [Hash] including :base, :content_type and :mapping_uri
    def self.get_doc_info(url, options = {})
      result = {base: url.to_s}
      options[:headers] ||= {"Accept" => "text/csv, text/tsv"}

      url = url.to_s[5..-1] if url.to_s.start_with?("file:")
      case url.to_s
      when /^http/
        parsed_url = ::URI.parse(url.to_s)
        until remote_document do
          Net::HTTP::start(parsed_url.host, parsed_url.port) do |http|
            http.request_head(parsed_url.request_uri, options[:headers]) do |response|
              case response
              when Net::HTTPSuccess
                # found object
                content_type, ct_param = response.content_type.to_s.downcase.split(";")
                result[:content_type] = content_type
                result[:base] = parsed_url.to_s

                # If the input has been retrieved, the response has an HTTP Link Header [RFC5988] using the http://www.w3.org/ns/csv-ld#mapping link relation and a content type of text/csv or any media type with a +csv suffix as defined in [RFC6839], set the mapping frame by parsing the resource referenced in the HTTP Link Header as JSON-LD document.
                links = response["link"].to_s.
                  split(",").
                  map(&:strip).
                  select {|h| h =~ %r{rel=\"http://www.w3.org/ns/csv-ld#mapping\"}}
                case links.length
                when 0  then #nothing to do
                when 1
                  result[:mapping_url] =  links.first.match(/<([^>]*)>/) && $1
                else
                  raise CSV::LD::CsvLdError::MultipleMappingLinkHeaders,
                    "expected at most 1 Link header with rel=http://www.w3.org/ns/csv-ld#mapping, got #{links.length}"
                end

                return block_given? ? yield(result) : result
              when Net::HTTPRedirection
                # Follow redirection
                parsed_url = ::URI.parse(response["Location"])
              else
                raise CSV::LD::CsvLdError::LoadingDocumentFailed, "<#{parsed_url}>: #{response.msg}(#{response.code})"
              end
            end
          end
        end
      else
        result[:content_type] = case url.to_s
        when /\.tsv/ then "text/tsv"
        when /\.csv/ then "text/csv"
        end
        return block_given? ? yield(result) : result
      end
    end
  end
end
