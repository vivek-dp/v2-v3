module CP
	class ColorPicker
		def activate
			@x1 = 5     # x location of top left corner of color picker - 5 default
		  @y1 = 5     # y location of top left corner of color picker - 5 default
		  @h = 256    # height of color pickers - 256 default
		  @h1 = 50    # height of color box - 50 default
		  @h2 = 20    # height of RGB, OK, and Cancel boxes - 20 default
		  @spacer = 20    # Space between Rainbow Strip and Gradient Square - 20 default  
		  @spacer2 = 10   # Space between RGB, OK, and Cancel boxes - 10 default
		  @w1 = 256    # Width of Gradient square - 256 default
		  @w2 = 20    # Width of Rainbow strip - 20 default
		  @w3 = 70    # Width of 3rd row of buttons - 70 default
		  @grad_chunk = 8   # Controls the gradient pixelation - Must be an even integer (2,4,8,16,32,64) - 8 default
		  @b_off = 5    # Controls the size of the black window for the color picker - 5 default
		  @w_off = 4    # Controls the size of the white window for the color picker - 4 default

		  @mouse_down = false
		  @box1 = false
		  @box2 = false
		  @rainbow_percent = 100
		  @base_col = val_to_col(@rainbow_percent)
		  @selected_col = @base_col
		  @clear = false
		  
		  @left_color = []
		  @black_col = Sketchup::Color.new(0,0,0)
		  @white_col = Sketchup::Color.new(255,255,255)
		  @grid_x = 0
		  @grid_y = 0
		  
		  @rgb_prompt = ["R: ", "G: ", "B: "]
		  @rgb_default = [@selected_col.to_a[0],@selected_col.to_a[1],@selected_col.to_a[2]]
		  @rbg_box_title = "RGB color Specifier"
		  self.draw_ui # Set the rest of the parameters before invalidating the view
		  
		  Sketchup.active_model.active_view.invalidate
		end

		def draw_ui
		  @x2 = @x1+@w1
		  @y2 = @y1+@h
		  @x3 = @x2+@spacer
		  @x4 = @x3+@w2 
		  @x5 = @x4 + @spacer
		  @x6 = @x5 + @w3
		  @rgbx1 = @x5
		  @rgbx2 = @x6
		  @rgbyr1 = @y1+@h1+@spacer2
		  @rgbyr2 = @rgbyr1+@h2
		  @rgbyg1 = @rgbyr2+@spacer2
		  @rgbyg2 = @rgbyg1+@h2
		  @rgbyb1 = @rgbyg2+@spacer2
		  @rgbyb2 = @rgbyb1+@h2
		  @oky1 = @rgbyb2+@spacer2
		  @oky2 = @oky1+@h2
		  @cancely1 = @oky2+@spacer2
		  @cancely2 = @cancely1+@h2
		  @rgb_text_x1 = @x5+10
		  @rgb_text_y1 = @rgbyr1
		  @rgb_text_y2 = @rgbyg1
		  @rgb_text_y3 = @rgbyb1
		  @ok_text_y = @oky1
		  @cancel_text_y = @cancely1
		  @win1 = [[@x1,@y1],[@x2,@y1],[@x2,@y2],[@x1,@y2]]
		  @win2 = [[@x3,@y1],[@x4,@y1],[@x4,@y2],[@x3,@y2]]
		  @win3 = [[@x5,@y1],[@x6,@y1],[@x6,@y1+@h1],[@x5,@y1+@h1]]
		  @winr = [[@rgbx1,@rgbyr1],[@rgbx2,@rgbyr1],[@rgbx2,@rgbyr2],[@rgbx1,@rgbyr2]]
		  @wing = [[@rgbx1,@rgbyg1],[@rgbx2,@rgbyg1],[@rgbx2,@rgbyg2],[@rgbx1,@rgbyg2]]
		  @winb = [[@rgbx1,@rgbyb1],[@rgbx2,@rgbyb1],[@rgbx2,@rgbyb2],[@rgbx1,@rgbyb2]]
		  @winok = [[@rgbx1,@oky1],[@rgbx2,@oky1],[@rgbx2,@oky2],[@rgbx1,@oky2]]
		  @wincancel = [[@rgbx1,@cancely1],[@rgbx2,@cancely1],[@rgbx2,@cancely2],[@rgbx1,@cancely2]]
		  @windows = [@win1, @win2, @win3, @winr, @wing, @winb, @winok, @wincancel]
		  @current_y = @y1
		  @color_y_depth_adjustor = 255.to_f/@h.to_f
		  #screen_to_grid(@x1,@y1)
		  @grid_xy = [@grid_x,@grid_y]
		end

		def getMenu(menu)
		  menu.add_item("Color Picker Settings") do
			  prompts = ["X Position", "Y Position", "Size", "Gradient Detail"]
			  defaults = [@x1,@y1,@h,@grad_chunk]
			  list = ["", "", "32|64|128|256|512", "1|2|4|8|16|32"]
			  results = UI.inputbox prompts, defaults, list, "Color Picker Settings"

			  @x1 = results[0]
			  @y1 = results[1]
			  @h = results[2]
			  @w1 = results[2]
			  @grad_chunk = results[3]
			  draw_ui
			  Sketchup.active_model.active_view.invalidate
		  end
		  menu.add_item("Low Res") do
		   	@w1 = 128
			  @h = 128
		   	@grad_chunk = 16
			  draw_ui
		   	Sketchup.active_model.active_view.invalidate
		  end
		  menu.add_item("Medium Res") do
		   	@w1 = 256
		   	@h = 256
		   	@grad_chunk = 8
		   	draw_ui
		   	Sketchup.active_model.active_view.invalidate
		  end
		  menu.add_item("High Res") do
		   	@w1 = 512
		   	@h = 512
		   	@grad_chunk = 4
		   	draw_ui
		   	Sketchup.active_model.active_view.invalidate   
		  end
		  menu.add_item("Reset Location") do
		   	@x1 = 5
		   	@y1 = 5
		   	draw_ui
		   	Sketchup.active_model.active_view.invalidate
		  end
		end

		def rgb_to_hsv(results)
			r = (results[0]/255.0)
			g = (results[1]/255.0)
			b = (results[2]/255.0)
			color = [r,b,g]
			color.sort!
			value = color[2]
			if value == 0
				return [0,0,0]
			end
			r = r/color[2]
			g = g/color[2]
			b = b/color[2]
			color = [r,b,g]
			color.sort!
			max_col = color[2]
			min_col = color[0]
			saturation = (max_col - min_col)
			if saturation == 0
				return [0,saturation,value]
			end
			r = (r-min_col)/(max_col - min_col)
			g = (g-min_col)/(max_col - min_col)
			b = (b-min_col)/(max_col - min_col)
			color = [r,b,g]
			color.sort!
			max_col = color[2]
			min_col = color[0]

			if r == max_col
				hue = 0.0 + 60.0*(g - b)
				if (hue < 0.0)
					hue += 360.0
				end
			elsif max_col == g
				hue = 120.0 + 60.0*(b - r);
			else
				hue = 240.0 + 60.0*(r - g);
			end
			return [hue, saturation,value]
		end

		def screen_to_grid(x,y)
			x = (1.0/@w1.to_f)*(x-@x1)
			y = (1.0/@h.to_f)*(y-@y1)
			x = 0.0 if x < 0.0
			y = 0.0 if y < 0.0
			x = 1.0 if x > 1.0
			y = 1.0 if y > 1.0
			@grid_x = x
			@grid_y = y
		end

		def get_rgb(x,y)
			if @box1
				screen_to_grid(x,y)
			end
			xy_percent = [@grid_x, @grid_y]
			left_col = @black_col.blend @white_col, xy_percent[1]
			right_col = @black_col.blend @base_col, xy_percent[1]
			@selected_col = right_col.blend left_col, xy_percent[0]
		end

		def within(x,y)
			pt = [x,y]
			@windows.each_with_index do |box, index|
				return index if Geom.point_in_polygon_2D(pt, box, true)
			end
			false
		end

		def onLButtonDown(flags, x, y, view)
			box_num = within(x,y)
			case box_num
			when 0
				get_rgb(x,y)
				@box1 = true
				@grid_xy = [x,y]
				get_rgb(x,y)
			when 1
				@box2 = true
				@rainbow_percent = (((y-@y1).to_f/@h.to_f)*100.0).to_i
				@base_col = val_to_col(@rainbow_percent)
				get_rgb(x,y)
			when 2
				@box3 = true
				final_rgb = @selected_col.to_a
				@x_start = x
				@y_start = y
				@base_x = @x1
				@base_y = @y1
				@base_grid_x = @grid_xy[0]
				@base_grid_y = @grid_xy[1]
			when 3,4,5
				@rgb_default = [@selected_col.to_a[0],@selected_col.to_a[1],@selected_col.to_a[2]]
				results = UI.inputbox @rgb_prompt, @rgb_default, @rbg_box_title
				if results
					results[0] = 0 if results[0] < 0
					results[1] = 0 if results[1] < 0
					results[2] = 0 if results[2] < 0
					results[0] = 255 if results[0] > 255
					results[1] = 255 if results[1] > 255
					results[2] = 255 if results[2] > 255
					@selected_col = [results[0], results[1], results[2]]
					hsv = rgb_to_hsv(@selected_col)
					@grid_x = ((hsv[1]*@h)+@x1)
					@grid_y = ((@w1-(hsv[2]*@w1))+@y1)
					@rainbow_percent = (hsv[0]*100)/360
					@base_col = val_to_col(@rainbow_percent)
					draw_ui
				end
			when 6
				Sketchup.active_model.set_attribute(:rio_global, 'last_color_picked', @selected_col.to_s)
				deactivate view
			when 7
				deactivate view
				UI.messagebox 'Color not selected!', MB_OK
			end
			@mouse_down = true
			view.invalidate
		end

		def onLButtonUp(flags, x, y, view)
			@mouse_down = false
			@box1 = false
			@box2 = false
			@box3 = false
			view.invalidate
		end

		def onMouseMove(flags, x, y, view)
			if (@mouse_down)&&(@box1)
				x = @x1 if x-@x1 < 0
				y = @y1 if y-@y1 < 0
				x = @x2 if x-@x2 > 0
				y = @y2 if y-@y2 > 0
				@grid_xy = [x,y]
				get_rgb(x,y)
			end
			if (@mouse_down) && (@box2)
				@rainbow_percent = (((y-@y1).to_f/@h.to_f)*100.0).to_i
				@base_col = val_to_col(@rainbow_percent)
				@rainbow_percent = 100 if @rainbow_percent > 100
				@rainbow_percent = 0 if @rainbow_percent < 0
				get_rgb(x,y)
			end
			if (@mouse_down) && (@box3)
				@x_offset = x - @x_start
				@y_offset = y - @y_start
				@grid_x_offset = x - @x_start
				@grid_y_offset = y - @y_start
				@x1 = (@base_x + @x_offset)
				@y1 = (@base_y + @y_offset)
				@grid_x = (@base_grid_x + @grid_x_offset)
				@grid_y = (@base_grid_y + @grid_y_offset)
				draw_ui
				view.invalidate
			end
			view.invalidate
		end

		def val_to_col(value = 0, max = 100, min = 0)
			clr = []
			clr << Sketchup::Color.new(255,0,0)
			clr << Sketchup::Color.new(255,255,0)
			clr << Sketchup::Color.new(0,255,0)
			clr << Sketchup::Color.new(0,255,255)
			clr << Sketchup::Color.new(0,0,255)
			clr << Sketchup::Color.new(255,0,255)
			clr << Sketchup::Color.new(255,0,0)
			# Cap value to range.
			value = [min, value].max
			value = [max, value].min
			# Calculate what colours to blend between and the blending ratio.
			n = (value-min) / ( (max-min) / (clr.length-1.0) )
			index1 = n.to_i
			index2 = [index1+1, clr.length-1].min
			ratio = n - index1
			return clr[index2].blend(clr[index1], ratio)
		end

		def draw(view)
			unless @clear
			@h.times do |col|
				view.drawing_color = val_to_col col, @h
				view.draw2d GL_LINES, [@x3, @current_y], [@x4,@current_y]
				@current_y +=1
			end
			@current_y = @y1
			# Draw the Square Gradient
			(@h/@grad_chunk).times do |row|
				grey_num = ((((@h/@grad_chunk)-row)*@color_y_depth_adjustor*@grad_chunk).to_i)
				@left_color = Sketchup::Color.new(grey_num,grey_num,grey_num)
				@right_color = @black_col.blend @base_col, ((row*@grad_chunk).to_f/@h.to_f)
				(@w1/@grad_chunk).times do |column|
					view.drawing_color = @right_color.blend @left_color, ((column*@grad_chunk).to_f/@w1.to_f)
					view.draw2d GL_QUADS, [(column*@grad_chunk)+@x1+@grad_chunk,(row*@grad_chunk)+@y1+@grad_chunk], [(column*@grad_chunk)+@x1+@grad_chunk,(row*@grad_chunk)+@y1], [(column*@grad_chunk)+@x1,(row*@grad_chunk)+@y1],[(column*@grad_chunk)+@x1,(row*@grad_chunk)+@y1+@grad_chunk]
				end
			end

			#Draw the Actual Color box (win3)
			view.drawing_color = @selected_col
			view.draw2d GL_QUADS, @win3

			# Draw the white out backgrounds
			view.drawing_color = @white_col
			view.draw2d GL_QUADS, @winr
			view.draw2d GL_QUADS, @wing
			view.draw2d GL_QUADS, @winb
			view.draw2d GL_QUADS, @winok
			view.draw2d GL_QUADS, @wincancel

			#Draw the strip for the Rainbow Picker
			view.drawing_color = @black_col
			view.line_width = 5
			y_val = (((@rainbow_percent.to_f/100.0)*@h.to_f)+@y1.to_f)
			view.draw2d GL_LINES, [@x1+@w1+@spacer-13, y_val], [@x1+@w1+@spacer-1, y_val], [@x1+@w1+@spacer+@w2+1, y_val], [@x1+@w1+@spacer+@w2+13, y_val]
			view.line_width = 1


			# Draw the RGB, OK, Cancel boxes text
			view.draw_text [@rgb_text_x1,@rgb_text_y1+1], "R: #{@selected_col.to_a[0]}"
			view.draw_text [@rgb_text_x1,@rgb_text_y2+1], "G: #{@selected_col.to_a[1]}"
			view.draw_text [@rgb_text_x1,@rgb_text_y3+1], "B: #{@selected_col.to_a[2]}"
			view.draw_text [@rgb_text_x1+17, @ok_text_y+1], "OK"
			view.draw_text [@rgb_text_x1+5, @cancel_text_y+1], "Cancel"


			# Draw the outline lines of all the boxes
			@windows.each { |win| view.draw2d GL_LINE_LOOP, win }

			# Draw the Square Gradient Picker Window (blac outline first)
			view.draw2d GL_LINE_STRIP, [@grid_xy[0]-@b_off, @grid_xy[1]-@b_off], [@grid_xy[0]+@b_off, @grid_xy[1]-@b_off], [@grid_xy[0]+@b_off, @grid_xy[1]+@b_off], [@grid_xy[0]-@b_off, @grid_xy[1]+@b_off], [@grid_xy[0]-@b_off, @grid_xy[1]-@b_off]


			# Draw the white outline for the square gradient cursor
			view.drawing_color= @white_col
			view.draw2d GL_LINE_STRIP, [@grid_xy[0]-@w_off, @grid_xy[1]-@w_off], [@grid_xy[0]+@w_off, @grid_xy[1]-@w_off], [@grid_xy[0]+@w_off, @grid_xy[1]+@w_off], [@grid_xy[0]-@w_off, @grid_xy[1]+@w_off], [@grid_xy[0]-@w_off, @grid_xy[1]-@w_off]
			end
		end

		def resume(view)
			view.invalidate
		end

		def deactivate(view)
			@clear = true
			view.invalidate
		end
	end #class ColorPicker

	def self.call_picker
		Sketchup.active_model.select_tool(ColorPicker.new)
	end
end #module CP