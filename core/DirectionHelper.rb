module RIO
	module DirectionHelper
		def self.get_perpendicular_vector edge
			edge_vector  = edge.line[1]
			perpendicular_vector = Geom::Vector3d.new(-edge_vector.y, edge_vector.x, edge_vector.z)
			perpendicular_vector 
		end
		
		def self.get_pt_face_vector inp_pt, ref_face
			inp_pt.offset()
		end

		#Based on the origin of the entity
		def self.get_entity_vector entity, ref_face
			unless entity
				puts "Entity is Nil."
				return false
			end
			origin = entity.transformation.origin
		end
 
		def self.rotate_item entity, rotate_axis=Z_AXIS, angle=90
			point = entity.bounds.center
			angle = angle.degrees
			transformation = Geom::Transformation.rotation(point, rotate_axis, angle)
			entity.transform!(transformation)
		end

		def self.get_edge_directional_vector edge, vector
			
		end

		def self.get_sort_params vector, direction='cw'
			sort_by_x 		= false
			sort_by_y 		= false
			vector_type 	= false
			corner_index	= false
			start_index		= false

			#For unit vectors
			case vector
			when Y_AXIS.reverse
				vector_type		= 1
				if direction=='cw'
					sort_by_x 		= 1
					corner_index	= 0
					start_index		= 2
				else
					sort_by_x 		= -1
					corner_index	= 1
					start_index		= 3
				end
			when X_AXIS
				vector_type		= 2
				if direction=='cw'
					sort_by_y 		= 1
					corner_index	= 1
					start_index		= 0
				else
					sort_by_y 		= -1
					corner_index	= 3
					start_index		= 1
				end
			when Y_AXIS
				vector_type		= 3
				if direction=='cw'
					sort_by_x 		= -1
					corner_index 	= 3
					start_index		= 1
				else
					sort_by_x 		= 1
					corner_index 	= 2
					start_index		= 0
				end
			when X_AXIS.reverse
				vector_type		= 4
				if direction=='cw'
					sort_by_y 		= -1
					corner_index 	= 2
					start_index		= 3
				else
					sort_by_y 		= 1
					corner_index 	= 3
					start_index		= 1
				end
			end		

			unless vector_type
				if vector.x>0&&vector.y<0 #Reverse of Y axis
					vector_type		= 5
					if direction=='cw'
						sort_by_x 		= 1
						sort_by_y 		= 1
						corner_index 	= 0
						start_index		= 2
					else
						sort_by_x 		= -1
						sort_by_y 		= -1
						corner_index 	= 0
						start_index		= 2
					end
				elsif vector.x>0&&vector.y>0
					vector_type		= 6
					if direction=="cw"
						sort_by_x 		= -1
						sort_by_y 		= 1
						corner_index 	= 1
						start_index		= 0
					else
						sort_by_x 		= 1
						sort_by_y 		= -1
						corner_index 	= 1
						start_index		= 0
					end
				elsif vector.x<0&&vector.y>0
					vector_type		= 7
					if direction=="cw"
						sort_by_x 		= -1
						sort_by_y 		= -1
						corner_index 	= 3
						start_index		= 1
					else
						sort_by_x 		= 1
						sort_by_y 		= 1
						corner_index 	= 3
						start_index		= 1
					end
				elsif vector.x<0&&vector.y<0
					vector_type		= 8
					if direction=="cw"
						sort_by_x 		= 1
						sort_by_y 		= -1
						corner_index 	= 2
						start_index		= 3
					else
						sort_by_x 		= -1
						sort_by_y 		= 1
						corner_index 	= 2
						start_index		= 3
					end
				end
			end

			return sort_by_x , sort_by_y, vector_type, corner_index, start_index
		end

		def self.sort_wall_items entities=[], wall_facing_vector=X_AXIS, wall_side='left'

			if entities.empty?
				puts "No entities passed to sort."
				return false
			end
			
			allowed_ents = ['wall', 'column']
			entities.select!{|ent| allowed_ents.include?(ent.get_attribute(:rio_block_atts, 'block_type'))}

			direction=(wall_side=="left") ? "cw":"acw"
			x_sort_flag, y_sort_flag, vector_type, corner_index, start_index = get_sort_params(wall_facing_vector, direction)

			puts "flags : #{x_sort_flag} : #{y_sort_flag} : #{vector_type} : #{direction}"
			sorted_entities = []
			#x_sort_flag = 1
			if x_sort_flag
				puts "X sorting"
				entities = entities.to_a; entities.flatten!
				sorted_entities = entities.sort_by!{|ent| x_sort_flag*ent.bounds.corner(corner_index).x}
			end
			if y_sort_flag
				puts "Y sorting"
				if sorted_entities.empty?
					entities = entities.to_a; entities.flatten!
					sorted_entities = entities.sort_by!{|ent| y_sort_flag*ent.bounds.corner(corner_index).y}
				else
					sorted_entities.sort_by!{|ent| y_sort_flag*ent.bounds.corner(corner_index).y}
				end
			end
			first_entity = sorted_entities.first
			bl_type = first_entity.get_attribute(:rio_block_atts, 'block_type')
			
			if bl_type=='wall'
				case vector_type
				when 1
					start_index=(wall_side=='left')?0:1
				when 2
					start_index=(wall_side=='left')?1:3
				when 3
					start_index=(wall_side=='left')?3:2
				when 4
					start_index=(wall_side=='left')?2:0
				when 5
					start_index=(wall_side=='left')?0:1
				when 6
					start_index=(wall_side=='left')?1:3
				when 7
					start_index=(wall_side=='left')?3:2
				when 8
					start_index=(wall_side=='left')?2:0
				else
					puts "Unknown vector type for finding the start point."
				end
			end
			puts "bl_type : #{bl_type} : #{start_index}"

			return sorted_entities, start_index
		end

		def self.get_component_corners icomponent
			if icomponent && icomponent.is_a?(Sketchup::ComponentInstance)
				comp_rotz = icomponent.transformation.rotz
				if comp_rotz >= 0
					case comp_rotz
					when 0..89
						corners = [0,1,3,2,4,5,7,6]
					when 90..179
						corners = [1,3,2,0,5,7,6,4]
					when 180..269
						corners = [3,2,0,1,7,6,4,5] 
					else
						corners = [2,0,1,3,6,4,5,7]
					end
				else
					comp_rotz = -comp_rotz
					case comp_rotz
					when 271..360
						corners = [0,1,3,2,4,5,7,6]
					when 181..270
						corners = [1,3,2,0,5,7,6,4]
					when 91..180
						corners = [3,2,0,1,7,6,4,5] 
					else
						corners = [2,0,1,3,6,4,5,7]
					end
				end
				return corners
			end
		end
	end 
end