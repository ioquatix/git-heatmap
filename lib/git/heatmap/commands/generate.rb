#!/usr/bin/env ruby

# Copyright (C) 2010 Samuel Williams. All Rights Reserved.

require 'rubygems'
require 'set'
require 'erubis'
require 'optparse'

class Period
	def aggregate(values, options = {})
		slots = {}

		values.each do |value|
			time = value[:date]

			k = key(time)

			slots[k] ||= []
			slots[k] << value
		end
		
		return slots
	end
	
	def between(first, last)
		cur = first
		all = []
		p = 0
		
		while true
			cur = key(first, p)
			
			if cur <= last
				all << cur
			else
				break
			end
			
			p += 1
		end
		
		return all
	end
	
	def key(t)
		raise ArgumentError
	end

	def mktime(year, month=1, day=1, hour=0, minute=0, second=0)
		return Time.gm(year, month, day, hour, minute, second)
	end
end

class Hourly < Period
	def name
		"Hours"
	end
	
	def key(t, p = 0)
		mktime(t.year, t.month, t.day, t.hour) + (3600 * p)
	end
end

class Daily < Period
	def name
		"Days"
	end
	
	def key(t, p = 0)
		mktime(t.year, t.month, t.day) + (3600 * 24 * p)
	end
end

class Weekly < Period
	def name
		"Weeks"
	end
	
	def key(t, p = 0)
		(mktime(t.year, t.month, t.day) - (t.wday * 3600 * 24)) + (3600 * 24 * 7 * p)
	end
end

class Monthly < Period
	def name
		"Months"
	end
	
	def key(t, p = 0)
		# Month is from 1 - 12, so we shift it to 0 - 11 + years
		month = (t.month + p) - 1
		year = month / 12
		
		mktime(t.year + year, (month % 12) + 1)
	end
end

class Quarterly < Period
	def name
		"Quarters"
	end
	
	def key(t, p = 0)
		quater = (t.month - 1) / 3
		month = (quater + p) * 3
		year = month / 12

		mktime(t.year + year, (month % 12) + 1)
	end
end

class Yearly < Period
	def name
		"Years"
	end
	
	def key(t, p = 0)
		mktime(t.year + p)
	end
end

PERIODS = {
	"hourly" => Hourly,
	"daily" => Daily,
	"weekly" => Weekly,
	"monthly" => Monthly,
	"quarterly" => Quarterly,
	"yearly" => Yearly
}

def trie_depth(top, path)
	depth = nil
	
	path.each do |p|
		break if top == nil
		depth = top[:depth] if top[:depth]

		top = top[p]
	end
	
	return depth
end

class Revision
	def initialize(details, changes = {})
		# Path => Statistics
		@details = details.dup
		@changes = (@details.delete(:changes) || changes).freeze
		
		@details.freeze
		
		@lines_added = @changes.values.inject(0){|total,stats| total + stats[0]}
		@lines_removed = @changes.values.inject(0){|total,stats| total + stats[1]}
	end
	
	def [](key)
		if (key == :changes)
			return @changes
		else
			return @details[key]
		end
	end
	
	attr :details
	attr :changes
	attr :lines_added
	attr :lines_removed
	
	def partition_in_directory(dir)
		a = {} ; b = {}
		
		@changes.each do |path, stats|
			if path.index(dir)
				a[path] = stats
			else
				b[path] = stats
			end
		end
		
		return Revision.new(@details, a), Revision.new(@details, b)
	end
	
	def update_from(other)
		@details = other.details
		@changes = other.changes
		@lines_added = other.lines_added
		@lines_removed = other.lines_removed
	end
end

class WeightedMap
	def initialize
		@values = {}
	end
	
	def add(key, weight = 1)
		@values[key] ||= 0
		@values[key] += 1
	end
	
	def insert(others)
		others.each do |other|
			add(other)
		end
	end
	
	def sorted
		@values.to_a.sort{|a,b| b[1] <=> a[1]}
	end
