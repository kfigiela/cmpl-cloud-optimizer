require 'nori'
require 'tempfile'
require 'pry'
require 'active_support/hash_with_indifferent_access'
require 'pp'

module DataGenerator
  Tuple = Struct.new(:sets)
  Vector = Struct.new(:sets)
  class Set; end
  
  def DataGenerator.validate_schema(schema)
    schema.each do |k,v|
      if v.is_a? Class
        unless [Numeric, Range, Set].include? v
          raise "Bad schema for key #{k}: #{v}"
        end
      elsif v.is_a? Hash
        v.each do |param,type|
          unless type == Numeric or type.is_a? Tuple
            raise "Bad schema for key #{k}.#{param}: #{type}"
          end
        end
      elsif v.is_a? Tuple or v.is_a? Vector
        # OK
      else
        raise "Bad schema for key #{k}: #{v}"
      end
    end
  end
  
  
  def DataGenerator.generate_data(schema, params)
    output = {sets: [], params: []}
    flat_params = []
    sets = []
    relations = []
    flat_relations = {}
    flat_vectors = {}
    
    schema.each do |k,v|
      if v.is_a? Class
        if v == Numeric
          flat_params << k
        elsif v == Range
          sets << k
        elsif v == Set
          sets << k
        else
          raise "Bad schema for key #{k}: #{v} expected Numeric or Set"
        end
      elsif v.is_a? Tuple
        flat_relations[k] = v
      elsif v.is_a? Vector
        flat_vectors[k] = v
      elsif v.is_a? Hash
        sets << k
      end
    end
    
    flat_params.each do |param|
      output[:params] << "%#{param} < #{params[param.to_s]} >"
    end    

    flat_relations.each do |param, relation|
      entries = params[param.to_s].map {|items| items.join " "}
      output[:params] << "%#{param.to_s} set[#{relation.sets.length}] <\n  #{entries.join("\n  ")}\n>"
    end
    
    flat_vectors.each do |param, vector|
      entries = params[param.to_s].map {|items| items.join " "}
      output[:params] << "%#{param.to_s}[#{vector.sets.join(',')}] indices <\n  #{entries.join("\n  ")}\n>"
    end    
    
    sets.each do |set|
      if schema[set].is_a? Hash
        output[:sets] << "%#{set} set < #{params[set.to_s].keys.join(' ')} >"
        schema[set].each do |param, type|
          if type == Numeric
            # raise "Parameter #{param} for #{set} not found!" unless @params[set.to_s][param.to_s]
            output[:params] << "%#{param}[#{set}] < #{params[set.to_s].map{|k,v| v.fetch(param.to_s, Float::NAN)}.join(' ')} >"
          elsif type.is_a? Tuple
            entries = params[set.to_s].map{|k,v| 
              v.fetch(param.to_s, []).map { |item|
                [k, item].join(" ")
              }
            }
            output[:params] << "%#{set}_#{param} set[#{type.sets.length + 1}] <\n  #{entries.join("\n  ")}\n>"
          else
            raise "Bad data!"
          end
        end
      elsif schema[set] == Range
        output[:sets] << "%#{set} set < #{params[set.to_s].min}..#{params[set.to_s].max} >"
      elsif schema[set] == Set
        output[:sets] << "%#{set} set < #{params[set.to_s].join(' ')} >"
      end
    end
    
    
    [output[:sets] + output[:params]].join("\n").strip
  end
end

class Problem
  Solution = Struct.new(:objective, :vars) do
    def method_missing(m, *args, &block) 
      self.vars[m.to_s]
    end
  end
  Objective = Struct.new(:name, :value, :status)
  
  class VarHash < Hash
    def[](*args)      
      fetch(args.map(&:to_s))
    rescue KeyError
      puts "getting variable of unknown index #{args.inspect}, falling back with zero"
      0
    end
  end
  
  @@nori = Nori.new(convert_tags_to: ->(tag){ tag.snakecase.to_sym })
  
  attr_accessor :params
  
  def initialize(schema, model_file='workflow.cmpl', cmpl_opts = ['-s'])
    @model_file = model_file
    @cmpl_opts = cmpl_opts
    @schema = schema
    @params = {}

    DataGenerator.validate_schema(@schema)
  end
  
  def generate_data
    DataGenerator.generate_data(@schema, @params)
  end
  
  def Problem.parse_results(xml)
    hash = @@nori.parse(xml)
    data = hash[:cmpl_solutions]
    
    vars = Hash.new {|h,k| h[k] = VarHash.new { } } 
    
    data[:solution][:variables][:variable].map do |var|
      name_parts = var[:@name].match /^(?<name>[a-zA-Z_][a-zA-Z0-9_]*)(?:\[(?<indexes>.*?)\])?$/
      name = name_parts[:name].snakecase
      value = case var[:@type]
        when "B", "I"
          var[:@activity].to_i
        when "C"
          var[:@activity].to_f
        else
          var[:@activity]
      end
      
      if name_parts[:indexes].nil?
        vars[name] = value
      else
        indexes = name_parts[:indexes].split(',')
        vars[name][indexes] = value
      end      
    end
    
    objective = Objective.new(data[:general][:objective_name], data[:solution][:@value].to_f, data[:solution][:@status])
    Solution.new(objective,vars)
  end

  def run!
    data = self.generate_data        
#    tmpfile = Dir::Tmpname.make_tmpname(['cmpl_',''], nil)
    tmpfile = "test"
    solution_file = tmpfile + ".sol"
    data_file = tmpfile + ".cdat"

    IO.write(data_file, data)

    args = ['cmpl', @model_file, '-solution', solution_file, '-data', data_file]
    args += @cmpl_opts

    cmpl_output = nil
    process = IO.popen(args, "r") do |cmpl|
      cmpl_output = cmpl.read
    end
    solution_xml = IO.read(solution_file)
    [Problem.parse_results(solution_xml), cmpl_output]
  end

end