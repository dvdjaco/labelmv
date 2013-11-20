#!/usr/bin/env ruby
#
# Author: David Jacovkis <djacovkis@zinio.com>
# 
# Parse a CSV file containing 3 paths per row (src, dst, bkp).
# Copy each file in src into dst and bkp, then remove it from src.
# These 3 paths can be restricted to subtrees with command-line parameters.

require 'csv'
require 'optparse'
require 'fileutils'
include FileUtils

class ProcessLabelFiles
    def initialize()
        # Parse command line options and set default values
        opts = Hash.new

        opts[:debug] = false
        opts[:src_pre] = "/"
        opts[:dst_pre] = "/"
        opts[:bkp_pre] = "/"
     
        oparse = OptionParser.new do |o|
            o.banner = "Usage: labelmv.rb [options] inputFiles"
            o.separator ""
            o.separator "Specific options:"
            o.on("-vv", "Turn debug mode on") { |b| opts[:debug] = b }
            
            o.on("-s SOURCEDIR",
            "Use SOURCEDIR as the base path for destination directories.",
            " Default value: #{opts[:src_pre]}") do |src_pre|
                opts[:src_pre] = src_pre
            end
            
            o.on("-d DESTDIR",
            "Use DESTDIR as the base path for destination directories.",
            " Default value: #{opts[:dst_pre]}") do |dst_pre|
                opts[:dst_pre] = dst_pre
            end
            
            o.on("-b BKPDIR",
            "Use BKPDIR as the base path for backup directories.",
            " Default value: #{opts[:bkp_pre]}") do |bkp_pre|
                opts[:bkp_pre] = bkp_pre
            end
            
            o.on("-n", "--dry-run",
            "Perform a test run with no real changes made to disk") { |n| opts[:dry_run] = n }
            
            o.separator ""
            o.separator "Common options:"
            o.on("-h", "--help", "This message") { p o; exit }
        end
        
        begin
            oparse.parse!
            
            if ARGV.empty? then
				raise "You must specify at least one input file."
			end
            
            @file_list = ARGV
            @debug = opts[:debug]
            @src_pre = Dir.new(opts[:src_pre])
            @dst_pre = Dir.new(opts[:dst_pre])
            @bkp_pre = Dir.new(opts[:bkp_pre])
            @dry_run = opts[:dry_run]
            @process_label_status = 0
        rescue Exception => e
            puts "Error initializing..."
            puts e.message
            exit 1
        end
    end
    
    def run()
        if @dry_run then
            puts "[WARN] This is a dry run, no changes will be made to the disk"
            puts ""
        end
        puts "[INFO]  - Found input files:"
        puts *@file_list
        @file_list.each do |label_file|
            puts ""
            puts "***"
            parse(File.new(label_file))
        end
        return @process_label_status
    end
    
    def parse(label_file)
        puts "[INFO]  - Processing input file: #{label_file.path}"
        CSV.foreach(label_file) do |row|
            line_n = $INPUT_LINE_NUMBER
            
            # Ignore comments and empty lines
            if (row.length == 0 or (!row[0].nil? and row[0][/^#/])) then
                puts "[INFO]  - line #{line_n} ignored." if @debug
                next
            end

            # Check number of fields
            if row.length != 3 then
                puts "[ERROR] - line #{line_n}: Wrong number of fields, skipping. Check you paths for commas!"
                next
            end
            
            # Sanitize paths
            begin
                if (row[0].nil? or row[1].nil? or row[2].nil?) then
                    puts "[ERROR] - line #{line_n}: Empty field(s), skipping"
                    next
                end
                src = Dir.new(row[0])
                dst = Dir.new(row[1])
                bkp = Dir.new(row[2])
            rescue Exception => e
                puts "[ERROR] - line #{line_n}: " + e.message + ", skipping"
                next
            end            
            unless src.path.match("#{@src_pre.path}")
                puts "[ERROR] - line #{line_n}: Source path forbidden, skipping - #{src.path}"
                next
            end
            unless dst.path.match("#{@dst_pre.path}")
                puts "[ERROR] - line #{line_n}: Destination path forbidden, skipping - #{dst.path}"
                next
            end
            unless bkp.path.match("#{@bkp_pre.path}")
                puts "[ERROR] - line #{line_n}: Backup path forbidden, skipping - #{bkp.path}"
                next
            end                        
            if Dir.glob(src.path+"/*").empty?
                if @debug then
                    puts "[INFO]  - line #{line_n}: Source directory is empty, skipping - #{src.path}"
                end
                next
            end
            Dir.glob(src.path+"/*").each do |f|
				if File.directory?(f) then
					puts "[ERROR] - line #{line_n}: Source path contains subdirectories, skipping - #{src.path}"
					next
				end
			end
            
            # Copy the files and remove from src, unless this is a dry-run            
            files = Dir.glob(src.path+"/*")
            v = true
            if @dry_run then
                n = true
            else
                n = false
            end
            puts "[INFO]  - line #{line_n}: Executing file operations on #{src.path}."
            cp(files, dst.path, {:verbose => v, :noop => n})
            cp(files, bkp.path, {:verbose => v, :noop => n})
            rm(files, {:verbose => v, :noop => n})
        end
    end
end

if __FILE__ == $0
 process_label = ProcessLabelFiles.new()
 exit_status = process_label.run()
 exit exit_status
end
