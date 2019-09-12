# load 'E:\git\siva\controller\dp_core.rb'
# load 'E:\git\siva\scripts\multi_room_door.rb'
# load 'E:\git\siva\controller\room_tool.rb'
# load 'E:\git\siva\scripts\multi_room_preprocess.rb'
# load 'E:\git\siva\scripts\multi_room_door.rb'
# load 'E:\git\siva\controller\room_tool.rb'

def check_wall_intersection comp, walls
	intersect_wall = false
	walls.each {|wall|
		res = DP::get_intersect_area comp, wall
		#puts "res : #{res}"
		next if res[0] == false
		if res[0] == 'volume'
			return ['overlap', wall]
		elsif res[0] == 'area'
			intersect_wall = true
		end
	}
	if intersect_wall
		#Properly touching wall
		return ['perfect', nil]
	else
		#Component in the room but not touching wall
		return ['not_glued', nil]
	end
end

def check_comp_intersection comp, room_name
	room_walls  = DP::get_walls room_name
	room_comps 	= MRP::get_room_components room_name
	room_walls.each{|wall|
		res = DP::get_intersect_area comp, wall
		if res[0] == 'volume'
			puts "Cannot place component. Component overlaps wall"
			return false
		end
	}
	room_comps = room_comps - [comp]
	room_comps.each{|room_comp|
		res = DP::get_intersect_area comp, room_comp
		if res[0] == 'volume'
			# puts "room_comp : #{room_comp} : #{comp}
			puts "Cannot place component. Component overlaps another component"
			Sketchup.active_model.selection.add(comp)
			Sketchup.active_model.selection.add(room_comp)
			return false
		end
	}
	return true
end

def get_comp_move_vector comp
	return false if comp.nil? || comp.deleted?
	comp_trans = comp.transformation.rotz
	case comp_trans
	when 0
		return Geom::Vector3d.new(0,-1,0)
	when 90
		return Geom::Vector3d.new(1,0,0)
	when -90
		return Geom::Vector3d.new(-1,0,0)
	when 180, -180
		return Geom::Vector3d.new(0,1,0)
	end
	return false
end

def get_comp_wall_offset comp, wall
	return false if comp.nil? || comp.deleted?
	comp_trans = comp.transformation.rotz
	
	wall_origin = wall.transformation.origin
	comp_origin = comp.transformation.origin
	
	offset = 0
	case comp_trans
	when 0
		offset = comp.bounds.corner(2).y - wall.bounds.corner(0).y
	when 90
		offset = wall.bounds.corner(1).x - comp.bounds.corner(0).x
	when -90
		offset = wall.bounds.corner(0).x - comp.bounds.corner(1).x
	when 180, -180
		offset = wall.bounds.corner(2).y - comp.bounds.corner(0).y
	end
	offset = offset.abs
	return offset
end

def set_camera comp
	trans = comp.transformation.rotz
	case trans
	when 0
		cPos 	= [0, 0, 0]
		cTarg 	= [0, 1, 0]
		cUp 	= [0, 0, 1]
	when 90
		cPos 	= [0, 0, 0]
		cTarg 	= [-1, 0, 0]
		cUp 	= [0, 0, 1]
	when -90
		cPos 	= [0, 0, 0]
		cTarg 	= [1, 0, 0]
		cUp 	= [0, 0, 1]
	when -180, 180
		cPos 	= [0, 0, 0]
		cTarg 	= [0, -1, 0]
		cUp 	= [0, 0, 1]
	end
	Sketchup.active_model.active_view.camera.set cPos, cTarg, cUp
	Sketchup.active_model.active_view.zoom_extents
end


