require_relative 'comp_visible_test.rb'
module MRP
	COMP_DIMENSION_OFFSET 	= 20000.mm unless defined?(COMP_DIMENSION_OFFSET)
	WALL_OUTLINE_OFFSET 	= 20000.mm unless defined?(WALL_OUTLINE_OFFSET)
	WALL_DIMENSION_OFFSET 	= 20000.mm unless defined?(WALL_DIMENSION_OFFSET)
	WALL_SHADE_OFFSET 		= 20000.mm unless defined?(WALL_SHADE_OFFSET)
	@comp_outer_edges		= []

	def self.reset_comp_outer_edges
		@comp_outer_edges = []
	end

	def self.get_comp_outer_edges
		@comp_outer_edges
	end

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
		wall_faces.each {|face|
			face.edges.each{ |edge|
				verts =  edge.vertices
				verts.each{ |vert|
					other_vert = verts - [vert]
					other_vert = other_vert[0]
					#puts "vert : #{vert} : #{other_vert} : #{verts}"
					
					vector 	= vert.position.vector_to(other_vert).reverse
					pt 		= vert.position.offset vector, 10.mm
					res 	= face.classify_point(pt)
					#puts "res : #{res} : #{edge} "
					if res == Sketchup::Face::PointInside || res == Sketchup::Face::PointOnFace
						ray = [vert.position, vector]
						hit_item 	= model.raytest(ray, false)
						#puts hit_item, hit_item[1][0].layer
						if hit_item[1][0].layer.name == 'Wall'
							#puts "Wall..."
							pts << [vert.position, hit_item[0]]
						end
					end
				}
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
	
	#If egde has both sides perpendicular its a single view
	def self.get_wall_views face
		model 	= Sketchup.active_model
		view_h 	= {}
		view_count = 1
		outer_loop_edge_array 	= face.outer_loop.edges
		edge_array	= []
		view_name	= 'view_'+view_count.to_s
		
		#Shift the array until u find a corner edge
		outer_loop_edge_array.each { |outer_edge|
			next_edge 	= outer_loop_edge_array[1]
			angle 		= outer_edge.line[1].angle_between next_edge.line[1] 
			angle 		= angle*(180/Math::PI)
			outer_loop_edge_array.rotate!
			break if angle.round == 90
		}
		
		
		#puts "outer_loop_edge_array : #{outer_loop_edge_array}"
		edge_count = outer_loop_edge_array.length
		(edge_count+1).times{|i|
			outer_edge 	= outer_loop_edge_array[0]
			#puts "count : #{outer_edge} :  #{view_count}"
			if outer_edge.layer.name == 'Door'
				edge_array << outer_edge
				next_edge 	= outer_loop_edge_array[1]
				edge_array << next_edge
				
				outer_loop_edge_array.rotate! if next_edge.layer.name == 'Wall'
			else
				next_edge 	= outer_loop_edge_array[1]
				angle 		= outer_edge.line[1].angle_between next_edge.line[1] 
				angle 		= (angle*(180/Math::PI)).round
				#puts "#{i} : #{outer_edge} : #{angle}"
				if angle == 90
					#puts "++++++++"
					sel.add(outer_edge)
					# puts "90.... #{outer_edge}"
					# prev_edge 	= outer_loop_edge_array.last
					# angle 		= outer_edge.line[1].angle_between prev_edge.line[1] 
					# angle 		= (angle*(180/Math::PI)).round
					# if angle == 90
						# view_name 	= 'view_'+view_count.to_s
						# view_h[view_name] = [outer_edge]
						# view_count += 1
					# else
					secondary_edge = outer_loop_edge_array[2]
					if secondary_edge.layer.name == 'Door'
						edge_array << outer_edge
						#edge_array << next_edge
						outer_loop_edge_array.rotate!
					else
						edge_array << outer_edge
						view_h[view_name] = edge_array
						view_count += 1
						view_name 	= 'view_'+view_count.to_s
						edge_array = []
					end
				else
					edge_array << outer_edge				
				end
				#puts "edge_array : #{edge_array}"
			end
			view_h[view_name] = edge_array
			outer_loop_edge_array.rotate!
		}
		if view_h['view_1'].length == 1
			edge = view_h['view_1']
			last_view = view_h.keys.last
			if view_h[last_view].include?(edge)
				view_h['view_1'] << view_h[last_view]
				view_h['view_1'].flatten!
				view_h.delete last_view
			end	
		end
		return view_h
	end
	
	
		
	def self.find_edge_common_face edge1, edge2
		common_face		= (edge1.faces & edge2.faces)[0]
		common_vertex 	= (edge1.vertices & edge2.vertices)[0]
		edges 			= common_face.edges
		return nil if common_vertex.nil?
		common_vertex.faces.each{|face|
			face_edges = face.edges.select{|ed| edges.include?(ed)}
			return face if face_edges.length==0
		}
		return nil
	end
	
	def self.get_views face
		sliding_door = false

		model 	= Sketchup.active_model
		view_h 	= {}
		view_count = 0
		outer_loop_edge_array 	= face.outer_loop.edges
		edge_array	= []
		view_name	= 'view_'+view_count.to_s
		
		#Shift the array until u find a corner edge-----------------------------------------------
		outer_loop_edge_array.each { |outer_edge|
			next_edge 	= outer_loop_edge_array[1]
			angle 		= outer_edge.line[1].angle_between next_edge.line[1] 
			angle 		= angle*(180/Math::PI)
			outer_loop_edge_array.rotate!
			break if angle.round == 90
		}
		
		#Find door view edges-----------------------------------------------
		door_edges = outer_loop_edge_array.select{|edge| edge.layer.name == 'Door'}
		sliding_door = true if door_edges.length == 3
		
		outer_loop_edge_array.length.times{|i|
			wall_edge 	= false
			curr_edge = outer_loop_edge_array.first
			unless curr_edge.layer.name == 'Door'
				next_edge 	= outer_loop_edge_array[1]
				prev_edge 	= outer_loop_edge_array.last
				
				if next_edge.layer.name == 'Door' || prev_edge.layer.name == 'Door'
					wall_edge 	= true if curr_edge.length < 301.mm
				end
				door_edges << curr_edge if wall_edge
			end
			outer_loop_edge_array.rotate!
		}
		#sel.add(door_edges)
		
		
		edge_array	= outer_loop_edge_array - door_edges
		
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
		view_h
	end

    def self.check_wall_entity edge, floor_face

		line_vector = edge.line[1]
		perp_vector = Geom::Vector3d.new(line_vector.y, -line_vector.x, line_vector.z)

		pt 		= edge.bounds.center.offset perp_vector, 10.mm
		res  	= floor_face.classify_point(pt)

		if res == Sketchup::Face::PointInside || res == Sketchup::Face::PointOnFace
			perp_vector = Geom::Vector3d.new(-line_vector.y, line_vector.x, line_vector.z)
		end

		other_faces = edge.faces - [floor_face]
		other_faces.each {|face|
			start_pt	= edge.bounds.center

			ray = [start_pt, perp_vector]
			hit_item = Sketchup.active_model.raytest(ray, false)
			if hit_item && hit_item[1][0].is_a?(Sketchup::Edge)
				if hit_item[1][0].layer.name == 'Wall'
					distance = start_pt.distance hit_item[0]
					if distance < 250.mm
						return true
					end
				end
			end
		}

		return false
	end
	
	
	def self.raise_walls face, inputs={}, wall_color=nil
		return false if face.nil?
		Sketchup.active_model.start_operation '2d_to_3d'
		views = get_views face
		wall_height = inputs['wall_height'].to_i.mm
		wall_layer_name  = 'DP_Wall_'+inputs['space_name']
		Sketchup.active_model.layers.add wall_layer_name
		
		door_edges 		= []
		window_edges 	= []
		
		face.outer_loop.edges.each{ |edge|
			if edge.layer.name == 'Door'
				door_edges << edge
			elsif edge.layer.name == 'Window'
				window_edges << edge
			end
		}
		
		views.each_pair{|view_name, ents| 
			
		}
		views.each_pair{|view_name, ents|
			pre_ents	= []
			post_ents 	= []
			faces_arr 	= []
			
			Sketchup.active_model.entities.each{|ent| pre_ents<<ent}
			
			ents.each{ |ent|
                
                #Check if the entity is a proper entity or dont raise walls
				res = check_wall_entity ent, face
                #puts "res   : #{res}"
				next unless res
                
				if ent.is_a?(Sketchup::Face)
					faces_arr << ent #Corner face
				elsif ent.is_a?(Sketchup::Edge)
					faces=ent.faces - [face]	
					faces_arr << faces[0] #Array created because to avoid double pushpul if two edges have same face
					
				end
			}
			#puts "faces_arr : #{faces_arr}"
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
						sel.add(ent)
						#return
					end
					
				}
			end
			wall_group 	= Sketchup.active_model.entities.add_group(rem_ents)
			wall_group.layer = wall_layer_name
		}
	end
	
	def self.get_room_bounds room_name
		ents = Sketchup.active_model.entities.select{|ent| ent.layer.name.end_with?(room_name)}
		room_group 	= Sketchup.active_model.entities.add_group(ents)
		return room_group
	end

	def self.get_room_components room_name='Room#1'
		ents 		= Sketchup.active_model.entities
		room_ents 	= ents.grep(Sketchup::ComponentInstance).select{|ent| ent.get_attribute(:rio_atts, 'space_name') == room_name}
		room_ents << ents.grep(Sketchup::Group).select{|ent| ent.get_attribute(:rio_atts, 'space_name') == room_name && !ent.get_attribute(:rio_atts, 'custom_type').nil?}
		if V2_V3_CONVERSION_FLAG
			room_ents 	= ents.grep(Sketchup::ComponentInstance).select{|ent| ent.get_attribute(:rio_comp_atts, 'room_name') == room_name}
			room_ents << ents.grep(Sketchup::Group).select{|ent| ent.get_attribute(:rio_comp_atts, 'room_name') == room_name && !ent.get_attribute(:rio_comp_atts, 'custom_type').nil?}
		end
		room_ents.flatten!
		room_ents
	end
	
	def self.get_comp_room comp
		room_names = DP::get_space_names
		room_names.each {|room_name|
			comps = get_room_components room_name
			return room_name if comps.include?(comp)
		}
		return false
	end
	
	def self.get_room_face room_name
		gp = Sketchup.active_model.entities.select{|ent| ent.layer.name == 'DP_Floor_'+room_name.to_s}[0]
		if V2_V3_CONVERSION_FLAG
			gp = Sketchup.active_model.entities.select{|ent| ent.layer.name == 'RIO_Floor_'+room_name.to_s}[0]
		end
		if gp.nil?
			puts "Floor group not found"
			return nil
		else
			room_face = gp.entities.select{|ent| ent.is_a?(Sketchup::Face)}[0]
			puts "Room face not found in the group" if room_face.nil?
			return room_face
		end
	end
	
	def self.get_top_corners comp
		#comp_pts = []
		#[4,5,7,6].each{|index| comp_pts << comp.bounds.corner(index)}
		#comp_pts
		
		all_points 	= []
		
		pt1 = comp.bounds.corner(4)
		pt2 = comp.bounds.corner(7)
		vector = pt1.vector_to pt2
		offset = (pt1.distance pt2)/5
		
		4.times{ |index|
			all_points << pt1.offset(vector, (index+1)*offset)
		}

		pt1 = comp.bounds.corner(5)
		pt2 = comp.bounds.corner(6)
		vector = pt1.vector_to pt2
		offset = (pt1.distance pt2)/5
		
		4.times{ |index|
			all_points << pt1.offset(vector, (index+1)*offset)
		}
		all_points
	end

	def self.get_top_room_comps room_name
		room_comps 	= MRP::get_room_components room_name
		floor_group=Sketchup.active_model.entities.grep(Sketchup::Group).select{|x| x.layer.name=='DP_Floor_'+room_name}.select{|y| y.get_attribute :rio_atts, 'space_name'}[0]
		
		zvector = Geom::Vector3d.new(0,0,1)
		pts_arr = []
		[4,5,7,6].each{|index| pts_arr << floor_group.bounds.corner(index).offset(zvector, 5000.mm)}
		hit_face 	= Sketchup.active_model.entities.add_face(pts_arr)
		hit_group 	= Sketchup.active_model.entities.add_group(hit_face)
		
		visible_comps = []
		room_comps.each{|comp|
			pts = get_top_corners comp
			#ent.add_face(pts)
			visible = true
			pts.each { |pt|
				hit_item = Sketchup.active_model.raytest(pt, zvector)
				#puts "hit_item : #{pt} : #{hit_item}"
				if hit_item && hit_item[1][0] == hit_group

				else
					visible = false
				end
			}
			#puts "comp : #{comp} : #{visible}"
			visible_comps << comp if visible
		}
		Sketchup.active_model.entities.erase_entities(hit_group)
		visible_comps
	end
	

	
	
	def self.get_comp_intersection comp1, comp2
		comp_intersection = comp1.bounds.intersect comp2.bounds
		#puts "comp1 : #{comp1} : #{comp2} : #{comp_intersection.valid?}"
		if comp_intersection.valid?
			volume = comp_intersection.width * comp_intersection.height * comp_intersection.depth
			#puts "vol : #{volume}"
			return comp_intersection if volume.round == 0
		else
			return false
		end
		return false
	end

	def self.get_intersecting_comp comp, comps
		other_comps = comps - [comp]
		intersecting_comps = {}
		other_comps.each{|o_comp|
			#puts "o_comp : #{o_comp}" 
			xn = get_comp_intersection comp, o_comp
			next unless xn
			#puts "xn : #{xn.depth}"
			if xn.depth == 0
				if xn.center.z == comp.transformation.origin.z
					intersecting_comps['bottom'] = o_comp
				else
					intersecting_comps['top'] = o_comp
				end
			else
				left_flag = false
				rotz = comp.transformation.rotz
				case rotz
				when 0
					left_flag = true if xn.center.x == comp.transformation.origin.x
				when 90
					left_flag = true if xn.center.y == comp.transformation.origin.y
				when -90
					left_flag = true if xn.center.y == comp.transformation.origin.y
				when 180, -180
					left_flag = true if xn.center.x == comp.transformation.origin.x
				end
				if left_flag
					intersecting_comps['left'] = o_comp
				else
					intersecting_comps['right'] = o_comp
				end
			end
		}
		return intersecting_comps
	end
	
	def self.get_adjacent_comps comps
		inp_comps = comps
		return {} if inp_comps.empty?
		
		comp_list = {}
		
		inp_comps.each{ |comp|
			xn_comps = 	get_intersecting_comp comp, comps
			pid = comp.persistent_id
			comp_list[pid] = xn_comps
		}
		comp_list.each_pair { |comp_pid, comp_h|
			next if comp_h['right'].empty?
			right_comp = comp_h['right']
			
		}
	end
	
	def self.add_comp_dimension comp,  view='top', lamination_pts=[], show_dimension=true
		# puts "comp dim : #{comp} "
		sel = Sketchup.active_model.selection		
		sel.add comp
		return nil unless comp.valid?
		bounds = comp.bounds
		
		layer_name = 'DP_dimension_'+view
		Sketchup.active_model.layers.add(layer_name) if Sketchup.active_model.layers[layer_name].nil?
		dim_off = 4*rand + 1
		
		offset = @@drawing_image_offset

		rotz = comp.transformation.rotz
		case view
		when 'top'   
			case rotz
			when 0
				st_index, end_index, vector, lvector = 2,3, Geom::Vector3d.new(0,dim_off,0), Geom::Vector3d.new(0,2*dim_off,0)
				pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
				pt1.z=offset;pt2.z=offset
				mid_point = Geom.linear_combination( 0.5, pt1, 0.5, pt2 )
				dim_l = add_dimension_pts(pt1, pt2, vector)
				dim_l.layer = layer_name
				if show_dimension
					st_index, end_index, vector = 0,2, Geom::Vector3d.new(-dim_off,0,0)
					pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
					pt1.z=offset;pt2.z=offset
					dim_l = add_dimension_pts(pt1, pt2, vector)
					dim_l.layer = layer_name
				end
			when 90
				st_index, end_index, vector, lvector = 0,2, Geom::Vector3d.new(-dim_off,0,0), Geom::Vector3d.new(0,-dim_off*2,0)
				pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
				pt1.z=offset;pt2.z=offset
				mid_point = Geom.linear_combination( 0.5, pt1, 0.5, pt2 )
				dim_l = add_dimension_pts(pt1, pt2, vector)
				dim_l.layer = layer_name
				if show_dimension
					st_index, end_index, vector = 0,1, Geom::Vector3d.new(0,dim_off,0)
					pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
					pt1.z=offset;pt2.z=offset
					dim_l = add_dimension_pts(pt1, pt2, vector)
					dim_l.layer = layer_name
				end
			when 180, -180
				st_index, end_index, vector, lvector = 0,1, Geom::Vector3d.new(0,-dim_off,0), Geom::Vector3d.new(0,-dim_off*2,0)
				pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
				pt1.z=offset;pt2.z=offset
				mid_point = Geom.linear_combination( 0.5, pt1, 0.5, pt2 )
				dim_l = add_dimension_pts(pt1, pt2, vector)
				dim_l.layer = layer_name
				if show_dimension
					st_index, end_index, vector = 0,2, Geom::Vector3d.new(-dim_off,0,0)
					pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
					pt1.z=offset;pt2.z=offset
					dim_l = add_dimension_pts(pt1, pt2, vector)	
					dim_l.layer = layer_name
				end
			when -90
				st_index, end_index, vector, lvector = 1,3, Geom::Vector3d.new(dim_off,0,0), Geom::Vector3d.new(2*dim_off,0,0)
				pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
				pt1.z=offset;pt2.z=offset
				mid_point = Geom.linear_combination( 0.5, pt1, 0.5, pt2 )
				dim_l = add_dimension_pts(pt1, pt2, vector)
				dim_l.layer = layer_name
				if show_dimension
					st_index, end_index, vector = 0,1, Geom::Vector3d.new(0,-dim_off,0)
					pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
					pt1.z=offset;pt2.z=offset
					dim_l = add_dimension_pts(pt1, pt2, vector)
					dim_l.layer = layer_name
				end
			end	
			
		when 'left'
			if show_dimension
				st_index, end_index, vector = 2,6, Geom::Vector3d.new(0,dim_off,0)
				pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
				pt1.x=-offset;pt2.x=-offset
				dim_l = add_dimension_pts(pt1, pt2, vector)
				dim_l.layer = layer_name
			end

			st_index, end_index, vector = 2,0, Geom::Vector3d.new(0,0,dim_off)
			pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
			pt1.x=-offset;pt2.x=-offset
			dim_l = add_dimension_pts(pt1, pt2, vector)
			dim_l.layer = layer_name
		when 'right'
			if show_dimension
				st_index, end_index, vector = 1,5, Geom::Vector3d.new(0,-dim_off,0)
				pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
				pt1.x=offset;pt2.x=offset
				dim_l = add_dimension_pts(pt1, pt2, vector)
				dim_l.layer = layer_name
			end
			
			st_index, end_index, vector = 1,3, Geom::Vector3d.new(0,0,dim_off)
			pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
			pt1.x=offset;pt2.x=offset
			dim_l = add_dimension_pts(pt1, pt2, vector)
			dim_l.layer = layer_name
		when 'front'
			
			st_index, end_index, vector = 0,1, Geom::Vector3d.new(0,0,dim_off)
			pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
			pt1.y=-offset;pt2.y=-offset
			dim_l = add_dimension_pts(pt1, pt2, vector)
			dim_l.layer = layer_name
			
			if show_dimension
				st_index, end_index, vector = 0,4, Geom::Vector3d.new(-dim_off,0,0)
				pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
				pt1.y=-offset;pt2.y=-offset
				dim_l = add_dimension_pts(pt1, pt2, vector)
				dim_l.layer = layer_name
			end
		when 'back'
			st_index, end_index, vector = 2,3, Geom::Vector3d.new(0,0,dim_off)
			pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
			pt1.y=offset;pt2.y=offset
			dim_l = add_dimension_pts(pt1, pt2, vector)
			dim_l.layer = layer_name
			if show_dimension	
				st_index, end_index, vector = 2,6, Geom::Vector3d.new(dim_off,0,0)
				pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
				pt1.y=offset;pt2.y=offset
				dim_l = add_dimension_pts(pt1, pt2, vector)
				dim_l.layer = layer_name
			end
		end
		Sketchup.active_model.layers[layer_name].visible=true
		
	end

	def self.add_row_dimension row, view
		#puts "add_row_dimension"
		comp_names = []
		return comp_names if row.empty?

		row_len = row.length
		dim_off = (7*rand) + 1
		vector  = Geom::Vector3d.new(0,0,-dim_off)
		offset 	= 3000.mm

		case view
		when 'front'
			row.sort_by!{|x| -DP::get_comp_pid(x).transformation.origin.x}
			start 	= 5
			last 	= 4
			start_point = DP::get_comp_pid(row[0]).bounds.corner(start)
			end_point	= DP::get_comp_pid(row[row_len-1]).bounds.corner(last)
			start_point.y	= -offset
			end_point.y 	= -offset 
		when 'left'
			row.sort_by!{|x| DP::get_comp_pid(x).transformation.origin.y}
			start 	= 4
			last 	= 6
			start_point = DP::get_comp_pid(row[0]).bounds.corner(start)
			end_point	= DP::get_comp_pid(row[row_len-1]).bounds.corner(last)
			start_point.x	= -offset
			end_point.x 	= -offset
		when 'right'
			row.sort_by!{|x| -DP::get_comp_pid(x).transformation.origin.y}
			start 	= 7
			last 	= 5
			start_point = DP::get_comp_pid(row[0]).bounds.corner(start)
			end_point	= DP::get_comp_pid(row[row_len-1]).bounds.corner(last)
			start_point.x	= offset
			end_point.x 	= offset
		when 'back'
			row.sort_by!{|x| DP::get_comp_pid(x).transformation.origin.x}
			start 	= 6
			last 	= 7
			start_point = DP::get_comp_pid(row[0]).bounds.corner(start)
			end_point	= DP::get_comp_pid(row[row_len-1]).bounds.corner(last)
			start_point.y	= offset
			end_point.y 	= offset
		end
		
		if view != 'top'
			dim_l = add_dimension_pts(start_point, end_point, vector)
			dim_l.material.color = '1D8C2C'
			dim_l.set_attribute :rio_atts, 'dimension_entity', 'true'
		end
	end
	
	
	def self.get_comp_rows comp_h, view
		corners = []
		singles = []
		comp_h.each_pair{|x, y| 
			if y[:type]==:corner
				corners<<x 
			elsif y[:type]==:single 
				singles<<x
			end
		}
		rows = []
		
		corners.each{|id| comp_h[id][:type]=:corner}
		corners.each{|cor|
			adjs = comp_h[cor][:adj]
			row = []
			adjs.each{|adj_comp|
				row  = [cor]
				curr = adj_comp
				
				comp_h[curr][:adj].delete cor
				while comp_h[curr][:type] == :double
					break if (comp_h[curr][:adj].nil? || comp_h[curr][:adj].empty?)
					row << curr
					adj_next = comp_h[curr][:adj][0]
					adj_comp = DP::get_comp_pid adj_next 
					break if adj_comp.layer.name != 'DP_Comp_layer'
					comp_h[adj_next][:adj].delete curr
					comp_h[curr][:adj].delete adj_next
					curr = adj_next
				end
				row << curr
				row.sort_by!{|r| comp=DP.get_comp_pid r; comp.transformation.origin.x}
				rows << row
			}
		} 
		row_elems = rows.flatten
		
		singles.reject!{|x| row_elems.include?(x)}
		singles.each{|cor|
			adjs = comp_h[cor][:adj]
			row = []
			adjs.each{|adj_comp|
				row  = [cor]
				curr = adj_comp
				
                next if comp_h[curr].nil?
                next if comp_h[curr][:adj].nil? || comp_h[curr][:adj].empty?
				#comp_h[cor][:adj].delete curr
				comp_h[curr][:adj].delete cor
				count = 0
				while comp_h[curr][:type] == :double
					count+=1
					break if count == 10
					row << curr
					adj_next = comp_h[curr][:adj][0]
					#puts "curr : #{curr} : #{comp_h[curr]} : #{comp_h[adj_next]} : #{adj_next}"
					if adj_next && comp_h[adj_next]
						comp_h[adj_next][:adj].delete curr 
						comp_h[curr][:adj].delete adj_next
						curr = adj_next
						#puts "curraaa : ---- #{curr}"
					else
						break if curr.nil?
					end
				end
				row << curr
				row.sort_by!{|r| comp=DP.get_comp_pid r; comp.transformation.origin.x}
				rows << row
			}
		} 		
		
		rows
	end

	def self.add_dimension_pts pt1, pt2, vector
		dim_l 	= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, vector)
		dim_l.material.color = 'red'
		dim_l.set_attribute :rio_atts, 'dimension_entity', 'true'
		dim_l
	end

	def self.add_edge_array_dimension(edge_list, vector)
		
		vector = vector.normalize
		vert_list = []
		edge_list.each{|edge| vert_list << edge.vertices}
		vert_list.flatten!.uniq!
		if vector.x != 0
			vert_list.sort_by!{|vert| vert.position.y}
			vector = Geom::Vector3d.new(vector.x*10, 0, 0)
		else 
			vert_list.sort_by!{|vert| vert.position.x}
			vector = Geom::Vector3d.new(0,vector.y*10, 0)
		end
		#puts "vert_list : #{vert_list.first.position} : #{vert_list.last.position} : #{vector}"
		pt1 	=  vert_list.first.position
		pt2 	=  vert_list.last.position
		pt1.z=0;pt2.z=0;
		dim_l = Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, vector) 
		dim_l.material.color = 'blue'
		dim_l.set_attribute :rio_atts, 'dimension_entity', 'true'
	end
	
	def self.get_room_view_components room_name
		walls 		= Sketchup.active_model.entities.select{|ent| ent.layer.name == 'DP_Wall_'+room_name}
		#puts "walls : #{walls}"
		room_comps 	= MRP::get_room_components room_name
		view_count 	= 0
		view_h		= {}
		#room_face 	= get_room_face room_name
		
		filler_hash = {}
		Sketchup.active_model.entities.grep(Sketchup::Group).each{|gp| 
			if gp.get_attribute(:rio_atts, 'custom_type') == 'filler'
				comp_id = gp.get_attribute(:rio_atts, 'associated_comp')
				filler_hash[comp_id] = gp
			end
		}
		
		walls.each {|wall|
			#puts "wall : #{wall}"
			wall_trans = wall.get_attribute(:rio_atts, 'wall_trans').to_i
			wall_comps 	= room_comps.select{|comp| 
				(comp.bounds.intersect wall.bounds).valid?
			}
			# puts "wall_comps : #{wall_comps}"
			if wall_trans.abs == 180
				wall_comps.select!{|x| x.transformation.rotz.abs==wall_trans.abs}
			else
				wall_comps.select!{|x| x.transformation.rotz==wall_trans}
			end

			wall_pid = wall.persistent_id
			associated_comps=[];
			room_comps.each{|rcomp| 
				wid = rcomp.get_attribute(:rio_atts, 'associated_wall')
				if wid && (rcomp.get_attribute(:rio_atts, 'visible_in_working_drawing') == true)
					associated_comps << rcomp if wall_pid == wid
				end
			}
			wall_comps += associated_comps

			#puts "wall_comps : #{wall_comps}"

			if !wall_comps.empty?
				#..............Add filler components.....................
				filler_comps = []
				
				wall_comps.each{|comp|
					filler_comps << comp if filler_hash.keys.include?(comp.persistent_id)
				}
				if !filler_comps.empty?
					wall_comps << filler_comps
					wall_comps.flatten!
				end
				#----------------------End---------------------
				
				#...............Add custom components.....................
				
				#-----------------------End------------------------------
				
				
				#Add non intersecting components
				#non_intersecting_comps = Sketchup.active_model.entities.select{|ent| ent.get_attribute(:rio_atts, 'associated_wall') == wall.persistent_id}			
				#wall_comps = wall_comps.select{|ent| ent.get_attribute(:rio_atts, 'visible_in_working_drawing') == true}
				
				#-----------------------End-----------------------------
				wall_comps.uniq!
				#puts "#-----------------------End-----------------------------"
				#puts wall_comps

				case wall_trans
				when 0
					side_name = 'back'
				when 90
					side_name = 'left'
				when -90
					side_name = 'right'
				else
					side_name = 'front'
				end

				view_count 	+= 1
				view_name 	= 'view_'+view_count.to_s+'_'+side_name
				view_h[view_name] = {}
				view_h[view_name]['comps'] = wall_comps 
				view_h[view_name]['transform'] = wall_trans
				view_h[view_name]['wall'] = wall
			end
		}
		view_h
	end

	def self.MVP_get_room_view_components room_name 
		room_comps 	= MRP::get_room_components room_name
		room_walls = Sketchup.active_model.entities.select{|ent| ent.get_attribute(:rio_comp_atts, 'room_name')==room_name.to_s}

		view_count 	= 0
		view_h		= {}
	end
	
	#MRP::get_working_drawing_sides 'Room#1'
	def self.get_working_drawing_sides room_name='Bedroom', scan_flag=false

		if scan_flag
			res = scan_room_components room_name, true
			#puts "scan_room_components : #{res}"
			if res[1] == false
				return {}
			end
		end
		rotz 	= 0
		room_face 	= MRP::get_room_face room_name
		#room_face = fsel #Hardcode
		view_h 		= MRP::get_room_view_components room_name
		
		return {} if view_h.empty?
		exception_raised = false
		# puts "exception_raised : #{exception_raised}"
		begin
			Sketchup.active_model.start_operation "Working Drawing"
			edge_render_option = Sketchup.active_model.rendering_options["EdgeColorMode"]
			Sketchup.active_model.rendering_options["EdgeColorMode"] = 0

			#puts "Room View : #{view_h}"
			curr_active_layer 	= Sketchup.active_model.active_layer
			#wd_layer			= Sketchup.active_model.layers.add 'Rio_WorkingDrawing'
			#Sketchup.active_model.active_layer=wd_layer
			active_camera = Sketchup.active_model.active_view.camera
			zvector = Geom::Vector3d.new(0,0,1)
			
			view_details_h = {}
			comp_count  = 1
			all_comp_list = {}
			
			view_h.each_pair{ |view_name, view_arr|

				Sketchup.active_model.entities.each{|ent| ent.visible=false}
				#wd_entities = Sketchup.active_model.entities.select{|ent| ent.layer=wd_layer}
				#Sketchup.active_model.entities.erase_entities wd_entities
				res = false 
				
				res = true if !view_h[view_name]['comps'].empty?
				
				trans = view_h[view_name]['transform'].to_i
				wall = view_h[view_name]['wall']
				case trans
				when 0
					@cPos 	= [0, 0, 0]
					@cTarg 	= [0, 1, 0]
					@cUp 	= [0, 0, 1]
					@pts 	= [0, 1, 5, 4]
					@pts 	= [2, 3, 7, 6]	 
					@side_vector = Geom::Vector3d.new(-1,0,0)
					@side_offset_wall_vector = Geom::Vector3d.new(-10,0,0)
				when 90
					@cPos 	= [0, 0, 0]
					@cTarg 	= [-1, 0, 0]
					@cUp 	= [0, 0, 1]
					@pts 	= [2, 0 , 4, 6]
					@pts 	= [1, 3, 7, 5]
					@side_vector = Geom::Vector3d.new(0,-1,0)
					@side_offset_wall_vector = Geom::Vector3d.new(0,10,0)
				when -90
					@cPos 	= [0, 0, 0]
					@cTarg 	= [1, 0, 0]
					@cUp 	= [0, 0, 1]
					@pts	= [1, 3, 7, 5]
					@pts 	= [2, 0 , 4, 6]
					@side_vector = Geom::Vector3d.new(0, 1,0)
					@side_offset_wall_vector = Geom::Vector3d.new(0,-10,0)
				when -180, 180
					@cPos 	= [0, 0, 0]
					@cTarg 	= [0, -1, 0]
					@cUp 	= [0, 0, 1]
					@pts 	= [0, 1, 5, 4]
					@side_vector = Geom::Vector3d.new(-1,0,0)
					@side_offset_wall_vector = Geom::Vector3d.new(10,0,0)
					
				end





				comp_outline_flag=true
				if comp_outline_flag #for testing
							
				
					comps = view_h[view_name]['comps']
					transform = view_h[view_name]['transform']
					wall_length = wall.get_attribute(:rio_atts, 'view_wall_length').to_i.mm
					

					#----Background wall.........
					wall_pts = []
					case transform 
					when 0
						dim_vector = Geom::Vector3d.new(0,1,0)
						pt1 	= wall.bounds.corner(0)
						pt2 	= pt1.offset(Geom::Vector3d.new(1,0,0), wall_length)
						pt4 	= wall.bounds.corner(4)
						pt3 	= pt4.offset(Geom::Vector3d.new(1,0,0), wall_length)
					when 90
						dim_vector = Geom::Vector3d.new(-1,0,0)
						pt1 	= wall.bounds.corner(1)
						pt2 	= pt1.offset(Geom::Vector3d.new(0,1,0), wall_length)
						pt4 	= wall.bounds.corner(5)
						pt3 	= pt4.offset(Geom::Vector3d.new(0,1,0), wall_length)
					when -90
						dim_vector = Geom::Vector3d.new(1,0,0)
						pt1 	= wall.bounds.corner(2)
						pt2 	= pt1.offset(Geom::Vector3d.new(0,-1,0), wall_length)
						pt4 	= wall.bounds.corner(6)
						pt3 	= pt4.offset(Geom::Vector3d.new(0,-1,0), wall_length)
					when 180, -180
						dim_vector = Geom::Vector3d.new(0,-1,0)
						pt1 	= wall.bounds.corner(3)
						pt2 	= pt1.offset(Geom::Vector3d.new(-1,0,0), wall_length)
						pt4 	= wall.bounds.corner(7)
						pt3 	= pt4.offset(Geom::Vector3d.new(-1,0,0), wall_length)
					end

					#puts "Wall length : #{wall_length}"

					#@pts.each{|index| wall_pts << TT::Bounds.point(wall.bounds, index).offset(dim_vector, 30.mm)}
					#wall_face = Sketchup.active_model.entities.add_face wall_pts

					wpts = [pt1,pt2,pt3,pt4]
					wpts.each{|pt| wall_pts << pt.offset(dim_vector, 30.mm)}
					wall_face = Sketchup.active_model.entities.add_face wall_pts
					
					#puts "wall_pts : #{wall_pts} : #{wpts}"
					@offset_wall_zvector	= Geom::Vector3d.new(0,0,10)
					
					wall_face.hidden=true
					#return

					#......Sketchup 3d screenshot-----------------------------------------
					comps.each {|x| x.visible=true}
					#--------------------Write Image-----------------------------------
					outpath = File.join(RIO_ROOT_PATH, "temp/")
					end_format = ".jpg"
					Dir::mkdir(outpath) unless Dir::exist?(outpath)
					file_name = File.basename(DP::current_file_path, '.skp')
					
					room_image_name = room_name.gsub(' ', '_')
					bg_image_file_name = outpath+file_name+'_'+room_image_name+'_'+view_name+'_background'+end_format
					
					Sketchup.active_model.active_view.camera.set @cPos, @cTarg, @cUp
					Sketchup.active_model.active_view.zoom_extents
					keys = {
						:filename => bg_image_file_name,
						:width => 1920,
						:height => 1080,
						:antialias => true,
						:compression => 0,
						:transparent => true
					}
					
					Sketchup.active_model.active_view.camera.perspective = false
					
					#Sketchup.active_model.active_view.write_image keys
					Sketchup.active_model.active_view.write_image bg_image_file_name
					
					if wall_face
						Sketchup.active_model.entities.erase_entities(wall_face.edges) if !wall_face.deleted?
					end
					
					
					comps.each {|x| x.visible=false}

					set_x = false;set_y = false
					case transform 
					when 0
						dim_vector = Geom::Vector3d.new(0,1,0)
						view = 'back'
						index1 = 4
						index2 = 17
						set_y = true
					when 90
						dim_vector = Geom::Vector3d.new(-1,0,0)
						view = 'left'
						index1 = 7
						index2 = 17
						set_x  = true
					when -90
						dim_vector = Geom::Vector3d.new(1,0,0)
						view = 'right'
						index1 = 6
						index2 = 16
						set_x  = true
					when 180, -180
						dim_vector = Geom::Vector3d.new(0,-1,0)
						view = 'front'
						index1 = 6
						index2 = 19
						set_y  = true
					end
					
					#fsel.transformation.rotz
					#fsel.get_attribute :rio_atts, 'wall_trans'
					comp_list = {}
					
					#Wall dimesnion
					
					#wall_pts = []
					#@pts.each{|index| wall_pts << TT::Bounds.point(wall.bounds, index).offset(dim_vector, 3000.mm)}
					
					#wall_face = Sketchup.active_model.entities.add_face wall_pts
					#puts "wall_pts : #{wall_pts}"
					wall_pts = []
					wpts.each{|pt| 
						wall_pt = pt.offset(dim_vector, WALL_OUTLINE_OFFSET)
						if set_x
							wall_pt.x = WALL_OUTLINE_OFFSET
						elsif set_y
							wall_pt.y = WALL_OUTLINE_OFFSET
						end 
						wall_pts << wall_pt					
					}



					#puts "wall_pts.... : #{wall_pts}"

					wall_face = Sketchup.active_model.entities.add_face wall_pts
					@offset_wall_zvector	= Geom::Vector3d.new(0,0,10)
					
					wall_face.hidden=true
					
					
					#pt1, pt2 = wall_pts[0].offset(dim_vector, 3000.mm), wall_pts[1].offset(dim_vector, 3000.mm)
					pt1, pt2 = wall_pts[0], wall_pts[1]
					dim_l 	= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, @offset_wall_zvector.reverse) 
					dim_l.material.color = 'blue'
					dim_l.set_attribute :rio_atts, 'dimension_entity', 'true'
					
					#pt1, pt2 = wall_pts[1].offset(dim_vector, 3000.mm), wall_pts[2].offset(dim_vector, 3000.mm)
					pt1, pt2 = wall_pts[1], wall_pts[2]
					dim_l 	= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, @side_offset_wall_vector.reverse) 
					dim_l.material.color = 'blue'
					dim_l.set_attribute :rio_atts, 'dimension_entity', 'true'

					comps.each{ |comp|
						if comp.is_a?(Sketchup::ComponentInstance) && (comp.layer.name == 'DP_Comp_layer' || comp.layer.name == 'DP_Cust_Comp_layer')
							if comp.get_attribute(:rio_atts, 'custom_type') == 'filler'
								comp_pts = []
								@pts.each{|index| comp_pts << TT::Bounds.point(comp.bounds, index)}
								#puts "@pts : #{@pts} : #{comp_pts}"
								4.times{|i|
									pt1, pt2 = comp_pts[0].offset(dim_vector, COMP_DIMENSION_OFFSET), comp_pts[1].offset(dim_vector, COMP_DIMENSION_OFFSET)
									if set_x
										pt1.x = COMP_DIMENSION_OFFSET
										pt2.x = COMP_DIMENSION_OFFSET
									elsif set_y
										pt1.y = COMP_DIMENSION_OFFSET
										pt2.y = COMP_DIMENSION_OFFSET
									end 
									comp_outline = Sketchup.active_model.entities.add_line pt1, pt2
									comp_outline.set_attribute :rio_atts, 'dimension_entity', 'true'
									#puts "@side_vector.. : #{@side_vector.class} : #{pt1} : #{pt2} : #{i}"
									if i==1			
										dim_l 	= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, @side_vector) 
										dim_l.material.color = 'red'
										#dim_l.layer=wd_layer
										dim_l.set_attribute :rio_atts, 'dimension_entity', 'true'
										dim_l
									elsif i==0
										dim_l 	= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, zvector) 
										dim_l.material.color = 'red'
										#dim_l.layer=wd_layer
										dim_l.set_attribute :rio_atts, 'dimension_entity', 'true'
									end
									comp_pts.rotate!
								}
							else
								comp_pts = []
								@pts.each{|index| comp_pts << TT::Bounds.point(comp.bounds, index)}
								#puts "@pts : #{@pts} : #{comp_pts}"
								shade_pts = []
								4.times{|i|
									pt1, pt2 = comp_pts[0].offset(dim_vector, COMP_DIMENSION_OFFSET), comp_pts[1].offset(dim_vector, COMP_DIMENSION_OFFSET)
									if set_x
										pt1.x = COMP_DIMENSION_OFFSET
										pt2.x = COMP_DIMENSION_OFFSET
									elsif set_y
										pt1.y = COMP_DIMENSION_OFFSET
										pt2.y = COMP_DIMENSION_OFFSET
									end 

									shade_pts << pt1 #[pt1.offset(dim_vector, COMP_DIMENSION_OFFSET)]#, pt2.offset(dim_vector, COMP_DIMENSION_OFFSET)]
									comp_outline = Sketchup.active_model.entities.add_line pt1, pt2
									comp_outline.set_attribute :rio_atts, 'dimension_entity', 'true'
									#puts "@side_vector.. : #{@side_vector.class} : #{pt1} : #{pt2} : #{i}"
									if i==1			
										dim_l 	= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, @side_vector) 
										dim_l.material.color = 'red'
										#dim_l.layer=wd_layer
										dim_l.set_attribute :rio_atts, 'dimension_entity', 'true'
										dim_l
									elsif i==0
										dim_l 	= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, zvector) 
										dim_l.material.color = 'red'
										#dim_l.layer=wd_layer
										dim_l.set_attribute :rio_atts, 'dimension_entity', 'true'
									end
									comp_pts.rotate!
								}
								shade_pts.flatten!
								shade_pts.uniq!
								#puts "shade_pts : #{shade_pts}"

								#Internal_dimension addition
								#DP::add_rect_face_lines shade_pts
								add_internal_dimension comp


								# reset_comp_outer_edges
								# find_outer_edges(comp)
								# outer_edges = get_comp_outer_edges
								#
								# outer_edges.each{ |ent|
								# 	next if ent.nil? || ent.deleted?
								# 	pt1, pt2 = ent.vertices[0].position, ent.vertices[1].position
								# 	if set_x
								# 		pt1.x = COMP_DIMENSION_OFFSET
								# 		pt2.x = COMP_DIMENSION_OFFSET
								# 	elsif set_y
								# 		pt1.y = COMP_DIMENSION_OFFSET
								# 		pt2.y = COMP_DIMENSION_OFFSET
								# 	end
								#
								# 	outer_line = Sketchup.active_model.entities.add_line(pt1, pt2)
								# 	outer_line.material = 'yellow' if outer_line
								# }

								comp_name 					= "C#"+comp_count.to_s
								comp_list[comp_name]	 	= comp
								all_comp_list[comp_name] 	= comp
								comp_count += 1
								
								bound_point = TT::Bounds.point(comp.bounds, 26)
								p1 			= TT::Bounds.point( comp.bounds, index1 )
								p2 			= TT::Bounds.point( comp.bounds, index2 )
								bound_point = Geom.linear_combination( 0.5, p1, 0.5, p2 )
								
								coordinates = bound_point.offset(dim_vector, COMP_DIMENSION_OFFSET)
								text_point 	= Geom::Point3d.new coordinates
								
								text 		= Sketchup.active_model.entities.add_text comp_name, text_point
								text.set_attribute :rio_atts, 'temp_component_name', 'true'
								text.material.color = '7A003D'
							end
						else #if not component instance
							
						end
					}
					
					
					#Add row dimension..............................................	
					comp_h 		= DP::parse_components comps
					rows 		= get_comp_rows comp_h, view
					row_elems 	= rows.flatten.uniq
					comp_names 	= []
					
					comp_h.keys.each { |id| comp_h[id][:row_elem] = true if row_elems.include?(id)}
					rows.each{|row| comp_names << (add_row_dimension row, view)}
					
					#--------------------Write Image-----------------------------------
					outpath = File.join(RIO_ROOT_PATH, "temp/")
					end_format = ".jpg"
					Dir::mkdir(outpath) unless Dir::exist?(outpath)
					file_name = File.basename(DP::current_file_path, '.skp')
					room_img_name = room_name.gsub(" ","_")
					image_file_name = outpath+file_name+'_'+room_img_name+'_'+view_name+end_format
					
					Sketchup.active_model.active_view.camera.set @cPos, @cTarg, @cUp
					Sketchup.active_model.active_view.zoom_extents
					keys = {
						:filename => image_file_name,
						:width => 1920,
						:height => 1080,
						:antialias => true,
						:compression => 0,
						:transparent => true
					}
					
					Sketchup.active_model.active_view.camera.perspective = false
					
					#Sketchup.active_model.active_view.write_image keys
					Sketchup.active_model.active_view.write_image image_file_name
					
					#
                end

				visible_ents = Sketchup.active_model.entities.select{|ent| ent.layer.name='Rio_WorkingDrawing'}
				visible_ents.each{|ent| ent.visible=false}

				dim_ents = Sketchup.active_model.entities.select{|ent| ent.get_attribute(:rio_atts, 'dimension_entity') == 'true'}
				Sketchup.active_model.entities.erase_entities dim_ents

				comp_name_ents = Sketchup.active_model.entities.select{|ent| ent.get_attribute(:rio_atts, 'temp_component_name') == 'true'}
				Sketchup.active_model.entities.erase_entities comp_name_ents



                internal_flag = true
                if internal_flag


                    #--------------Add the wall outline----------------------
                    add_internal_wall_flag = true
                    if add_internal_wall_flag
                        comps = view_h[view_name]['comps']
                        transform = view_h[view_name]['transform']
                        wall_length = wall.get_attribute(:rio_atts, 'view_wall_length').to_i.mm


                        #----Background wall.........
                        wall_pts = []
                        case transform
                        when 0
                            dim_vector = Geom::Vector3d.new(0,1,0)
                            pt1 	= wall.bounds.corner(0)
                            pt2 	= pt1.offset(Geom::Vector3d.new(1,0,0), wall_length)
                            pt4 	= wall.bounds.corner(4)
                            pt3 	= pt4.offset(Geom::Vector3d.new(1,0,0), wall_length)
                        when 90
                            dim_vector = Geom::Vector3d.new(-1,0,0)
                            pt1 	= wall.bounds.corner(1)
                            pt2 	= pt1.offset(Geom::Vector3d.new(0,1,0), wall_length)
                            pt4 	= wall.bounds.corner(5)
                            pt3 	= pt4.offset(Geom::Vector3d.new(0,1,0), wall_length)
                        when -90
                            dim_vector = Geom::Vector3d.new(1,0,0)
                            pt1 	= wall.bounds.corner(2)
                            pt2 	= pt1.offset(Geom::Vector3d.new(0,-1,0), wall_length)
                            pt4 	= wall.bounds.corner(6)
                            pt3 	= pt4.offset(Geom::Vector3d.new(0,-1,0), wall_length)
                        when 180, -180
                            dim_vector = Geom::Vector3d.new(0,-1,0)
                            pt1 	= wall.bounds.corner(3)
                            pt2 	= pt1.offset(Geom::Vector3d.new(-1,0,0), wall_length)
                            pt4 	= wall.bounds.corner(7)
                            pt3 	= pt4.offset(Geom::Vector3d.new(-1,0,0), wall_length)
                        end

                        wpts = [pt1,pt2,pt3,pt4]

                        comps.each {|x| x.visible=false}

                        set_x = false;set_y = false
                        case transform
                        when 0
                            dim_vector = Geom::Vector3d.new(0,1,0)
                            view = 'back'
                            index1 = 4
                            index2 = 17
                            set_y = true
                        when 90
                            dim_vector = Geom::Vector3d.new(-1,0,0)
                            view = 'left'
                            index1 = 7
                            index2 = 17
                            set_x  = true
                        when -90
                            dim_vector = Geom::Vector3d.new(1,0,0)
                            view = 'right'
                            index1 = 6
                            index2 = 16
                            set_x  = true
                        when 180, -180
                            dim_vector = Geom::Vector3d.new(0,-1,0)
                            view = 'front'
                            index1 = 6
                            index2 = 19
                            set_y  = true
                        end

                        # comp_list = {}

                        wall_pts = []
                        wpts.each{|pt|
                            wall_pt = pt.offset(dim_vector, WALL_OUTLINE_OFFSET)
                            if set_x
                                wall_pt.x = WALL_OUTLINE_OFFSET
                            elsif set_y
                                wall_pt.y = WALL_OUTLINE_OFFSET
                            end
                            wall_pts << wall_pt
                        }



                        #puts "wall_pts.... : #{wall_pts}"

                        wall_face = Sketchup.active_model.entities.add_face wall_pts
                        @offset_wall_zvector	= Geom::Vector3d.new(0,0,10)

                        wall_face.hidden=true


                        #pt1, pt2 = wall_pts[0].offset(dim_vector, 3000.mm), wall_pts[1].offset(dim_vector, 3000.mm)
                        pt1, pt2 = wall_pts[0], wall_pts[1]
                        dim_l 	= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, @offset_wall_zvector.reverse)
                        dim_l.material.color = 'blue'
                        dim_l.set_attribute :rio_atts, 'dimension_entity', 'true'

                        #pt1, pt2 = wall_pts[1].offset(dim_vector, 3000.mm), wall_pts[2].offset(dim_vector, 3000.mm)
                        pt1, pt2 = wall_pts[1], wall_pts[2]
                        dim_l 	= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, @side_offset_wall_vector.reverse)
                        dim_l.material.color = 'blue'
                        dim_l.set_attribute :rio_atts, 'dimension_entity', 'true'
                    end

                    #-------------Add comp internals-------------------------
                    add_comp_internal_wall_flag = true
                    if add_comp_internal_wall_flag
                        pre_internal_entities = []
                        Sketchup.active_model.entities.each{|x| pre_internal_entities << x}
                        comps.each{ |comp|
                            if comp.is_a?(Sketchup::ComponentInstance) && (comp.layer.name == 'DP_Comp_layer' || comp.layer.name == 'DP_Cust_Comp_layer')
                                if comp.get_attribute(:rio_atts, 'custom_type') == 'filler'
                                else
                                    RioIntDim::add_internal_outlines comp
                                end
                            end
                        }
                    end

                    #-------------------Add image
                    add_internal_image_flag = true
                    if add_internal_image_flag
                        outpath = File.join(RIO_ROOT_PATH, "temp/")
                        end_format = ".jpg"
                        Dir::mkdir(outpath) unless Dir::exist?(outpath)
                        file_name = File.basename(DP::current_file_path, '.skp')
                        room_img_name = room_name.gsub(" ","_")
                        internal_image_file_name = outpath+file_name+'_'+room_img_name+'_'+view_name+'_internal'+end_format

                        Sketchup.active_model.active_view.camera.set @cPos, @cTarg, @cUp
                        Sketchup.active_model.active_view.zoom_extents
                        keys = {
                            :filename => internal_image_file_name,
                            :width => 1920,
                            :height => 1080,
                            :antialias => true,
                            :compression => 0,
                            :transparent => true
                        }

                        Sketchup.active_model.active_view.camera.perspective = false

                        #Sketchup.active_model.active_view.write_image keys
                        Sketchup.active_model.active_view.write_image internal_image_file_name
                    end

                    #--------------Post operation deletion...........
                    post_internal_entities = []
                    Sketchup.active_model.entities.each{|x| post_internal_entities << x}

                    new_entities = post_internal_entities - pre_internal_entities
                    Sketchup.active_model.entities.erase_entities(new_entities)
				end

                #Remove the wall face of the straight views
                if wall_face
                  Sketchup.active_model.entities.erase_entities(wall_face.edges) if !wall_face.deleted?
                end



				top_internal_flag = true
				if top_internal_flag

					#----Background wall for internal top view.........
					wall_pts = []
					case transform
					when 0
						dim_vector = Geom::Vector3d.new(0,1,0)
						pt1 	= wall.bounds.corner(4)
						pt2 	= pt1.offset(Geom::Vector3d.new(1,0,0), wall_length)
						pt4 	= wall.bounds.corner(6)
						pt3 	= pt4.offset(Geom::Vector3d.new(1,0,0), wall_length)
					when 90
						dim_vector = Geom::Vector3d.new(-1,0,0)
						pt1 	= wall.bounds.corner(4)
						pt2 	= pt1.offset(Geom::Vector3d.new(0,1,0), wall_length)
						pt4 	= wall.bounds.corner(5)
						pt3 	= pt4.offset(Geom::Vector3d.new(0,1,0), wall_length)
					when -90
						dim_vector = Geom::Vector3d.new(1,0,0)
						pt1 	= wall.bounds.corner(6)
						pt2 	= pt1.offset(Geom::Vector3d.new(0,-1,0), wall_length)
						pt4 	= wall.bounds.corner(7)
						pt3 	= pt4.offset(Geom::Vector3d.new(0,-1,0), wall_length)
					when 180, -180
						dim_vector = Geom::Vector3d.new(0,-1,0)
						pt1 	= wall.bounds.corner(5)
						pt2 	= pt1.offset(Geom::Vector3d.new(-1,0,0), wall_length)
						pt4 	= wall.bounds.corner(7)
						pt3 	= pt4.offset(Geom::Vector3d.new(-1,0,0), wall_length)
					end

					#puts "Wall length : #{wall_length}"

					#@pts.each{|index| wall_pts << TT::Bounds.point(wall.bounds, index).offset(dim_vector, 30.mm)}
					#wall_face = Sketchup.active_model.entities.add_face wall_pts

					wpts = [pt1,pt2,pt3,pt4]
					wpts.each{|pt| wall_pts << pt.offset(dim_vector, 30.mm)}
					wall_face = Sketchup.active_model.entities.add_face wall_pts

					#----------Component dimensions--------------------
                    comps = view_h[view_name]['comps']
                    top_comps = get_top_room_comps room_name
                    top_view_comps = top_comps & comps
                    pre_internal_entities = []
                    Sketchup.active_model.entities.each{|x| pre_internal_entities << x}
                    top_view_comps.each{ |comp|
                      if comp.is_a?(Sketchup::ComponentInstance) && (comp.layer.name == 'DP_Comp_layer' || comp.layer.name == 'DP_Cust_Comp_layer')
                        if comp.get_attribute(:rio_atts, 'custom_type') == 'filler'
                        else
                          RioIntDim::add_top_outlines comp
                        end
                      end
                    }

                    #-------------------Add image
                    add_internal_image_flag = true

                    if add_internal_image_flag
                      outpath = File.join(RIO_ROOT_PATH, "temp/")
                      end_format = ".jpg"
                      Dir::mkdir(outpath) unless Dir::exist?(outpath)
                      file_name = File.basename(DP::current_file_path, '.skp')
                      room_img_name = room_name.gsub("#","_")
                      top_internal_image_file_name = outpath+file_name+'_'+room_img_name+'_'+view_name+'_top_internal'+end_format

					  @cPos = [0, 0, 0]
					  @cTarg = [0, 0, -1]
					  @cUp = [0, 1, 0]

                      Sketchup.active_model.active_view.camera.set @cPos, @cTarg, @cUp
                      Sketchup.active_model.active_view.zoom_extents
                      keys = {
                          :filename => top_internal_image_file_name,
                          :width => 1920,
                          :height => 1080,
                          :antialias => true,
                          :compression => 0,
                          :transparent => true
                      }

                      Sketchup.active_model.active_view.camera.perspective = false

                      #Sketchup.active_model.active_view.write_image keys
                      Sketchup.active_model.active_view.write_image top_internal_image_file_name
                    end

                    post_internal_entities = []
                    Sketchup.active_model.entities.each{|x| post_internal_entities << x}

                    new_entities = post_internal_entities - pre_internal_entities
                    Sketchup.active_model.entities.erase_entities(new_entities)

					if wall_face
						Sketchup.active_model.entities.erase_entities(wall_face.edges) if !wall_face.deleted?
					end
					
				end #top_internal_flag

                #return
				#puts "comp_list : #{comp_list}"
                view_details_h[view_name] = {
                    :comp_list => comp_list,
                    :outline_file_name => image_file_name,
                    :internal_file_name => internal_image_file_name,
                    :background_file_name => bg_image_file_name,
                    :top_internal_file_name => top_internal_image_file_name
                }

				
				#------------------------------------------------------------
                #dim_ents = Sketchup.active_model.entities.select{|ent| ent.get_attribute(:rio_atts, 'dimension_entity') == 'true'}
                #Sketchup.active_model.entities.erase_entities dim_ents


				if wall_face
					Sketchup.active_model.entities.erase_entities(wall_face.edges) if !wall_face.deleted?
				end

				
			}#....Each view
			
			
		
			
			#===================================================Top View===============================
			dim_ents = Sketchup.active_model.entities.select{|ent| ent.get_attribute(:rio_atts, 'dimension_entity') == 'true'}
			Sketchup.active_model.entities.erase_entities dim_ents
			
			#return

			top_view = true
			if(top_view) #For testing

				#***************************** FInd and add face for the top view **************************
				#I am adding group origin values to make the exact face.....or it will come in origin
				floor_gp = Sketchup.active_model.entities.select{|ent| ent.layer.name == 'DP_Floor_'+room_name.to_s}[0]
				floor_origin = floor_gp.transformation.origin
				
				room_face_pts = []
				room_face.outer_loop.vertices.each{|vert|
					#puts "posn : #{vert.position}"
					pt = vert.position.offset(zvector, -10.mm)
					pt.x += floor_origin.x
					pt.y += floor_origin.y
					room_face_pts << pt
				}
				
				es = Sketchup.active_model.entities
				es.each{|x| x.visible=false}
				
				#puts "room_face_pts : #{room_face_pts}"
				floor_face = Sketchup.active_model.entities.add_face(room_face_pts)
				
				#Adding dimension to top view face
				floor_edges = []
				floor_face.edges.each{|edge| floor_edges << edge}
				floor_edges.length.times {|index|
					curr_edge 	=  	floor_edges[0]
					next_edge 	=	floor_edges[1]
					if MRP::check_perpendicular(curr_edge, next_edge)
						break
					else
						floor_edges.rotate! 
					end
				}
				floor_edges.rotate! #Start with the perpendicular edge

				edge_list  	= []
				last_edge 	= nil
				vector 		= nil
				first_edge = floor_edges[0]

				floor_edges.each{|edge|
					if edge_list.empty?
						edge_list << edge
						last_edge = edge
					else
						curr_edge = edge
						#puts "curr_edge : #{curr_edge} : #{last_edge} : #{edge_list}"
						if MRP::check_perpendicular(curr_edge, last_edge)
							#puts "perpendicular : #{curr_edge} : #{last_edge}"
							common_vertex 	= (curr_edge.vertices & last_edge.vertices)[0]
							other_vertex = curr_edge.vertices - [common_vertex]
							other_vertex = other_vertex[0]
							
							vector  = common_vertex.position.vector_to other_vertex
							pt 		= last_edge.bounds.center.offset vector, 10.mm
							res  	= floor_face.classify_point(pt)
							
							if res == Sketchup::Face::PointInside || res == Sketchup::Face::PointOnFace
								vector = vector.reverse
							end
							#puts res, vector.reverse
							
							MRP::add_edge_array_dimension(edge_list, vector)
							#puts "edge_list #{edge_list} : #{vector}"
							edge_list = [curr_edge]	
							last_edge = curr_edge
						else
							edge_list << curr_edge
							last_edge = curr_edge
						end
					end
				}

				#puts "first_edge : #{first_edge} : #{last_edge}" 
				#For the last list of edge
				common_vertex 	= (first_edge.vertices & last_edge.vertices)[0]
				other_vertex = first_edge.vertices - [common_vertex]
				other_vertex = other_vertex[0]

				vector  = common_vertex.position.vector_to other_vertex
				pt 		= last_edge.bounds.center.offset vector, 10.mm
				res  	= floor_face.classify_point(pt)

				#puts res, vector.reverse, "jhfjkh"
				#puts "edge_list : #{edge_list} : #{vector}"
				if res == Sketchup::Face::PointInside || res == Sketchup::Face::PointOnFace
					#vector = vector.reverse
				end 
				MRP::add_edge_array_dimension(edge_list, vector.reverse)

				#********************* Add outline & dimension for the other top comps
				Sketchup.active_model.entities.each{|ent| ent.visible=true}
				top_comps = get_top_room_comps room_name
				#puts "all_comp_list : #{all_comp_list} : #{top_comps}"
				Sketchup.active_model.entities.each{|ent| ent.visible=false}
				
				#Top dimensions
				floor_edges.each{|edge| edge.visible=true}
				
				#Top bg image
				top_comps.each {|x| x.visible=true}
				#--------------------Write Image-----------------------------------
				outpath = File.join(RIO_ROOT_PATH, "temp/")
				end_format = ".jpg"
				Dir::mkdir(outpath) unless Dir::exist?(outpath)
				file_name = File.basename(DP::current_file_path, '.skp')
				new_room_name = room_name.gsub(" ", "_")
				top_bg_image_file_name = outpath+file_name+'_'+new_room_name+'_'+'top_background'+end_format
				
				@cPos = [0, 0, 0]
				@cTarg = [0, 0, -1]
				@cUp = [0, 1, 0]
				
				Sketchup.active_model.active_view.camera.set @cPos, @cTarg, @cUp
				Sketchup.active_model.active_view.zoom_extents
				keys = {
					:filename => top_bg_image_file_name,
					:width => 1920,
					:height => 1080,
					:antialias => true,
					:compression => 0,
					:transparent => true
				}
				
				Sketchup.active_model.active_view.camera.perspective = false
				
				#Sketchup.active_model.active_view.write_image keys
				Sketchup.active_model.active_view.write_image top_bg_image_file_name
				
				
				
				top_comps.each {|x| x.visible=false}
				
				
				
				
				top_comps.each{ |comp|
					comp_name = all_comp_list.key(comp)
					comp_pts = []
					[4,5,7,6].each{|index| comp_pts << TT::Bounds.point(comp.bounds, index)}
					#puts "@pts : #{@pts} : #{comp_pts}"
					4.times{|i|
						pt1, pt2 = comp_pts[0].offset(zvector, 10000.mm), comp_pts[1].offset(zvector, 10000.mm)

						#This is to make all pts at z=0 for zoom component
						pt1.z=0
						pt2.z=0
						
						comp_outline = Sketchup.active_model.entities.add_line pt1, pt2
						comp_outline.set_attribute :rio_atts, 'dimension_entity', 'true'
						#puts "@side_vector.. : #{@side_vector.class} : #{pt1} : #{pt2} : #{i}"
						if i==1			
							vector = Geom::Vector3d.new(-1,0,0)
							dim_l 	= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, vector) 
							dim_l.material.color = 'red'
							dim_l.set_attribute :rio_atts, 'dimension_entity', 'true'
							dim_l
						elsif i==0
							vector = Geom::Vector3d.new(0,1,0)
							dim_l 	= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, vector) 
							dim_l.material.color = 'red'
							dim_l.set_attribute :rio_atts, 'dimension_entity', 'true'
						end
						comp_pts.rotate!
					}
					
					bound_point = TT::Bounds.point(comp.bounds, 26)
					
					coordinates = bound_point.offset(zvector, 10000.mm)
					text_point 	= Geom::Point3d.new coordinates
					
					#puts "comp_name : #{comp_name} : #{text_point}"

					
					if comp_name
						transform = comp.transformation.rotz
						case transform 
						when 0
							dim_vector = Geom::Vector3d.new(0,1,0)
							view = 'back'
							index1 = 4
							index2 = 17
						when 90
							dim_vector = Geom::Vector3d.new(-1,0,0)
							view = 'left'
							index1 = 7
							index2 = 17
						when -90
							dim_vector = Geom::Vector3d.new(1,0,0)
							view = 'right'
							index1 = 6
							index2 = 16
						when 180, -180 
							dim_vector = Geom::Vector3d.new(0,-1,0)
							view = 'front'
							index1 = 6
							index2 = 19
						end

						index1 = 6
						index2 = 13
						
						p1 			= TT::Bounds.point( comp.bounds, index1 )
						p2 			= TT::Bounds.point( comp.bounds, index2 )
						bound_point = Geom.linear_combination( 0.5, p1, 0.5, p2 )
						bound_point.z = 0
						coordinates = bound_point.offset(dim_vector, 1000.mm)
						text_point 	= Geom::Point3d.new coordinates

						text 		= Sketchup.active_model.entities.add_text comp_name, bound_point
						text.set_attribute :rio_atts, 'temp_component_name', 'true'
						text.material.color = '7A003D'
					end
				}
				
				#If floor_background needed
				floor_background = true
				if floor_background
					floor_face.hidden = false
					floor_face.material = 'white'
					floor_face.back_material = 'white'
				else
					floor_face.hidden = true
				end
				dim_ents = Sketchup.active_model.entities.select{|ent| ent.get_attribute(:rio_atts, 'dimension_entity') == 'true'}
				dim_ents.each{|ent| ent.visible=true}
				
				outpath = File.join(RIO_ROOT_PATH, "temp/")
				end_format = ".jpg"
				Dir::mkdir(outpath) unless Dir::exist?(outpath)
				file_name = File.basename(DP::current_file_path, '.skp')
				
				room_image_name = room_name.gsub(' ', '_')
				top_image_file_name = outpath+file_name+'_'+room_image_name+'_'+'top'+end_format

				@cPos = [0, 0, 0]
				@cTarg = [0, 0, -1]
				@cUp = [0, 1, 0]
				Sketchup.active_model.active_view.camera.set @cPos, @cTarg, @cUp
				Sketchup.active_model.active_view.zoom_extents
				keys = {
					:filename => top_image_file_name,
					:width => 1920,
					:height => 1080,
					:antialias => true,
					:compression => 0,
					:transparent => true
				}
				
				Sketchup.active_model.active_view.camera.perspective = false
				
				#Sketchup.active_model.active_view.write_image keys
				Sketchup.active_model.active_view.write_image top_image_file_name
				
				view_details_h["top_view"] = [top_image_file_name, top_bg_image_file_name]
				
				visible_ents = Sketchup.active_model.entities.select{|ent| ent.layer.name='Rio_WorkingDrawing'}
				visible_ents.each{|ent| ent.visible=false}
				
				dim_ents = Sketchup.active_model.entities.select{|ent| ent.get_attribute(:rio_atts, 'dimension_entity') == 'true'}
				Sketchup.active_model.entities.erase_entities dim_ents
				
				comp_name_ents = Sketchup.active_model.entities.select{|ent| ent.get_attribute(:rio_atts, 'temp_component_name') == 'true'}
				Sketchup.active_model.entities.erase_entities comp_name_ents
				
				Sketchup.active_model.entities.erase_entities(floor_face.edges)
			end
			
			#return
			
			#============================================Top================================================
			
			
			
			#Sketchup.active_model.active_layer='Layer0'
			#Sketchup.active_model.entities.each{|ent| ent.visible=false if ent.layer.name='Rio_WorkingDrawing'}
			#Sketchup.active_model.entities.each{|ent| ent.visible=true unless ent.layer.name='Rio_WorkingDrawing'}
			
			
			Sketchup.active_model.entities.each{|ent| ent.visible=true}
			
			Sketchup.active_model.active_view.camera=active_camera
			Sketchup.active_model.active_view.zoom_extents
			Sketchup.active_model.active_view.camera.perspective = true
			
			# puts "\n\n Working Drawing hash "
			# puts view_details_h
		rescue Exception => e
			puts "Exception raisedd during working drawing..."
			puts e
			raise e
			puts "------------------------------------------"
			Sketchup.active_model.active_view.camera.perspective = true
			Sketchup.active_model.rendering_options["EdgeColorMode"] = edge_render_option
			Sketchup.active_model.abort_operation
			exception_raised = true
		else
			Sketchup.active_model.commit_operation
		end

		#Post operations
		Sketchup.active_model.rendering_options["EdgeColorMode"] = edge_render_option

		# puts "exception_raised : #{exception_raised}"
		if exception_raised
			return {}
		else
			return view_details_h
		end
	end


	
	def self.add_internal_dimension comp
		# puts "add_internal_dimension : #{comp}"
	
		zvector = Geom::Vector3d.new(0, 0, 1)
		
		#Internal shelf fix entities
		shelf_fix_entities 	= comp.definition.entities.select{|x| x.layer.name.start_with?('72IMOSXD01_IM_SHELF_FIX')}
		shelf_fix_entities.sort_by!{|x| x.transformation.origin.z}
		lower_shelf_fix 	= shelf_fix_entities.first
		upper_shelf_fix		= shelf_fix_entities.last
		
		#Shutter outline
		shutter_code    = comp.get_attribute(:rio_atts, 'shutter-code') 
		shutter_code    = comp.definition.get_attribute(:rio_atts, 'shutter-code') if shutter_code.nil?
		# puts "shutter_code : #{shutter_code}"
		
		side_vector = Geom::Vector3d.new(1,0,0)
		
		trans = comp.transformation.rotz
		case trans
		when 0
			@cPos 	= [0, 0, 0]
			@cTarg 	= [0, 1, 0]
			@cUp 	= [0, 0, 1]
			@pts 	= [0, 1, 5, 4]
			@pts 	= [2, 3, 7, 6]	 
			set_y 	= true
			@side_vector = Geom::Vector3d.new(-1,0,0)
			@side_offset_wall_vector = Geom::Vector3d.new(-10,0,0)
			dim_vector = Geom::Vector3d.new(0,1,0)
		when 90
			@cPos 	= [0, 0, 0]
			@cTarg 	= [-1, 0, 0]
			@cUp 	= [0, 0, 1]
			@pts 	= [2, 0 , 4, 6]
			@pts 	= [1, 3, 7, 5]
			set_x  	= true
			@side_vector = Geom::Vector3d.new(0,1,0)
			@side_offset_wall_vector = Geom::Vector3d.new(0,10,0)
			dim_vector = Geom::Vector3d.new(-1,0,0)
		when -90
			@cPos 	= [0, 0, 0]
			@cTarg 	= [1, 0, 0]
			@cUp 	= [0, 0, 1]
			@pts	= [1, 3, 7, 5]
			@pts 	= [2, 0 , 4, 6]
			set_x  	= true
			@side_vector = Geom::Vector3d.new(0,-1,0)
			@side_offset_wall_vector = Geom::Vector3d.new(0,-10,0)
			dim_vector = Geom::Vector3d.new(1,0,0)
		when -180, 180
			@cPos 	= [0, 0, 0]
			@cTarg 	= [0, -1, 0]
			@cUp 	= [0, 0, 1]
			@pts 	= [0, 1, 5, 4]
			set_y 	= true
			@side_vector = Geom::Vector3d.new(1,0,0)
			@side_offset_wall_vector = Geom::Vector3d.new(10,0,0)
			dim_vector = Geom::Vector3d.new(0,-1,0)
		end
		
		if shutter_code
			shutter_ent		= comp.definition.entities.select{|e| e.definition.name.start_with?(shutter_code)}[0]
			#Check if shutter entities more than one.
			
			prev_shutter = nil
			show_dimension = true
			shutter_ent.definition.entities.each{ |sh_ent|
				if prev_shutter
					show_dimension 	= false if DP::get_comp_volume(sh_ent).round==DP::get_comp_volume(prev_shutter).round
				end
				prev_shutter 	= sh_ent
				#puts sh_ent.bounds.corner(0)
				
				comp_pts 		= []
				@pts.each{|index| comp_pts << TT::Bounds.point(sh_ent.bounds, index)}
				
				sh_ent_bounds  	= sh_ent.bounds
				sh_org 	= comp.transformation.origin
				shade_pts = []
				#puts "pts : #{comp_pts} : #{dim_vector} : #{sh_org}"
				#puts "show : #{show_dimension}"
				4.times{|i|
					pt1, pt2 = comp_pts[0].offset(dim_vector, COMP_DIMENSION_OFFSET), comp_pts[1].offset(dim_vector, COMP_DIMENSION_OFFSET)
					pt1.x+=sh_org.x
					pt2.x+=sh_org.x
					pt1.y+=sh_org.y
					pt2.y+=sh_org.y
					pt1.z+=sh_org.z
					pt2.z+=sh_org.z

					if set_x
						pt1.x = COMP_DIMENSION_OFFSET
						pt2.x = COMP_DIMENSION_OFFSET
					elsif set_y
						pt1.y = COMP_DIMENSION_OFFSET
						pt2.y = COMP_DIMENSION_OFFSET
					end 

					#puts "pt : #{pt1} : #{pt2}"
					shade_pts << [pt1.offset(dim_vector, COMP_DIMENSION_OFFSET)]#, pt2.offset(dim_vector, COMP_DIMENSION_OFFSET)]
					comp_outline = Sketchup.active_model.entities.add_line pt1, pt2
					comp_outline.set_attribute :rio_atts, 'dimension_entity', 'true'
					#puts "@side_vector.. : #{@side_vector.class} : #{pt1} : #{pt2} : #{i}"
					
					if show_dimension
						if i==1			
							dim_l 	= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, @side_vector) 
							dim_l.material.color = 'olive'
							#dim_l.layer=wd_layer
							dim_l.set_attribute :rio_atts, 'dimension_entity', 'true'
							dim_l
						elsif i==0
							dim_l 	= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, zvector) 
							dim_l.material.color = 'olive'
							#dim_l.layer=wd_layer
							dim_l.set_attribute :rio_atts, 'dimension_entity', 'true'
						end
					end
					comp_pts.rotate!
				}
                DP::add_rect_face_lines(shade_pts.flatten!) unless shade_pts.empty?
			}
		end
		
		#Sketchup.active_model.selection.clear
		#Sketchup.active_model.selection.add(shutter_ent)
	
	end

	def self.find_outer_edges(entity, transformation = IDENTITY)
		#puts entity
		if entity.is_a?( Sketchup::Model)
			#puts "Modellll."
			entity.entities.each{ |child_entity|
			  find_outer_edges(child_entity, transformation)
			}
		elsif entity.is_a?(Sketchup::Group)
			#puts "Group : "
			transformation *= entity.transformation
			entity.definition.entities.each{ |child_entity|
			  find_outer_edges(child_entity, transformation.clone)
			}
		elsif entity.is_a?(Sketchup::ComponentInstance)
			#puts "ComponentInstance : "
			# Multiply the outer coordinate system with the group's/component's local coordinate system.
			transformation *= entity.transformation
			entity.definition.entities.each{ |child_entity|
				find_outer_edges(child_entity, transformation.clone)
			}
		elsif entity.is_a?(Sketchup::Face)
			#puts "Face : "
			#@verts << entity.vertices
			edges 	= entity.edges
			edges.each { |edge|
				efaces 	= edge.faces 
				if efaces.length == 1
					@comp_outer_edges << edge
				else
					@comp_outer_edges << edge if efaces[0].normal != efaces[1].normal
				end
			}
		end
	end


end