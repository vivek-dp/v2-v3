module LAM
	
	#------------------------------------------------------------
		# jpg_path = 'E:\decorpot materials\Merino-laminates-catalogue-2018\10196 WV Celtic Ebony.jpg'
		# options={'side'=>'top', 'image_path'=>jpg_path, 'lam_type'=>'material'}
		# LAM::add_laminate fsel, options
	#------------------------------------------------------------
	def self.add_laminate comp, options
		puts "options----#{options}" 
		puts "comp----#{comp}" 
		@dict_name = 'carcase_spec'
		if comp.nil?
			puts "No Component selected"
			return false
		end

		return false unless comp
		return false unless comp.is_a?(Sketchup::ComponentInstance)
		
		ents                = Sketchup.active_model.entities
		rotz                = comp.transformation.rotz
		comp_transform      = comp.transformation
        product_name 		= comp.get_attribute('carcase_spec', 'attr_product_name' )
        product_code 		= comp.get_attribute('carcase_spec', 'attr_product_code' )

		arr = []
		ents.each{|x| arr<<x}
		
		lam_side	= options['side']
		lam_type	= options['lam_type']
		image_path 	= options['image_path']
		#puts "1-----image_path-------------#{image_path}"
		return false if image_path.nil?
		#puts "2-----image_path-------------#{image_path}"
		
		carcass_entities = []
		#Sketchup.active_model.start_operation 'lamination_code'
		if lam_type == 'material'
			model = Sketchup.active_model
			materials = model.materials
			material = materials.add('Joe')
			material.texture = image_path
		else
			model = Sketchup.active_model
			materials = model.materials
			material = materials.add('Joe')
			material.color = image_path			
		end

		defn_name 	= comp.definition.name
        comp_attr_dicts 	= {}
        comp.attribute_dictionaries.each{ |dict|
            comp_attr_dicts[dict.name] = {}
            dict.each_pair{|key, value|
                comp_attr_dicts[dict.name][key] = value
            }
        }

        defn_attr_dicts 	= {}
        comp.definition.attribute_dictionaries.each{ |dict|
            defn_attr_dicts[dict.name] = {}
            dict.each_pair{|key, value|
                defn_attr_dicts[dict.name][key] = value
            }
        }


		if lam_side == 'front'
            shutter_code    = comp.definition.get_attribute(:rio_atts, 'shutter-code') 
            filler_left 	= comp.get_attribute(:rio_atts, 'filler_left')
			filler_right 	= comp.get_attribute(:rio_atts, 'filler_right')
            if shutter_code.nil?
                UI.messagebox "Shutter code not available"
                return false
            end
            exploded_ents 	= comp.explode

            
            shutter_ent  	= exploded_ents.grep(Sketchup::ComponentInstance).select{|ent| ent.definition.name.start_with?(shutter_code)}[0]
            
            if (shutter_ent.nil?)
                UI.messagebox "Shutter entity not available"
                return false
            else
                other_ents              = exploded_ents - [shutter_ent]
                shutter_ent.material    = material
                comp_group = Sketchup.active_model.entities.add_group(other_ents, shutter_ent)
            end
        else
            origin 		= comp.transformation.origin

            bounds 		= comp.bounds
            defn_name 	= comp.definition.name

            case rotz
            when 0
                case lam_side 
                when 'left'
                    indexes = [0, 2, 6, 4]
                    vector 	= Geom::Vector3d.new(-1,0,0) 
                when 'right'
                    indexes = [1, 5, 7, 3]
                    vector 	= Geom::Vector3d.new(1,0,0)
                when 'top'
                    indexes	= [4, 5, 7, 6]
                    vector 	= Geom::Vector3d.new(0,0,1)
                end
            when 90
                case lam_side 
                when 'left'
                    indexes = [0, 1, 5, 4]
                    vector 	= Geom::Vector3d.new(0,-1,0)
                when 'right'
                    indexes = [2, 3, 7, 6]
                    vector 	= Geom::Vector3d.new(0,1,0)
                when 'top'
                    indexes	= [4, 5, 7, 6]
                    vector 	= Geom::Vector3d.new(0,0,1)
                end
            when -90
                case lam_side 
                when 'left'
                    indexes = [2, 3, 7, 6]
                    vector 	= Geom::Vector3d.new(0,1,0)
                when 'right'
                    indexes = [0, 1, 5, 4]
                    vector 	= Geom::Vector3d.new(0,-1,0)
                when 'top'
                    indexes	= [4, 5, 7, 6]
                    vector 	= Geom::Vector3d.new(0,0,1)
                end
            when -180, 180
                case lam_side 
                when 'left'
                    indexes = [1, 5, 7, 3]
                    vector 	= Geom::Vector3d.new(1,0,0)
                when 'right'
                    indexes = [0, 2, 6, 4]
                    vector 	= Geom::Vector3d.new(-1,0,0)
                when 'top'
                    indexes	= [4, 5, 7, 6]
                    vector 	= Geom::Vector3d.new(0,0,1)
                end
            end


            face_pts = []
            indexes.each{|index|
                face_pts << comp.bounds.corner(index).offset(vector, 100.mm)
            }

            exploded_ents = comp.explode
            carcass_ent = exploded_ents.grep(Sketchup::ComponentInstance).select{|ent| defn_name.start_with?(ent.definition.name.split('#')[0])}[0]

            # puts "defn_name : #{defn_name}"
            #puts "exploded_ents : #{exploded_ents}"
            #puts "carcass_ent : #{carcass_ent}"

            if carcass_ent.nil?
                puts "Carcass entity definition not found"
                return false
            end

            carcass_name = carcass_ent.definition.name

            carcass_entities 	= []
            gps 				= carcass_ent.explode
            gps.each{|gp| 
                if gp.is_a?(Sketchup::Group)
                    carcass_entities << gp.explode
                else
                    carcass_entities << gp
                end
            }

            carcass_entities.flatten!

            ray_test_face = Sketchup.active_model.entities.add_face(face_pts)

            hit_ents = []
            hit_ents << ray_test_face
            hit_ents << ray_test_face.edges
            hit_ents.flatten!

            Sketchup.active_model.entities.each{|x| x.visible=false}
            hit_ents.each{|x| x.visible=true}
            carcass_entities.each{|x| 
                if !x.deleted?
                    x.visible=true if (x.is_a?(Sketchup::Edge) || x.is_a?(Sketchup::Face))
                end
            }
            visible_faces = []
            carcass_entities.grep(Sketchup::Face).each{ |face|
                #puts "face : #{face} "
                next if face.deleted?
                hit_item = Sketchup.active_model.raytest face.bounds.center, face.normal
                #puts "hit_item : #{hit_item}"
                if hit_item && hit_ents.include?(hit_item[1][0])
                    visible_faces << face
                    next
                end
                hit_item = Sketchup.active_model.raytest face.bounds.center, face.normal.reverse
                if hit_item && hit_ents.include?(hit_item[1][0])
                    visible_faces << face
                end
            }

            #puts "visible_faces : #{visible_faces}"
            visible_faces.each {|face| 
                face.material=material
                face.back_material=material
            }

            #return
            Sketchup.active_model.entities.each{|x| x.visible=true}
            Sketchup.active_model.entities.erase_entities ray_test_face.edges

            curr_ents = [];
            Sketchup.active_model.entities.each{|x| curr_ents<<x}

            #puts "carcass_entities : #{carcass_entities}"

            diff_ents = curr_ents - arr
            other_ents = diff_ents - carcass_entities
            carcass_entities.select!{|x| !x.deleted?} 
            carcass_entities.select!{|x| x.is_a?(Sketchup::Face) || x.is_a?(Sketchup::Edge)} 
            #carcass_entities.each{|x| puts "par : #{x} : #{x.parent}"}
            #puts "carcass_entities : #{carcass_entities}"
            # puts "carcass_name : #{carcass_name}"

            carcass_group 	= Sketchup.active_model.entities.add_group(carcass_entities)
            carcass_inst 	= carcass_group.to_component
            carcass_inst.definition.name = carcass_name
            #return
            #carcass_group
            # puts "carcass_group : #{carcass_inst}"
            # puts "other_ents : #{other_ents}"

            other_ents.select!{|x| x.is_a?(Sketchup::ComponentInstance)}
            comp_group = Sketchup.active_model.entities.add_group(other_ents, carcass_inst)

        end
		comp_group.layer = Sketchup.active_model.layers['DP_Comp_layer']

		# puts "comp_group : #{comp_group}"
		#return
		comp_attr_dicts.each_pair{|dict_name, values|
			values.each_pair {|key,val| 
				#puts "comp_group : #{key} : #{val} : #{dict_name}"
				comp_group.set_attribute dict_name, key, val 
			}
        }


        defn_attr_dicts.each_pair{|dict_name, values|
			values.each_pair {|key,val| 
				# puts "comp_group : #{key} : #{val} : #{dict_name}"
				comp_group.definition.set_attribute dict_name, key, val 
			}
        }
        


        comp_inst = comp_group.to_component
        #comp_inst = 
        puts rotz
        comp_inst = DP::update_laminate_axes comp_inst, rotz if rotz != 0 
		comp_inst.set_attribute('carcase_spec', 'attr_product_name', product_name )
		comp_inst.definition.name = defn_name
        #comp_inst.transformation = comp_transform
        comp_inst.layer = Sketchup.active_model.layers['DP_Comp_layer']
        #-------Filler laminate addition..........
			if lam_side == 'front'
				if filler_left
					filler_comp = DP::get_comp_pid filler_left.to_i
					DP::add_filler_laminate comp_inst, filler_comp
				end
				if filler_right
					filler_comp = DP::get_comp_pid filler_right.to_i
					DP::add_filler_laminate comp_inst, filler_comp
				end
			end
		comp_inst

	end
end






=begin

options = {"edit"=>0,
		"main-category"=>"Kitchen_Base_Unit",
		"sub-category"=>"Base_Double_Door",
		"carcass-code"=>"BC_900",
		"door-type"=>"Double",
		"shutter-code"=>"SD_90_70",
		"shutter-type"=>"solid",
		"shutter-origin"=>"1_1",
		"auto_mode"=>"false",
		"auto_position"=>"bottom_right",
		"space_name"=>'Room#2'
		}

Decor_Standards::place_component options


load 'E:\git\siva\scripts\laminate.rb'

jpg_path = 'E:\decorpot materials\Merino-laminates-catalogue-2018\10196 WV Celtic Ebony.jpg'
options={'side'=>'top', 'image_path'=>jpg_path, 'lam_type'=>'material'}
LAM::add_laminate fsel, options



 


load 'E:\git\siva\scripts\laminate.rb'

jpg_path = 'E:\decorpot materials\Merino-laminates-catalogue-2018\10196 WV Celtic Ebony.jpg'
options={'side'=>'right', 'image_path'=>jpg_path, 'lam_type'=>'material'}
LAM::add_laminate fsel, options
=end