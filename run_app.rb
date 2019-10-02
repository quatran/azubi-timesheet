#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'json'
require 'date'
require 'axlsx'
require 'fileutils'

# Controller class of the MVC-Model
class Controller
  def initialize(json_file_name)
    @json_file_name = json_file_name
    @model = Model.new(json_file_name)
    @hash_array = @model.create_json_hash
    @console_view = ViewInConsole.new
    @console_view.clear_console
  end

  def start
    loop do
      chosen_case = check_record_count ? @console_view.start_view : add_record
      case chosen_case
      when 'exit'
        @console_view.clear_console
        @console_view.goodbye
        break
      when 'add'
        append add_new_record
      when 'edit'
        date = @console_view.date_input
        if record_exists? date
          (edit existing_record date)
        else
          @console_view.record_doesnt_exist
          add_record
        end
      when 'count', 'printnum', 'printnumber'
        print_record_count
      when 'printone', 'printonerecord'
        date = @console_view.date_input
          (record_exists? date) ? (print_full_record existing_record date) : (@console_view.record_doesnt_exist)
      when 'printall', 'printallrecords'
        @console_view.print_all_records @hash_array
      when 'delete'
        date = @console_view.date_input
          (record_exists? date) ? (delete_record_with date) : (@console_view.record_doesnt_exist)
      when 'sort'
        sort_array
      when 'export'
        sort_array
        export_sheet
      when 'open', 'libreoffice'
        open_timesheet
      when 'help', 'clear'
        @console_view.clear_console
        @console_view.available_commands 0
      else
        @console_view.clear_console
        @console_view.available_commands 0
      end
      save_array
    end
  end

  def open_timesheet
    system('xdg-open export/timesheet.xlsx') if @console_view.answer_to("\n Open timesheet?(yes/no) ")
  end

  def sort_array
    @model.sort_by_date @hash_array
  end

  def save_array
    @model.make_pretty_and_save @hash_array
  end

  def append(record)
    @model.append_this_to_that record, @hash_array unless record.nil?
  end

  def add_record
    @console_view.add_new_record? ? (append add_new_record) : 'exit'
  end

  def add_new_record
    date = @console_view.date_input
    unless record_exists? date
      return @console_view.answer_special ? (create_special_record date) : (create_normal_record date)
    end

    @console_view.record_exists
  end

  def create_special_record(date)
    special_case = @console_view.special_input
    return if special_case == 'exit'

    @model.create_special_json_record(date, special_case)
  end

  def create_normal_record(date)
    record_data = @console_view.new_record_input
    @model.create_pretty_json_record(record_data.unshift(date))
  end

  def record_exists?(date)
    @hash_array.any? { |hash| hash['date'].include?(date) }
  end

  def existing_record(date)
    @hash_array.select { |hash| hash['date'].include?(date) }.first
  end

  def delete_record_with(value)
    print_full_record(existing_record(value))
    @model.delete_record_with value, @hash_array if @console_view.sure?
  end

  def check_record_count
    num = @hash_array.count
    if num <= 0
      print_record_count
      return false
    end
    true
  end

  def edit(record)
    print_full_record record
    date = record['date']
    if @console_view.answer_special
      new_record = create_special_record date
      record.replace(new_record) unless new_record.nil?
    elsif record.key? 'special'
      record.replace(create_normal_record(date))
    else
      loop do
        key, value = @console_view.key_value_input
        break if (key == 'back') || (key == 'exit')

        if key == 'date' && (record_exists? value)
          @console_view.record_exists
        else
          record[key] = value
        end
      end
    end
  end

  def print_record_count
    num = @hash_array.count
    @console_view.print_record_count num, @json_file_name
  end

  def print_full_record(record)
    clone = make_complete record
    @console_view.print_record clone
  end

  def make_complete(record)
    clone = record.clone

    break_total = calculate_break_total record
    day_total = calculate_day_total record, break_total
    work_quota = calculate_work_quota day_total

    clone['break_total'] = break_total.to_s
    clone['day_total'] = day_total.to_s
    sign = work_quota.negative? ? '' : '+'
    clone['work_quota'] = "#{sign}#{work_quota}"
    if friday? record['date']
      record_index = @hash_array.index(record)
      week_total = calculate_week_total(record_index)
      clone['week_total'] = week_total.to_s
    end
    clone
  end

  def hour_from(string)
    DateTime.strptime(string, '%H:%M').hour
  rescue ArgumentError
    0
  end

  def min_from(string)
    DateTime.strptime(string, '%H:%M').min
  rescue ArgumentError
    0
  end

  def difference_between startTime, endTime
    hour = hour_from(endTime) - hour_from(startTime)
    min = min_from(endTime) - min_from(startTime)
    return (hour*60 + min)/60.to_f
  end

  def calculate_break_total(record)
    0.0 if record.key? 'special'
    break_start = record['break_start']
    break_end = record['break_end']
    difference_between(break_start, break_end)
  end

  def calculate_day_total(record, break_total)
    return 8.0 if record.key? 'special'

    start_day = record['start_day']
    end_day = record['end_day']
    day_total = difference_between(start_day, end_day) - break_total
    day_total
  end

  def calculate_work_quota(day_total)
    day_total.to_f - 8
  end

  def friday?(string)
    date = Date.parse string
    date.friday?
  end

  def day_german(string)
    date = Date.parse string
    return 'Montag' if date.monday?
    return 'Dienstag' if date.tuesday?
    return 'Mittwoch' if date.wednesday?
    return 'Donnerstag' if date.thursday?
    return 'Freitag' if date.friday?
  end

  def calculate_week_total(record_index)
    week_total = 0
    5.times do
      if record_index >= 0
        break_total = calculate_break_total @hash_array[record_index]
        day_total = calculate_day_total @hash_array[record_index], break_total
        week_total += day_total
        record_index -= 1
      end
    end
    week_total
  end

  def month_german(date)
    months_german = %w[Dezember Januar Februar März April Mai Juni Juli August
                       September Oktober November Dezember]
    months_german[date.to_i]
  end

  def add_image_from(path, sheet)
    img = File.expand_path(path, __FILE__)
    sheet.add_image(image_src: img, noSelect: true, noMove: true) do |image|
      image.width = 261
      image.height = 118
    end
  end

  def weekdays_count(date)
    d1 = Date.new(date.year, date.month, 1)
    d2 = Date.new(date.year, date.month, -1)
    wdays = [0, 6]
    weekdays = (d1..d2).reject { |day| wdays.include? day.wday }
    weekdays.count * 8
  end

  def add_beginning_rows_to(sheet, big_bold_style)
    add_image_from '../suse_logo.png', sheet
    5.times { sheet.add_row [] }

    sheet.add_row ['', 'Stundenzettel'], style: [0, big_bold_style]
    sheet.merge_cells('B6:K6')
    sheet.add_row []
  end

  def export_sheet
    date = @hash_array[0]['date']
    date = Date.parse(date)
    year = date.year
    name, carryover = @console_view.input_export_data
    month_ger = month_german(date.month)
    total_of_hours = weekdays_count(date)
    timesheet = create_sheet(name, month_ger, year, carryover, total_of_hours)

    FileUtils.mkdir_p 'export' unless File.exist? 'export'
    # filename = `echo $(date +"%_Y_%_m")_${USER}_timetable.xlsx`.chomp
    filename = 'timesheet.xlsx'
    timesheet.serialize("export/#{filename}")
  end

  def create_sheet(name, month_ger, year, carryover, total_of_hours)
    axlsx_package = Axlsx::Package.new
    wb = axlsx_package.workbook
    setup = { fit_to_width: 1, fit_to_height: 1, orientation: :portrait,
              paper_height: '297mm', paper_width: '210mm' }
    options = { grid_lines: false}
    wb.add_worksheet(name: 'SUSE Timesheet', page_setup: setup, print_options: options) do |sheet|
      center = { horizontal: :center, vertical: :center }
      default_cell = { alignment: center, sz: 10 }
      hair_border =  { style: :hair, color: '00' }
      border_cell = default_cell.merge(border: hair_border)

      big_bold_style = sheet.styles.add_style sz: 16, b: true, alignment: center

      def_style = sheet.styles.add_style default_cell
      def_b_style = sheet.styles.add_style default_cell.merge(b: true)

      cell_style = sheet.styles.add_style border_cell
      cell_b_style = sheet.styles.add_style border_cell.merge(b: true)

      cell_green_style = sheet.styles.add_style border_cell.merge(bg_color: '7DC148')
      cell_b_green_style = sheet.styles.add_style border_cell.merge(
        b: true, bg_color: '7DC148'
      )

      row8_style = [0, 0, cell_b_style, cell_b_style, 0, 0, cell_b_style]
      row9_style = [0, 0, cell_b_style, cell_b_style, 0, 0, 0, cell_b_style, 0,
                    cell_b_green_style, cell_b_green_style]
      row11_style = [
        0, 0, cell_b_style, cell_b_style, cell_b_style, cell_b_style,
        cell_b_style, cell_b_style, cell_b_style, cell_b_style, cell_b_style,
        cell_b_style
      ]

      record_style = [
        0, cell_style, cell_style, cell_green_style, cell_green_style,
        cell_green_style, cell_green_style, cell_style, cell_style, cell_style,
        cell_style, cell_style, 0
      ]
      carryover_style = [0, 0, 0, 0, 0, 0, 0, cell_b_style, 0, cell_style,
                         cell_style]
      soll_style = [0, 0, def_b_style, def_style, 0, 0, 0, def_b_style,
                    def_style]

      add_beginning_rows_to sheet, big_bold_style

      sheet.add_row ['', '', 'Name:', name, '', '', ''], style: row8_style
      sheet.merge_cells('D8:G8')

      sheet.add_row [
        '', '', 'Monat:', month_ger + " #{year}", '', '', '', 'Stundenübertrag',
        '', carryover, ''
      ], style: row9_style
      sheet.merge_cells('D9:G9')
      sheet.merge_cells('H9:I9')
      sheet.merge_cells('J9:K9')
      sheet.add_row []

      sheet.add_row [
        '', '', 'Datum', 'Kommt', 'Geht', 'P-Beginn', 'P-Ende', 'Pause', 'AZ',
        'GES-Stunden', '', 'Kommentar         ' # white space makes cell larger
      ], style: row11_style
      sheet.merge_cells('J11:K11')
      sheet.add_row []

      worked_hours = 0
      @hash_array.each do |record|
        day = day_german record['date']
        clone = make_complete record
        sheet.add_row [
          '', "#{day} ", record['date'], clone['start_day'], clone['end_day'],
          clone['break_start'], clone['break_end'], clone['break_total'],
          clone['day_total'], clone['work_quota'], clone['week_total'],
          clone['comment'], ''
        ], style: record_style
        worked_hours += clone['day_total'].to_f
      end

      sheet.add_row []
      sheet.add_row [
        '', '', '', '', '', '', '', 'Stundenübertrag', '',
        (worked_hours - total_of_hours) + carryover, ''
      ], style: carryover_style
      sheet.merge_cells(
        "H#{sheet.rows.last.index + 1}:I#{sheet.rows.last.index + 1}"
      )
      sheet.merge_cells(
        "J#{sheet.rows.last.index + 1}:K#{sheet.rows.last.index + 1}"
      )
      3.times { sheet.add_row [] }

      sheet.add_row [
        '', '', 'Soll:', total_of_hours, '', '', '', 'Gesamt:', worked_hours
      ], style: soll_style
      2.times { sheet.add_row [] }

      sheet.add_row [
        '', '', 'Unterschrift Auszubildender', '', '', '',
        'Unterschrift Betreuer', '', '', '', 'Unterschrift Ausbilder'
      ]

      sheet.add_row []
      sheet.add_row [
        '', '', '____________________', '', '', '', '____________________', '',
        '', '', '____________________'
      ]
      sheet.column_widths nil, 10, 10, 8, 8, 8, 8, 8, 8, 8, 8, 22, nil
    end
    axlsx_package
  end
