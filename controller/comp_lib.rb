#--------------------------------------------------------------------------
#Library of VG codes
#--------------------------------------------------------------------------

module VG
	module_function

	unless defined?(RIO_FACE_FRONT)
		RIO_FACE_FRONT		= 0
		RIO_FACE_BACK		= 1
		RIO_FACE_LEFT 		= 2
		RIO_FACE_RIGHT		= 3
		RIO_FACE_TOP		= 4
		RIO_FACE_BOTTOM		= 5

		RIO_FRONT_POINTS	= [0, 1, 5, 4, 8,  10, 16, 17, 22]
		RIO_BACK_POINTS		= [2, 3, 7, 6, 9,  11, 18, 19, 23]
		RIO_LEFT_POINTS		= [2, 0, 4, 6, 12, 13, 18, 16, 20]
		RIO_RIGHT_POINTS	= [3, 1, 5, 7, 14, 15, 19, 17, 21]
		RIO_TOP_POINTS		= [4, 5, 7, 6, 10, 11, 13, 15, 24]
		RIO_BOTTOM_POINTS	= [0, 1, 3, 2, 8,   9, 12, 14, 25]
	end

	@traverse_groups 	= []
	@traverse_insts 	= []
	@traverse_faces		= []

	class << self
		attr_accessor :traverse_faces, :traverse_insts, :traverse_groups
	end

	def reset_traverse_ents
		@traverse_groups 	= []
		@traverse_insts 	= []
		@traverse_faces		= []
	end

	# -------------------------------------------------------------------------------
	# Returns details about the edge with respect to the input face
	# Inputs : Sketchup::Edge, Sketchup::Face
	#-------------------------------------------------------------------------------
	def get_edge_details iedge, iface
		return {} if (iedge.nil? || iface.nil?)
		return {} unless iedge.is_a?(Sketchup::Edge)
		return {} unless iface.is_a?(Sketchup::Face)
		return {} unless iface.edges.include?(iedge)

		edges 					= iface.edges
		face_vector				= iface.normal

		edge_point, edge_vector = iedge.line
		verts 					= iedge.vertices
		edge_center				= iedge.bounds.center

		adjacent_edges 			= (edges-[iedge]).select{|edge| !(edge.vertices&verts).empty?}
		perpendicular_vector 	= face_vector*edge_vector

		offset_point 			= edge_center.offset(perpendicular_vector, 0.5.mm)
		res 					= iface.classify_point(offset_point)

		perpendicular_vector.reverse! unless res == Sketchup::Face::PointOnFace

		edge_details_h = {}
		edge_details_h[:vertices] 			= iedge.vertices
		edge_details_h[:adjacent_edges] 	= adjacent_edges

		#Vector------------------------------------------
		edge_details_h[:edge_vector]		= edge_vector
		edge_details_h[:face_vector]		= perpendicular_vector
		edge_details_h[:edge_center]		= edge_center

		edge_details_h
	end


	def traverse_recurse(entity, transformation = IDENTITY)
		if entity.is_a?(Sketchup::Model)
			puts transformation
			entity.entities.each{ |child_entity| traverse_recurse(child_entity, transformation)}
		elsif entity.is_a?(Sketchup::Group)
			transformation *= entity.transformation
			@traverse_groups << entity
			entity.definition.entities.each{ |child_entity| traverse_recurse(child_entity, transformation.clone) }
		elsif entity.is_a?(Sketchup::ComponentInstance)
			transformation *= entity.transformation
			@traverse_insts << entity
			entity.definition.entities.each{ |child_entity| traverse_recurse(child_entity, transformation.clone) }
		elsif entity.is_a?(Sketchup::Face)
			@traverse_faces << entity
		end
	end



	#---------------------------------------------------------------------------------
	# Get all the entities within a comp...........
	#---------------------------------------------------------------------------------
	def get_component_entities icomp
		return false unless icomp && icomp.is_a?(Sketchup::ComponentInstance)
		reset_traverse_ents #---------------------------Call this at start end end

		traverse_recurse(icomp)
		comp_entities_h = {
				:faces=>@traverse_faces,
				:insts=>@traverse_insts,
				:groups=>@traverse_groups
		}

		reset_traverse_ents
		comp_entities_h
	end

	#Only for left face
	def get_left_visible_faces icomp

		pt1 	= ORIGIN
		pt2		= pt1.offset(Y_AXIS, 3000.mm)
		pt3		= pt2.offset(Z_AXIS, 3000.mm)
		pt4		= pt1.offset(Z_AXIS, 3000.mm)

		Sketchup.active_model.selection.clear
		reset_traverse_ents

		@face = Sketchup.active_model.entities.add_face(pt1, pt2, pt3, pt4)
		traverse_recurse_side(icomp)
		Sketchup.active_model.entities.erase_entities(@face.edges)

		reset_traverse_ents
	end


	def traverse_recurse_side(entity, transformation = IDENTITY)
		#puts entity
		if entity.is_a?(Sketchup::Model)
			puts transformation
			entity.entities.each{ |child_entity| traverse_recurse_side(child_entity, transformation)}
		elsif entity.is_a?(Sketchup::Group)
			#entity.make_unique
			puts "Group trans : #{entity.transformation.origin}"
			transformation *= entity.transformation
			@traverse_groups << entity
			entity.definition.entities.each{ |child_entity| traverse_recurse_side(child_entity, transformation.clone) }
		elsif entity.is_a?(Sketchup::ComponentInstance)
			#entity.make_unique
			puts "Inst trans : #{entity.transformation.origin}"
			transformation *= entity.transformation
			@traverse_insts << entity
			entity.definition.entities.each{ |child_entity| traverse_recurse_side(child_entity, transformation.clone) }
		elsif entity.is_a?(Sketchup::Face)
			hit_item 	= Sketchup.active_model.raytest([entity.bounds.center, Y_AXIS.reverse])
			puts "hit_item : #{entity.bounds.center} #{hit_item}"
			Sketchup.active_model.entities.add_face(entity.vertices)
			if hit_item
				hit_face = hit_item[1][0]
				puts "hit Face : #{hit_item}"
				if hit_face == @face
					#if (entity.normal*X_AXIS)==Z_AXIS
					ray_normal = hit_face.normal
					if ray_normal == entity.normal #|| ray_normal == entity.normal.reverse
						puts "entity : #{entity} : #{hit_item} : #{entity.normal}"
						fcolor = Sketchup::Color.new "FF335B"
						entity.material 		= fcolor
						entity.back_material 	= fcolor
					end
				end
			end
			@traverse_faces << entity
		end
	end

	def get_component_visible_view_face icomp
		views 		= %w[left right front back top bottom]
		bbox 		= icomp.bounds
		ray_offset 	= 1000.mm
		#icomp.make_unique

		Sketchup.active_model.start_operation('Get visible face')

		(RIO_FACE_FRONT..RIO_FACE_BOTTOM).each{ |view|
			raytest_temp_face_points =
					case view
					when RIO_FACE_FRONT
						RIO_FRONT_POINTS
					when RIO_FACE_BACK
						RIO_BACK_POINTS
					when RIO_FACE_LEFT
						RIO_LEFT_POINTS
					when RIO_FACE_RIGHT
						RIO_RIGHT_POINTS
					when RIO_FACE_TOP
						RIO_TOP_POINTS
					when RIO_FACE_BOTTOM
						RIO_BOTTOM_POINTS
					else
						[]
					end

			next if raytest_temp_face_points.empty?

			ray_pts = []
			raytest_temp_face_points.first(4).each{|index| ray_pts << bbox.corner(index).offset(Y_AXIS.reverse, ray_offset)				}
			@face = Sketchup.active_model.entities.add_face(ray_pts)
			puts "Face :::::: #{@face}"

			traverse_recurse_side(icomp)
			#Sketchup.active_model.entities.erase_entities(@face.edges)
			return []
		}
	end

end#Module End VG