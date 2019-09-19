require 'singleton'
require_relative 'multi_room_preprocess.rb'
require_relative 'multi_room_door.rb'
require_relative '../tools/UIInterface.rb'

class RoomTool
	include Singleton	
		
	def initialize
		@count = 1
		@colors = Sketchup::Color.names
		#puts "@count : #{@count}"
	end
	
	def activate
		Sketchup.active_model.selection.clear
		Sketchup.active_model.entities.grep(Sketchup::Edge).each{|edge| edge.find_faces}
		DP::add_face_attributes
		# puts 'Your tool has been activated.'
	end
	
	def deactivate(view)
		DP::clear_face_attributes
		# puts "deactivate"
	end
	
	def onCancel(flag, view)
		# puts "onCancel"
		Sketchup.active_model.select_tool(nil)
	end
	
	def reduce_count
		@count-=1
	end

	def get_color
		@colors.shuffle!
		@colors.shuffle!
		#puts "@colors : #{@colors} : #{@colors.length}"
		@colors.pop
	end

	def get_count
		@count
	end
	
	def clicked_face view, x, y
		ph = view.pick_helper
		ph.do_pick x, y
		face = ph.best_picked
		return nil unless face.is_a?(Sketchup::Face)
		return face
	end
	
	def get_space_inputs face
		space_dialog = UI::HtmlDialog.new({:dialog_title=>"RioSTD - Space Type", :preferences_key=>"com.rio.plugin", :scrollable=>false, :resizable=>false, :style=>UI::HtmlDialog::STYLE_DIALOG})
		html_path = File.join(WEBDIALOG_PATH, 'load_spacetype.html')
		space_dialog.set_file(html_path)
		space_dialog.set_size(400, 480)
		space_dialog.center
		space_dialog.show

		space_dialog.add_action_callback("spacetype"){|dlg, param|
			mainarr = []
			edges = face.edges
			door_flag = false
			window_flag = false
			spname = "Room#"+get_count.to_s
			mainarr.push("space_name|"+spname)

			edges.each {|edge|
				layer_name = edge.layer.name
				if layer_name == 'Door'
					mainarr.push("door_flag|1")
				else
					mainarr.push("door_flag|0")
				end

				if layer_name == 'Window'
					mainarr.push("window_flag|1")
				else
					mainarr.push("window_flag|0")
				end
			}
			jstype = "passSpaceType("+mainarr.to_s+")"
			space_dialog.execute_script(jstype)
		}

		space_dialog.add_action_callback("submitspace"){|dlg, param|
			space_dialog.close
			inputs = JSON.parse(param)
			# p inputs
			puts "Room inputs V2 : #{inputs}"
			if inputs
				space_names = DP::get_space_names
				MRD::add_wall_faces
				if space_names.include?(inputs['space_name'])
					UI::messagebox 'Name already taken. Please input an Unique name to the room'
					#inputs 		= get_space_inputs face
					Sketchup.active_model.selection.clear
					#Sketchup.active_model.selection.add face
					#DP::add_spacetype inputs, face
				else
					Sketchup.active_model.selection.clear
					Sketchup.active_model.selection.add face
					wall_color 	= get_color
					#MRP::raise_walls face, inputs, wall_color
					res_face = MRD::get_face_views face, inputs, wall_color
					if V2_V3_CONVERSION_FLAG
						 converted_inputs = [
							inputs['space_name'],
							inputs['wall_height'],
							inputs['door_height'],
							inputs['window_height'],
							inputs['window_offset']
						]
						RIO::Tools::UITools.instance.create_room converted_inputs
					else
						DP::add_spacetype inputs, res_face
					end
					@count += 1
				end
				# space_arr 	= DP::get_space_names
				# getlist 	= Decor_Standards::add_option(space_arr)
				# jsadd 		= "passSpaceList("+getlist.to_s+")"
				# $rio_dialog.execute_script(jsadd)
			end
		}

		space_dialog.add_action_callback("canceldlg"){|dlg, param|
			space_dialog.close
		}
	end

	def get_space_inputs_back face
		edges 		= face.edges
		door_flag 	= false
		window_flag	= false

		edges.each { |edge|
			layer_name	= edge.layer.name
			if layer_name == 'Door'
				door_flag 	= true
			elsif layer_name == 'Window'
				window_flag = true
			end
		}
		input_h = {'space_type'=>'',
					'space_name'=>'',
					'wall_height'=>'',
					'door_height'=>'',
					'window_height'=>'',
					'window_offset'=>'',
				}

		prompts 	= ["Space Type","Name","Wall height"]
		
		defaults 	= ["Kitchen"]
		defaults << "Room#"+get_count.to_s
		defaults << 2000
		list 		= ["Kitchen|Wash Room|Bed Room|Living Room|Balcony"]
		
		if door_flag
			prompts << "Door height" 
			defaults << 1200
		end
		if window_flag
			prompts	<< "Window height" 
			prompts	<< "Window offset(from floor)"
			defaults << 600
			defaults << 600
		end
		
		input 		= UI.inputbox(prompts, defaults, list, "Space Type.")
		if input
			name 	= input[1].start_with?('Room#')
			# puts "name : #{name} : #{input[1]}"
			# puts "prompts : #{prompts}"
			input_h['space_type']	=input[0]
			input_h['space_name']	=input[1]
			input_h['wall_height']	=input[2]
			input_h['door_height']	=input[3]
			input_h['window_height']=input[4]
			input_h['window_offset']=input[5]
			
			return input_h
		end
		return false
	end
	
	def onLButtonDown(flags,x,y,view)
		#@count+=1
		#wall_color = @colors.shuffle.last
		#puts "wall_color : #{wall_color}"
		#@colors.delete wall_color
		
		input_point = view.inputpoint x, y
		face 		= clicked_face view, x, y
		# puts "onLButtonDown : #{@count} : #{face}"
		if face && face.is_a?(Sketchup::Face)
			inputs 		= get_space_inputs face 
			# puts "inputs----#{inputs}"
			# if inputs
			# 	space_names = DP::get_space_names
			# 	if space_names.empty?
			# 		MRD::add_wall_faces
			# 	end
			# 	if space_names.include?(inputs['space_name'])
			# 		UI::messagebox 'Name already taken. Please input an Unique name to the room'
			# 		#inputs 		= get_space_inputs face
			# 		Sketchup.active_model.selection.clear
			# 		#Sketchup.active_model.selection.add face
			# 		#DP::add_spacetype inputs, face
			# 	else
			# 		Sketchup.active_model.selection.clear
			# 		Sketchup.active_model.selection.add face
			# 		wall_color 	= get_color
			# 		#MRP::raise_walls face, inputs, wall_color
			# 		res_face = MRD::get_face_views face, inputs, wall_color
			# 		DP::add_spacetype inputs, res_face
			# 		@count += 1
			# 	end
			# 	# space_arr 	= DP::get_space_names
			# 	# getlist 	= Decor_Standards::add_option(space_arr)
			# 	# jsadd 		= "passSpaceList("+getlist.to_s+")"
			# 	# $rio_dialog.execute_script(jsadd)
			# end
		else
			puts "Click on face to add room"
		end	
	end
	
end

