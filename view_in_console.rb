
class ViewInConsole
  def start_view
    print "What would you like to do? "
    return $stdin.gets.chomp.downcase
  end
  def new_record_input
    return start_day_input, end_day_input, break_start_input, break_end_input, comment_input
  end

  def key_value_input
    loop do
      available_commands 2
      key = $stdin.gets.chomp.downcase
      case key
      when 'back','exit'
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
    return valid_date_input "Date(dd.mm.yyyy): "
  end
  def start_day_input
    return valid_time_input "Came to work at(hh:mm): "
  end
  def end_day_input
    return valid_time_input "Left work at: "
  end
  def break_start_input
    return valid_time_input "Went for a break at: "
  end
  def break_end_input
    return valid_time_input "Came back from break at: "
  end
  def comment_input
    print "Comment: "
    return $stdin.gets.chomp
  end
  def input_export_data
    print 'Name:'
    name = $stdin.gets.chomp

    begin
      print 'Working hours carryover(Stundenübertrag):'
      carryover = $stdin.gets.chomp
    end while !numeric? carryover

    return name, carryover.to_f
  end
  def answer_to question
    begin
      print question
      answer = $stdin.gets.chomp.downcase
    end while (answer != "no") && (answer != "yes")
    return answer == "yes" ? true : false
  end
  def answer_special
    return answer_to "Is it a special day?(Yes/No): "
  end
  def are_you_sure?
    return answer_to "Are you sure?(Yes/No): "
  end
  def add_new_record?
    return answer_to "Add a new Record?(Yes/No): "
  end
  def special_input
    begin
      available_commands 1
      special = $stdin.gets.chomp.downcase
    end while !['school', 'holiday', 'vacation', 'ill', 'other', 'exit'].include? special
    return special
  end
  def print_record record
    puts '---'
    record.each do |key, value|
      puts key + ' : ' + value
    end
    puts '---'
  end
  def print_all_records records
    records.each do |record|
      puts print_record record
    end
  end
  def print_record_count num, file_name
    puts "--- There are #{num} records in #{file_name} ---"
  end
  def record_doesnt_exist
    puts "A record with this date does not exist."
  end
  def record_exists
    puts "A record with this date already exists."
  end
  def available_commands level
    puts "Available commands: add, edit, delete, sort, export, count, printOne, printAll or EXIT" if level == 0
    puts "Available commands: holiday, vacation, school,ill or EXIT. " if level == 1
    puts "Available commands: date, start_day, end_day, break_start, break_end, comment or EXIT" if level == 2
  end
  def goodbye
    puts "Goodbye!"
  end
  def clear_console
    system "clear" or system "cls"
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
  def valid_time? string
    format = '%H:%M'
    DateTime.strptime(string, format)
    true
  rescue  ArgumentError
    false
  end
  def numeric? string
    Float(string) != nil rescue false
  end
end
