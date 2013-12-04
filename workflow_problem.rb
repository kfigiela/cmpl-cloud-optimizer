#!/usr/bin/env ruby

require 'bundler/setup'
require 'yaml'
require_relative 'cmpl'

module YAML
  def self.dump_file(data, filename)
    File.open(filename, 'w') do |out|
      YAML.dump(data, out)
    end
  end
end

def schema 
  {
      instances: {
        instance_price: Numeric,
        ccu: Numeric
      },
      providers: {
        provider_max_machines: Numeric,
        transfer_price_in: Numeric,
        transfer_price_out: Numeric,
        instances: DataGenerator::Tuple.new([:instances])
      },
      storages: {
        storages_transfer_price_in: Numeric,
        storages_transfer_price_out: Numeric
      },
      transfer_rate: DataGenerator::Vector.new([:storages, :providers]),
      request_price: Numeric,
      storage_local_rel: DataGenerator::Tuple.new([:storages, :providers]),
      tasks: {
        task_count: Numeric,
        exec_time: Numeric,
        data_size_in: Numeric,
        data_size_out: Numeric
      },
      layers: { 
        tasks: DataGenerator::Tuple.new([:tasks])
      },
      workflow_deadline: Numeric,
      storage: Symbol
  }
end

def run_optimization!(params)
  problem = Problem.new schema, debug: true

  infrastructure = YAML.load_file('infrastructure.yaml')
  workflow = YAML.load_file('workflow_1000.yaml')

  problem.params = infrastructure.merge(workflow).merge(params)

  result = problem.run!
  YAML.dump_file(result, "outs/#{params.values.join("_").downcase}.yaml")
  File.open("out.txt", 'a') do |out|
    out.puts "%s    %s" % [params.values.map{|v| "%20s" % [v] }.join("\t"), result.objective.value.inspect]
  end
  return result
end

# 
# problem.params["storage"] = "S3"
# 32.downto(1).each do |deadline|
#   run_optimization!("deadline" => i, "storage" => "CloudFiles")
#   
