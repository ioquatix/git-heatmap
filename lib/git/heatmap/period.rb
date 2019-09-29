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

module Git
	module Heatmap
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
				return to_enum(:between, first, last) unless block_given?
				
				current = first
				offset = 0
				
				while true
					current = key(first, offset)
					
					if current <= last
						yield current
					else
						break
					end
					
					offset += 1
				end
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
	end
end
