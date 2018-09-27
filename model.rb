require 'json'
require 'csv'
require 'date'


class Model
  attr_accessor :fileName
  def initialize(fileName)
    @fileName = fileName
  end
  def getJsonHash
    return parseJsonFile readFile fileName
  end
  def parseJsonFile jsonFile
    return jsonFile.empty? ? Array.new : (JSON.parse jsonFile)
  end
  def prettyJsonArray array
    return JSON.pretty_generate array
  end
  def createNewJsonRecord(date, startDay, endDay, breakStart, breakEnd, comment)
    {
      "date" => date,
      "startDay" => startDay,
      "endDay" => endDay,
      "breakStart" => breakStart,
      "breakEnd" => breakEnd,
      "comment" => comment
    }
  end
  def createSpecialJsonRecord(date, specialCase)
    newRecord = createNewJsonRecord(date, '', '', '', '', specialCase)
    newRecord["special"] = "true"
    return newRecord
  end

  def getDateFrom record
    return Date.parse record["date"]
  end
  def readFile fileName
    return File.exist?(fileName) ? File.read(fileName) : File.read(File.new(fileName, "w"))
  end
  def appendThisToThat this, that
      that << this
  end
  def prettyAndSaveArrayToFile array
    array = prettyJsonArray array
    File.open(fileName, "w") do |line|
      line.puts array
    end
  end

  def getNumOfRecords array
    return array.count
  end
  def deleteRecordFromArray array, value
    array.delete_if { |record| record["date"] == value}
  end
  def sortArrayByDate array
    array.sort_by! { |record| (getDateFrom record) }
  end

  def readCsvFile csvFile
    return CSV.read(csvFile, col_sep: '|', headers: true)
  end
  def saveArrayToCsv array, csvFile
    CSV.open(csvFile, 'w') do |csvObj|
      array.each do |row|
        csvObj << row
      end
    end
  end
end
