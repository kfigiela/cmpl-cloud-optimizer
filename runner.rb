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
      workflow_deadline: Numeric
    }

problem = Problem.new schema, debug: true
problem.params = YAML.load_file('infrastructure.yaml')

result = problem.run!
pp result

binding.pry