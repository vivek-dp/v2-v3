module MultiRoomLib
	def self.add_text_to_face face, text
		temp_group 			= Sketchup.active_model.entities.add_group
		temp_entity_list 	= temp_group.entities
		text_scale 			= face.bounds.height/50
		temp_entity_list.add_3d_text(text,  TextAlignCenter, "Arial", false, false, text_scale)
		text_component 		= temp_group.to_component
		text_definition 	= text_component.definition
		text_component.erase!

		text_inst 			= Sketchup.active_model.entities.add_instance text_definition, Geom::Transformation.new(face.bounds.center)
		text_inst
	end
	
	def self.get_window_faces
		window_faces = []
		Sketchup.active_model.entities.grep(Sketchup::Face).each{|face|
			face_edges = face.edges
			next if face.edges.length != 4
			window_faces << face if face.edges.select{|ed| ed.layer.name == 'Wall'}.length == 2 && face.edges.select{|ed| ed.layer.name == 'Window'}.length == 2
		}
		window_faces
	end
	
	#Send an Array with pushed elements ....use array.push
	def self.find_adj_window_face arr=[]
		puts "arr : #{arr} #{arr.length}"
		window_faces = get_window_faces
		if arr.length == 3
			return arr
		else
			face = arr.last
			face.edges.each{|edge|
				edge.faces.each{|face|
					if window_faces.include?(face) && !arr.include?(face)
						arr.push(face)
						find_adj_window_face arr
					end
				}
			}
			return arr 
		end
	end
	
	def self.check_sliding_door edge, height
		sliding_door = nil
		edge.faces.each{ |face| 
			if face.edges == 4
				door_edges 		= face.edges.select{|edge| edge.layer.name == 'Door'}
				sliding_door 	= face if door_edges.length == 3
			end
		}
	end

	def self.create_spacetype space_face, space_inputs, create_face_flag=false
		Sketchup.active_model.start_operation '2d_to_3d'
		puts "create_space : #{space_inputs}"
		if space_inputs.is_a?(Array)
			space_type 		= space_inputs[0]
			space_name		= space_inputs[1]
			wall_height		= space_inputs[2].to_i.mm
			door_height		= space_inputs[3].to_i.mm
			window_height	= space_inputs[4].to_i.mm
			window_offset	= space_inputs[5].to_i.mm
		else
			space_type 		= space_inputs['space_type']
			space_name		= space_inputs['space_name']
			wall_height		= space_inputs['wall_height'].to_i.mm
			wall_thickness  = space_inputs['wall_thickness'].to_i.mm
			door_height		= space_inputs['door_height'].to_i.mm
			window_height	= space_inputs['window_height'].to_i.mm
			window_offset	= space_inputs['window_offset'].to_i.mm
		end
	
		
		zvector 		= Geom::Vector3d.new(0, 0, 1)
		model			= Sketchup.active_model
		ents			= model.entities
		seln 			= model.selection
		layers			= model.layers

		if seln.length == 0
			Sketchup.active_model.abort_operation
			puts "No Component selected" 
			return false
		end
		#space_face 		= seln[0]
		if !space_face.is_a?(Sketchup::Face)
			puts "Selection is not a face" 
			return
		end
		space_face.set_attribute :rio_atts, 'floor_name', space_name
		floor_layer		= Sketchup.active_model.layers.add 'DP_Floor_'+space_name
		wall_layer		= Sketchup.active_model.layers.add 'DP_Wall_'+space_name
		space_face.layer= floor_layer
		text_inst 		= add_text_to_face space_face, space_name
		
		space_edges		= space_face.outer_loop.edges 
		#Add walls
		wall_faces_group	= Sketchup.active_model.entities.add_group
		temp_entity_list 	= wall_faces_group.entities

		puts "#{space_edges} : #{space_face}"
		wall_faces 	= []
		space_edges.each{ |edge|
			if edge.layer.name == 'Wall' 
				vertices	= edge.vertices
				pt1 		= vertices[0].position
				pt2			= vertices[1].position

				pt3			= pt2.offset(zvector, wall_height)
				pt4			= pt1.offset(zvector, wall_height)
				
				wall_face 	= ents.add_face pt1, pt2, pt3, pt4
				wall_face.layer = 'DP_Wall'
				wall_faces << wall_face
			elsif edge.layer.name == 'Door'
				#sliding_door_flag = check_sliding_door edge
			end
		}

		#----------------------------Add door top face-----------------------------
		if door_height
			space_edges.each {|edge|
				if edge.layer.name == 'Door' 
					vertices	= edge.vertices
					pt1 		= vertices[0].position.offset(zvector, door_height)
					pt2			= vertices[1].position.offset(zvector, door_height)

					pt3			= vertices[1].position.offset(zvector, wall_height)
					pt4			= vertices[0].position.offset(zvector, wall_height)

					wall_face 	= ents.add_face pt1, pt2, pt3, pt4
					wall_face.layer = 'DP_Wall'
					wall_faces << wall_face
				end
				
			}
		else
			#Create walls for windows and doors
			if edge.layer.name == 'Door' 
				vertices	= edge.vertices
				pt1 		= vertices[0].position
				pt2			= vertices[1].position

				pt3			= pt2.offset(zvector, wall_height)
				pt4			= pt1.offset(zvector, wall_height)
				
				wall_face 	= ents.add_face pt1, pt2, pt3, pt4
				wall_face.layer = 'DP_Wall'
				wall_faces << wall_face
			end
		end

		#----------------------------Add door top face-----------------------------
		if window_height
			puts "window h :#{window_height}"
			puts "window o :#{window_offset}"
			combined_ht = (window_offset+window_height).mm
			height_arr = [window_offset, combined_ht, wall_height]
			puts "height_arr : #{height_arr}"
			#This algorithm will create a single 
			space_edges.each {|edge|
				if edge.layer.name == 'Window' 
					vertices	= edge.vertices
					
					#Normal wall rise for Window
					pt1 		= vertices[0].position
					pt2			= vertices[1].position

					pt3			= pt2.offset(zvector, window_offset)
					pt4			= pt1.offset(zvector, window_offset)

					puts "Window pts : #{pt1} : #{pt2} : #{pt3} : #{pt4} " 
					wall_face 	= ents.add_face pt1, pt2, pt3, pt4
					wall_face.layer = 'DP_Wall'
					wall_faces << wall_face
					#wall_face.edges.each{|ed| (ents.erase_entities ed) if (ed.line[1] == zvector || ed.line[1] == zvector.reverse)}

					#Extra face for window only when the combined height is less than Wall height
					if (window_offset+window_height < wall_height)
						pt1 		= vertices[0].position.offset(zvector, window_offset+window_height)
						pt2			= vertices[1].position.offset(zvector, window_offset+window_height)

						pt3			= vertices[1].position.offset(zvector, wall_height)
						pt4			= vertices[0].position.offset(zvector, wall_height)

						wall_face 	= ents.add_face pt1, pt2, pt3, pt4
						wall_face.layer = 'DP_Wall'
						wall_faces << wall_face
					end
					window_face 	= edge.faces
					window_face.delete space_face
					window_faces = find_adj_window_face [window_face[0]]
					
					edge_array = []
					window_faces.each{|wface| edge_array << wface.edges}
					edge_array.flatten!.uniq!.select!{|x| x.layer.name=='Window'}
					
					edge_array.sort_by!{|x| x.bounds.center.distance edge.bounds.center}
					sel.add(edge_array.last)
					last_edge 	= edge_array.last
					
					
					#puts "height_arr : #{height_arr}"
					# height_arr.each { |face_height|
						# puts "face_height : #{face_height}"
						# window_faces.each{|face|
							# verts = face.vertices
							# pt_arr = []
							# verts.each{|pt|
								# pt_arr << pt.position.offset(zvector, face_height)
							# }
							# temp_face = ents.add_face(pt_arr) if pt_arr
							# wall_faces << temp_face
						# }
					# }
					#Removing the loop above......Dunno why it doesnt work for unit conversion.....window_height+window_offset doesnt work :(
					temp_arr = []
					temp_face = nil
					window_faces.each{|face|
							verts = face.vertices
							pt_arr = []
							verts.each{|pt|
								pt_arr << pt.position.offset(zvector, window_offset)
							}
							temp_face = ents.add_face(pt_arr) if pt_arr
							#temp_arr << [temp_face, window_offset]
							wall_faces << temp_face
					}
					
					verts 	= last_edge.vertices
					ledge1 	= verts[0].position
					ledge2 	= verts[1].position
					pt3		= ledge2.offset(zvector, window_offset)
					pt4		= ledge1.offset(zvector, window_offset)
					temp_face = ents.add_face(ledge1, ledge2, pt3, pt4) #Down back  window face
					wall_faces << temp_face
					
					
					pt1 	= ledge1.offset(zvector, window_offset+window_height)
					pt2 	= ledge2.offset(zvector, window_offset+window_height)
					pt3		= ledge2.offset(zvector, wall_height)
					pt4		= ledge1.offset(zvector, wall_height)
					temp_face = ents.add_face(pt1, pt2, pt3, pt4) #Up back window face
					wall_faces << temp_face
					
					window_faces.each{|face|
							verts = face.vertices
							pt_arr = []
							verts.each{|pt|
								pt_arr << pt.position.offset(zvector, window_height+window_offset)
							}
							temp_face = ents.add_face(pt_arr) if pt_arr
							wall_faces << temp_face
					}
					window_faces.each{|face|
							verts = face.vertices
							pt_arr = []
							verts.each{|pt|
								pt_arr << pt.position.offset(zvector, wall_height)
							}
							temp_face = ents.add_face(pt_arr) if pt_arr
							reverse_offset = door_height - (window_height+window_offset)
							#temp_arr << [temp_face, reverse_offset]
							wall_faces << temp_face
					}
					
				end
				
			}
		else
			#Create walls for windows and doors
			space_edges.each {|edge|
				if edge.layer.name == 'Window' 
					vertices	= edge.vertices
					pt1 		= vertices[0].position
					pt2			= vertices[1].position

					pt3			= pt2.offset(zvector, wall_height)
					pt4			= pt1.offset(zvector, wall_height)
					
					window_face 	= ents.add_face pt1, pt2, pt3, pt4
					window_face.layer = 'DP_Window'
					wall_faces << window_face
				end
			}
		end



		#pre processingo
		prev_active_layer 	= Sketchup.active_model.active_layer.name
		model.active_layer 	= floor_layer
		floor_group 		= model.active_entities.add_group(space_face, text_inst)

		model.active_layer 	= wall_layer
		color_array 		= Sketchup::Color.names
		wall_color			= color_array[rand(140)]
		wall_faces.each{|wall|
			wall.material 		= wall_color
			wall.back_material 	= wall_color
		}
		wall_group 			= model.active_entities.add_group(wall_faces)

		model.active_layer 	= prev_active_layer
	end
end