def scan_room_components room_name, correction_flag=false
	comps_auto_corrected = false
    
    continue_flag = true
    
	#Change to all components if some components are copied from other room
	#room_comps 	= MRP::get_room_components room_name
	#room_comps 	= Sketchup.active_model.entities.select{|comp| comp.get_attribute 'rio_comp'==true}
	room_comps 	= Sketchup.active_model.entities.select{|comp| !comp.get_attribute(:rio_atts, 'rio_comp').nil?}
	floor_face 	= MRP::get_room_face room_name
	room_walls  = DP::get_walls room_name
	zvector		= Geom::Vector3d.new(0, 0, 1)
	
	floor_gp 		= Sketchup.active_model.entities.select{|ent| ent.layer.name == 'DP_Floor_'+room_name.to_s}[0]
	floor_origin 	= floor_gp.transformation.origin

	wall_height 	= floor_gp.get_attribute(:rio_atts, 'wall_height').to_i.mm

	proper_comps 	= []
	
	if room_comps.empty?
		puts "No Component to scan in room #{room_name}"
		return false
	elsif floor_face.nil?
		return false
	elsif room_walls.empty?
		puts "No walls in the room"
		return false
	elsif floor_gp.nil?
		puts "Floor group not found"
		return false
	end
	
	previous_ents =[]
	Sketchup.active_model.entities.each{|ent| previous_ents << ent}
	
	
	room_face_pts = []
	floor_face.outer_loop.vertices.each{|vert|
		#puts "posn : #{vert.position}"
		pt = vert.position.offset(zvector, 10000.mm)
		pt.x += floor_origin.x
		pt.y += floor_origin.y
		room_face_pts << pt
	}
	hit_face = Sketchup.active_model.entities.add_face(room_face_pts)

	
	#Only hit face and the component should be visible
	Sketchup.active_model.entities.each{|x| x.visible=false}
	hit_face.visible = true
	
	hit_ents = []
	hit_ents << hit_face
	hit_ents << hit_face.edges
	hit_ents.flatten!
	
	#----------------Pre positioning tests-------------------------
	room_comps.each {|comp|
		inside = true
		
		#---------------------Test 1-------------------------------
		#First test to check component within the 2d floor face....
		#raytest with the face created similar to floor face
		comp.visible = true
		[4, 5, 6, 7].each{|index|
			ray = [comp.bounds.corner(index), zvector]
			hit_item 	= Sketchup.active_model.raytest(ray, true)
			# puts "hit_item :-------- #{hit_item}"
			if hit_item && hit_ents.include?(hit_item[1][0])
			
			else
				sel.add(hit_item[1][0]) if hit_item
				inside = false
			end
		}
		comp.visible = false
		
		#---------------------Test 2-------------------------------
		#Test for component placed position
		#Checking for gluing
		# puts "insidee : #{inside}"
		if inside
			#---------------------Sub Test 2-------------------------------
			#Next test to check component within the room 3d bounds.....
			#Top and bottom check
			comp_origin = comp.transformation.origin
			z_offset 	= 0
			if comp_origin.z < floor_origin.z
				res = DP::get_intersect_area comp, floor_gp
				if res[0] != false
					z_offset = floor_origin.z - comp_origin.z
					puts "Component below the floor and intersect the floor"
				else
					puts "Component below the room"
					next
				end
			end
			
			component_top_end 	= comp.transformation.origin.z + comp.bounds.depth
			room_top_end		= floor_origin.z + wall_height
			if comp_origin.z > room_top_end
				puts "Component above ceiling"
				next
			elsif component_top_end > room_top_end
				z_offset = room_top_end - component_top_end
				puts "Component intersects ceiling"
			end
			
			if z_offset != 0 && correction_flag
				transform_vector = Geom::Vector3d.new(0, 0, z_offset)
				transformed_inst 	= comp.transform!(transform_vector)
				proper_comps		<< transformed_inst
				comps_auto_corrected = true
			else
				proper_comps 		<< comp
			end		
			#--------------------- 		End of Sub Test -------------------------------
			
			
			res = check_wall_intersection comp, room_walls
			# puts "res : #{res}"
			if res[0] == 'not_glued' && correction_flag
				puts "Component inside but not glued to wall"
				comp_trans	= comp.transformation.rotz
				
				if comp_trans.abs == 180
					trans_walls = room_walls.select{|wall| wall.get_attribute(:rio_atts, 'wall_trans')==comp_trans.abs}
				else
					trans_walls = room_walls.select{|wall| wall.get_attribute(:rio_atts, 'wall_trans')==comp_trans}
				end
				
				# puts "trans_walls : #{trans_walls}"
				if trans_walls.length == 0
					puts "No Walls to associate this component : #{comp.persistent_id}"
				elsif trans_walls.length == 1
					Sketchup.active_model.selection.clear
					Sketchup.active_model.selection.add(comp)
					
					curr_cam			= Sketchup.active_model.active_view.camera
					last_seen_camera 	= Sketchup::Camera.new curr_cam.eye, curr_cam.target, curr_cam.up
					#Sketchup.active_model.entities.each{|ent| ent.visible = false}
					hit_ents.each{|ent| ent.visible = false}
					comp.visible = true
					trans_walls[0].visible = true
					set_camera comp
					
					resp 	=  UI.messagebox 'The selected component will be moved to wall behind.', MB_OKCANCEL
					if resp == IDOK						
						move_vector 		= (get_comp_move_vector comp).reverse
						move_offset			= get_comp_wall_offset comp, trans_walls[0]
						transform_vector 	= Geom::Vector3d.new(move_vector.x*move_offset, move_vector.y*move_offset, 0)
						transformation 		= comp.transformation
						
						room_comps.each{|comp| comp.visible=true}
						transformed_inst 	= comp.transform!(transform_vector)
						res 				= check_comp_intersection transformed_inst, room_name
						room_comps.each{|comp| comp.visible=false}
						
						puts "checking component intersection : #{res}"
						if res
							proper_comps		<< transformed_inst
							comp.set_attribute :rio_atts, 'associated_wall', trans_walls[0].persistent_id
							comps_auto_corrected = true
						else
							UI.messagebox "Component cant be attached to wall since it overlaps other component"
							#transformed_inst 	= transformed_inst.transform!(transformation)
							transformed_inst.transformation=transformation
							continue_flag = false
							#return [[], false]
							proper_comps		<< transformed_inst
						end
						
					else
						resp 	=  UI.messagebox 'The selected component should be available in working drawing?', MB_OKCANCEL
						if resp == IDOK
							comp.set_attribute :rio_atts, 'associated_wall', trans_walls[0].persistent_id
							comp.set_attribute :rio_atts, 'visible_in_working_drawing', true
						else
							comp.set_attribute :rio_atts, 'visible_in_working_drawing', false
						end
					end
					
					#Resetting All the changes................
					hit_ents.each{|ent| ent.visible = true}
					trans_walls[0].visible = false
					comp.visible = false
					Sketchup.active_model.active_view.camera	= last_seen_camera
				else
					room_walls.each{|wall| wall.visible=true}
					
					ray_vector 	= (get_comp_move_vector comp).reverse
					ray = [comp.bounds.center, ray_vector]
					comp.visible = false
					hit_item = Sketchup.active_model.raytest(ray, true)
					
					room_walls.each{|wall| wall.visible=false}
					
					puts "Multiple walls for this component.. : #{comp.persistent_id} : #{ray_vector} : #{comp.bounds.center}"
					# puts "hit_item : #{hit_item}"
					#return
					if hit_item
						Sketchup.active_model.selection.add(hit_item[1])
						if room_walls.include?(hit_item[1][0])
							wall = hit_item[1][0]
							move_offset		= get_comp_wall_offset comp, wall
							
							#.....Others Same as single wall.................
							Sketchup.active_model.selection.clear
							Sketchup.active_model.selection.add(comp)
							
							curr_cam			= Sketchup.active_model.active_view.camera
							last_seen_camera 	= Sketchup::Camera.new curr_cam.eye, curr_cam.target, curr_cam.up
							#Sketchup.active_model.entities.each{|ent| ent.visible = false}
							hit_ents.each{|ent| ent.visible = false}
							comp.visible = true
							wall.visible = true
							set_camera comp
							#return
							
							resp 	=  UI.messagebox 'The selected component will be moved to wall behind by '+move_offset.to_mm.round(3).to_s+'mm', MB_OKCANCEL
							if resp == IDOK						
								move_vector 		= (get_comp_move_vector comp).reverse
								transform_vector 	= Geom::Vector3d.new(move_vector.x*move_offset, move_vector.y*move_offset, 0)
								transformation 		= comp.transformation
								
								room_comps.each{|comp| comp.visible=true}
								transformed_inst 	= comp.transform!(transform_vector)
								res 				= check_comp_intersection transformed_inst, room_name
								room_comps.each{|comp| comp.visible=false}
								
								puts "checking component intersection : #{res}"
								if res
									proper_comps		<< transformed_inst
									comps_auto_corrected = true
								else
									UI.messagebox "Component cant be attached to wall since it overlaps other component.Manually place it."
									#transformed_inst 	= comp.transform!(transformation)
									transformed_inst.transformation=transformation
									proper_comps		<< transformed_inst
									continue_flag = false
									#return [[], false]
								end
						
								transformed_inst.set_attribute :rio_atts, 'associated_wall', nil
								transformed_inst.set_attribute :rio_atts, 'visible_in_working_drawing', true
							else
								resp 	=  UI.messagebox 'The selected component should be available in working drawing?', MB_OKCANCEL
								if resp == IDOK
									comp.set_attribute :rio_atts, 'associated_wall', wall.persistent_id
									comp.set_attribute :rio_atts, 'visible_in_working_drawing', true
								else
									comp.set_attribute :rio_atts, 'visible_in_working_drawing', false
								end
							end
							
							#Resetting All the changes................
							hit_ents.each{|ent| ent.visible = true}
							trans_walls[0].visible = false
							comp.visible = false
							Sketchup.active_model.active_view.camera	= last_seen_camera
						else
							puts "Auto positioning : The component behind is not a room wall"
						end
					else
						Sketchup.active_model.selection.add(comp)
						UI.messagebox "The selected component cannot be associated with any wall."
						continue_flag = false
					end
				end
			else
				res 				= check_comp_intersection comp, room_name
				# puts "Component glued to wall : #{comp.persistent_id}"
				if res
					proper_comps << comp
				else
					UI.messagebox("Component overlaps each another")
					continue_flag = false
				end
			end
		else
			res = check_wall_intersection comp, room_walls
			if res[0] == 'overlap'
				if correction_flag
					puts "Component #{comp.persistent_id} is overlapping #{res[1].persistent_id}"
					wall_trans 	= res[1].get_attribute(:rio_atts, 'wall_trans')
					
					comp_back_overlap = false
					if wall_trans.abs == 180
						comp_back_overlap = true if comp.transformation.rotz.abs == wall_trans 
					else
						comp_back_overlap = true if comp.transformation.rotz == wall_trans 
					end
					
					if comp_back_overlap
						Sketchup.active_model.selection.clear
						Sketchup.active_model.selection.add(comp)
						#UI.messagebox "Component back side overlaps wall. It will be pushed inside room"
						move_vector 	= get_comp_move_vector comp
						move_offset		= get_comp_wall_offset comp, res[1]
						
						#-------------Find the Z transformation-------------
						comp_origin = comp.transformation.origin
						component_top_end 	= comp.transformation.origin.z + comp.bounds.depth
						room_top_end		= floor_origin.z + wall_height
						z_offset 			= 0
						if comp_origin.z < floor_origin.z
							z_offset = floor_origin.z - comp_origin.z
						elsif component_top_end > room_top_end
							z_offset = room_top_end - component_top_end #negating it 
						end
						#-----------    Z transformation   -----------------
						
						transform_vector = Geom::Vector3d.new(move_vector.x*move_offset, move_vector.y*move_offset, z_offset)
						puts transform_vector
						transformed_inst 	= comp.transform!(transform_vector)
						proper_comps		<< transformed_inst
						comps_auto_corrected = true
                        continue_flag = false
					else
						#UI.messagebox "Component side overlaps wall. Please manually autocorrect the component"
						puts "Component side overlaps wall. Please manually autocorrect the component"
                        continue_flag = false
					end
				else
					proper_comps << comp
				end
			else
				a=false
				# puts "Comp : #{comp.persistent_id} is completely outside"
			end
		end
		
	}
	
	
	proper_comps.uniq!
	
	if comps_auto_corrected
		UI.messagebox "Few components auto corrected.Please verify the model and run Working Drawing again."
    	continue_flag = false
    	# $rio_dialog.set_size(650, 780)
	end
	
	#if correction_flag
		proper_comps.each{|comp| comp.set_attribute :rio_atts, 'space_name', room_name}
	#end
	
	puts proper_comps.length
	
	Sketchup.active_model.entities.erase_entities(hit_face.edges)
	Sketchup.active_model.entities.each{|x| x.visible=true}
	return [proper_comps, continue_flag]
