#!/usr/bin/env ruby

load 'controller.rb'

controller = Controller.new('timetable.json')
controller.start
