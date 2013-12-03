#!/usr/bin/env ruby

require 'bundler/setup'
require_relative 'cmpl'
require 'pp'
require 'yaml'

schema = {
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

problem = Problem.new schema, debug: true

infrastructure = YAML.load_file('infrastructure.yaml')
workflow = YAML.load_file('workflow.yaml')

problem.params = infrastructure.merge(workflow)

problem.params["storage"] = "S3"
# result = problem.run!
# pp result
2.downto(1).each do |deadline|
  problem.params["workflow_deadline"] = deadline
  result = problem.run!
  File.open("outs/#{deadline}.yaml", 'w' ) do |out|
    YAML.dump(result, out)
  end
  File.open("out.txt", 'a') do |out|
    out.puts "%3d    %s" % [deadline, result.objective.value.inspect]
  end
end