# Copyright, 2019, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'samovar'
require 'rugged'

require_relative '../period'
require_relative '../templates/series'

require 'irb'

module Git
	module Heatmap
		module Command
			class Generate < Samovar::Command
				self.description = "Generate the visualisation."
				
				PERIODS = {
					"hourly" => Hourly,
					"daily" => Daily,
					"weekly" => Weekly,
					"monthly" => Monthly,
					"quarterly" => Quarterly,
					"yearly" => Yearly
				}
				
				options do
					option "--template <path>", "The template file to use.", default: "series"
					option "--period <name>", "The period to use, one of: #{PERIODS.keys.join(', ')}.", default: "weekly"
					option "--depth <integer>", "Specify the depth of aggregation (depth of top level directories).", type: Integer, default: 2
					
					option "--output <path>", "The output path to use."
				end
				
				many :paths, "One or more repositories to visualise."
				
				def period
					PERIODS[@options[:period]].new
				end
				
				def title
					@paths.map do |path|
						File.basename(File.expand_path(path))
					end.join(', ')
				end
				
				def output_path
					@options.fetch(:output) do
						"#{title} #{@options[:period]}.html"
					end
				end
				
				def template(commits)
					Templates::Series.new(commits, title: self.title)
				end
				
				def call
					commits = Commits.new(filter: self.period, depth: @options[:depth])
					
					@paths.each do |path|
						repository = Rugged::Repository.discover(path)
						
						commits.add(repository)
					end
					
					File.write(output_path, template(commits).call)
				end
			end
		end
	end
end