end
























































=begin

room_name = 'Room#7'

room_comps 	= MRP::get_room_components room_name
room_face 	= MRP::get_room_face room_name
room_walls  = DP::get_walls room_name

#room_face = fsel
floor_gp 		= Sketchup.active_model.entities.select{|ent| ent.layer.name == 'DP_Floor_'+room_name.to_s}[0]
floor_origin 	= floor_gp.transformation.origin

wall_height 	= floor_gp.get_attribute(:rio_atts, 'wall_height').to_i.mm

previous_ents =[]
Sketchup.active_model.entities.each{|ent| previous_ents << ent}


room_verts = []
room_face.vertices.each{|vert| 
	pt = vert.position
	pt.x+=floor_origin.x; 
	pt.y+=floor_origin.y
	pt.z += 10000
	room_verts << pt
}

new_face = Sketchup.active_model.entities.add_face(room_verts)
new_face.pushpull wall_height

curr_ents 	= []
Sketchup.active_model.entities.each{|ent| curr_ents << ent}

new_ents 	= curr_ents - previous_ents

room_group 	= Sketchup.active_model.entities.add_group(new_ents)


room_comps.each {|comp|
	inside = true
	[0,1,2,3].each{|index| 
		pt 		= comp.bounds.corner(index)
		pt.z 	= floor_origin.z
		res  	= room_face.classify_point(pt)
		puts res			
		if res == Sketchup::Face::PointInside || res == Sketchup::Face::PointOnFace
			puts "inside"
		else
			puts "#{pt} outside face"
			inside = false
		end
	}
	if inside
		
	end
	
}





