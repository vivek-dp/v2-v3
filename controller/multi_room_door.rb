module MRD
	def self.get_wall_points
		model 	= Sketchup.active_model
		pts = []
		wall_faces = []
		all_faces = Sketchup.active_model.entities.grep(Sketchup::Face)


		all_faces.each{|face|
			wall_face_flag = true
			face.edges.each{|edge|
				wall_face_flag = false if edge.layer.name != 'Wall'
			}
			wall_faces << face if wall_face_flag
		}
        
        wall_layer = Sketchup.active_model.layers['Wall']
        
        #Previous used method.............
        
        
#		wall_faces.each {|face|
#			face.edges.each{ |edge|
#				verts =  edge.vertices
#				verts.each{ |vert|
#					other_vert = verts - [vert]
#					other_vert = other_vert[0]
#					#puts "vert : #{vert} : #{other_vert} : #{verts}"
#					
#					vector 	= vert.position.vector_to(other_vert).reverse
#					pt 		= vert.position.offset vector, 10.mm
#					res 	= face.classify_point(pt)
#					#puts "res : #{res} : #{edge} "
#					if res == Sketchup::Face::PointInside || res == Sketchup::Face::PointOnFace
#						ray = [vert.position, vector]
#						hit_item 	= model.raytest(ray, false)
#						#puts hit_item, hit_item[1][0].layer
#						if hit_item[1][0].layer.name == 'Wall'
#							#puts "Wall..."
#							pts << [vert.position, hit_item[0]]
#						end
#					end
#				}
#			}
#		}

        
        #Latest one...based on wall distance
        wall_faces.each { |wall_face|
            wall_face.outer_loop.edges.each{ |edge|
                verts 	= edge.vertices

                first_vert 		= verts[0]
                second_vert 	= verts[1]

                ray_vector 	= first_vert.position.vector_to second_vert.position

                start_pt	= first_vert.position

                ray = [start_pt, ray_vector.reverse]
                hit_item = Sketchup.active_model.raytest(ray, false)
                #puts "hit_item : #{hit_item}"

                if hit_item && hit_item[1][0].is_a?(Sketchup::Edge)
                    if hit_item[1][0].layer.name == 'Wall'
                        distance = first_vert.position.distance hit_item[0]
                        #puts distance
                        if distance < 250.mm
                            wall_line = Sketchup.active_model.entities.add_line first_vert.position, hit_item[0]
                            wall_line.layer = wall_layer
                        end
                    end
                end


                start_pt	= second_vert.position

                ray = [start_pt, ray_vector]
                hit_item = Sketchup.active_model.raytest(ray, false)
                #puts "hit_item : #{hit_item}"

                if hit_item && hit_item[1][0].is_a?(Sketchup::Edge)
                    if hit_item[1][0].layer.name == 'Wall'
                        distance = second_vert.position.distance hit_item[0]
                        #puts distance
                        if distance < 250.mm
                            wall_line = Sketchup.active_model.entities.add_line second_vert.position, hit_item[0]
                            wall_line.layer = wall_layer
                        end
                    end
                end
            }
        }
        
		pts
	end
	
	def self.add_wall_faces
		model 	= Sketchup.active_model
		#Sketchup.active_model.start_operation 'sdfsdf'
		pts_list = get_wall_points
		pts_list.each{|pt_a|
			line = model.entities.add_line pt_a[0], pt_a[1]
			line.layer = model.layers['Wall']
		}
		faces 	= []
		model.entities.grep(Sketchup::Face).each{ |face|
			wall_face = true
			face.edges.each { |edge|
				wall_face = false if edge.layer.name != 'Wall'
			}
			faces << face if wall_face
		}
		model.selection.add(faces)
	end
	
	def self.get_edges
		edges = fsel.outer_loop.edges
		sel.clear

		timer_id = UI.start_timer(0.5, true) {
			if edges.empty?
				UI.stop_timer timer_id
			else
				x = edges.pop
				sel.add x
			end	
		}
	end
	
	def self.check_perpendicular edge1, edge2
		angle 	= edge1.line[1].angle_between edge2.line[1] 
		angle 	= angle*(180/Math::PI)
		return true if angle.round == 90
		return false
	end

	def self.find_transformation edge, face

			
		#These four returns for console testing
		return false unless edge 
		return false unless edge.is_a?(Sketchup::Edge)
		return false unless face 
		return false unless face.is_a?(Sketchup::Face)

		vector_arr 		= [Geom::Vector3d.new(1,0,0), Geom::Vector3d.new(-1,0,0), Geom::Vector3d.new(0,-1,0), Geom::Vector3d.new(0,1,0)]
		line_vector 	= edge.line[1]
		perp_vector = Geom::Vector3d.new(line_vector.y, -line_vector.x, line_vector.z)
		
		vector_arr		= [perp_vector.normalize, perp_vector.reverse.normalize]
		result_vector 	= nil
		center_point 	= edge.bounds.center	
		vector_arr.each { |vect|
			offset 	= center_point.offset vect, 110.mm
			res 	= face.classify_point(offset)
			#puts "res : #{res}"
			if res == Sketchup::Face::PointInside || res == Sketchup::Face::PointOnFace 
				result_vector = vect
			end
		}
		#puts result_vector
		#return result_vector
		case result_vector
		when Geom::Vector3d.new(1,0,0)
			trans = 90
		when Geom::Vector3d.new(-1,0,0)
			trans = -90
		when Geom::Vector3d.new(0,1,0)
			trans = 180
		when Geom::Vector3d.new(0,-1,0)
			trans = 0
		end
		return trans
	end

	def self.find_adjacent_edge edges, edge
		vertices 	= edge.vertices
		other_edges = edges - [edge]
		edge_list 	= []
		other_edges.each{|ent|
			xn = ent.vertices & vertices
			edge_list << ent if !xn.empty?
		}
		edge_list
	end

	def self.add_door_face input_face
		#puts "input_face : #{input_face}"
		face_edges 	= input_face.outer_loop.edges
		edge_vertices	= []
		new_face = input_face
		face_edges.each{|edge|
			if edge.layer.name == 'Door'
				edges = find_adjacent_edge face_edges, edge
				next if edges.empty?
				edges.sort_by!{|ed| ed.length}
				wall_edge = nil
				edges.each{|ed|
					if ed.length > 100.mm && ed.length < 300.mm
						wall_edge = ed 
					end
				}
				if wall_edge && (wall_edge.line[1].perpendicular? edge.line[1])
					common_vert = wall_edge.vertices & edge.vertices
					other_vert 	= wall_edge.vertices - common_vert
					vector 		= common_vert[0].position.vector_to other_vert[0].position
					#puts "vector : #{vector} : #{common_vert} : #{other_vert}"
					
					door_vert 	= edge.vertices - common_vert
					new_vert 	= door_vert[0].position.offset vector, wall_edge.length
					edge_vertices << [other_vert[0].position, new_vert]
				end
			end
		}
		#puts "......."
		#puts "ver : #{edge_vertices}"
		edge_vertices.each { |vert|
			pt1 = vert[0].is_a?(Sketchup::Vertex) ? vert[0].position : vert[0]
			pt2 = vert[1].is_a?(Sketchup::Vertex) ? vert[1].position : vert[1]
			
			pre_ents	= []
			post_ents 	= []
			
			Sketchup.active_model.entities.each{|ent| pre_ents<<ent}	
			pre_ents = pre_ents - [input_face]
			wall_line = Sketchup.active_model.entities.add_line pt1, pt2
			Sketchup.active_model.entities.each{|ent| post_ents<<ent}
			
			other_ents = post_ents - pre_ents
			
			
			#puts "wall_line.. : #{wall_line} : #{wall_line.deleted?}"
			#wall_line.layer.name = 'Door'
			wall_line.layer=Sketchup.active_model.layers['Door']
			#puts wall_line.deleted?
			#wall_line.layer=Sketchup.active_model.layers['Door']

			faces = other_ents.grep(Sketchup::Face).select{|x| !x.deleted?}
			#puts faces
			
			#puts "line : #{wall_line.layer.name}"
			faces = wall_line.faces
			
			faces.sort_by!{|f| -f.area}
			new_face = faces[0]
		}
		# puts "new : #{new_face}....."
		new_face
	end

	def self.check_perpendicular edge1, edge2
		angle 	= edge1.line[1].angle_between edge2.line[1] 
		angle 	= angle*(180/Math::PI)
		return true if angle.round == 90
		return false
	end

	def self.find_edge_common_face edge1, edge2
		common_face		= (edge1.faces & edge2.faces)[0]
		common_vertex 	= (edge1.vertices & edge2.vertices)[0]
		edges 			= common_face.edges
		return nil if common_vertex.nil?
		common_vertex.faces.each{|face|
			#puts "face : #{face}"
			face_edges = face.edges.select{|ed| edges.include?(ed)}
			#puts "face_edges : #{face_edges}"
			return face if face_edges.length==0
		}
		return nil
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
		face = arr.last
        
		face.edges.each{|edge|
			edge.faces.each{|face|
				window_edges = face.edges.select{|face_edge| face_edge.layer.name=='Window'}
				# puts window_edges.count
				if window_edges.count > 1 && !arr.include?(face)
					arr.push(face)
					find_adj_window_face arr
				end
			}
		}
		return arr 
	end
    
    def self.check_wall_entity edge, floor_face

		line_vector = edge.line[1]
		perp_vector = Geom::Vector3d.new(line_vector.y, -line_vector.x, line_vector.z)

		pt 		= edge.bounds.center.offset perp_vector, 10.mm
		res  	= floor_face.classify_point(pt)

		if res == Sketchup::Face::PointInside || res == Sketchup::Face::PointOnFace
			perp_vector = Geom::Vector3d.new(-line_vector.y, line_vector.x, line_vector.z)
		end


		# puts perp_vector
		#perp_vector = line_vector
		# puts (perp_vector.perpendicular?(line_vector))

		other_faces = edge.faces - [floor_face]
		other_faces.each {|face|
			start_pt	= edge.bounds.center

			ray = [start_pt, perp_vector]
			hit_item = Sketchup.active_model.raytest(ray, false)
			# puts "hit_item : #{hit_item}"
			if hit_item && hit_item[1][0].is_a?(Sketchup::Edge)
				if hit_item[1][0].layer.name == 'Wall'
					distance = start_pt.distance hit_item[0]
					# puts distance
					if distance < 400.mm
						return true
					end
				end
			end
		}

		return false
	end
	
		
    #face is sent to get new face if the door is added
	def self.get_face_views input_face, inputs={}, wall_color=nil
		return false if input_face.nil?
		#Sketchup.active_model.start_operation '2d_to_3d'
		# puts "MRD::get_face_views"
		model 	= Sketchup.active_model
		wall_color = inputs['wall_color']
		wall_height = inputs['wall_height'].to_i.mm
		door_height = inputs['door_height'].to_i.mm
		window_height = inputs['window_height'].to_i.mm
		window_offset = inputs['window_offset'].to_i.mm
		wall_layer_name  = 'DP_Wall_'+inputs['space_name']
		Sketchup.active_model.layers.add wall_layer_name
		
		view_count = 0
		view_h = {}
		
		res = add_door_face input_face
        
        # puts "input_face... : #{input_face} : #{res}"
        door_flag = false
        if res && res.is_a?(Sketchup::Face) && (res.area != input_face.area)
            door_flag = true
            new_face = res
        else
            new_face = input_face
        end
        
		edge_array = new_face.outer_loop.edges
		edge_list 	= []
		edge_array.each_index {|index|
			curr_edge 	=  	edge_array[index]
			next_edge 	=	edge_array[index+1]
			if next_edge.nil?
				last_edge 	= 	true 
				next_edge   =   edge_array.first 
			end
			if check_perpendicular(curr_edge, next_edge)
				face 	= find_edge_common_face(curr_edge, next_edge)
				edge_list << face unless face.nil? #This code for raising the corner face walls
				edge_list << curr_edge
				view_count += 1
				view_name	= 'view_'+view_count.to_s
				view_h[view_name] = edge_list
				edge_list = []
			else
				edge_list << curr_edge
				if last_edge
					#view_count += 1
					view_name	= 'view_1'
					view_h[view_name] << edge_list
					view_h[view_name].flatten!
				end
			end
		}
		
		view_h.each_pair{|view_name, ents|
			pre_ents	= []
			post_ents 	= []
			faces_arr 	= []
			
			Sketchup.active_model.entities.each{|ent| pre_ents<<ent}
			trans_arr = []
			ents.each{ |ent|
				if ent.is_a?(Sketchup::Face)
					faces_arr << ent #Corner face
				elsif ent.is_a?(Sketchup::Edge)
					if ent.layer.name == 'Door' && door_flag
                        # puts door_flag
						edge_face =ent.faces - [new_face]

						#Check the width of the face.......sliding door it will be 100 ....normal wall
						door_edges = edge_face[0].edges - [ent]
						parallel_edge = door_edges.select{|ed| ed.line[1].parallel?(ent.line[1])}[0]
						
						distance = ent.bounds.center.distance parallel_edge.bounds.center
						# puts "ent : #{ent} : #{distance}"
						if distance > 149.mm && distance < 251.mm
							# puts "dist : #{distance}"
							vertices = edge_face[0].vertices
							pts = []
							vertices.each{|ver|
								pts << ver.position.offset(Geom::Vector3d.new(0,0,1), door_height)
							}
							door_face = Sketchup.active_model.entities.add_face(pts)
							door_face.pushpull(-(wall_height - door_height), true)
						end
					elsif ent.layer.name == 'Window'
						window_face 	= ent.faces
						window_face.delete new_face
						window_faces = find_adj_window_face [window_face[0]]
						ht 	= window_height+window_offset

						#puts "ht : #{ht}"
						window_faces.each { |wface|
							vertices	= wface.vertices
							pts = []
							vertices.each{|v| puts v.position}
							#puts "window_ver : #{vertices}"
							vertices.each{|ver|
								pts<<ver.position.offset(Geom::Vector3d.new(0,0,1), ht)
							}
							#puts "pts : #{pts}"
							top_face_window = Sketchup.active_model.entities.add_face(pts)
							
							wface.pushpull(-window_offset)
							top_face_window.pushpull(-(wall_height-ht))
						}
					elsif ent.layer.name == 'Wall'
                        res = check_wall_entity ent, new_face
                        next unless res
                        # puts "Proper Wall"
                        
						faces=ent.faces - [new_face]	
						faces_arr << faces[0] #Array created because to avoid double pushpul if two edges have same face
					end
					trans_arr << find_transformation(ent, new_face)
				end
			}
			freq 		= trans_arr.inject(Hash.new(0)) { |h,v| h[v] += 1; h }
			group_trans = trans_arr.max_by { |v| freq[v] }
			
			# puts "faces_arr : #{faces_arr}"
			faces_arr.flatten!
			faces_arr.uniq!
			faces_arr.each {|face| 
				normal = [0,0,1]
				dot = face.normal.dot normal
				if dot < 0.0
					face.reverse!
				end
				face.pushpull(wall_height, true)
			}
			Sketchup.active_model.entities.each{|ent| 
				post_ents<<ent
			}
			
			rem_ents 	= post_ents - pre_ents
			#puts "rem_ents : #{rem_ents} : #{wall_color}"
			#material = Sketchup.
			if wall_color
				rem_ents.each{|ent| 
					if ent.is_a?(Sketchup::Face)
						ent.material= wall_color
						ent.back_material= wall_color
						Sketchup.active_model.selection.add(ent)
						#return
					end
					
				}
			end
			unless rem_ents.empty?
				edge_ents = ents.select{|e| e.is_a?(Sketchup::Edge)}
				temp_group = Sketchup.active_model.entities.add_group(edge_ents)

				wall_length = 0
				if group_trans == 90 || group_trans == -90
					wall_length = temp_group.bounds.height.to_mm
				else
					wall_length = temp_group.bounds.width.to_mm
				end
				#temp_group.explode
				# puts "--------------------------------- : #{temp_group.bounds}"
				# puts wall_length

				wall_group 	= Sketchup.active_model.entities.add_group(rem_ents)
				wall_group.layer = wall_layer_name
				wall_group.set_attribute :rio_atts, 'view_wall_length', wall_length.round(2)
				wall_group.set_attribute :rio_atts, 'wall_trans', group_trans
				wall_group.set_attribute :rio_atts, 'view_name', view_name
				wall_group.set_attribute :rio_atts, 'room_name', inputs['space_name']
				
			end
		}

		new_face
	end
end



# load 'E:\git\siva\scripts\multi_room_preprocess.rb'
# load 'E:\git\siva\controller\room_tool.rb'

#MRP::add_wall_faces

# get_face_views fsel, 
#inputs={'wall_height'=>'2000', 'space_name'=>'adfsdf', 'door_height'=>'1500', 'window_height'=>'800', 'window_offset'=>'600'}, 'Yellow'