end

# Model class of the MVC-Model
class Model
  attr_accessor :file_name
  def initialize(file_name)
    @file_name = file_name
  end

  def create_json_hash
    parse_json_file read_file file_name
  end

  def parse_json_file(file)
    file.empty? ? [] : (JSON.parse file)
  end

  def pretty_generate(json_array)
    JSON.pretty_generate json_array
  end

  def create_pretty_json_record(record_data)
    date, start_day, end_day, break_start, break_end, comment = record_data
    {
      'date' => date,
      'start_day' => start_day,
      'end_day' => end_day,
      'break_start' => break_start,
      'break_end' => break_end,
      'comment' => comment
    }
  end

  def create_special_json_record(date, special_case)
    record_data = date, '', '', '', '', special_case
    record = create_pretty_json_record(record_data)
    record['special'] = 'true'
    record
  end

  def extract_date_from(record)
    Date.parse record['date']
  end

  def read_file(file_name)
    File.exist?(file_name) ? File.read(file_name) : File.read(File.new(file_name, "w"))
  end

  def append_this_to_that(this, that)
    that << this
  end

  def make_pretty_and_save(array)
    array = pretty_generate(array)
    File.open(file_name, 'w') do |line|
      line.puts(array)
    end
  end

  def delete_record_with(value, array)
    array.delete_if { |record| record['date'] == value}
  end

  def sort_by_date(array)
    array.sort_by! { |record| (extract_date_from record) }
  end

  # unused CSV methods
  # def read_csv_file file
  #   return CSV.read(file, col_sep: '|', headers: true)
  # end
  # def save_array_to_file(array, file)
  #   CSV.open(file, 'w') do |csvObj|
  #     array.each do |row|
  #       csvObj << row
  #     end
  #   end
  # end
