load 'model.rb'
load 'view_in_console.rb'
require 'axlsx'
require 'fileutils'
class Controller
  @@json_file_name = 'timetable.json'
  @@json_model = Model.new(@@json_file_name)
  @@hash_array = @@json_model.create_json_hash
  @@console_view = ViewInConsole.new
  @@console_view.clear_console
  def start
    loop do
      chosen_case = check_record_count ? @@console_view.start_view : add_record
      case chosen_case
      when 'exit'
        @@console_view.clear_console
        @@console_view.goodbye
        break
      when 'add'
        append add_new_record
      when 'edit'
        date = @@console_view.date_input
        if(record_exists? date)
          (edit existing_record date)
        else
          @@console_view.record_doesnt_exist
          add_record
        end
      when 'count', 'printnum', 'printnumber'
        print_record_count
      when 'printone', 'printonerecord'
          date = @@console_view.date_input
          (record_exists? date) ? (print_full_record existing_record date) : (@@console_view.record_doesnt_exist)
      when 'printall', 'printallrecords'
          @@console_view.print_all_records @@hash_array
      when 'delete'
          date = @@console_view.date_input
          (record_exists? date) ? (delete_record_with date) : (@@console_view.record_doesnt_exist)
      when 'sort'
        sort_array
      when 'export'
        sort_array
        export_sheet
      when 'help', 'clear'
        @@console_view.clear_console
        @@console_view.available_commands 0
      else
        @@console_view.clear_console
        @@console_view.available_commands 0
      end
      save_array
    end
  end

  def sort_array
    @@json_model.sort_by_date @@hash_array
  end

  def save_array
    @@json_model.make_pretty_and_save @@hash_array
  end

  def append(record)
    @@json_model.append_this_to_that record, @@hash_array unless record.nil?
  end

  def add_record
    @@console_view.add_new_record? ? (append add_new_record) : 'exit'
  end

  def add_new_record
    date = @@console_view.date_input
    if (record_exists? date)
      @@console_view.record_exists
    else
      return @@console_view.answer_special ? (create_special_record date) : (create_normal_record date)
    end
  end

  def create_special_record(date)
    special_case = @@console_view.special_input
    if special_case != 'exit'
      return @@json_model.create_special_json_record(date, @@console_view.comment_input)
    end
  end

  def create_normal_record(date)
    start_day, end_day, break_start, break_end, comment=  @@console_view.new_record_input
    return @@json_model.create_pretty_json_record(date, start_day, end_day, break_start, break_end, comment)
  end

  def record_exists?(date)
    @@hash_array.any? { |hash| hash['date'].include?(date) }
  end

  def existing_record date
    return @@hash_array.select { |hash| hash['date'].include?(date) }.first
  end

  def delete_record_with value
      print_full_record existing_record value
      @@json_model.delete_record_with value, @@hash_array unless !@@console_view.are_you_sure?
  end

  def check_record_count
    num = @@hash_array.count
    if num <= 0
      print_record_count
      return false
    end
    return true
  end

  def edit record
    print_full_record record
    date = record['date']
    if @@console_view.answer_special
      new_record = create_special_record date
      record.replace(new_record) unless new_record.nil?
    elsif record.key? 'special'
      record.replace(create_normal_record(date))
    else
      loop do
        key, value = @@console_view.key_value_input
        break if (key == 'back') || (key == 'exit')

        if key == 'date' && (record_exists? value)
          @@console_view.record_exists
        else
          record[key] = value
        end
      end
    end
  end

  def print_record_count
    num = @@hash_array.count
    @@console_view.print_record_count num, @@json_file_name
  end

  def print_full_record record

    clone = make_complete record
    @@console_view.print_record clone
  end

  def make_complete record
    clone = record.clone

    break_total = calculate_break_total record
    day_total = calculate_day_total record, break_total
    work_quota = calculate_work_quota day_total

    clone["break_total"] = "#{break_total}"
    clone["day_total"] = "#{day_total}"
    sign = work_quota < 0 ? '' : '+'
    clone["work_quota"] = "#{sign}#{work_quota}"
    if is_friday? record["date"]
      record_index = @@hash_array.index(record)
      week_total = calculate_week_total  record_index
      clone["week_total"] = "#{week_total}"
    end
    return clone
  end

  def hour_from string
    return DateTime.strptime(string, '%H:%M').hour
  rescue ArgumentError
    return 0
  end
  def min_from string
    return DateTime.strptime(string, '%H:%M').min
  rescue ArgumentError
    return 0
  end

  def difference_between startTime, endTime
    hour = hour_from(endTime) - hour_from(startTime)
    min = min_from(endTime) - min_from(startTime)
    return (hour*60 + min)/60.to_f
  end

  def calculate_break_total record
    return 0.0 if record.has_key? "special"
    break_start = record["break_start"]
    break_end = record["break_end"]
    return difference_between(break_start, break_end)
  end

  def calculate_day_total record, break_total
    return 8.0 if record.has_key? "special"
    start_day = record["start_day"]
    end_day = record["end_day"]
    day_total = difference_between(start_day, end_day) - break_total
    return day_total
  end

  def calculate_work_quota day_total
    return day_total.to_f - 8
  end

  def is_friday? string
    date = Date.parse string
    return date.friday?
  end

  def day_german string
    date = Date.parse string
    return 'Montag' if date.monday?
    return 'Dienstag' if date.tuesday?
    return 'Mittwoch' if date.wednesday?
    return 'Donnerstag' if date.thursday?
    return 'Freitag' if date.friday?
  end

  def calculate_week_total record_index
    week_total = 0
    5.times do
      if record_index >= 0
        break_total = calculate_break_total  @@hash_array[record_index]
        day_total = calculate_day_total @@hash_array[record_index], break_total
        week_total+= day_total
        record_index -= 1
      end
    end
    return week_total
  end

  def extract_month_from string
    date = Date.parse string
    year = date.year
    case date.month
    when 1
      return "Januar #{year}"
    when 2
      return "Februar #{year}"
    when 3
      return "März #{year}"
    when 4
      return "April #{year}"
    when 5
      return "Mai #{year}"
    when 6
      return "Juni #{year}"
    when 7
      return "Juli #{year}"
    when 8
      return "August #{year}"
    when 9
      return "September #{year}"
    when 10
      return "Oktober #{year}"
    when 11
      return "November #{year}"
    when 12
      return "Dezember #{year}"
    end
  end

  def add_image_from path, sheet
    img = File.expand_path(path, __FILE__)
    sheet.add_image(:image_src => img, :noSelect => true, :noMove => true) do |image|
      image.width=261
      image.height=118
      #image.start_at 1, 1
    end
  end

  def weekdays_count string
    date = Date.parse string
    d1 = Date.new(date.year, date.month, 1)
    d2 = Date.new(date.year, date.month, -1)
    wdays = [0, 6]
    weekdays = (d1..d2).reject { |day| wdays.include? day.wday}
    return weekdays.count * 8
  end

  def add_beginning_rows_to sheet, big_bold_style
    add_image_from '../suse_logo.png', sheet
    5.times {sheet.add_row []}

    sheet.add_row ['', 'Stundenzettel'], :style => [0, big_bold_style]
    sheet.merge_cells("B6:K6")
    sheet.add_row []


  end

  def export_sheet
    string = @@hash_array[0]['date']
    name, carryover = @@console_view.input_export_data
    month = extract_month_from string
    total_of_hours = weekdays_count string
    save_axlsx name, month, carryover, total_of_hours
  end

  def save_axlsx name, month, carryover, total_of_hours
    p = Axlsx::Package.new
    wb = p.workbook
    setup = {:fit_to_width => 1,:fit_to_height => 1, :orientation => :portrait, :paper_height => "297mm", :paper_width => "210mm"}
    options = {:grid_lines => false}
    wb.add_worksheet(:name => "SUSE Timesheet", :page_setup => setup, :print_options => options) do |sheet|
      center = { :horizontal=> :center, :vertical => :center }
      default_cell = { :alignment => center, :sz => 10 }
      hair_border =  { :style => :hair, :color => "00" }
      border_cell = default_cell.merge({:border => hair_border})

      big_bold_style = sheet.styles.add_style :sz => 16, :b => true, :alignment => center

      def_style = sheet.styles.add_style default_cell
      def_b_style = sheet.styles.add_style default_cell.merge({:b => true})

      cell_style = sheet.styles.add_style border_cell
      cell_b_style = sheet.styles.add_style border_cell.merge(:b => true)

      cell_green_style = sheet.styles.add_style border_cell.merge(:bg_color => '7DC148')
      cell_b_green_style = sheet.styles.add_style border_cell.merge(:b => true, :bg_color => '7DC148')

      row8_style = [0, 0, cell_b_style, cell_b_style, 0,0,cell_b_style]
      row9_style = [0, 0, cell_b_style, cell_b_style, 0,0,0, cell_b_style, 0, cell_b_green_style,cell_b_green_style]
      row11_style = [0, 0, cell_b_style, cell_b_style, cell_b_style, cell_b_style, cell_b_style, cell_b_style,
        cell_b_style, cell_b_style, cell_b_style, cell_b_style]

      record_style = [0 ,cell_style ,cell_style, cell_green_style ,cell_green_style, cell_green_style,
        cell_green_style ,cell_style, cell_style ,cell_style, cell_style, cell_style, 0]
      carryover_style = [0,0,0,0,0,0,0, cell_b_style,0, cell_style, cell_style]
      soll_style = [0,0, def_b_style, def_style, 0,0,0, def_b_style, def_style]

      add_beginning_rows_to sheet, big_bold_style

      sheet.add_row ['', '', 'Name:', name, '', '', ''], style: row8_style
      sheet.merge_cells('D8:G8')

      sheet.add_row [
        '', '', 'Monat:', month, '', '', '', 'Stundenübertrag', '', carryover, ''
      ], style: row9_style
      sheet.merge_cells('D9:G9')
      sheet.merge_cells('H9:I9')
      sheet.merge_cells('J9:K9')
      sheet.add_row []

      sheet.add_row [
        '', '', 'Datum', 'Kommt', 'Geht', 'P-Beginn', 'P-Ende', 'Pause', 'AZ',
        'GES-Stunden', '', 'Kommentar         '
      ], style: row11_style
      sheet.merge_cells('J11:K11')
      sheet.add_row []

      worked_hours = 0
      @@hash_array.each do |record|
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
      #  :style =>
      sheet.add_row []
      sheet.add_row [
        '', '', '____________________', '', '', '', '____________________', '',
        '', '', '____________________'
      ]
      sheet.column_widths nil, 10, 10, 8, 8, 8, 8, 8, 8, 8, 8, 22, nil
    end
    FileUtils.mkdir_p 'Timetable_output' unless File.exist? 'Timetable_output'
    p.serialize('Timetable_output/timetable.xlsx')
  end

end

conr = Controller.new
conr.start
