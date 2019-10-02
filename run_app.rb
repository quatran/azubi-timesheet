#!/usr/bin/env ruby

load 'controller.rb'

controller = Controller.new('timesheet.json')
controller.start
