require 'singleton'
require_relative '../features/CivilFeatures.rb'
require_relative '../core/CivilHelper.rb'
require_relative '../tools/UtilitiesInterface.rb'

module RIO
	module Tools
		class UITools
			include Singleton
			@@rio_dialog = nil
			
			def initialize
				@dialog_width 	= 400
				@dialog_height 	= 650
				@dialog_url 		= RIOV3_ROOT_PATH + 'tools/tools_main.html'
				@style_window 	= UI::HtmlDialog::STYLE_WINDOW
				@style_dialog 	= UI::HtmlDialog::STYLE_DIALOG
			end

			def get_dialog
				@@rio_dimalog
			end
			
			def get_params_from_string param_str
				#Benchmark fast
				param_str = param_str[2..-2]
				elements_a = param_str.split('"@"')
				elements_a
			end

			def check_room_parameters input_h
				room_name = input_h[0]
				room_names = RIO::CivilHelper::get_room_names
				if room_names.include?(room_name)
					UI.messagebox "Room name already taken. Try something else"
					return false
				end
				return true
			end

			def door_face_identification input_face
				model 	= Sketchup.active_model
				ents	= model.entities
				input_face_edges = input_face.outer_loop.edges
				pts = []
				door_edges = input_face_edges.select{|ent| ent.layer.name == 'RIO_Door'}
				
				puts "door_edges : #{door_edges}"
				door_edges.each { |door_edge|
					puts "door_edge : #{door_edge}"
					faces = door_edge.faces
					door_vertices = door_edge.vertices
					
					common_edges = []
					perpendicular_edges = []
					input_face_edges.each{ |face_edge|
						common_edges << face_edge unless (face_edge.vertices&door_vertices).empty?
					}
					puts "coomon_edge : #{common_edges}"
					common_edges.each { |common_edge|
						perpendicular_edges << common_edge if door_edge.line[1].perpendicular?(common_edge.line[1])
					}
					if perpendicular_edges.empty?
						puts "Something peculiar about this door #{door_edge.persistent_id}"
						next
					end
					perpendicular_edges.sort_by!{|pedge| pedge.length}
					puts "perpendicular_edges : #{perpendicular_edges}"
					if perpendicular_edges.length == 2
						wall_edge = perpendicular_edges[0]
						if wall_edge.length < 251.mm
							offset_len 	= wall_edge.length
						else
							offset_len = 250.mm
						end
						tw_vector 	= RIO::CivilHelper::check_edge_vector door_edge, input_face
						puts "tw_vector : #{tw_vector}"
						#face_pts 	= [door_vertices[0].position]
						#face_pts 	<< door_vertices[0].position.offset(tw_vector, offset_len)
						#face_pts 	<< door_vertices[1].position.offset(tw_vector, offset_len)
						#face_pts	<< door_vertices[1].position
						if tw_vector
							pt1 = door_vertices[0].position.offset(tw_vector, offset_len)
							pt2 = door_vertices[1].position.offset(tw_vector, offset_len)
							pts << [pt1, pt2]
							
						end
						
						#new_face 	= ents.add_face(face_pts)
						#new_face.set_attribute(:rio_atts, 'wall_face', 'true')
					end
				}
				
				unless pts.empty?
					pre_ents = model.entities.to_a
					pts.each{|arr|
						new_line = ents.add_line(arr[0], arr[1])
						new_line.layer = Sketchup.active_model.layers['RIO_Door']
						new_line.set_attribute(:rio_edge_atts, 'new_edge', 'true')
					}
					post_ents = model.entities.to_a
					new_ents = post_ents - pre_ents
					new_faces = new_ents.grep(Sketchup::Face)
					puts "new_faces : #{new_faces}"
					unless new_faces.empty?
						new_faces.sort_by!{|ent| -ent.area}
						sel.clear
						sel.add(new_faces[0])
					end
				end
				
				return true
			end

			def create_room elements_a
				room_name 		= elements_a[0]
				wall_height 	= elements_a[1].to_f.mm
				door_height 	= elements_a[2].to_f.mm
				window_height	= elements_a[3].to_f.mm
				window_offset	= elements_a[4].to_f.mm 

				resp_flag = check_room_parameters(elements_a)
				puts "Room parameters check : #{resp_flag}"
				if resp_flag
					room_face = Sketchup.active_model.selection[0]
					resp = door_face_identification room_face

					puts "Doors identified #{resp}"
					if resp
						ob = RIO::CivilMod::PolyRoom.new(  :room_name=>room_name,
							:wall_height=>wall_height, 
							:door_height=>door_height,
							:window_height=>window_height, 
							:window_offset=>window_offset)
					end
				end
			end

			def get_room_names
				room_names = ["room 1", "room 2", "room 3"]
				js_command = "updateRoomNames("+ message.to_s + ")"
				@dialog.execute_script(js_command)
			end

			def check_room_face room_face
				no_layers_flag = true
				no_layer_edge_a = []
				room_face.edges.each { |face_edge|
					if face_edge.layer.name.start_with?('RIO')
						no_layers_flag = false
					else
						no_layer_edge_a << face_edge
					end
				}
				if no_layers_flag
					RIO::Utilities::ModalBox::no_layer_added
					return false
				elsif !no_layer_edge_a.empty?
					sel.clear
					sel.add(no_layer_edge_a)
					resp = UI.messagebox('Selected lines are not layered in this face. Shall we mark them as walls', MB_OKCANCEL)
					puts "resp : #{resp} : #{no_layer_edge_a}"
					if resp==1
						puts "Setting layers"
						no_layer_edge_a.each{|sel_edge|
							puts "edge : #{sel_edge}"
							sel_edge.layer=Sketchup.active_model.layers['RIO_Wall']
						}
					else
						return false
					end
				end
				return true
			end
			
			def create_dialog_room_addition
				# if @@rio_dialog && @@rio_dialog.visible?
				# 	puts "Dialog already open"
				# elsif @@rio_dialog && !@@rio_dialog.visible?
				# 	@@rio_dialog.show()
				# else
					dialog_hash = {}
					dialog_hash[:dialog_title] 	= 'Rio Dev Tools'
					dialog_hash[:scrollable]	= true
					dialog_hash[:resizable]		= true
					dialog_hash[:width]			= @dialog_width
					dialog_hash[:height]		= @dialog_height
					dialog_hash[:min_width]		= 50
					dialog_hash[:min_height]	= 50
					dialog_hash[:style]			= @style_dialog
					dialog_hash[:left]			= 100
					dialog_hash[:right]			= 100
					
					@@rio_dialog = UI::HtmlDialog.new(dialog_hash)
					@@rio_dialog.set_url(@dialog_url)
				
					@@rio_dialog.add_action_callback("rioCreateRoom"){|dialog, params|
						puts "Inside UI..   #{dialog} -- #{params}"
						elements_a = get_params_from_string params
						puts "elements_a : #{elements_a}"
						create_room(elements_a)
					}
					@@rio_dialog.add_action_callback("rioRemoveRoomComponents") {|dialog, params|
						puts "UIInt : rioRemoveRoomComponents"
						RIO::CivilHelper.remove_room_entities(params)
					}
					@@rio_dialog.show()
				#end
			end
		end
	end #module Tools

	def self.get_wall_location
		dialog_url 		= RIOV3_ROOT_PATH + 'tools/wall_location.html' 
		dialog_inputs_h = { :title		=>'Enter wall location',
							:scrollable	=>false,
							:resizable	=>false,
							:width 		=>400,
							:height		=>600
							#:style		=>UI::HtmlDialog::STYLE_DIALOG
						}
		wall_location_dialog = UI::HtmlDialog.new(dialog_inputs_h)
		wall_location_dialog.add_action_callback("sendWallLocation") { |dialog, params|
			inputs = params.split(',')
			from_wall 	= inputs[0].to_f.mm
			wall_side 	= inputs[1]
			from_floor 	= inputs[2].to_f.mm
			
			puts "sendWallLocation : #{inputs}"
			
			wall_selected = Sketchup.active_model.selection[0]
			unless wall_selected
				UI.messagebox "Nothing selected. Please select a wall."
				return false
			end
			
			block_type = wall_selected.get_attribute :rio_block_atts, 'block_type'
			unless block_type=='wall'
				UI.messagebox "Selection is not a wall"
				return false
			end
			
			towards_wall_v = wall_selected.get_attribute :rio_block_atts, 'towards_wall_vector' 
			
			#Get the wall vector			
			start_pt 	= wall_selected.get_attribute :rio_block_atts, 'start_point'
			end_pt 		= wall_selected.get_attribute :rio_block_atts, 'end_point'
			wall_vector = start_pt.vector_to(end_pt)
			
			wall_offset_point = RIO::CivilHelper::get_comp_location wall_selected, from_wall, from_floor , wall_side
			active_model = Sketchup.active_model

			active_model.set_attribute :rio_atts, 'room_name', wall_selected.get_attribute(:rio_block_atts, 'room_name')
			active_model.set_attribute :rio_atts, 'wall_offset_pt', wall_offset_point
			active_model.set_attribute :rio_atts, 'movement_vector', towards_wall_v
			active_model.set_attribute :rio_atts, 'wall_id', wall_selected.persistent_id
			active_model.set_attribute :rio_atts, 'wall_side', wall_side
			active_model.set_attribute :rio_atts, 'wall_vector', wall_vector
			active_model.set_attribute :rio_atts, 'wall_height', wall_selected.get_attribute(:rio_block_atts, 'wall_height')
			active_model.set_attribute :rio_atts, 'from_wall', from_wall
			active_model.set_attribute :rio_atts, 'from_floor', from_floor
			
			$rio_wall_trans = wall_selected.transformation
			
			puts "The start point is : #{from_wall} : #{from_floor} : #{wall_offset_point}"
			
			if true #only for the civil 
				carcass_path 	= File.join(RIOV3_ROOT_PATH, 'assets/BC_800.skp')
				defn 			= Sketchup.active_model.definitions.load(carcass_path)
				
				RIO::CivilHelper::place_component defn, 'wall'
			end
		}
		wall_location_dialog.set_url(dialog_url);
		wall_location_dialog.show();
	end
	
	UI.add_context_menu_handler do |menu|
		model = Sketchup.active_model
		selected_entity = model.selection[0]
		if selected_entity 
			case selected_entity
			when Sketchup::Face
				rbm = menu.add_submenu("Add RIO Comp-->")
				face_normal = selected_entity.normal
				if face_normal.parallel?(Z_AXIS)
					rbm.add_item("Column") {
						comp_inst = RIO::CivilHelper::create_single_column selected_entity.outer_loop.edges, column_face: selected_entity
						if comp_inst 
							puts "Column created successfully"
						else
							puts "Column creation issue"
						end
					} 
				else
					rbm.add_item("Beam") { RIO::CivilHelper.create_beam(selected_entity) }
				end
			when Sketchup::Group
				puts "Group selected"
			when Sketchup::ComponentInstance
				comp_type = selected_entity.get_attribute(:rio_block_atts, 'block_type')
				puts "Comp type : #{comp_type}"	
				case comp_type
				when 'wall'
					menu.add_item("Fix Rio Component") {
						get_wall_location
					}
				else
				end
			end
		end
	end
end
