#!/usr/bin/env ruby

require_relative 'workflow_problem'

50.downto(1).each do |deadline|
run_optimization!("workflow_deadline" => deadline, "storage" => "S3")
run_optimization!("workflow_deadline" => deadline, "storage" => "CloudFiles")
end