load 'Model.rb'
load 'ViewInConsole.rb'


class Controller
  @@jsonFileName = 'timetable.json'
  @@jsonModel = Model.new(@@jsonFileName)
  @@jsonHashArray = @@jsonModel.getJsonHash
  @@newConsoleView = ViewInConsole.new
  def start
    loop do
      chosenCase = checkNumOfRecords ? @@newConsoleView.startView : addRecord
      case chosenCase
      when 'exit'
        @@newConsoleView.clearConsole
        @@newConsoleView.goodbye
        break
      when 'add'
        append addNewRecord
      when 'edit'
        date = @@newConsoleView.getDate
        if(recordExistsInArray? date)
          (edit getExistingRecord date)
        else
          (@@newConsoleView.recordNotExists)
          addRecord
        end
      when 'printnum', 'printnumber', 'printnumofrecords', 'printnumberofrecords'
        printNumberOfRecords numOfRecords
      when 'printone', 'printonerecord'
          date = @@newConsoleView.getDate
          (recordExistsInArray? date) ? (printOneComplete getExistingRecord date) : (@@newConsoleView.recordNotExists)
      when 'printall', 'printallrecords'
          @@newConsoleView.printAllRecords @@jsonHashArray
      when 'delete'
          date = @@newConsoleView.getDate
          (recordExistsInArray? date) ? (deleteRecordWith date) : (@@newConsoleView.recordNotExists)
      when 'sort'
        @@jsonModel.sortArrayByDate @@jsonHashArray
      when 'help', 'clear'
        @@newConsoleView.clearConsole
        @@newConsoleView.availableCommands 0
      else
        @@newConsoleView.clearConsole
        @@newConsoleView.availableCommands 0
      end
      saveArray
    end
  end


  def saveArray
    @@jsonModel.prettyAndSaveArrayToFile @@jsonHashArray
  end
  def append record
    @@jsonModel.appendThisToThat record, @@jsonHashArray unless record.nil?
  end
  def addRecord
    return @@newConsoleView.addNewRecord? ? (append addNewRecord) : 'exit'
  end
  def addNewRecord
    date = @@newConsoleView.getDate
    if(recordExistsInArray? date)
      @@newConsoleView.recordExists
    else
      return @@newConsoleView.getAnswerSpecial ? (createSpecialRecord date) : (createNormalRecord date)
    end
  end
  def createSpecialRecord date
    specialCase = @@newConsoleView.getSpecialCase
    if specialCase != 'exit'

      return @@jsonModel.createSpecialJsonRecord(date, @@newConsoleView.getComment)
    end
  end
  def createNormalRecord date
    startDay, endDay, breakStart, breakEnd, comment=  @@newConsoleView.getNewRecordInput
    return @@jsonModel.createNewJsonRecord(date, startDay, endDay, breakStart, breakEnd, comment)
  end
  def recordExistsInArray? value
    return @@jsonHashArray.any? { |hash| hash['date'].include?(value) }
  end
  def getExistingRecord value
    return @@jsonHashArray.select { |hash| hash['date'].include?(value) }.first
  end
  def deleteRecordWith value
      printOneComplete getExistingRecord value
      @@jsonModel.deleteRecordFromArray @@jsonHashArray, value unless !@@newConsoleView.areYouSure?
  end
  def checkNumOfRecords
    num = @@jsonModel.getNumOfRecords @@jsonHashArray
    if num <= 0
      printNumberOfRecords num
      return false
    end
    return true
  end
  def edit record
    printOneComplete record
    date = record["date"]
    if @@newConsoleView.getAnswerSpecial
      newRecord = createSpecialRecord date
      record.replace(newRecord) unless newRecord.nil?
    elsif record.has_key? "special"
      record.replace(createNormalRecord date)
    else
      loop do
        choice, input = @@newConsoleView.getChoiceAndInput
        break if (choice == 'back') || (choice == 'exit')
        record[choice] = input
      end
    end
  end
  def printNumberOfRecords num
    @@newConsoleView.printNumOfRecords num, @@jsonFileName
  end
  def printOneComplete record

    clone = addTimeDifferencesTo record
    @@newConsoleView.printOneRecord clone
  end
  def addTimeDifferencesTo record
    clone = record.clone
    index = @@jsonHashArray.index(record)
    breakTotal = getBreakTotal record
    dayTotal = getDayTotal record, breakTotal
    workQuota = getWorkQuota dayTotal
    sign = workQuota < 0 ? '' : '+'
    clone["breakTotal"] = "#{breakTotal}"
    clone["dayTotal"] = "#{dayTotal}"
    clone["workQuota"] = "#{sign}#{workQuota}"
    if isFriday? record["date"]
      weekTotal = getWeekTotal  index
      clone["weekTotal"] = "#{weekTotal}"
    end
    return clone
  end

  def getHour string
    return DateTime.strptime(string, '%H:%M').hour
  rescue ArgumentError
    return 0
  end
  def getMin string
    return DateTime.strptime(string, '%H:%M').min
  rescue ArgumentError
    return 0
  end
  def getTimeDifference startTime, endTime
    hour = getHour(endTime) - getHour(startTime)
    min = getMin(endTime) - getMin(startTime)
    return (hour*60 + min)/60.to_f
  end
  def getBreakTotal record
    return 0.0 if record.has_key? "special"
    breakStart = record["breakStart"]
    breakEnd = record["breakEnd"]
    return getTimeDifference(breakStart, breakEnd)
  end
  def getDayTotal record, breakTotal
    return 8.0 if record.has_key? "special"
    startDay = record["startDay"]
    endDay = record["endDay"]
    dayTotal = getTimeDifference(startDay, endDay) - breakTotal
    return getTimeDifference(startDay, endDay) - breakTotal
  end
  def getWorkQuota dayTotal
    return dayTotal.to_f - 8
  end
  def isFriday? string
    date = Date.parse string
    return date.friday?
  end
  def getWeekTotal recordIndex
    weekTotal = 0
    5.times do
      if recordIndex >= 0 
        breakTotal = getBreakTotal  @@jsonHashArray[recordIndex]
        dayTotal = getDayTotal @@jsonHashArray[recordIndex], breakTotal
        weekTotal+= dayTotal
        recordIndex -= 1
      end
    end
    return weekTotal
  end
end

 conr = Controller.new
 conr.start