end

class HeatMap
	def initialize(revisions, files, options)
		@depth = options[:depth] || 2
		@filter = options[:filter] || {}
		@period = PERIODS[options[:period]].new
		@options = options
		
		@files = Set.new
		@authors = Set.new
		
		@lines_added = 0
		@lines_removed = 0
		
		# Put commits into bins depending on the top most directory
		bins = {}
		revisions.each do |rev|
			@authors << rev[:author]
			
			rev.changes.each do |name, stats|
				@files << name
				@lines_added += stats[0]
				@lines_removed += stats[1]
				
				dir = File.dirname(name)
				parts = dir.split("/")
				
				depth = trie_depth(@filter, parts) || @depth
				next if depth == 0
				
				dir = parts[0...depth].join("/")
				
				bins[dir] ||= Set.new
				bins[dir] << rev
			end
		end
		
		@slices = {}
		
		# Split commits into slices so that a change only belongs to a specific slice. This breaks revisions into pieces.
		# Sort so the longest path comes first. This means that paths will be put into the deepest slice possible.
		bins.to_a.sort{|a,b| b[0] <=> a[0]}.each do |dir, revisions|
			slice = @slices[dir] = []
			
			revisions.each do |rev|
				next if rev.changes.size == 0
				
				a, b = rev.partition_in_directory(dir)
				rev.update_from(b)
				
				slice << a
			end
		end
				
		@first, @last = nil, nil
		@aggregates = {}
		@max = 0
		
		@slices.each do |dir, revisions|
			sorted = @period.aggregate(revisions)
			
			dates = sorted.keys.sort
			@max = [@max, sorted.values.collect{|v| magnitude(v)}.max].max

			if !@first || @first > dates.first
				@first = dates.first
			end

			if !@last || @last < dates.last
				@last = dates.last
			end

			@aggregates[dir] = sorted
		end
	end
	
	def magnitude(revisions)
		# Number of commits during this period
		rs = revisions.size
		
		# Number of files changed during this period
		fs = revisions.inject(0){|total,commit| total + commit.changes.size }
		
		# Net number of lines changed
		# If we add a line, this is +1/0
		# If we change a line, this is +1/-1
		# If we remove a line, this is 0/-1
		ls = revisions.inject(0){|total,commit| total + ((commit.lines_added + commit.lines_removed) >> 1) }
		
		# Weight together the changes
		# A commit represents a unit of work in general, whether it be across one file or many files.
		# We assume that most commits will modify only a few files, but if they modify 1000s of files,
		# that the individual modification is less important, and mostly dictated by the average number of lines
		# changed per file.
		m = rs
		
		# We make sure that we don't have a division by zero...
		m += Math::log10((ls.to_f / fs.to_f) + 1) if fs > 0
		
		# This is the expansion factor, it changes how compressed the data is.
		# This number is a bit magic, it will change the entire visualisation.
		# The lower this number, the more compressed the data will be.
		f = 60.0
		
		return Math::log10((m.to_f / f) + 1) * f + 1.0
		#return m
	end
	
	attr :aggregates
	attr :first
	attr :last
	attr :period
	
	# all files over all commits
	attr :files
	
	# all authors over all commits
	attr :authors
	
	# Bins with revisions divided by path
	attr :slices
	
	attr :lines_added
	attr :lines_removed
	
	attr :max
	
	def debug(io = $stdout)
		io.puts "From #{@first} to #{@last}..."
		@aggregates.each do |dir, sorted|
			puts "-- #{dir} : Total Revisions = #{@bins[dir].size}"
			sorted.to_a.sort.each do |agg|
				puts "#{agg[0]} = #{agg[1].size}"
			end
		end
	end
end