end

# View  class of the MVC-Model
class ViewInConsole
  def start_view
    print "\n\tAZUBI Timesheet\n What would you like to do? "
    $stdin.gets.chomp.downcase
  end

  def new_record_input
    [
      start_day_input, end_day_input, break_start_input,
      break_end_input, comment_input
    ]
  end

  def key_value_input
    loop do
      available_commands 2
      key = $stdin.gets.chomp.downcase
      case key
      when 'back', 'exit'
        return 'back', ''
      when 'date'
        return 'date', date_input
      when 'startday', 'start_day'
        return 'start_day', start_day_input
      when 'endday', 'end_day'
        return 'end_day', end_day_input
      when 'breakstart', 'break_start'
        return 'break_start', break_start_input
      when 'breakend', 'break_end'
        return 'break_end', break_end_input
      when 'comment'
        return 'comment', comment_input
      end
    end
  end

  def date_input
    valid_date_input 'Date(dd.mm.yyyy): '
  end

  def start_day_input
    valid_time_input 'Came to work at(hh:mm): '
  end

  def end_day_input
    valid_time_input 'Left work at: '
  end

  def break_start_input
    valid_time_input 'Went for a break at: '
  end

  def break_end_input
    valid_time_input 'Came back from break at: '
  end

  def comment_input
    print 'Comment: '
    $stdin.gets.chomp
  end

  def input_export_data
    print 'Name:'
    name = $stdin.gets.chomp

    begin
      print 'Working hours carryover(Stundenübertrag):'
      carryover = $stdin.gets.chomp
    end while !numeric? carryover

    [name, carryover.to_f]
  end

  def answer_to(question)
    loop do
      print question
      answer = $stdin.gets.chomp.downcase
      return true if answer.start_with?('y')
      return false if answer.start_with?('n')
    end
  end

  def answer_special
    answer_to 'Is it a special day?(Y/N): '
  end

  def sure?
    answer_to 'Are you sure?(Y/N): '
  end

  def add_new_record?
    answer_to 'Add a new Record?(Y/N): '
  end

  def special_input
    puts 'Type in Comment: '
    $stdin.gets.chomp
  end

  def print_record(record)
    puts '---'
    record.each do |key, value|
      puts "#{key} : #{value}"
    end
    puts '---'
  end

  def print_record_line(record)
    print "\n"
    record.each do |key, value|
      print value.empty? ? ' |          ' : " |   #{value}  " unless key == 'special'
    end
  end

  def print_all_records(records)
    print ' |      Date      | Start day |  End day  |Break start| Break end |   Comment'
    records.each do |record|
      print_record_line record
    end
    puts "\n\n"
  end

  def print_record_count(num, file_name)
    puts "--- There are #{num} records in #{file_name} ---"
  end

  def record_doesnt_exist
    puts 'A record with this date does not exist.'
  end

  def record_exists
    puts 'A record with this date already exists.'
  end

  def available_commands(level)
    if level.zero?
      puts 'Available commands:
      add, edit, delete, sort, export, open, count, printOne, printAll or EXIT'
    elsif level == 1
      puts 'Available commands:
        holiday, vacation, school,ill, other or EXIT'
    else
      puts 'Available commands:
        date, start_day, end_day, break_start, break_end, comment or EXIT'
    end
  end

  def goodbye
    puts 'Goodbye!'
  end

  def clear_console
    system 'clear'
  end

  def valid_date_input message
    begin
      print message
      input = $stdin.gets.chomp.downcase
    end while !valid_date? input
    return input
  end

  def valid_time_input message
    begin
      print message
      input = $stdin.gets.chomp.downcase
    end while !valid_time? input
    return input
  end

  def valid_date? string
    format = '%d.%m.%Y'
    DateTime.strptime(string, format)
    true
  rescue ArgumentError
    false
  end

  def valid_time?(string)
    format = '%H:%M'
    DateTime.strptime(string, format)
    true
  rescue ArgumentError
    false
  end

  def numeric?(string)
    !Float(string).nil?
  rescue ArgumentError
    false
  end
end

controller = Controller.new('timesheet.json')
controller.start
