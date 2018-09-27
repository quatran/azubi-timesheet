load 'Model.rb'
load 'ViewInConsole.rb'
require 'axlsx'
require 'fileutils'
class Controller
  @@jsonFileName = 'timetable.json'
  @@jsonModel = Model.new(@@jsonFileName)
  @@jsonHashArray = @@jsonModel.getJsonHash
  @@newConsoleView = ViewInConsole.new
  @@newConsoleView.clearConsole
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
        printNumberOfRecords @@jsonModel.getNumOfRecords @@jsonHashArray
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
      when 'exportsheet'

        save_axlsx
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
  def day_german string
    date = Date.parse string
    return 'Montag' if date.monday?
    return 'Dienstag' if date.tuesday?
    return 'Mittwoch' if date.wednesday?
    return 'Donnerstag' if date.thursday?
    return 'Freitag' if date.friday?
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
  def add_beginning_rows_to sheet, big_bold_style
    add_image_from '../suse_logo.png', sheet
    5.times {sheet.add_row []}

    sheet.add_row ['', 'Stundenzettel'], :style => [0, big_bold_style]
    sheet.merge_cells("B6:K6")
    sheet.add_row []


  end
  def export_sheet
    name, carryover = @@newConsoleView.input_export_data
    month = extract_month_from @@jsonHashArray[0]['date']
    save_axlsx name, month, carryover
  end
  def save_axlsx name, month, carryover
    p = Axlsx::Package.new
    wb = p.workbook
    setup = {:fit_to_width => 1,:fit_to_height => 1, :orientation => :portrait, :paper_height => "297mm", :paper_width => "210mm"}
    options = {:grid_lines => false}
      wb.add_worksheet(:name => "SUSE Timesheet", :page_setup => setup, :print_options => options) do |sheet|

        center = { :horizontal=> :center, :vertical => :center }
        default_cell = { :alignment => center, :sz => 10 }
        hair_border =  { :style => :hair, :color => "00" }

        big_bold_style = sheet.styles.add_style :sz => 16, :b => true, :alignment => center

        def_style = sheet.styles.add_style default_cell
        def_b_style = sheet.styles.add_style default_cell.merge({:b => true})
        cell_style = sheet.styles.add_style default_cell.merge(:border => hair_border)
        cell_b_style = sheet.styles.add_style default_cell.merge(:b => true, :border => hair_border)

        row8_style = [0, 0, cell_b_style, cell_b_style, 0,0,0]
        row9_style = [0, 0, cell_b_style, cell_b_style, 0,0,0, cell_b_style, 0, cell_b_style]
        row11_style = [0, 0, cell_b_style, cell_b_style, cell_b_style, cell_b_style, cell_b_style, cell_b_style,
          cell_b_style, cell_b_style, cell_b_style, cell_b_style]
        record_style = [0 ,cell_style ,cell_style, cell_style ,cell_style, cell_style,
          cell_style ,cell_style, cell_style ,cell_style, cell_style, cell_style, 0]
        soll_style = [0,0, def_b_style, def_style, 0,0,0, def_b_style, def_style]
        add_beginning_rows_to sheet, big_bold_style


        sheet.add_row ['', '','Name:', 'a_name', '','',''], :style => row8_style
        sheet.merge_cells("D8:G8")
        sheet.add_row ['', '','Monat:', month,'','','','Stundenübertrag','',carryover], :style => row9_style
        sheet.merge_cells("D9:G9")
        sheet.merge_cells("H9:I9")
        sheet.merge_cells("J9:K9")
        sheet.add_row []

        sheet.add_row ['','', 'Datum', 'Kommt', 'Geht', 'P-Beginn', 'P-Ende',
          'Pause', 'AZ', 'GES-Stunden','', 'Kommentar         '], :style => row11_style
        sheet.merge_cells("J11:K11")
        sheet.add_row []

        @@jsonHashArray.each do |record|
          day = day_german record['date']
          clone = addTimeDifferencesTo record
          sheet.add_row ['' , "#{day} ", record['date'], clone['startDay'], clone['endDay'],
          clone['breakStart'], clone['breakEnd'], clone['breakTotal'], clone['dayTotal'],
          clone['workQuota'], clone['weekTotal'], clone['comment'],''], :style => record_style
        end
        sheet.add_row []
        sheet.add_row ['', '','','','','','','Stundenübertrag','','number', ''], :style => [0,0,0,0,0,0,0, cell_b_style,0, cell_style, 0]
        sheet.merge_cells("H#{sheet.rows.last.index+1}:I#{sheet.rows.last.index+1}")
        sheet.merge_cells("J#{sheet.rows.last.index+1}:K#{sheet.rows.last.index+1}")
        3.times {sheet.add_row []}
        sheet.add_row ['','','Soll:', 'a_number','','','', 'Gesamt:', 'a_number'], :style => soll_style
        2.times {sheet.add_row []}
        sheet.add_row ['','','Unterschrift Auszubildender', '','','', 'Unterschrift Betreuer', '','','', 'Unterschrift Ausbilder']
        #  :style =>
        sheet.add_row []
        sheet.add_row ['','','____________________', '','','', '____________________', '','','', '____________________']
        sheet.column_widths nil, 10, 10, 8, 8, 8, 8, 8, 8, 8, 8, 22

    end
    FileUtils.mkdir_p 'Timetable_output' unless File.exists? 'Timetable_output'
    p.serialize('Timetable_output/timetable.xlsx')
  end

end
 conr = Controller.new
 conr.start