def load_revisions(path)
	files = Set.new
	revisions = []
	
	data = nil
	Dir.chdir(path) do
		lines = []
		
		# Read the information from git
		IO.popen("git log --numstat --oneline --date=rfc --pretty=format:'%h %aE %aD'") do |io|
			lines = io.readlines
		end
		
		total = 0
		lines.each{|line| total += line.size}
		
		$stderr.puts "Processing #{total >> 10}Kbytes git logs..."
		
		# Process the data
		commit = nil
		lines.each do |line|
			if (line =~ /([0-9a-f]{7}) (.+?) (.*?)$/)
				revisions << Revision.new(commit) if commit
				$stderr.write "."
				$stderr.flush
				
				commit = {
					:id => $1, :author => $2, :date => Date.parse($3), :changes => {}
				}
			elsif (line =~ /(\d+)\s+(\d+)\s+(.*?)$/)
				abort("Data already exists for #{$3}!?") if commit[:changes][$3] != nil
				
				change = commit[:changes][$3] = [$1.to_i, $2.to_i]
				
				files << $3
			elsif (line =~ /\n/)
				# Empty line...
			else
				$stderr.puts "Invalid Line : #{line.dump}"
			end
		end
		
		revisions << Revision.new(commit) if commit
	end
	
	$stderr.puts
	
	return {:revisions => revisions.reverse, :files => files.to_a.sort}
end

OPTIONS = {
	:template => File.dirname(__FILE__) + "/template.erb",
	:output => nil,
	:period => "monthly",
	:depth => 2,
	:filter => nil
}

files = ARGV.options do |o|
	script_name = File.basename($0)

	o.set_summary_indent('  ')
	o.banner = "Usage: #{script_name} [options] [git-path]"
	o.define_head "This script can be used to generate visualisations of git repositories."

	o.separator ""
	o.on("-t template.erb", String, "Specify the template to use.") do |path|
		OPTIONS[:template] = path
	end
	
	o.on("-o output.html", String, "Specify the output file.") do |path|
		OPTIONS[:output] = path
	end
	
	o.on("-p period", String, "Specify the period of aggregation: Hourly, Daily, Weekly, Monthly, Quarterly Yearly.") do |period|
		OPTIONS[:period] = period
	end
	
	o.on("-d depth", Integer, "Specify the depth of aggregation (depth of top level directories).") do |depth|
		OPTIONS[:depth] = depth
	end
	
	o.on("-f filter", String, "Specify the depth of specific branches, 0 means exclude.") do |filter|
		paths = filter.split(",").collect{|s|s.split(":")}
		trie = {}
		paths.each do |path, depth|
			top = trie
			
			path.split("/").each do |p|
				top = top[p] ||= {}
			end
			
			top[:depth] = depth.to_i
		end
		
		OPTIONS[:filter] = trie
	end
	
	o.separator ""
	o.separator "Help and Copyright information"

	o.on_tail("--copy", "Display copyright information") do
		puts "#{script_name} v0.1. Copyright (c) 2010 Samuel Williams. Released under the GPLv3."
		puts "See http://www.oriontransfer.co.nz/ for more information."

		exit
	end

	o.on_tail("-h", "--help", "Show this help message.") { puts o; exit }
end.parse!

$stderr.puts "ARGV: #{files}"

unless files[0] && File.exist?(files[0])
	abort("Please specify a path argument!")
end

$stderr.puts "Options : #{OPTIONS.inspect}"

$stderr.puts "Loading revisions..."
data = load_revisions(files[0])
data[:title] = File.basename(ARGV[0])

OPTIONS[:output] ||= "#{data[:title]}-#{OPTIONS[:period]}-#{Time.now.to_i}.html"

$stderr.puts "Generating heatmap..."
data[:heatmap] = HeatMap.new(data[:revisions], data[:files], OPTIONS)

template = File.open(OPTIONS[:template]).read
output = Erubis::Eruby.new(template).result(data)

File.open(OPTIONS[:output], "w") do |fp|
	fp.write(output)
end

$stderr.puts "Wrote output to #{OPTIONS[:output]}."
