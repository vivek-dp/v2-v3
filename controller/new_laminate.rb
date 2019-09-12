mod = Sketchup.active_model
ent = mod.entities
sel = mod.selection
comp = fsel

def get_laminate_faces(entity, transformation = IDENTITY)
	if entity.is_a?(Sketchup::Group)
		entity.make_unique
		pts	= [];
    transformation *= entity.transformation
		@indexes.each {|index|
			pts << entity.definition.bounds.corner(index)
		}
		face = Sketchup.active_model.entities.add_face(pts)
		face.set_attribute('rio_atts', 'temp_raytest_faces', 'true')
		entity.definition.entities.each{ |child_entity|
      get_laminate_faces(child_entity, transformation.clone)
    }
  elsif entity.is_a?(Sketchup::ComponentInstance)
		entity.make_unique
		pts = []
    transformation *= entity.transformation
		entity.definition.entities.each{ |child_entity|
      get_laminate_faces(child_entity, transformation.clone)
    }
	end
end

def get_laminate_comps(entity, transformation = IDENTITY)
	if entity.is_a?(Sketchup::Group)
		entity.make_unique
    transformation *= entity.transformation
		defn_bbox 		= entity.definition.bounds
		entity.definition.entities.each{ |child_entity|
      get_laminate_comps(child_entity, transformation.clone)
    }
  elsif entity.is_a?(Sketchup::ComponentInstance)
		entity.make_unique
    transformation *= entity.transformation
		pts = []
		if !transformation.identity?
			@indexes.each {|index|
				pt = entity.definition.bounds.corner(index)
				pt.transform!(transformation)
				pt.z = 5000.mm
				pts << pt
			}
		end
		comp_type = entity.get_attribute('rio_atts', 'comp_type')
		comp_type = entity.definition.get_attribute('rio_atts', 'comp_type')
		if comp_type != 'shutter'
			entity.definition.entities.each{ |child_entity|
				get_laminate_comps(child_entity, transformation.clone )
			}
		end
	elsif entity.is_a?(Sketchup::Face)
		face_center 	= entity.bounds.center
		laminate_ray	= [face_center, @offset_vector]
		hit_item 		= mod.raytest(laminate_ray, true)
		if hit_item
			vector = entity.normal
			if vector == @offset_vector || vector == @offset_vector.reverse
				sel.add(entity)
				if hit_item[1][0] == @ray_face	
					entity.material = @fmaterial
					entity.back_material = @fmaterial
					sel.add(hit_item[1])
				end
			end
		end
  end
end

def add_shutter_material(entity, transformation = IDENTITY)
	if entity.is_a?(Sketchup::Group)
		entity.definition.entities.each{ |child_entity|
			add_shutter_material(child_entity, transformation.clone)
		}
	elsif entity.is_a?(Sketchup::ComponentInstance)
		comp_type = entity.definition.get_attribute(:rio_atts, 'comp_type')
		if comp_type == 'shutter'
			entity.material = @fmaterial
		else 
			entity.definition.entities.each{ |child_entity|
				add_shutter_material(child_entity, transformation.clone)
			}
		end
	end

	if entity.get_attribute(:rio_atts, 'filler_left')
		filler_comp = DP::get_comp_pid entity.get_attribute(:rio_atts, 'filler_left').to_i
		DP::add_filler_laminate entity, filler_comp
	end

	if entity.get_attribute(:rio_atts, 'filler_right')
		filler_comp = DP::get_comp_pid entity.get_attribute(:rio_atts, 'filler_right').to_i
		DP::add_filler_laminate entity, filler_comp
	end
end

def add_laminate_to_comp(comp, material, side='left')
	if material.nil?
		puts "Material is not Valid.SIDE : #{side}"
		return false
	end
	@fmaterial = material
	face_width = 100000.mm
	if side == 'front'
		add_shutter_material(comp)
	else
		case side
		when 'top'
			@indexes 		= [4,5,7,6]
			@offset_vector	= Z_AXIS
			@ray_face 		= Sketchup.active_model.entities.add_face([-face_width, -face_width, face_width],[face_width, -face_width, face_width],[face_width, face_width, face_width], [-face_width, face_width, face_width])
			res = get_laminate_faces(comp)
			res = get_laminate_comps(comp)
		when 'left'
			@indexes 		= [0,2,6,4]
			@offset_vector 	= X_AXIS.reverse
			@ray_face 		= Sketchup.active_model.entities.add_face([-face_width, -face_width, -face_width],[-face_width, face_width, -face_width],[-face_width, face_width, face_width], [-face_width, -face_width, face_width])
			res = get_laminate_faces(comp)
			res = get_laminate_comps(comp)
		when 'right'
			@indexes = [1,3,7,5]
			@offset_vector 	= X_AXIS
			@ray_face 		= Sketchup.active_model.entities.add_face([face_width, -face_width, -face_width],[face_width, face_width, -face_width],[face_width, face_width, face_width], [face_width, -face_width, face_width])
			res = get_laminate_faces(comp)
			res = get_laminate_comps(comp)
		end
		faces = Sketchup.active_model.entities.grep(Sketchup::Face).each{|face| face.get_attribute('rio_atts', 'temp_raytest_faces') == 'true'}
		faces.each { |face| Sketchup.active_model.entities.erase_entities(face.edges) if !face.deleted?}
		Sketchup.active_model.entities.erase_entities(@ray_face.edges) if @ray_face && !@ray_face.deleted?
	end

	def add_filler_laminate comp, filler
		image_path = comp.get_attribute :carcase_spec, 'front_lam_value'
		return false if image_path.nil?
		rotz	 = comp.transformation.rotz
		filler_ents = filler.definition.entities
		ents_faces = get_face_views_ents filler_ents
		top_face = ents_faces[0]
		
		case rotz
		when 0
			side_face = ents_faces[2]
		when 90
			side_face = ents_faces[5]
		when -90
			side_face = ents_faces[3]
		when 180, -180
			side_face = ents_faces[4]
		end
				
		model = Sketchup.active_model
		materials = model.materials
		material = materials.add('filler_lam')
		puts image_path.include?('#')
		if image_path.include?('#') == true
			material.color = image_path
		else
			material.texture = RIO_ROOT_PATH+'/materials/'+image_path
		end
		
		side_face.material 		= material
		side_face.back_material = material
		filler.set_attribute(:rio_atts, 'front_lam_value', image_path)
	end
end