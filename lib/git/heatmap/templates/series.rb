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

require 'trenni/template'

require_relative '../commits'

module Git
	module Heatmap
		module Templates
			class Series
				def self.template
					Trenni::Template.load_file(File.expand_path("series/template.trenni", __dir__))
				end
				
				def initialize(commits, title:, template: self.class.template)
					@commits = commits
					@title = title
					
					@template = template
				end
				
				attr :commits
				attr :title
				
				def ramp(i, max = commits.maximum)
					x = i.to_f / max
					
					# Smoothstep:
					# return (3*x*x - 2*x*x*x)
					
					return Math::sqrt(x)
				end
				
				def interpolate(t, x, y)
					r = x.dup
					
					r.size.times{|i| r[i] = (x[i].to_f * (1.0 - t)) + (y[i].to_f * t)}
					
					return r
				end
				
				# t between 0...1
				def temperature(t, colors)
					p = (t.to_f * colors.size)
					
					if (p <= 0)
						return colors.first
					end
					
					if (p+1 >= colors.size)
						return colors.last
					end
					
					return interpolate(p - p.floor, colors[p.floor], colors[p.floor+1])
				end
				
				def hexcolor(c)
					'#' + c.collect{|k| k.to_i.to_s(16).rjust(2, '0')}.join
				end
				
				def background_color(size)
					temp = temperature(ramp(size.to_f), [
						[0xFF, 0xFF, 0xFF],
						#[0x04, 0x05, 0x57],
						
						#[0x17, 0xD3, 0xFF],
						[0x4D, 0x85, 0xFF],
						
						# [0x02, 0xB1, 0x50], # Green
						
						#[0xF2, 0xFD, 0xA0], # Yellow
						[0xF4, 0xFB, 0x13],
						
						[255, 0x05, 0x05],	# Red
						# [255, 200, 200]
					])
					
					return hexcolor(temp)
				end
				
				def call
					@template.to_string(self)
				end
			end
		end
	end
end
