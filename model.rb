require 'json'
require 'csv'
require 'date'


class Model
  attr_accessor :file_name
  def initialize(file_name)
    @file_name = file_name
  end
  def create_json_hash
    return parse_json_file read_file file_name
  end
  def parse_json_file file
    return file.empty? ? Array.new : (JSON.parse file)
  end
  def pretty_generate json_array
    return JSON.pretty_generate json_array
  end
  def create_pretty_json_record(date, start_day, end_day, break_start, break_end, comment)
    {
      "date" => date,
      "start_day" => start_day,
      "end_day" => end_day,
      "break_start" => break_start,
      "break_end" => break_end,
      "comment" => comment
    }
  end
  def create_special_json_record(date, special_case)
    record = create_pretty_json_record(date, '', '', '', '', special_case)
    record["special"] = "true"
    return record
  end

  def extract_date_from record
    return Date.parse record["date"]
  end
  def read_file file_name
    return File.exist?(file_name) ? File.read(file_name) : File.read(File.new(file_name, "w"))
  end
  def append_this_to_that this, that
      that << this
  end
  def make_pretty_and_save array
    array = pretty_generate array
    File.open(file_name, "w") do |line|
      line.puts array
    end
  end


  def delete_record_with value, array
    array.delete_if { |record| record["date"] == value}
  end
  def sort_by_date array
    array.sort_by! { |record| (extract_date_from record) }
  end

  def read_csv_file file
    return CSV.read(file, col_sep: '|', headers: true)
  end
  def save_array_to_file array, file
    CSV.open(file, 'w') do |csvObj|
      array.each do |row|
        csvObj << row
      end
    end
  end
end
