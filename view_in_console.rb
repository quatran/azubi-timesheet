
class ViewInConsole
  def startView
    print "What would you like to do? "
    return getInputFromConsole
  end
  def getNewRecordInput
    return getStartDay, getEndDay, getBreakStart, getBreakEnd, getComment
  end
  def getChosenRecordFrom numOfRecords
    return getValidInteger numOfRecords, "Choose a record between 0 and #{numOfRecords-1}: "

  end

  def getChoiceAndInput
    loop do
      availableCommands 2
      choice = getInputFromConsole
      case choice
      when 'back','exit'
        return 'back', ''
      when 'date'
        return 'date', getDate
      when 'startday'
        return 'startDay', getStartDay
      when 'endday'
        return 'endDay', getEndDay
      when 'breakstart'
        return 'breakStart', getBreakStart
      when 'breakend'
        return 'breakEnd', getBreakEnd
      when 'comment'
        return 'comment', getComment
      end
    end
  end

  def getDate
    return getValidDate "Date(dd.mm.yyyy): "
  end
  def getStartDay
    return getValidTime "Came to work at(hh:mm): "
  end
  def getEndDay
    return getValidTime "Left work at: "
  end
  def getBreakStart
    return getValidTime "Went for a break at: "
  end
  def getBreakEnd
    return getValidTime "Came back from break at: "
  end
  def getComment
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
  def getAnswer message
    begin
      print message
      answer = getInputFromConsole
    end while (answer != "no") && (answer != "yes")
    return answer == "yes" ? true : false
  end
  def getAnswerSpecial
    return getAnswer "Is it a special day?(Yes/No): "
  end
  def areYouSure?
    return getAnswer "Are you sure?(Yes/No): "
  end
  def addNewRecord?
    return getAnswer "Add a new Record?(Yes/No): "
  end
  def getSpecialCase
    begin
      availableCommands 1
      input = getInputFromConsole
    end while !['school', 'holiday', 'vacation', 'ill', 'other', 'exit'].include? input
    return input
  end
  def printOneRecord record
    if record.nil?

    else
      puts '---'
      record.each do |key, value|
        puts key + ' : ' + value
      end
      puts '---'
    end
  end
  def printAllRecords records
    records.each do |record|
      puts printOneRecord record
    end
  end
  def printNumOfRecords num, fileName
    puts "--- There are #{num} records in #{fileName} ---"
  end
  def recordNotExists
    puts "A record with this date does not exist."
  end
  def recordExists
    puts "A record with this date already exists."
  end
  def commandNotValid
    puts "That is not a valid command. Type 'HELP' for available commands."
  end
  def availableCommands level
    puts "Available commands: add, edit, delete, printOne, printAll, printNumOfRecords or EXIT" if level == 0
    puts "Available commands: holiday, vacation, school,ill or EXIT. " if level == 1
    puts "Available commands: date, startDay, endDay, breakStart, breakEnd, comment or EXIT" if level == 2
  end
  def goodbye
    puts "Goodbye!"
  end
  def clearConsole
    system "clear" or system "cls"
  end
  def getInputFromConsole
    $stdin.gets.chomp.downcase
  end
  def getValidInteger numOfRecords, message
    begin
      print message
      input = $stdin.gets.chomp
    end while (!is_integer? input) || (!input.to_i.between?(0, numOfRecords-1))
    return input.to_i
  end

  def getValidDate message
    begin
      print message
      input = getInputFromConsole
    end while !valid_date? input
    return input
  end
  def getValidTime message
    begin
      print message
      input = getInputFromConsole
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
  def is_integer? string
    Integer(string)
    true
  rescue ArgumentError
    false
  end
end