floor_gp = Sketchup.active_model.entities.select{|ent| ent.layer.name == 'DP_Floor_'+room_name.to_s}[0]
floor_origin = floor_gp.transformation.origin
room_walls 

room_face_pts = []
room_face.outer_loop.vertices.each{|vert|
	puts "posn : #{vert.position}"
	pt = vert.position.offset(zvector, 10000.mm)
	pt.x += floor_origin.x
	pt.y += floor_origin.y
	room_face_pts << pt
}

es = Sketchup.active_model.entities
es.each{|x| x.visible=false}

puts "room_face_pts : #{room_face_pts}"
floor_face = Sketchup.active_model.entities.add_face(room_face_pts)


Sketchup.active_model.entities.each{|ent| ent.visible = false}

room_comps.each {|comp|
	Sketchup.active_model.entities.each{|ent| ent.visible = false}
	comp.visible = true
	floor_face.visible = true
	floor_face.edges.each{|edge| edge.visible=true}
	hit_ents = []
	hit_ents << floor_face
	hit_ents << floor_face.edges
	hit_ents.flatten!
	#break
	puts comp
	inside = true
	[4, 5, 6, 7].each{|index|
		ray = [comp.bounds.corner(index), zvector]
		hit_item 	= Sketchup.active_model.raytest(ray, true)
		#puts "hit_item :-------- #{hit_item}"
		if hit_item && hit_ents.include?(hit_item[1][0])
			#pts << [vert.position, hit_item[0]]
			
		else
			#puts "#{pt} outside face"
			sel.add(hit_item[1][0]) if hit_item
			inside = false
		end
	}
	puts inside
	comp.visible = false
	
	if inside
		res = check_wall_intersection comp, room_walls
		if res[0] == 'not_glued'
			puts "Component inside but not glued to wall"
		else
			puts "Component glued to wall"
		end
	else
		res = check_wall_intersection comp, room_walls
		if res[0] == 'overlap'
			puts "componenet #{comp.persistent_id} is overlapping #{res[1].persistent_id}"
		else
			puts "comp : #{comp.persistent_id} is completely outside"
		end
	end
}	
Sketchup.active_model.entities.erase_entities(floor_face.edges)
Sketchup.active_model.entities.each{|ent| ent.visible = true}


=end
