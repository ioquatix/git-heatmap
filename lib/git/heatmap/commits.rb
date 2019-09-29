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

require 'set'

module Git
	module Heatmap
		class Aggregate
			def initialize(filter)
				@filter = filter
				
				@commits = {}
				
				@periods = {}
				@earliest_commit_at = nil
				@latest_commit_at = nil
				
				@maximum = 0
				
				@additions = Hash.new{|h,k| h[k] = 0}
				@deletions = Hash.new{|h,k| h[k] = 0}
				@churn = Hash.new{|h,k| h[k] = 0}
			end
			
			attr :commits
			attr :periods
			
			attr :earliest_commit_at
			attr :latest_commit_at
			
			attr :additions
			attr :deletions
			attr :churn
			
			def size
				@commits.size
			end
			
			attr :maximum
			
			def add(commit, patch)
				author = commit.author
				time = author[:time]
				key = @filter.key(time)
				
				unless @commits.include?(commit.oid)
					@commits[commit.oid] = commit
					
					commits = (@periods[key] ||= [])
					commits << commit
				end
				
				@additions[key] += patch.additions
				@deletions[key] += patch.deletions
				
				churn = patch.additions + patch.deletions.abs
				@churn[key] += churn
				
				total_churn = @churn[key]
				
				if total_churn > @maximum
					@maximum = total_churn
				end
				
				if @earliest_commit_at.nil? or time < @earliest_commit_at
					@earliest_commit_at = time
				end
				
				if @latest_commit_at.nil? or time > @latest_commit_at
					@latest_commit_at = time
				end
			end
		end
		
		class Commits
			def initialize(filter: Weekly.new, depth: 4)
				@filter = filter
				
				@authors = Set.new
				@directories = Hash.new{|h,k| h[k] = Aggregate.new(filter)}
				
				@depth = depth
				
				@earliest_commit_at = nil
				@latest_commit_at = nil
				
				@maximum = nil
			end
			
			attr :filter
			
			attr :earliest_commit_at
			attr :latest_commit_at
			
			def each_period(&block)
				@filter.between(@earliest_commit_at, @latest_commit_at, &block)
			end
			
			def maximum
				@maximum ||= @directories.each_value.max_by(&:maximum).maximum
			end
			
			attr :authors
			attr :directories
			
			def each_directory
				@directories.keys.sort.each do |key|
					yield key, @directories[key]
				end
			end
			
			def << commit
				@maximum = nil
				
				if parent = commit.parents.first
					# Documentation seems to imply this shouldn't be needed.
					diff = parent.diff(commit.tree)
				else
					empty_tree = Rugged::Tree.empty(commit.tree.repo)
					diff = empty_tree.diff(commit.tree)
				end
				
				author = commit.author
				time = author[:time]
				@authors << author[:name]
				
				if @earliest_commit_at.nil? or time < @earliest_commit_at
					@earliest_commit_at = time
				end
				
				if @latest_commit_at.nil? or time > @latest_commit_at
					@latest_commit_at = time
				end
				
				diff.each_patch do |patch|
					delta = patch.delta
					path = delta.new_file[:path]
					
					parts = path.split(File::SEPARATOR)
					parts.unshift(File.basename(commit.tree.repo.workdir))
					parts.pop # Remove file name
					root = parts[0...@depth]
					
					@directories[root].add(commit, patch)
				end
			end
			
			def add(repository)
				walker = Rugged::Walker.new(repository)
				
				walker.sorting(Rugged::SORT_DATE)
				walker.push(repository.head.target.oid)
				
				walker.each do |commit|
					self << commit
				end
			end
		end
	end
end
