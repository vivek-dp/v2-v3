require_relative 'tt_bounds.rb'
require_relative 'tt_core.rb'
require_relative '../core/CivilHelper.rb'

#-----------------------------------------------
#
#Decorpot Sketchup Core library
#
#-----------------------------------------------
require 'csv'

module DP
	#Global variables
	@@multi_layer_top_view_components=[]

	def self.set_multi_layer_top_view_components input
		@@multi_layer_top_view_components = input 
	end

	def self.get_multi_layer_top_view_components
		@@multi_layer_top_view_components
	end

	def self.mod
		Sketchup.active_model
	end
	
	def self.ents
		Sketchup.active_model.entities
	end
	
	def self.comps
		Sketchup.active_model.entities.grep(Sketchup::ComponentInstance)
	end
	
	def self.sel
		Sketchup.active_model.selection
	end
	
	def self.fsel
		Sketchup.active_model.selection[0]
	end

	def self.get_setting_attr_value keyatt
		value = Sketchup.active_model.get_attribute(:rio_settings, keyatt)
		return value
	end
	
	def self.get_intersect_area comp1, comp2
		xn 		= comp1.bounds.intersect comp2.bounds
		return [false, false] unless xn.valid?
		lengths = []
		lengths << xn.width
		lengths << xn.height
		lengths << xn.depth
		lengths.select!{|len| len!=0}
		if lengths.length == 2
			return ['area', lengths[0]*lengths[1]]
		elsif lengths.length == 3
			return ['volume', lengths[0]*lengths[1]*lengths[2]]
		end
		return [false, false]
	end

	def self.fpid
		compn = Sketchup.active_model.selection[0]
		return compn.persistent_id if compn.is_a?(Sketchup::ComponentInstance)
		return nil
	end
	
	def self.get_current_file_path
		Sketchup.active_model.path
	end
	
	def self.open_folder folder_path
		UI.openURL("file:///#{folder_path}")
	end
	
	def self.get_plugin_folder
		Sketchup.find_support_file("Plugins")
	end

	def self.add_component_observer
		Sketchup.active_model.selection.add_observer($rio_sel_observer)
	end

	def self.remove_component_observer
		Sketchup.active_model.selection.remove_observer($rio_sel_observer)
	end
	
	def self.simple_encrypt text, shift=7
		alphabet = [*('a'..'z'), *('A'..'Z')].join
		cipher = alphabet.chars.rotate(shift).join
		return text.tr(alphabet, cipher)
	end
	
	def self.simple_decrypt text, shift=7
		alphabet = [*('a'..'z'), *('A'..'Z')].join
		cipher = alphabet.chars.rotate(shift).join
		return text.tr(cipher, alphabet)
	end
	
	def self.get_current_file_name
		File.basename(get_current_file_path, '.skp')
	end
	
	def self.backup_current_file
		backup_folder 	= get_plugin_folder
		backup_file 	= get_current_file_path
		file_name		= File.basename(backup_file, '.skp')
		
		
		FileUtils.cp(get_current_file_path, backup_folder)
	end
	
	def self.pid entity
		return entity.persistent_id if entity.is_a?(Sketchup::ComponentInstance)
		return nil
	end
	
	def self.lower_bounds e; 
		return e.bounds.corner(0), e.bounds.corner(1), e.bounds.corner(3), e.bounds.corner(2);
	end
	
	def self.get_comp_pid id;
		Sketchup.active_model.entities.each{|x| return x if x.persistent_id == id};
		return nil;
	end
    
    def self.get_state
        @state
    end
    
    def self.comp_clicked_id
        @comp_id
    end
    
    def self.set_state status
        @state=status
	end
	
	def self.get_auto_mode
		@rio_auto_mode
	end
	
	def self.set_auto_mode position
		@rio_auto_mode = position
	end

	def self.off_auto_mode
		@rio_auto_mode = false
	end

	#very dangerous functions :)
	def self.hide_all_entities
		# puts "-----------------------------------------hide_all_entitites"
		@visible_comps = []
		Sketchup.active_model.entities.each{ |entity|
			@visible_comps << entity if entity.visible?
		}
		unless @visible_comps.empty?
			@visible_comps.each{ |visible_comp|
				visible_comp.visible=false
			}
		end
		# puts "@visible_comps----#{@visible_comps}"
	end

	def self.unhide_all_entities
		#puts "@@visible_comps : #{@visible_comps}"
		@visible_comps.each{ |visible_comp|
			visible_comp.visible=true unless visible_comp.deleted?
		}
	end

	def self.get_comp_width comp
		rotz 		= comp.transformation.rotz
		comp_bounds	= comp.bounds
		width = 0
		case rotz
		when 0, 180, -180
			width 	= comp_bounds.height
		when 90, -90
			width 	= comp_bounds.width
		end
		width = width.to_mm.round
		return width
	end

	def self.list_all_skps folder_name
		dir=folder_name
		Dir.chdir(dir)
		model = Sketchup.active_model
		layers_arr = []
		Dir.entries(dir).each{|folder_name|
			folder=dir+folder_name+'\\'
			# puts folder
			Dir.entries(folder).select{|e| e =~ /[.]skp$/ }.each{|skp|
					# puts skp
					#defn = model.definitions.load(folder+skp)
					#inst = model.entities.add_instance defn, ORIGIN
					layers = Sketchup.active_model.layers
					layers.each {|l| layers_arr << l.name}
					#Sketchup.active_model.entities.erase_entities inst
					Sketchup.active_model.layers.each {|l| 
						#sleep 0.1
						# puts l.name, l.deleted?
						if !l.deleted? && !l.nil?
							#if Sketchup.active_model.layers[l.name]
								#Sketchup.active_model.layers.remove(l) unless l.name.include?('Layer0')
							#end
						end
					}
			}
		}	
	end
	
	def self.get_local_version key
		path = File.join(RIO_ROOT_PATH+'/cache/')
		case key
		when 'carcass_db'
			file 	= Dir.glob(path+'Rio_carcass*.csv')[0]
		when 'sliding_db'
			file 	= Dir.glob(path+'Rio_sliding*.csv')[0]
		end
		version 	= File.basename(file, '.csv').split('_').last
		version
	end

	#Input 	:	Face, offset distance
	#return :	Array of offset points
	def self.face_off_pts(face, dist)
		pi = Math::PI
		
		return nil unless face.is_a?(Sketchup::Face)
		if (not ((dist.class==Fixnum || dist.class==Float || dist.class==Length) && dist!=0))
			return nil
		end
		
		verts=face.outer_loop.vertices
		pts = []
		
		# CREATE ARRAY pts OF OFFSET POINTS FROM FACE
		
		0.upto(verts.length-1) do |a|
			vec1 = (verts[a].position-verts[a-(verts.length-1)].position).normalize
			vec2 = (verts[a].position-verts[a-1].position).normalize
			vec3 = (vec1+vec2).normalize
			if vec3.valid?
				ang = vec1.angle_between(vec2)/2
				ang = pi/2 if vec1.parallel?(vec2)
				vec3.length = dist/Math::sin(ang)
				t = Geom::Transformation.new(vec3)
				if pts.length > 0
					vec4 = pts.last.vector_to(verts[a].position.transform(t))
					if vec4.valid?
						unless (vec2.parallel?(vec4))
							t = Geom::Transformation.new(vec3.reverse)
						end
					end
				end
				
				pts.push(verts[a].position.transform(t))
			end
		end
		duplicates = []
		pts.each_index do |a|
			pts.each_index do |b|
				next if b==a
				duplicates<<b if pts[a]===pts[b]
			end
			break if a==pts.length-1
		end
		duplicates.reverse.each{|a| pts.delete(pts[a])}
		return pts
	end

	def self.get_comp_volume comp
		bbox = comp.bounds
		return 0 unless bbox.width > 0
		return 0 unless bbox.height > 0
		return 0 unless bbox.depth > 0
		return bbox.width * bbox.height * bbox.depth
	end
	
	def self.get_camera_details_hash
		return {
			:filename 		=> '',
			:width 			=> 1920,
			:height 		=> 1080,
			:antialias 		=> true,
			:compression	=> 0,
			:transparent	=> true
		}
	end

    def self.get_transformation_hash rotz=0

        transform_hash = {
            :front_bounds => [],
            :back_bounds => [],
            :left_bounds => [],
            :right_bounds => [],
            :top_bounds => [],
            :bottom_bounds => [],

            :front_side_vector => nil,
            :front_side_vector_reverse => nil,
            :back_side_vector => nil,
            :back_side_vector_reverse => nil,
            :left_side_vector => nil,
            :left_side_vector_reverse => nil,
            :right_side_vector => nil,
            :right_side_vector_reverse => nil,
            :top_side_vector => nil,
            :top_side_vector_reverse => nil,
            :bottom_side_vector => nil,
            :bottom_side_vector_reverse => nil,


            :front_face_index_pts => [],
            :left_face_index_pts => [],
            :right_face_index_pts => [],
            :back_face_index_pts => [],
            :bottom_face_index_pts => [],
            :top_face_index_pts => [],

            :front_dim_vector => nil,
            :back_dim_vector => nil,
            :right_dim_vector => nil,
            :left_dim_vector => nil,
            :top_dim_vector => nil,
            :bottom_dim_vector => nil,
			
			:int_dim_vector => nil,

            :front_all_points => [],
            :set_x  => false,
            :set_y  => false,
			
			:camera_position 	=> nil,
			:camera_target		=> nil,
			:camera_up			=> nil
        }

        #puts "Input rotz : #{rotz}"
        case rotz
        when 0
            transform_hash[:front_bounds]       = [0, 1, 5, 4]
			transform_hash[:top_bounds]			= [4, 6, 7, 5]
            transform_hash[:front_dim_vector]   = X_AXIS
            transform_hash[:front_side_vector]  = Y_AXIS.reverse
			
            transform_hash[:front_all_points]   = VG::RIO_FRONT_POINTS
			transform_hash[:back_all_points]   	= VG::RIO_BACK_POINTS
			transform_hash[:left_all_points]   	= VG::RIO_LEFT_POINTS
			transform_hash[:right_all_points]   = VG::RIO_RIGHT_POINTS
			transform_hash[:top_all_points]   	= VG::RIO_TOP_POINTS
			transform_hash[:bottom_all_points]  = VG::RIO_BOTTOM_POINTS
            
			transform_hash[:set_y]              = true
			transform_hash[:camera_position] 	= ORIGIN
			transform_hash[:camera_target]		= Y_AXIS
			transform_hash[:camera_up]			= Z_AXIS
			transform_hash[:int_dim_vector]		= X_AXIS
        when 90
            transform_hash[:front_dim_vector]   = Y_AXIS
            transform_hash[:front_bounds]       = [1, 3, 7, 5]
			transform_hash[:top_bounds]			= [4, 5, 7, 6]
            transform_hash[:set_x]              = true
			transform_hash[:camera_position] 	= ORIGIN
			transform_hash[:camera_target]		= X_AXIS.reverse
			transform_hash[:camera_up]			= Z_AXIS
            transform_hash[:front_side_vector]  = X_AXIS.reverse
			
			transform_hash[:front_all_points]   = VG::RIO_RIGHT_POINTS
			transform_hash[:back_all_points]   	= VG::RIO_LEFT_POINTS
			transform_hash[:left_all_points]   	= VG::RIO_FRONT_POINTS
			transform_hash[:right_all_points]   = VG::RIO_BACK_POINTS
			transform_hash[:top_all_points]   	= VG::RIO_TOP_POINTS
			transform_hash[:bottom_all_points]  = VG::RIO_BOTTOM_POINTS
			transform_hash[:int_dim_vector]		= Y_AXIS
            
        when -90
            transform_hash[:front_dim_vector]   = Y_AXIS.reverse
            transform_hash[:front_bounds]       = [2, 0, 4, 6]
			transform_hash[:top_bounds]			= [6, 7, 5, 4]
            transform_hash[:set_x]              = true
			transform_hash[:camera_position] 	= ORIGIN
			transform_hash[:camera_target]		= X_AXIS
			transform_hash[:camera_up]			= Z_AXIS
            transform_hash[:front_side_vector]  = X_AXIS
			transform_hash[:int_dim_vector]		= Y_AXIS.reverse
			
			transform_hash[:front_all_points]   = VG::RIO_LEFT_POINTS
			transform_hash[:back_all_points]   	= VG::RIO_RIGHT_POINTS
			transform_hash[:left_all_points]   	= VG::RIO_BACK_POINTS
			transform_hash[:right_all_points]   = VG::RIO_FRONT_POINTS
			transform_hash[:top_all_points]   	= VG::RIO_TOP_POINTS
			transform_hash[:bottom_all_points]  = VG::RIO_BOTTOM_POINTS
        when 180, -180
            transform_hash[:front_bounds]       = [3, 2, 6, 7]
			transform_hash[:top_bounds]			= [7, 5, 4, 6]
            transform_hash[:front_dim_vector]   = X_AXIS.reverse
            transform_hash[:front_side_vector]  = Y_AXIS
            transform_hash[:front_all_points]   = [0,1,5,4,8,17,10,16,22]
            transform_hash[:set_y]              = true
			transform_hash[:camera_position] 	= ORIGIN
			transform_hash[:camera_target]		= Y_AXIS.reverse
			transform_hash[:camera_up]			= Z_AXIS
			transform_hash[:int_dim_vector]		= X_AXIS.reverse
			
			transform_hash[:front_all_points]   = VG::RIO_BACK_POINTS
			transform_hash[:back_all_points]   	= VG::RIO_FRONT_POINTS
			transform_hash[:left_all_points]   	= VG::RIO_RIGHT_POINTS
			transform_hash[:right_all_points]   = VG::RIO_LEFT_POINTS
			transform_hash[:top_all_points]   	= VG::RIO_TOP_POINTS
			transform_hash[:bottom_all_points]  = VG::RIO_BOTTOM_POINTS
        end
        transform_hash
    end


	def self.add_rect_face_lines face, color='red', count=15, facing_flag='left'

		face_created = false
		#For points
		if face.is_a?(Array)
			face = Sketchup.active_model.entities.add_face(face)
			face_created = true
		end

		return unless face.is_a?(Sketchup::Face)

		pt_cnt = (count/2)+1
		other_points = []
		zedge_points = []
		edges = face.outer_loop.edges
		if facing_flag == 'left'
			edge_arr = [[edges[0], edges[1]], [edges[2], edges[3]]]
		else
			edge_arr = [[edges[0], edges[3]], [edges[1], edges[2]]]
		end
		
		#material = Sketchup.active_model.materials.add(?Test?)
		#material.color = color
		
		edge_arr.each{ |edge|
			e1 = edge[0]
			e2 = edge[1]
			
			
			common_vert = e1.vertices & e2.vertices
			common_vert = common_vert[0]
			vert1 = e1.vertices - [common_vert]; vert1=vert1[0]
			vert2 = e2.vertices - [common_vert]; vert2=vert2[0]
			
			#puts "edge1 : #{e1} : #{e1.vertices}"
			#puts "edge2 : #{e2} : #{e2.vertices}"
			
			#puts "ver : #{vert1} : #{vert2} : #{common_vert}"
			
			pt1 	= vert1.position
			pt2 	= vert2.position
			pt3 	= common_vert.position
			
			shade_line = Sketchup.active_model.entities.add_line pt1, pt2
			shade_line.material=color if shade_line
			vector 	= pt1.vector_to pt2
			
			#puts "pt",pt1, pt2, pt3
			pt_cnt.times { |index|
				pt1_offset 	= (pt3.distance pt1)/pt_cnt
				pt2_offset 	= (pt3.distance pt2)/pt_cnt
				
				pt1_vector 	= pt1.vector_to pt3
				pt2_vector 	= pt2.vector_to pt3
				
				new_pt1 	= pt1.offset(pt1_vector, (index+1)*pt1_offset)
				new_pt2 	= pt2.offset(pt2_vector, (index+1)*pt2_offset)
				
				#puts "new pt: #{new_pt1}, #{new_pt2}"
				shade_line = Sketchup.active_model.entities.add_line new_pt1, new_pt2
				# puts "shade_line : #{shade_line}  #{new_pt1}, #{new_pt2}"
				shade_line.material=color if shade_line
			}
		}
		if face_created
			Sketchup.active_model.entities.erase_entities face
		end
	end

	def self.add_carcass_dimension comp
		comp=fsel
	
		comp_origin 	= comp.transformation.origin
	
		trans 	= comp.transformation.rotz
		pts 	= []
		case trans
		when 0
			pts = [0,1,5,4]
			side_vector = Geom::Vector3d.new(-1, 0, 0)
			bound_index = 0
		when 90
			pts	= [1,3,7,5]
			side_vector = Geom::Vector3d.new(0, 1, 0)
			bound_index = 1
		when -90
			pts = [0,2,6,4]
			side_vector = Geom::Vector3d.new(0, -1, 0)
			bound_index = 2
		when 180, -180
			pts = [2,3,7,6]
			side_vector = Geom::Vector3d.new(1, 0, 0)
			bound_index = 3
		end
	
		zvector = Geom::Vector3d.new(0, 0, 1)
		comp_dimension_offset 	= 5000.mm
	
		Sketchup.active_model.start_operation('Internal dimension')
	
		if true
			prev_ents	=[];
			Sketchup.active_model.entities.each{|ent| prev_ents << ent}
	
			comp.make_unique
			comp.explode
			
			post_ents 	= [];
			Sketchup.active_model.entities.each{|ent| post_ents << ent}
	
			exploded_ents = post_ents - prev_ents
			exploded_ents.select!{|x| !x.deleted?}
			
			shelf_fix_entities 	= exploded_ents.grep(Sketchup::Group).select{|x| x.layer.name.start_with?('72IMOSXD01_IM_SHELF_FIX')}
			shelf_fix_entities.sort_by!{|x| x.bounds.corner(0).z}
			lower_shelf_fix 	= shelf_fix_entities.first
			upper_shelf_fix		= shelf_fix_entities.last

			# puts "lower_shelf_fix : #{lower_shelf_fix} : #{upper_shelf_fix}"
			
			comp_ents 		= []
			exploded_ents.each{|ent| comp_ents << ent}
			comp_ents 		= comp_ents - [lower_shelf_fix]
			
			comp_ents.sort_by!{|x| x.bounds.corner(0).z}
			other_ents 	= []
			dim_ents 	= []
			comp_ents.each{ |shelf_ent|
				ent_org = shelf_ent.transformation.origin
				visible_flag = false
				if shelf_ent.layer.name.end_with?('SHELF_INT') || shelf_ent.layer.name.end_with?('SHELF_FIX')
					visible_flag = true
				elsif shelf_ent.layer.name.end_with?('DRAWER_FRONT')
					visible_flag = true
				elsif shelf_ent.layer.name.end_with?('DRAWER_INT')
					other_ents << shelf_ent
				elsif shelf_ent.layer.name.end_with?('SIDE_NORM')
					
				end
				
				dim_ents << shelf_ent  if visible_flag
			}
	
			lshelf_fix_ray_entities = []
			center_pt = TT::Bounds.point(lower_shelf_fix.bounds, 24)
			sel.clear
			dim_ents.each{|ent|
				#y_offset	= comp.transformation.origin.y - ent.transformation.origin.y
				y_offset 	= lower_shelf_fix.bounds.corner(0).y - ent.bounds.corner(0).y
				trans 		= Geom::Transformation.new([0, y_offset, 0])
				ent.transform!(trans)
			}
	
			center_pt = TT::Bounds.point(lower_shelf_fix.bounds, 10)
			#puts lower_shelf_fix
			#sel.add(lower_shelf_fix)
			[4,5].each{ |index| 
				pt = TT::Bounds.point(lower_shelf_fix.bounds, index)
				bound_point = Geom.linear_combination(0.5, pt, 0.5, center_pt)
				ray 		= [bound_point, zvector]
				hit_item 	= Sketchup.active_model.raytest(ray, true)
				# puts "lshelf hit_item : #{hit_item} : #{bound_point}"
				
				if hit_item && hit_item[1][0]
					sel.add(hit_item[1][0])
					if dim_ents.include?(hit_item[1][0])
						lshelf_fix_ray_entities << hit_item[1][0] 
						pt1 	= bound_point
						pt2 	= hit_item[0]
						#pt1.z	+=5000.mm
						#pt2.z	+=5000.mm
						pt1.y -= 2000.mm
						pt2.y -= 2000.mm
						if (pt1.distance pt2) > 10.mm
							Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, Geom::Vector3d.new(1,0,0))
							# puts "points : #{pt1} : #{pt2}"
						end
					end
				end
			}
	
			lshelf_fix_ray_entities.flatten!
			
			side_vector = Geom::Vector3d.new(1,0,0)
			# puts "lshelf_fix_ray_entities : #{lshelf_fix_ray_entities}"
			lshelf_fix_ray_entities.each{|internal_comp|
				continue_ray = true
				while continue_ray
					center_pt = TT::Bounds.point(internal_comp.bounds, 10)
					next_pt 	= true
					[4,5].each{ |index| 
						break unless next_pt
						pt 			= TT::Bounds.point(internal_comp.bounds, index)
						bound_point = Geom.linear_combination(0.5, pt, 0.5, center_pt)
						ray 		= [bound_point, zvector]
						hit_item 	= Sketchup.active_model.raytest(ray, true)
	
						
						if hit_item && hit_item[1][0]
							# puts "inner comps : #{hit_item[0]} : #{hit_item[1]} : #{bound_point}"
							sel.add(hit_item[1][0])
							if dim_ents.include?(hit_item[1][0]) 
								internal_comp 	= hit_item[1][0]
								pt1 	= bound_point
								pt2 	= hit_item[0]
								pt1.y -= 2000.mm
								pt2.y -= 2000.mm
								#pt1.z			+=5000.mm
								#pt2.z			+=5000.mm
								if (pt1.distance pt2) > 10.mm
									dim_l = Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
									dim_l.material.color = 'red'
								end
								next_pt 	= false
							else
								continue_ray = false 
							end
						else
							continue_ray = false 
						end
					}
				end
			}
	
		end
	end
	
	
	
	def self.add_to_rio_components comp
		prompts = ["Type", "Name"]
		defaults = [""]
		list = [""]
		input = UI.inputbox(prompts, defaults, list, "Custom Component")

		type 		= input[0].nil? ? 'RioCustom' : input[0]
		defn_name 	= input[1].nil? ? 'RioDefnName' : input[1]
						
		layer_name = 'DP_Cust_Comp_layer'
		Sketchup.active_model.layers.add(layer_name) if Sketchup.active_model.layers[layer_name].nil?
		comp.layer = layer_name
		comp.definition.name = defn_name 
		comp.set_attribute :rio_atts, 'rio_comp', 'custom'
		comp.set_attribute :rio_atts, 'custom_type', type
		UI.messagebox "Right click on the component and click change axes to set the visible side. The view the component will be visible is based on the origin."
	end

	def self.get_rio_components cust_comps=false
		inst_arr 	= Sketchup.active_model.entities.grep(Sketchup::ComponentInstance)
		group_arr	= Sketchup.active_model.entities.grep(Sketchup::Group)
		comps 		= inst_arr.select{|x| x.definition.get_attribute(:rio_atts, 'rio_comp')=='true'}
		comps 		<< inst_arr.select{|x| x.layer.name == 'DP_Comp_layer'}
		comps 		<< inst_arr.select{|x| x.layer.name == 'DP_Cust_Comp_layer'} if cust_comps
		comps 		<< group_arr.select{|x| x.layer.name == 'DP_Cust_Comp_layer'} if cust_comps
		comps.flatten!
		comps
	end
	
	def self.get_view_face view
		ent	  = Sketchup.active_model.entities
		l,x,y,z = 1000, 500, 500, 500
		
		case view
		when "top"
			pts = [[-l,-l,z], [l,-l,z], [l,l,z], [-l,l,z]]
			hit_face = ent.add_face pts
		when "right"
			pts = [[x,-l,-l], [x,l,-l], [x,l,l], [x,-l,l]]
			hit_face = ent.add_face pts
		when "left"
			pts = [[-x,-l,-l], [-x,l,-l], [-x,l,l], [-x,-l,l]]
			hit_face = ent.add_face pts
		when "front"
			pts = [[-l,-y,-l], [l,-y,-l], [l,-y,l], [-l,-y,l]]
			hit_face = ent.add_face pts
		when "back"
			pts = [[-l,y,-l], [l,y,-l], [l,y,l], [-l,y,l]]
			hit_face = ent.add_face pts
		end
		return hit_face
	end

	def self.zrotate
		comp = Sketchup.active_model.selection[0]
		if !comp.nil?
			point = comp.transformation.origin
			vector = Geom::Vector3d.new(0,0,1)
			angle = 90.degrees
			transformation = Geom::Transformation.rotation(point, vector, angle)
			comp.transform!(transformation)
		else
			UI.messagebox 'Component not selected!', MB_OK
		end
	end

	def self.traverse(entity, transformation = IDENTITY)
		rio_face_codes_h={'carcass_top_laminate_face'=>'false','carcass_top_default_laminate_face'=>'false','carcass_top_edge_band_face'=>'false','carcass_left_laminate_face'=>'false','carcass_left _default_laminate_face'=>'false','carcass_left _edge_band_face'=>'false','carcass_right_laminate_face'=>'false','carcass_right_default_laminate_face'=>'false','carcass_right_edge_band_face'=>'false','shutter_laminate_face'=>'false','shutter_default_laminate_face'=>'false','shutter_edge_band_face'=>'false','handle_location'=>'0_0_0','left_handle_location'=>'0_0_0','right_handle_location'=>'0_0_0','top_handle_location'=>'0_0_0','glass_face'=>'false','default_laminate_face'=>'false'}
		# If this node can have children, traverse its children.
		if entity.is_a?(Sketchup::Model)
			entity.entities.each{ |child_entity|
			  traverse(child_entity, transformation)
			}
		elsif entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
			# puts entity.get_attribute('rio_atts', 'right_laminate')
			# Multiply the outer coordinate system with the group's/component's local coordinate system.
			transformation *= entity.transformation
			entity.definition.entities.each{ |child_entity|
			  traverse(child_entity, transformation.clone)
			}
		end
		if entity.is_a?(Sketchup::Face)
			if entity.get_attribute('rio_face_codes', 'handle_location')
				# puts entity.get_attribute('rio_face_codes', 'handle_location').to_s
				# puts entity
			end
			
			dict_name = 'rio_face_codes'
			rio_face_codes_h.each_pair{|key, value|
				#entity.set_attribute dict_name, key, value
			}
		end
	end
	
	def self.get_points comp, view
		hit_pts = []
		mod	  = Sketchup.active_model
		ent	  = mod.entities
		
		bounds = comp.bounds
		case view
		when "top"
			indexes = [4,5,7,6,10,11,13,15,24]
			vector 	= Geom::Vector3d.new(0,0,1)
		when "right"
			indexes = [1,3,7,5,14,15,17,19,21]
			vector 	= Geom::Vector3d.new(1,0,0)
		when "left"
			indexes = [0,2,6,4,12,13,16,18,20]
			vector 	= Geom::Vector3d.new(-1,0,0)
		when "front"
			indexes = [0,1,5,4,8,10,16,17,22]
			vector 	= Geom::Vector3d.new(0,-1,0)
		when "back"
			indexes = [2,3,7,6,9,11,18,19,23]
			vector 	= Geom::Vector3d.new(0,1,0)
		end
		indexes.each { |i|
			hit_pts << TT::Bounds.point(bounds, i)
		}
        temp_face = ent.add_face(hit_pts[0],hit_pts[1],hit_pts[2],hit_pts[3])
		hit_pts = face_off_pts temp_face, -2
		#temp_face = ent.add_face(hit_pts[0],hit_pts[1],hit_pts[2],hit_pts[3])
		del_comps = [temp_face, temp_face.edges]
		del_comps.flatten.each{|x| ent.erase_entities x unless x.deleted?}
		
		return hit_pts, vector
	end
	
	#Get visible decorpot components from the view
	# floor = Sketchup.active_model.entities.select{|c| c.layer.name == 'DP_Floor'}[0]
	# pts = face_off_pts floor, 50
	# (pts.length).times{|i| pts[i].z = 200}
	# hit_face = Sketchup.active_model.entities.add_face(pts)
	def self.get_top_visible_comps
		mod	  = Sketchup.active_model
		ent	  = mod.entities
				
		comps = ent.grep(Sketchup::ComponentInstance)
		comps = comps.select{|x| x.hidden? == false}
		
		view = 'top'
		
		#comps = Sketchup.active_model.selection
		['DP_Floor', 'DP_Wall'].each{|layer| Sketchup.active_model.layers[layer].visible=false}
		
		hit_face = get_view_face view
		visible_comps = []
		comps.each{|comp|
			pts, nor_vector = get_points comp, view
			#ent.add_face(pts)
			pts.each { |pt|
				hit_item = mod.raytest(pt, nor_vector)
				if hit_item && hit_item[1][0] == hit_face
					visible_comps << comp
					#mod.selection.add comp 
					break
				end
			}
		}
		del_comps = [hit_face, hit_face.edges]
		del_comps.flatten.each{|x| 
            unless x.deleted?
                ent.erase_entities x 
            end
        }
		['DP_Floor', 'DP_Wall'].each{|layer| Sketchup.active_model.layers[layer].visible=true}
		return visible_comps
	end

	#Get 28 top points for all comps.....4 corner points + 4 border line * 4 + 2 diagonal line * 4
	def self.get_hit_points comp
		bounds 		= comp.bounds
		corner_pts 	= []
		all_points 	= []
		[4,5,7,6].each{ |index|
			corner_pts 	<< comp.bounds.corner(index) 
			all_points 	<< comp.bounds.corner(index)
		}

		4.times {|i|
			pt1 = corner_pts[0]
			pt2 = corner_pts[1]
			corner_pts.rotate!
			vector = pt1.vector_to pt2
			offset = (pt1.distance pt2)/5
			#offset = offset.to_i.mm
			#puts "offset : #{offset.to_mm}" if comp.guid.to_s == '05KanPBWfEOxJcSrOSLf8y'
			4.times{ |index|
				all_points << pt1.offset(vector, index*offset)
			}
		}

		pt1 = comp.bounds.corner(4)
		pt2 = comp.bounds.corner(7)
		vector = pt1.vector_to pt2
		offset = (pt1.distance pt2)/5
		#offset = offset.mm
		#puts "offset : #{offset.to_mm}" if comp.guid.to_s == '05KanPBWfEOxJcSrOSLf8y'
		4.times{ |index|
			all_points << pt1.offset(vector, index*offset)
		}

		pt1 = comp.bounds.corner(5)
		pt2 = comp.bounds.corner(6)
		vector = pt1.vector_to pt2
		offset = (pt1.distance pt2)/5
		#offset = offset.mm
		#puts "offset : #{offset.mm}" if comp.guid.to_s == '05KanPBWfEOxJcSrOSLf8y'
		4.times{ |index|
			all_points << pt1.offset(vector, index*offset)
		}
		#puts all_points.length
		all_points
	end

	#This algorithm is to get components at different levels.
	#First find the components visible form the top view.
	#Then hide them...and recursively find components at differnt levels
	def self.get_multi_layer_top_components comps
		if comps.empty?
			Sketchup.active_model.abort_operation
			return [] 
		end
		if @@multi_layer_top_view_components.empty?
			Sketchup.active_model.start_operation 'Multi layer Top Component'
		end
		#rio_comps	= get_rio_components
		rio_comps 	= comps 
	
		layers_arr 	= Sketchup.active_model.layers
	
		layers_arr.each{|mod_layer| mod_layer.visible=false}
	
		layers_arr['DP_Comp_layer'].visible=true
		layers_arr.each {|x| x.visible=true if x.name.start_with?('72IMOS')}
	
		model 	= Sketchup.active_model
		zvector = Geom::Vector3d.new(0, 0, 1)
	
		visible_comps = []
		rio_comps.each {|comp|
			comp_visible = true
			hit_points 	= get_hit_points comp
			hit_points.flatten!

			hit_points.each{ |corner_pt|
				hit_item	= model.raytest corner_pt, zvector
				#puts "hit_item_o : #{hit_item} : #{corner_pt}" if comp.guid.to_s == '05KanPBWfEOxJcSrOSLf8y'
				if hit_item
					
					hit_comp 	= hit_item[1][0]  
					#puts "hit_item_i : #{hit_item}" if comp.guid.to_s == '05KanPBWfEOxJcSrOSLf8y'
					if rio_comps.include?(hit_comp)
						#puts "hit_item_i : #{hit_item}"
						comp_visible = false 
						break
					end
				end
				next unless comp_visible
			}
			if comp_visible
				visible_comps << comp
				#comp.visible=false
			end
		}
		if visible_comps.empty?
			Sketchup.active_model.abort_operation
			return [] 
		else
			#puts "visible_comps_u : #{visible_comps.uniq}"
			#sel.add(visible_comps)
			@@multi_layer_top_view_components << visible_comps
			rem_comps = rio_comps - visible_comps
			visible_comps.each{|x| x.visible=false}
			#puts "rem_comps : #{rem_comps}........................"
			get_multi_layer_top_components rem_comps
		end
	end

	#Temporarily making wall invisible to find rio components.
	#Future get all rio components and find their transformation
	def self.get_visible_comps view
		visible_comps = []
		comps = get_rio_components
		case view.downcase
		when 'left'
			rotz = 90
		when 'right'
			rotz = -90
		when 'front'
			rotz = 180
		when 'back'
			rotz = 0
		end
		visible_comps = comps.select{|x| xrotz=x.transformation.rotz;xrotz=xrotz.abs if view=='front';xrotz==rotz}
		visible_comps
	end

	
	#Get the intersection of two components
	def self.get_xn_pts c1, c2
		xn = c1.bounds.intersect c2.bounds
		corners = []
		(0..7).each{|x| corners<<xn.corner(x)}
		arr = corners.inject([]){ |array, point| array.any?{ |p| p == point } ? array : array << point }
		return arr
	end

	
	def self.check_adj c1, c2
		return 0 if c1.nil?
		return 0 if c2.nil?
		return 0 unless (c1.bounds.intersect c2.bounds).valid?
		corners=[];
		intx=c1.bounds.intersect c2.bounds;
		(0..7).each{|x| corners<<intx.corner(x)}
		#puts corners
		return corners.map{|x| x.to_s}.uniq.length
	end
	
	def self.get_schema comp_arr
		comps = {}
		comp_arr.each {|comp| 
			next if comp.definition.name == 'region'
			pid = DP::pid comp;
			comps[pid] = {:type=>false, :adj=>[] , :row_elem=>false}
		}
		comps
	end
    
    def self.del_face face
        face.edges.each{|x| Sketchup.active_model.entities.erase_entities x unless x.deleted?}
    end
	
	#Parse the components and get the hash.
	def self.parse_components comp_arr
		comp_list = get_schema comp_arr
		corners = []
		comp_list.keys.each { |id|
			#lb_curr = lower_bounds id 
			adj_comps = []
			outer_comp = DP.get_comp_pid id
			#DP.comps.each{|inner_comp| # Just delete this line.........Not needed
            comp_arr.each{|inner_comp|    
				next if inner_comp.definition.name == 'region'
				next if outer_comp == inner_comp 
				alen = check_adj outer_comp, inner_comp
				type = :single
				if alen > 2
					next if inner_comp.definition.name == 'region'
					adj_comps << inner_comp.persistent_id
					if adj_comps.length > 1
                        adj = DP.get_comp_pid adj_comps[0]
                        #vec1    = outer_comp.bounds.center.vector_to adj.bounds.center
                        min_vec1    = outer_comp.bounds.min.vector_to adj.bounds.min
                        #max_vec1    = outer_comp.bounds.max.vector_to adj.bounds.max
                        type    = :double
                        #adj_face    = Sketchup.active_model.entities.add_face(xn_pts) 
                        (1..adj_comps.length-1).each{ |i|
                            adj_c   = DP.get_comp_pid adj_comps[i]
                            #vec2    = outer_comp.bounds.center.vector_to adj_c.bounds.center
                            min_vec2    = outer_comp.bounds.min.vector_to adj_c.bounds.min
                            #max_vec2    = outer_comp.bounds.max.vector_to adj_c.bounds.max
                            type = :corner if min_vec1.perpendicular?(min_vec2)
                            #type = :corner if max_vec1.perpendicular?(max_vec2)
                        }
                    end
					comp_list[id][:type] = type
					#corners << inner_comp.persistent_id) if adj_comps.length > 1
				end
			}

			comp_list[id][:adj] = adj_comps
		}
		return comp_list
	end
	
	#Create layers for multi components
	def self.create_layers
		layers = ['DP_Floor', 'DP_Dimension_layer', 'DP_Comp_layer', 'DP_lamination', 'DP_Wall', 'DP_Cust_Comp_layer']
		layers.each { |name|
			Sketchup.active_model.layers.add(name) if Sketchup.active_model.layers[name].nil?
		}
	end
	
	def self.corners b
		arr=[];(0..7).each{|i| arr<<b.bounds.corner(i)}
		return arr
	end
	
	#------------------------------------------------------------------------------------
	#This test checks if the objects are in the room based on the raytest with the floor.
	#
	#------------------------------------------------------------------------------------
	def self.visibility_raytest_floor
		comps = Sketchup.active_model.entities.grep(Sketchup::ComponentInstance)
		floor_face = fsel

		# puts "floor_face not selected " if floor_face.nil?
		Sketchup.active_model.selection.clear
		if !floor_face.nil?
			zvector = Geom::Vector3d.new(0, 0, -1)
			visible_ents = []

			comps.each{ |comp|
				visible_ents = Sketchup.active_model.entities.select{|x| x.hidden? == false} 
				visible_ents.each{|ent| 
					next if ent == comp 
					next if ent == floor_face
					ent.hidden=true 
				}
				(4..7).each{|i| 
					pt 			= comp.bounds.corner(i);
					hit_item	= Sketchup.active_model.raytest(pt, zvector);
					#puts hit_item
					if hit_item && hit_item[1][0] == floor_face
						# puts "floor_face"
					else
						# puts "Exterior : #{pt}"
						Sketchup.active_model.selection.add(comp)
						visible_ents.each{|x| x.hidden=false}
						#return false
					end
				}
				visible_ents.each{|x| x.hidden=false}
			}
		end
		#return true
	end

	#------------------------------------------------------------------------------------
	#This test checks for the bounds of every object to be within the bounds of the room.
	#------------------------------------------------------------------------------------
	def self.check_room_bounds_all_comps
		Sketchup.active_model.selection.clear
		comps 		= Sketchup.active_model.entities.grep(Sketchup::ComponentInstance) #change to rio comp test
		get_room 	= Sketchup.active_model.select{|x| x.get_attribute :rio_atts, 'position'}
		if get_room.empty?
			puts "room_bounds object not found"
		else
			room_bounds = get_room[0]
			comps = comps - [room_bounds]
			comps.each{|comp|
				if room_bounds.bounds.contains?(comp.bounds)
					# puts "true"
				else
					# puts "false"
					Sketchup.active_model.selection.add comp
				end
			}
		end
	end

	def self.check_room_bounds comp
		Sketchup.active_model.selection.clear
		Sketchup.active_model.start_operation('check_room_bounds')
		if comp.nil?
			# puts "Check room bounds : Comp is nil" 
			return true	
		end
		faces 	= Sketchup.active_model.entities.select{|x| !x.get_attribute(:rio_atts, 'position').nil?}
		temp_group = Sketchup.active_model.entities.add_group(faces)
		
		flag = false
		if temp_group.nil?
			puts "Floor object not found "
		else
			if temp_group.bounds.contains?(comp.bounds)
				flag = true
			else
				Sketchup.active_model.selection.add comp
			end
		end
		temp_group.explode
		Sketchup.active_model.abort_operation
		return flag
	end
    
	def self.create_wall inp_h
		mod 	= Sketchup.active_model

		origin	= Geom::Point3d.new(0, 0, 0)
		xvector = Geom::Vector3d.new(1, 0, 0)
		yvector = Geom::Vector3d.new(0, 1, 0)
		zvector	= Geom::Vector3d.new(0, 0, 1)
		

		#puts "inp_h : #{inp_h}"
        wwidth 	= inp_h['wall1'].to_f.mm.to_inch
        wlength = inp_h['wall2'].to_f.mm.to_inch
        wheight = inp_h['wheight'].to_f.mm.to_inch
        #thick	= inp_h['wthick'].to_f.mm.to_inch
        active_layer = Sketchup.active_model.active_layer.name
		pts = [Geom::Point3d.new(0,0,0), Geom::Point3d.new(wwidth,0,0), Geom::Point3d.new(wwidth,wlength,0), Geom::Point3d.new(0,wlength,0)]

		prev_active_layer = Sketchup.active_model.active_layer.name
        #Sketchup.active_model.active_layer='DP_Floor'
        floor_face = Sketchup.active_model.entities.add_face(pts)
		floor_face.set_attribute :rio_atts, 'position', 'floor'
		fcolor    			= Sketchup::Color.new "FF335B"
		floor_face.material 		= fcolor
        floor_face.back_material 	= fcolor

		Sketchup.active_model.active_layer='DP_Wall'
		fcolor    			= Sketchup::Color.new "33FFDA"
        floor_face.edges.each{ |edge|
            verts 	= edge.vertices
            pt1   	= verts[0]
            pt2   	= verts[1]
            pt3		= pt2.position.offset(zvector, wheight)
            pt4		= pt1.position.offset(zvector, wheight)
            #puts pt1, pt2, pt3, pt4
            face 	= mod.entities.add_face(pt1, pt2, pt3, pt4)
           
            #fcolor.alpha 		= 0.5
            
            position = get_position edge, floor_face
            face.set_attribute :rio_atts, 'position', position if position

            face.material 		= fcolor
            face.back_material 	= fcolor
            face.material.alpha	= 0.5
        }

		door_image_path 	= File.join(WEBDIALOG_PATH,"../images/door.png")
		window_image_path 	= File.join(WEBDIALOG_PATH,"../images/window.png")

        if inp_h["door"] && !inp_h["door"].empty?
            door_h 			= inp_h["door"]
            door_view 		= door_h['door_view'].to_sym
            door_position	= door_h['door_position'].to_f.mm.to_inch
            door_height		= door_h['door_height'].to_f.mm.to_inch
            door_width		= door_h['door_length'].to_f.mm.to_inch


			image 			= Sketchup.active_model.entities.add_image door_image_path, origin, door_width, door_height
			angle 			= 90.degrees
			transformation 	= Geom::Transformation.rotation(origin, xvector, angle)
			image.transform!(transformation)

            case door_view
            when :front	
                vector 		= Geom::Vector3d.new(-1, 0, 0)
                start_point = TT::Bounds.point(floor_face.bounds, 1) 

            when :back
                vector = Geom::Vector3d.new(1, 0, 0)
                start_point = TT::Bounds.point(floor_face.bounds, 2)

            when :left
                vector = Geom::Vector3d.new(0, 1, 0)
                start_point = TT::Bounds.point(floor_face.bounds, 0)

				image_vector = Geom::Vector3d.new(0,0,1)
				transformation = Geom::Transformation.rotation(origin, image_vector, angle)
				image.transform!(transformation)
            when :right
                vector = Geom::Vector3d.new(0, -1, 0)
				start_point = TT::Bounds.point(floor_face.bounds, 3)
				
				image_vector = Geom::Vector3d.new(0,0,-1)
				transformation = Geom::Transformation.rotation(origin, image_vector, angle)
				image.transform!(transformation)
			end
			
			door_start_point 	= start_point.offset(vector, door_position)
			door_end_point		= start_point.offset(vector, door_position+door_width)
			door_left_point		= door_start_point.offset(zvector, door_height)
			door_right_point	= door_end_point.offset(zvector, door_height)

			door = mod.entities.add_face(door_start_point, door_end_point, door_right_point, door_left_point)
			Sketchup.active_model.entities.erase_entities door

			#puts "door_start_point : #{door_start_point}"
			#puts "door_end_point : #{door_end_point}"
			start_point = door_view == :front ? door_end_point : door_start_point
			image_trans = Geom::Transformation.new(start_point)
			image.transform!(image_trans)
		end
		
		#"windows"=>{"window_view"=>"left", "win_lftposition"=>"300", "win_btmposition"=>"500", "win_height"=>"400", "win_length"=>"350"}}

		if inp_h["windows"] && !inp_h["windows"].empty?
			window_h 			= inp_h["windows"]
            window_view 		= window_h['window_view'].to_sym
            window_position		= window_h['win_lftposition'].to_f.mm.to_inch
			window_btmposition	= window_h['win_btmposition'].to_f.mm.to_inch
            window_height		= window_h['win_height'].to_f.mm.to_inch
            window_width		= window_h['win_length'].to_f.mm.to_inch

			image 			= Sketchup.active_model.entities.add_image window_image_path, origin, window_width, window_height
			angle 			= 90.degrees
			transformation 	= Geom::Transformation.rotation(origin, xvector, angle)
			image.transform!(transformation)

            case window_view
            when :front	
                vector 		= Geom::Vector3d.new(-1, 0, 0)
				start_point = TT::Bounds.point(floor_face.bounds, 1) 
				
			when :back
                vector = Geom::Vector3d.new(1, 0, 0)
				start_point = TT::Bounds.point(floor_face.bounds, 2)
				
				#image_trans = Geom::Transformation.new(Geom::Point3d.new(window_position, 0, window_btmposition))
				#image.transform!(image_trans)
            when :left
                vector = Geom::Vector3d.new(0, 1, 0)
				start_point = TT::Bounds.point(floor_face.bounds, 0)
				
				image_vector = Geom::Vector3d.new(0,0,1)
				transformation = Geom::Transformation.rotation(origin, image_vector, angle)
				image.transform!(transformation)
            when :right
                vector = Geom::Vector3d.new(0, -1, 0)
				start_point = TT::Bounds.point(floor_face.bounds, 3)
				
				image_vector = Geom::Vector3d.new(0,0,-1)
				transformation = Geom::Transformation.rotation(origin, image_vector, angle)
				image.transform!(transformation)
            end
			
			start_point = start_point.offset(zvector, window_btmposition)

			window_start_point 	= start_point.offset(vector, window_position)
			window_end_point		= start_point.offset(vector, window_position+window_width)
			window_left_point		= window_start_point.offset(zvector, window_height)
			window_right_point	= window_end_point.offset(zvector, window_height)

			window = mod.entities.add_face(window_start_point, window_end_point, window_right_point, window_left_point)
			Sketchup.active_model.entities.erase_entities window

			image_trans = Geom::Transformation.new(window_start_point)
			image.transform!(image_trans)
		end

        faces =[]
        floor_verts = []
        (0..3).each{|i| floor_verts << floor_face.bounds.corner(i)}
        
        floor_face.edges.each{|ed| 
            faces<<ed.faces
        }
        mod.selection.clear
        
        #----------makes all the faces to single component.....
        #faces.flatten.uniq.each{|f| Sketchup.active_model.selection.add f}
        #mod.entities.add_group(Sketchup.active_model.selection)
        
        faces.flatten.uniq.each { |face|  
			position = face.get_attribute :rio_atts, 'position'
			position = 'floor' if position.nil?
            gp = mod.entities.add_group(face)
            gp.set_attribute :rio_atts, 'position', position 
		}
		floor_face.layer = 'DP_Floor'
		Sketchup.active_model.active_layer=prev_active_layer
    end
    
    def self.get_position edge, face
        return nil if edge.nil?
        return nil if face.nil?

        floor_verts = []
        (0..3).each{|i| floor_verts << face.bounds.corner(i).to_s}

        edge_pts = []
        edge.vertices.each{|ver| 
            edge_pts << ver.position.to_s
        }
        if ([floor_verts[0], floor_verts[1]] & edge_pts).length == 2
            return "front"
        elsif ([floor_verts[3], floor_verts[1]] & edge_pts).length == 2
            return "right"
        elsif ([floor_verts[2], floor_verts[3]] & edge_pts).length == 2
            return "back"
        elsif ([floor_verts[0], floor_verts[2]] & edge_pts).length == 2
            return "left"
        end
        return nil
	end
	
	def self.save_dwg dir_path

		model 		= Sketchup.active_model

		files 		= Dir.glob(dir_path+'*.dwg')
		#files 		= Dir.glob('#{dir_path}/**/'+'*.DWG')
		files.each { |dwg_path|
			res 		= model.import dwg_path, false

			Sketchup.active_model.definitions.purge_unused
			Sketchup.active_model.layers.purge_unused
			Sketchup.active_model.materials.purge_unused
			Sketchup.active_model.styles.purge_unused

			skp_path 		= dwg_path.split('.')[0]+'.skp'
			image_file_name = dwg_path.split('.')[0]+'.jpg'
			skb_path 		= dwg_path.split('.')[0]+'.skb'
			Sketchup.active_model.save(skp_path)

			Sketchup.active_model.active_view.zoom_extents
			Sketchup.send_action("viewIso:")
			Sketchup.active_model.active_view.write_image image_file_name

			es = Sketchup.active_model.entities
			es.each{|x| es.erase_entities x }
			File.delete(skb_path) if File.exists?(skb_path)
		}
		return files.length
	end
	
	def self.hide_other_room_walls comp
		layers = Sketchup.active_model.layers
		room_name = comp.get_attribute(:rio_atts, 'space_name')
		layers.each{|layer|
			if layer.name.start_with?('DP_Wall')
				layer.visible=false if !layer.name.end_with?(room_name)
			end
		}
	end
	
	def self.unhide_all_room_walls
		layers = Sketchup.active_model.layers
		layers.each{|layer|
			layer.visible=true if layer.name.start_with?('DP_Wall')
		}
	end

	def self.change_filler_axes filler, comp_trans
		mod 	= Sketchup.active_model
		ents 	= mod.entities
		seln 	= Sketchup.active_model.selection

		comp_origin = filler.transformation.origin
		case rotz
		when 0
			new_trans 	= Geom::Transformation.new([0, -filler.bounds.height, 0])
			xoffset		= comp_origin.y - filler.bounds.corner(0).y
			yoffset		= comp_origin.x - filler.bounds.corner(0).x
			new_pt 		= Geom::Point3d.new(yoffset, xoffset, 0)
		when 90
			new_trans 	= Geom::Transformation.new([0, -filler.bounds.height, 0])
			xoffset		= comp_origin.y - filler.bounds.corner(1).y
			yoffset		= comp_origin.x - filler.bounds.corner(1).x
			new_pt 		= Geom::Point3d.new(xoffset, -yoffset, 0)
		when -90
			new_trans = Geom::Transformation.new([0, filler.bounds.height, 0])
			xoffset		= comp_origin.y - filler.bounds.corner(2).y
			yoffset		= comp_origin.x - filler.bounds.corner(2).x
			new_pt 		= Geom::Point3d.new(-xoffset, yoffset, 0)
		when 180, -180
			new_trans = Geom::Transformation.new([0, -filler.bounds.height, 0])
			xoffset		= comp_origin.y - filler.bounds.corner(3).y
			yoffset		= comp_origin.x - filler.bounds.corner(3).x
			new_pt 		= Geom::Point3d.new(-yoffset, -xoffset, 0)
		end

	end

	def self.change_axes comp, trans=nil
		mod 	= Sketchup.active_model
		ents 	= mod.entities
		seln 	= Sketchup.active_model.selection

		trans 	= comp.transformation if trans.nil?
		comp_origin = trans.origin
		
		rotz 	= trans.rotz# if rotz.nil?
		x_offset = 0
		y_offset = 0
		case rotz
		when 0
			new_trans 	= Geom::Transformation.new([0, -comp.bounds.height, 0])
			xoffset		= comp_origin.y - comp.bounds.corner(0).y
			yoffset		= comp_origin.x - comp.bounds.corner(0).x
			new_pt 		= Geom::Point3d.new(yoffset, xoffset, 0)
		when 90
			new_trans 	= Geom::Transformation.new([0, -comp.bounds.height, 0])
			xoffset		= comp_origin.y - comp.bounds.corner(1).y
			yoffset		= comp_origin.x - comp.bounds.corner(1).x
			new_pt 		= Geom::Point3d.new(xoffset, -yoffset, 0)
		when -90
			new_trans = Geom::Transformation.new([0, comp.bounds.height, 0])
			xoffset		= comp_origin.y - comp.bounds.corner(2).y
			yoffset		= comp_origin.x - comp.bounds.corner(2).x
			new_pt 		= Geom::Point3d.new(-xoffset, yoffset, 0)
		when 180, -180
			new_trans = Geom::Transformation.new([0, -comp.bounds.height, 0])
			xoffset		= comp_origin.y - comp.bounds.corner(3).y
			yoffset		= comp_origin.x - comp.bounds.corner(3).x
			new_pt 		= Geom::Point3d.new(-yoffset, -xoffset, 0)
		end

		prev_ents	=[];
		Sketchup.active_model.entities.each{|ent| prev_ents << ent}

		gp 			= ents.add_group()
		inst 		= gp.entities.add_instance(comp.definition, Geom::Transformation.new(new_pt))
		inst.explode

		# puts "offset : #{xoffset.to_mm} #{yoffset.to_mm} : "
		
		#return
		post_ents 	= [];
		Sketchup.active_model.entities.each{|ent| post_ents << ent}

		new_ent = post_ents - prev_ents

		new_ent[0].transform!(trans)
		
		
		
		new_trans = Geom::Transformation.new([0, -comp.bounds.height, 0])
		comp_inst = new_ent[0].transform!(new_trans)
		#Sketchup.active_model.entities.erase_entities(comp)
		comp_inst = comp_inst.to_component
		return comp_inst
	end

	def self.find_visible_entities_by_exploding carcass_def
		if true
			hide_all_entities

			front_vector		= Y_AXIS.reverse
			top_vector 			= Z_AXIS

			carcass_instance 	= Sketchup.active_model.entities.add_instance(carcass_def, ORIGIN)

			front_bounds 	= [0, 1, 5, 4]
			front_face_pts  = []
			front_bounds.each{|index|
				corner_pt   = carcass_instance.bounds.corner(index)
				face_pt     = corner_pt.offset(front_vector, 2000.mm)
				front_face_pts << face_pt
			}

			top_bounds 		= [4, 5, 7, 6]
			top_face_pts  = []
			top_bounds.each{|index|
				corner_pt   = carcass_instance.bounds.corner(index)
				face_pt     = corner_pt.offset(top_vector, 2000.mm)
				top_face_pts << face_pt
			}

			pre_explode_entities = []
			Sketchup.active_model.entities.each{|ent| pre_explode_entities << ent}

			carcass_instance.explode

			post_explode_entities = []
			Sketchup.active_model.entities.each{|ent| post_explode_entities << ent}

			new_entities 		= post_explode_entities - pre_explode_entities


			visible_layers      = ['SHELF_FIX', 'SHELF_NORM', 'SHELF_INT', 'SIDE_NORM', 'DRAWER_FRONT']
			defn_entities = carcass_def.entities

			#---------------Raytesting front faces------------------------------------
			front_raytest_face 	= Sketchup.active_model.entities.add_face(front_face_pts)

			ray_entities = []
			ray_entities << front_raytest_face
			ray_entities << front_raytest_face.edges
			ray_entities.flatten!.uniq!


			new_entities.each{ |new_entity|
				#puts "new_entity : #{new_entity}"
				new_entity_layer_name = new_entity.layer.name.split('_IM_')[1]
				#puts "new_entity_layer_name : #{new_entity_layer_name}"
				next unless visible_layers.include?(new_entity_layer_name)

				new_entity_front_bounds = [0,1,5,4,8,17,10,16]
				opposite_points			= [5,4,0,1,10,16,8,17]
				visible_flag 	= true

				new_entity_front_bounds.each_index{ |index|
					pt1	 	= TT::Bounds.point(new_entity.bounds, new_entity_front_bounds[index])
					pt2	 	= TT::Bounds.point(new_entity.bounds, opposite_points[index])
					vector 	= pt1.vector_to pt2
					offset_pt = pt1.offset(vector, 0.5.mm)
					ray 	= [offset_pt , front_vector]
					hit_item = Sketchup.active_model.raytest(ray, true)
					#puts "hit_item : #{hit_item}"
					if hit_item
						#puts "hit_item : #{hit_item[1][0].persistent_id}"
						ray_hit_item = hit_item[1][0]
						ray_entities
						unless ray_entities.include?(ray_hit_item)
							visible_flag = false
						end
					else
						#puts "visibility failed"
						visible_flag = false
					end
				}
				#puts "visible_flag : #{visible_flag} : #{new_entity}"
                #sel.add(new_entity) if visible_flag
				#visible_flag = true if new_entity_layer_name=='SIDE_NORM'
				if visible_flag
					#new_entity.set_attribute(:rio_atts, 'outline_visible_flag', 'true')
					#new_entity.set_attribute(:rio_atts, 'inner_dimension_visible_flag', 'true')
					carcass_defn_entity = carcass_def.entities.select{|x| x.bounds.corner(0) == new_entity.bounds.corner(0)}[0]
					if carcass_defn_entity
						carcass_defn_entity.set_attribute(:rio_atts, 'outline_visible_flag', 'true')
						carcass_defn_entity.set_attribute(:rio_atts, 'inner_dimension_visible_flag', 'true')
					else
						puts "Definition entity corresponding to the instance could not be found : create_carcass_definition"
					end
				end
			}

			Sketchup.active_model.entities.erase_entities(front_raytest_face.edges)

			#---------------Raytesting top faces------------------------------------
			top_raytest_face 	= Sketchup.active_model.entities.add_face(top_face_pts)

			ray_entities = []
			ray_entities << top_raytest_face
			ray_entities << top_raytest_face.edges
			ray_entities.flatten!.uniq!

			new_entity_front_bounds = [4,5,7,6,10,11,13,15]
			opposite_points			= [7,6,4,5,11,10,15,13]

			# puts "ray_entities : top : #{ray_entities}"

			new_entities.each{ |new_entity|
				#puts "new_entity : #{new_entity}"
				new_entity_layer_name = new_entity.layer.name.split('_IM_')[1]
				#puts "new_entity_layer_name : #{new_entity_layer_name}"
				next unless visible_layers.include?(new_entity_layer_name)

				visible_flag 	= true

				new_entity_front_bounds.each_index{ |index|
					pt1	 	= TT::Bounds.point(new_entity.bounds, new_entity_front_bounds[index])
					pt2	 	= TT::Bounds.point(new_entity.bounds, opposite_points[index])
					vector 	= pt1.vector_to pt2
					offset_pt = pt1.offset(vector, 0.5.mm)
					ray 	= [offset_pt , top_vector]
					hit_item = Sketchup.active_model.raytest(ray, true)
					# puts "hit_item : #{hit_item}"
					if hit_item
						# puts "hit_item : #{hit_item[1][0].persistent_id}"
						ray_hit_item = hit_item[1][0]
						ray_entities
						unless ray_entities.include?(ray_hit_item)
							visible_flag = false
						end
					else
						#puts "visibility failed"
						visible_flag = false
					end
				}
				# puts "visible_flag : #{visible_flag} : #{new_entity}"
				sel.add(new_entity) if visible_flag
				visible_flag = true if new_entity_layer_name=='SIDE_NORM'
				if visible_flag
					#new_entity.set_attribute(:rio_atts, 'outline_visible_flag', 'true')
					#new_entity.set_attribute(:rio_atts, 'inner_dimension_visible_flag', 'true')
					carcass_defn_entity = carcass_def.entities.select{|x| x.bounds.corner(0) == new_entity.bounds.corner(0)}[0]
					if carcass_defn_entity
						carcass_defn_entity.set_attribute(:rio_atts, 'top_outline_visible_flag', 'true')
						carcass_defn_entity.set_attribute(:rio_atts, 'top_inner_dimension_visible_flag', 'true')
					else
						puts "Definition entity corresponding to the instance could not be found : create_carcass_definition"
					end
				end
			}

			#--------------------Post operations-------------------------------------
			Sketchup.active_model.entities.erase_entities(new_entities)
            Sketchup.active_model.entities.erase_entities(top_raytest_face.edges)
			unhide_all_entities
			#abort('Aborted..............')
		end
	end

	def self.create_carcass_definition carcass_path='', shutter_path='', shutter_origin='0_0_0', left_internal='', right_internal='', center_internal=''
    # puts "create_carcass : #{carcass_path} : #{shutter_path} : #{shutter_origin}"
		model       = Sketchup.active_model

		if File.exists?(carcass_path)
			carcass_def = model.definitions.load(carcass_path)
			carcass_def.set_attribute(:rio_atts, 'comp_type', 'carcass')
			find_visible_entities_by_exploding carcass_def
			return carcass_def if shutter_path.empty?
		else
			UI.messagebox "Carcass file not found"
			return false
		end

		if File.exists?(shutter_path)
			shutter_def = model.definitions.load(shutter_path)
			shutter_def.set_attribute(:rio_atts, 'comp_type', 'shutter')
		else
			UI.messagebox "Shutter file not found"
			return false
		end

    bucket_name = 'rio-bucket-1'
    carcass_code= File.basename(carcass_path, '.skp') #.split('_')[0]
    shutter_code= File.basename(shutter_path, '.skp')
    defn_name   = carcass_code+'_'+shutter_code

    model       = Sketchup.active_model
    definitions = model.definitions
    defn        = definitions.add defn_name
        
    x_offset = 0
    y_offset = 0
    z_offset = 0
    if shutter_origin
      x_offset = shutter_origin.split('_')[0].to_f.mm
      z_offset = shutter_origin.split('_')[1].to_f.mm
    end
    trans       = Geom::Transformation.new([x_offset, 0, z_offset])
    shut_inst   = defn.entities.add_instance(shutter_def, trans)
        
		y_offset = shutter_origin.split('_')[2].to_f.mm
		if y_offset == 0
			y_offset    = shut_inst.bounds.height
		else
			y_offset 	= 0
		end
		
    #y_offset    = 23.mm
    shutter_height = y_offset
    #puts "#{x_offset} : #{y_offset} : #{z_offset}"
    trans       = Geom::Transformation.new([0,y_offset,0]) 
    ccass_inst  = defn.entities.add_instance(carcass_def, trans)
    ref_point   = ccass_inst.bounds.corner(6)
		defn.set_attribute(:rio_atts, 'shutter-code', shutter_code)
		
    unless left_internal.nil?
      x_offset    = 18
      y_offset    = -20
      z_offset    = -38

      code_split_arr = carcass_code.split('_')
      doors = code_split_arr[1].to_i
      door_width = code_split_arr[2]

			#-------------------------------------------------------------------------------------
			rhs_internal_skp    	= right_internal+'.skp'
			aws_internal_path    	= File.join('internal',rhs_internal_skp)
			local_internal_path  	= File.join(RIO_ROOT_PATH,'cache',rhs_internal_skp)
			unless File.exists?(local_internal_path)
				RioAwsDownload::download_file bucket_name, aws_internal_path, local_internal_path
			end
			rhs_def = model.definitions.load(local_internal_path)
			#-------------------------------------------------------------------------------------
			lhs_internal_skp        = left_internal+'.skp'
			aws_internal_path    	= File.join('internal',lhs_internal_skp)
			local_internal_path  	= File.join(RIO_ROOT_PATH,'cache',lhs_internal_skp)
			unless File.exists?(local_internal_path)
				RioAwsDownload::download_file bucket_name, aws_internal_path, local_internal_path
			end
			lhs_def = model.definitions.load(local_internal_path)
			
			#-------------------------------------------------------------------------------------
			if doors == 3
				center_internal_skp		= center_internal+'.skp'
				aws_internal_path    	= File.join('internal',center_internal_skp)
				local_internal_path  	= File.join(RIO_ROOT_PATH,'cache',center_internal_skp)
				unless File.exists?(local_internal_path)
					RioAwsDownload::download_file bucket_name, aws_internal_path, local_internal_path
				end
				center_def = model.definitions.load(local_internal_path)
				find_visible_entities_by_exploding center_def
				center_def.set_attribute(:rio_atts, 'center-internal-code', center_internal)
				center_def.set_attribute(:rio_atts, 'comp_type', 'center_internal')
			end
			find_visible_entities_by_exploding rhs_def
			find_visible_entities_by_exploding lhs_def

			rhs_def.set_attribute(:rio_atts, 'right-internal-code', left_internal)
			rhs_def.set_attribute(:rio_atts, 'comp_type', 'right_internal')
			lhs_def.set_attribute(:rio_atts, 'left-internal-code', right_internal)
			lhs_def.set_attribute(:rio_atts, 'comp_type', 'left_internal')
			
      es = Sketchup.active_model.entities
      #Just to get the width and height of the internals....Skip if necessary
      # inst        = es.add_instance lhs_def, ORIGIN
      lhs_height  = lhs_def.bounds.height
      # lhs_depth   = inst.bounds.depth
      # es.erase_entities inst

      #Get the reference point of the component
      pt      = Geom::Point3d.new(0, 0,   0)
      pt.y    = shutter_height 

      #res        = defn.entities.add_instance carcass_def, pt
      #ref_point  = res.bounds.corner(6)

      ply_width   = 18.mm
      door_width  = door_width.to_i.mm

			#puts "rhs_def : "+rhs_def.name
			inst_depth 		= rhs_def.bounds.depth
      trans_internal  = Geom::Transformation.new([ref_point.x+18.mm, ref_point.y-lhs_height-20.mm, ref_point.z-inst_depth-38.mm])
      res             = defn.entities.add_instance rhs_def, trans_internal

      if doors == 2
				x_next_offset 	= (door_width + (ply_width/2))
				inst_depth 		= lhs_def.bounds.depth
				inst_height		= lhs_def.bounds.height
        trans_internal 	= Geom::Transformation.new([ref_point.x+x_next_offset, ref_point.y-lhs_height-20.mm, ref_point.z-inst_depth-38.mm])
        res = defn.entities.add_instance lhs_def, trans_internal
      else
				x_next_offset   = (door_width + ply_width)
				inst_depth 		= center_def.bounds.depth
				inst_height		= lhs_def.bounds.height
        trans_internal  = Geom::Transformation.new([ref_point.x+x_next_offset, ref_point.y-inst_height-20.mm, ref_point.z-inst_depth-38.mm])
        res             = defn.entities.add_instance center_def, trans_internal
                
				x_next_offset   = 2*door_width + ply_width
				inst_depth 		= lhs_def.bounds.depth
				inst_height		= lhs_def.bounds.height
        trans_internal  = Geom::Transformation.new([ref_point.x+(x_next_offset), ref_point.y-inst_height-20.mm, ref_point.z-inst_depth-38.mm])
        res             = defn.entities.add_instance lhs_def, trans_internal
			end
			
			defn.set_attribute(:rio_atts, 'right-internal-code', left_internal)
			defn.set_attribute(:rio_atts, 'left-internal-code', right_internal)
			defn.set_attribute(:rio_atts, 'center_inter_code', center_internal) if center_def
        end
        defn
    end

	def self.find_adjacent_comps comps, comp
		adj_comps 	= []
		return adj_comps if comp.nil?
		return adj_comps if comps.empty?
		comps.each { |item|
			xn = comp.bounds.intersect item.bounds
			if ((xn.width + xn.depth + xn.height) != 0)
				adj_comps << item
			end
		}
		adj_comps
	end
	
	def self.get_visible_sides comp
		comps 					= Sketchup.active_model.entities.grep(Sketchup::ComponentInstance)
		#room_comp 		= comps.select{|x| x.definition.name=='room_bounds'}
		#comps 					= comps - room_comp
	
		adj_comps	= DP::find_adjacent_comps comps-[comp], comp;
		room_name 	= comp.get_attribute :rio_atts, 'space_name'
		walls 		= get_walls room_name
		walls.each{ |wall|
			xn 		= comp.bounds.intersect wall.bounds
			adj_comps<<wall if xn.valid?
		}
		adj_comps.flatten!


		rotz 		= comp.transformation.rotz
		left_view	= true
		right_view	= true
		top_view	= true
	
		comp_pts 	= []
		(0..7).each{|x| comp_pts << comp.bounds.corner(x).to_s}
		case rotz
		when 0
			right_pts 	= [comp_pts[0],	comp_pts[2], comp_pts[4], comp_pts[6]]
			left_pts	= [comp_pts[1],	comp_pts[3], comp_pts[5], comp_pts[7]]
			top_pts		= [comp_pts[4],	comp_pts[5], comp_pts[6], comp_pts[7]]
			adj_comps.each{|item|
				# Sketchup.active_model.selection.add(item)
				xn 		= comp.bounds.intersect item.bounds
				xn_pts 	= [];(0..7).each{|x| xn_pts<<xn.corner(x).to_s}	
	
				right_view	= false if (xn_pts&right_pts).length > 2
				left_view	= false if (xn_pts&left_pts).length > 2
				top_view 	= false if (xn_pts&top_pts).length > 2
			}
		when 90
			right_pts 	= [comp_pts[0],comp_pts[1],comp_pts[4],comp_pts[5]]
			left_pts	= [comp_pts[2],comp_pts[3],comp_pts[6],comp_pts[7]]
			top_pts		= [comp_pts[4],	comp_pts[5], comp_pts[6], comp_pts[7]]
			adj_comps.each{|item|
				# Sketchup.active_model.selection.add(item)
				xn 		= comp.bounds.intersect item.bounds
				xn_pts 	= [];(0..7).each{|x| xn_pts<<xn.corner(x).to_s}	
	
				right_view	= false if (xn_pts&right_pts).length > 2
				left_view	= false if (xn_pts&left_pts).length > 2
				top_view 	= false if (xn_pts&top_pts).length > 2
			}
		when 180, -180
			left_pts 	= [comp_pts[0],comp_pts[2],comp_pts[4],comp_pts[6]]
			right_pts	= [comp_pts[1],comp_pts[3],comp_pts[5],comp_pts[7]]
			top_pts		= [comp_pts[4],	comp_pts[5], comp_pts[6], comp_pts[7]]
			adj_comps.each{|item|
				# Sketchup.active_model.selection.add(item)
				xn 		= comp.bounds.intersect item.bounds
				xn_pts 	= [];(0..7).each{|x| xn_pts<<xn.corner(x).to_s}
				
				right_view	= false if (xn_pts&right_pts).length > 2
				left_view	= false if (xn_pts&left_pts).length > 2
				top_view 	= false if (xn_pts&top_pts).length > 2
			}
		when -90
			left_pts 	= [comp_pts[0],comp_pts[1],comp_pts[4],comp_pts[5]]
			right_pts	= [comp_pts[2],comp_pts[3],comp_pts[6],comp_pts[7]]
			top_pts		= [comp_pts[4],	comp_pts[5], comp_pts[6], comp_pts[7]]
			adj_comps.each{|item|
				# Sketchup.active_model.selection.add(item)
				xn 		= comp.bounds.intersect item.bounds
				xn_pts 	= [];(0..7).each{|x| xn_pts<<xn.corner(x).to_s}
				
				right_view	= false if (xn_pts&right_pts).length > 2
				left_view	= false if (xn_pts&left_pts).length > 2
				top_view 	= false if (xn_pts&top_pts).length > 2
			}
		end	
		comp_origin = comp.transformation.origin
		top_view = false if comp_origin.z > 1500.mm
		#Check the number of booleans set
		view_count=(right_view&&0||1)+(left_view&&0||1)+(top_view&&0||1)
		# puts "view :",view_count+1
		if Sketchup.active_model.selection.length != view_count+1
			puts "The components selected might be adjacent but dont cover the selected component full"
		end
		
		# puts "Visible views"
		#  puts "left_view : #{left_view}"
		# puts "right_view : #{right_view}"
		# puts "Top View : #{top_view}"
		return [left_view, right_view, top_view]
	end

	def self.get_walls room_name
		#walls = Sketchup.active_model.entities.grep(Sketchup::Group).select{|x| x.get_attribute(:rio_atts, 'position').nil? == false}
		walls = Sketchup.active_model.entities.select{|ent| ent.layer.name == 'DP_Wall_'+room_name}
		walls
	end

	def self.get_fillers view
		ents 		= Sketchup.active_model.entities
		comp_arr 	= []
		ents.each{|ent|
			pers_id 	= ent.get_attribute(:rio_atts, 'associated_comp')
			if pers_id
				comp = get_comp_pid pers_id
				next if comp_id.nil?
				rotz = comp.transformation.rotz
				case view
				when 'left'
					#comp_arr << 
				when 'right'
				when 'front'
				when 'back'
				end
			end
		}
	end

	def self.add_custom_comps view
		get_walls 
		get_intersect_area
	end
	
	def self.get_face_views_ents new_ents
		faces 	= new_ents.grep(Sketchup::Face)
		
		xvector = Geom::Vector3d.new(1,0,0)
		yvector = Geom::Vector3d.new(0,1,0)
		zvector = Geom::Vector3d.new(0,0,1) 
		
		zfaces = faces.select{|face| face.normal==zvector || face.normal==zvector.reverse}
		zfaces.sort_by!{|x| -x.bounds.corner(0).z}
		
		straight_faces = faces.select{|face| face.normal==yvector || face.normal==yvector.reverse}
		straight_faces.sort_by!{|x| x.bounds.corner(0).y}
		
		side_faces = faces.select{|face| face.normal==xvector || face.normal==xvector.reverse}
		side_faces.sort_by!{|x| x.bounds.corner(0).x}
		
		return [zfaces[0], zfaces[1], straight_faces[0], side_faces[0], straight_faces[1], side_faces[1]]
	end

	def self.update_laminate_axes comp, actual_rotz=0
		# puts "update_laminate_axes : #{comp} : #{actual_rotz}"
		mod 	= Sketchup.active_model # Open model
		ents 	= mod.entities # All entities in model
		origin 	= Geom::Point3d.new(0, 0, 0)
		z 		= Geom::Vector3d.new(0, 0, 1)
		
		#comp=fsel
		trans 	= comp.transformation# if trans.nil?
		comp_origin = trans.origin
		
		x_offset = 0
		y_offset = 0
		
			
		prev_ents	=[];
		Sketchup.active_model.entities.each{|ent| prev_ents << ent}
	
		inst = comp
		
		case actual_rotz
		when 90
			angle = 90.degrees
			new_trans 	= Geom::Transformation.new([comp.bounds.width, 0, 0])
			#comp = fsel
			
			trans 		= comp.transformation
			comp_origin = trans.origin
	
			origin 	= Geom::Point3d.new(0, 0, 0)
			x 		= Geom::Vector3d.new(0, -1, 0)
			y 		= Geom::Vector3d.new(1, 0, 0)
			z 		= Geom::Vector3d.new(0, 0, 1)
			
			
			
			xoffset		= comp_origin.y - comp.bounds.corner(1).y
			yoffset		= comp_origin.x - comp.bounds.corner(1).x
			new_pt 		= Geom::Point3d.new(yoffset, xoffset, 0)
			
			gp 			= ents.add_group()
			inst 		= gp.entities.add_instance(comp.definition, Geom::Transformation.new(new_pt))
			
			t2          = Geom::Transformation.axes(origin, x, y, z)
			inst.transform!(t2)
		when -90
			angle 	= -90.degrees
			new_trans 	= Geom::Transformation.new([0, -comp.bounds.width, 0])
			origin = Geom::Point3d.new(0, 0, 0)
			x = Geom::Vector3d.new(0, 1, 0)
			y = Geom::Vector3d.new(1, 0, 0)
			z = Geom::Vector3d.new(0, 0, 1)
			
			new_trans 	= Geom::Transformation.new([0, comp.bounds.height, 0])
			xoffset		= comp_origin.y - comp.bounds.corner(0).y
			yoffset		= comp_origin.x - comp.bounds.corner(0).x
			new_pt 		= Geom::Point3d.new(yoffset, xoffset, 0)
			
			prev_ents	=[];
			Sketchup.active_model.entities.each{|ent| prev_ents << ent}
	
			#For lamination components
			# puts new_pt
			gp 			= ents.add_group()
			inst 		= gp.entities.add_instance(comp.definition, Geom::Transformation.new(new_pt))
			
			t2          = Geom::Transformation.axes(origin, x, y, z)
			inst.transform!(t2)
		when 180, -180
			new_trans 	= Geom::Transformation.new([0, -comp.bounds.height, 0])
			#comp = fsel
	
			trans     = comp.transformation
			comp_origin = trans.origin
	
			origin = Geom::Point3d.new(0, 0, 0)
			x = Geom::Vector3d.new(0, 1, 0)
			y = Geom::Vector3d.new(-1, 0, 0)
			z = Geom::Vector3d.new(0, 0, 1)
	
			new_trans 	= Geom::Transformation.new([comp.bounds.width, comp.bounds.height, 0])
				
			xoffset        = comp_origin.y - comp.bounds.corner(3).y
			yoffset        = comp_origin.x - comp.bounds.corner(3).x
			new_pt         = Geom::Point3d.new(yoffset, xoffset, 0)
	
			gp             = ents.add_group()
			inst         = gp.entities.add_instance(comp.definition, Geom::Transformation.new(new_pt))
	
			t2          = Geom::Transformation.axes(origin, x, y, z)
			inst.transform!(t2)
	
			t2          = Geom::Transformation.axes(origin, x, y, z)
			inst.transform!(t2)
			angle 	= 180.degrees
		end
	
		inst.explode
		# puts "Exploded.."
		
		post_ents 	= [];
		Sketchup.active_model.entities.each{|ent| post_ents << ent}
	
		new_ent 	= post_ents - prev_ents
		comp_inst 	= new_ent[0].to_component
		
		vector 		= Geom::Vector3d.new(0,0,1)
	
		
	
		transformation = Geom::Transformation.rotation(comp_origin, vector, angle)
		#comp_inst.transform!(transformation)
		#comp.inst.rotate
		
		comp_inst.transform!(trans)
		transformation = Geom::Transformation.rotation(comp_inst.transformation.origin, vector, angle)
		comp_inst.transform!(transformation)
		comp_inst.transform!(new_trans)
		
		#------------Dictionaries set
		if comp.attribute_dictionaries
			comp.attribute_dictionaries.each{|dict|
				dict.each_pair {|key,val| 
					#puts "comp_group : #{key} : #{val} : #{dict_name}"
					comp_inst.set_attribute dict.name, key, val 
				}
			}
		end
		if comp.definition.attribute_dictionaries
			comp.definition.attribute_dictionaries.each{|dict|
				dict.each_pair {|key,val| 
					#puts "comp_group : #{key} : #{val} : #{dict_name}"
					comp_inst.definition.set_attribute dict.name, key, val 
				}
			}
		end
		
		
		Sketchup.active_model.entities.erase_entities(comp)
		comp_inst
	end

	def self.fdefn_dict comp
        return false if comp.nil?

        if comp.attribute_dictionaries
            comp.attribute_dictionaries.each { |dict|
                # puts "Dictionary : #{dict.name}"
                dict.each_pair{ |key, value|
                    # puts "#{key} : #{value}"
                }
            }
        end
        if comp.definition.attribute_dictionaries
            comp.definition.attribute_dictionaries.each { |dict|
                # puts "Dictionary : #{dict.name}"
                dict.each_pair{ |key, value|
                    # puts "#{key} : #{value}"
                }
            }
        end
    end

    def self.get_comp_def_entities comp
        entities_hash 	= {}
        internal_arr    = []
        carcass_ent     = nil
        shutter_ent     = nil
        comp.definition.entities.each{|ent|
            defn_type = ent.definition.get_attribute(:rio_atts, 'comp_type')
            next if defn_type.nil?
            case defn_type
            when 'carcass'
                carcass_ent = ent
            when 'shutter'
                shutter_ent = ent
            end
            if defn_type.end_with?('internal')
                internal_arr << ent
            end
        }
        entities_hash['carcass']    = carcass_ent
        entities_hash['shutter']    = shutter_ent
        entities_hash['internal']   = internal_arr
        entities_hash
    end

    def self.get_internal_entities comp
        visible_layers      = ['SHELF_FIX', 'SHELF_INT', 'DRAWER_FRONT', 'DRAWER_INT', 'SIDE_NORM']
        dimension_entities  = []
        comp.definition.entities.each{|shelf_ent|
            visible_flag        = false
            shelf_layer_name    = shelf_ent.layer.name.split('_IM_')[1]
            # puts "shelf_layer_name : #{shelf_layer_name}"
            if visible_layers.include?(shelf_layer_name)
                visible_flag = true
            end
            dimension_entities << shelf_ent  if visible_flag
        }
        dimension_entities
    end

	def self.add_filler_laminate comp, filler
		image_path = comp.get_attribute :carcase_spec, 'front_lam_value'
		# puts "add_filler_laminate : #{image_path}"
		return false if image_path.nil?
		# puts "add_filler_laminate : #{image_path}"
		rotz		= comp.transformation.rotz
		filler_ents 	= filler.definition.entities
		ents_faces 		= get_face_views_ents filler_ents
		
		top_face 	= ents_faces[0]
		
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
		if image_path.include?('#') == true
			material.color = image_path
		else
			material.texture = RIO_ROOT_PATH+'/materials/'+image_path
		end
		
		#top_face.material 		= material
		#top_face.back_material 	= material
		
		side_face.material 		= material
		side_face.back_material = material
		filler.set_attribute(:rio_atts, 'front_lam_value', image_path)
		
	end

	def self.add_filler comp, distance, side
		# puts "add_filler : #{side} : #{distance}"
		rotz	= comp.transformation.rotz

        carcass_comp        = comp.definition.entities.select{|ent| ent.definition.get_attribute(:rio_atts, 'comp_type')=='carcass'}[0]
        carcass_comp_bbox   = carcass_comp.bounds

        case rotz
        when 0
            if side == 'right'
                pts = [1,3, 7,5]
            elsif side == 'left'
                pts = [0, 2, 6, 4]
                distance = -distance
            end
        when 90
            if side == 'right'
                pts = [2, 3, 7, 6]
            elsif side == 'left'
                pts = [0, 1, 5, 4]
                distance = -distance
            end
        when -90
            if side == 'right'
                pts = [0, 1, 5, 4]
            elsif side == 'left'
                pts = [2, 3, 7, 6]
                distance = -distance
            end
        when 180, -180
            if side == 'right'
                pts = [0, 2, 6, 4]
                distance = -distance
            elsif side == 'left'
                pts = [1, 3, 7, 5]
            end
        end

        new_pts = []
        pts.each{|index|
            new_trans   = comp.transformation * Geom::Transformation.new(TT::Bounds.point(carcass_comp_bbox, index))
            new_pts     << new_trans.origin
        }
		prev_ents = [];Sketchup.active_model.entities.grep(Sketchup::Face).each{|ent| prev_ents<<ent}

		filler_face 		= Sketchup.active_model.entities.add_face new_pts
		filler_face.pushpull distance

		curr_ents = [];Sketchup.active_model.entities.grep(Sketchup::Face).each{|ent| curr_ents<<ent}

		new_ents = curr_ents - prev_ents
		new_ents<<filler_face
		
		if new_ents.empty?
			return nil
		else
			new_ents.flatten!
			new_ents.uniq!
		end
		
		filler_group 		= Sketchup.active_model.entities.add_group(new_ents)

		#filler_group 		= Sketchup.active_model.entities.add_group(filler_face.all_connected)
		filler_inst = filler_group.to_component #Change in MRP get_room_view_components
		
		#filler_inst = filler_group
		
		
		filler_inst.layer = Sketchup.active_model.layers['DP_Cust_Comp_layer']
		filler_inst.set_attribute(:rio_atts, 'custom_type', 'filler')
		filler_inst.set_attribute(:rio_atts, 'rio_comp', 'filler')
		pers_id 			= comp.persistent_id
		filler_inst.set_attribute(:rio_atts, 'associated_comp', pers_id)

		room_name = comp.get_attribute :rio_atts, 'space_name'
		filler_inst.set_attribute(:rio_atts, 'space_name', room_name)

		filler_inst.set_attribute(:rio_atts, 'filler_rotz', rotz)
		filler_inst = DP::update_laminate_axes filler_inst, rotz if rotz!=0
		
		filler_name = 'filler_'+side
		comp.set_attribute(:rio_atts, filler_name, filler_inst.persistent_id)

		#Auto add skirting for filler if comp has skirting 
		if comp.get_attribute(:rio_atts, 'skirting')
			add_filler_skirting filler_inst
		end

		return filler_inst
		
		
		
		
	end

	def self.check_filler comp
		model 	= Sketchup.active_model
		room_name = comp.get_attribute :rio_atts, 'space_name'
		room_hide = hide_other_room_walls comp

        if room_name.nil?
            UI.messagebox 'Component attributes are not proper. Please run scan components for this room in utilities.'
            return
        end
		walls 	= DP::get_walls room_name
		rotz	= comp.transformation.rotz
		min_distance 	= 39.mm
		max_distance	= 101.mm
		case rotz
		when 0
			left_index 	= 20
			right_index = 21
			left_vector 		= Geom::Vector3d.new(-1,0,0) 
			right_vector 		= Geom::Vector3d.new(1,0,0) 
		when 90
			left_index 	= 22
			right_index = 23
			left_vector 		= Geom::Vector3d.new(0,-1,0) 
			right_vector 		= Geom::Vector3d.new(0,1,0) 
		when -90
			left_index 	= 23
			right_index = 22
			left_vector 		= Geom::Vector3d.new(0,1,0) 
			right_vector 		= Geom::Vector3d.new(0,-1,0)
		when 180, -180
			left_index 	= 21
			right_index = 20
			left_vector 		= Geom::Vector3d.new(1,0,0) 
			right_vector 		= Geom::Vector3d.new(-1,0,0) 
		end

		
		#Check for wall on the left side....................
		#puts "Checking filler for the left side"
		left_point  = TT::Bounds.point(comp.bounds, left_index)
		left_ray	= [left_point, left_vector]
		# puts left_ray
		hit_array	= model.raytest(left_ray)
		if hit_array
			hit_point	= hit_array[0]
			hit_item 	= hit_array[1][0]
			distance 	= left_point.distance hit_point
		end

		if walls.include?(hit_item)
			if distance > min_distance && distance < max_distance
				filler_inst = add_filler comp, distance, 'left'
				add_filler_laminate comp, filler_inst
				#return true
			else 
				if distance < min_distance
					UI::messagebox("Left : Filler Wall is less than 40 mm")
				elsif distance > max_distance
					if distance > 100.mm
						UI::messagebox("Left : Filler Wall is at a distance greater than 100 mm")
					end
				end
			end
		else
			UI::messagebox("Left :No Wall nearby - 40mm to 100mm distance")
			#return false
		end

		#Check for wall on the right side....................
		# puts "Checking filler for the right side"
		right_point  = TT::Bounds.point(comp.bounds, right_index)
		right_ray	= [right_point, right_vector]
		hit_array	= model.raytest(right_ray)
		if hit_array
			hit_point	= hit_array[0]
			hit_item 	= hit_array[1][0]
			distance 	= right_point.distance hit_point
		end

		if walls.include?(hit_item)
			if distance > min_distance && distance < max_distance
				filler_inst = add_filler comp, distance, 'right'
				add_filler_laminate comp, filler_inst
			else
				if distance < min_distance
					UI::messagebox("Right : Filler Wall is less than 40 mm")
				elsif distance > max_distance
					UI::messagebox("Right : Filler Wall is at a distance greater than 100 mm")
				end
			end
		else
			UI::messagebox("Right : No Wall nearby - 40mm to 100mm distance")
			#return false
		end
	end
	
	def self.add_filler_skirting comp
		comp_trans 	= comp.transformation
		rotz 		= comp_trans.rotz 
		
		origin		= comp_trans.origin
		bbox		= comp.bounds
		case rotz
		when 0
			pt1 = origin
			pt2 = pt1.offset(Geom::Vector3d.new(0,1,0), 	18.mm)
			pt3	= pt2.offset(Geom::Vector3d.new(1,0,0), 	bbox.width)
			pt4 = pt1.offset(Geom::Vector3d.new(1,0,0), 	bbox.width)
		when 90
			pt1	= comp.transformation.origin;pt1.x-=carcass_origin.y;pt1.y-=carcass_origin.x;
			pt2 = pt1.offset(Geom::Vector3d.new(-1,0,0), 	18.mm)
			pt3	= pt2.offset(Geom::Vector3d.new(0,1,0), 	bbox.width)
			pt4 = pt1.offset(Geom::Vector3d.new(0,1,0), 	bbox.width)
		when -90
			pt1	= comp.transformation.origin;pt1.x+=carcass_origin.y;pt1.y+=carcass_origin.x;
			pt2 = pt1.offset(Geom::Vector3d.new(1,0,0), 	18.mm)
			pt3	= pt2.offset(Geom::Vector3d.new(0,-1,0), 	bbox.width)
			pt4 = pt1.offset(Geom::Vector3d.new(0,-1,0), 	bbox.width)
		when 180, -180
			pt1 = comp.transformation.origin;pt1.x-=carcass_origin.x;pt1.y-=carcass_origin.y;
			pt2 = pt1.offset(Geom::Vector3d.new(0,-1,0), 	18.mm)
			pt3	= pt2.offset(Geom::Vector3d.new(-1,0,0), 	bbox.width)
			pt4 = pt1.offset(Geom::Vector3d.new(-1,0,0), 	bbox.width)
		end
		
		prev_ents	=[];
		Sketchup.active_model.entities.each{|ent| prev_ents << ent}
		
		skirting_face = Sketchup.active_model.entities.add_face([pt1,pt2,pt3,pt4])
		skirting_face.pushpull 100.mm
		
		post_ents 	= [];
		Sketchup.active_model.entities.each{|ent| post_ents << ent}
	
		new_ents = post_ents - prev_ents
		new_ents<<skirting_face
		
		skirting_group 		= Sketchup.active_model.entities.add_group(new_ents)

		#filler_group 		= Sketchup.active_model.entities.add_group(filler_face.all_connected)
		skirting_inst 		= skirting_group.to_component #Change in MRP get_room_view_components
		
		skirting_inst.layer = Sketchup.active_model.layers['DP_Cust_Comp_layer']
		skirting_inst.set_attribute(:rio_atts, 'custom_type', 'skirting')
		pers_id 			= comp.persistent_id
		skirting_inst.set_attribute(:rio_atts, 'associated_comp', pers_id)

		room_name = comp.get_attribute :rio_atts, 'space_name'
		skirting_inst.set_attribute(:rio_atts, 'space_name', room_name)

		skirting_inst.set_attribute(:rio_atts, 'filler_rotz', rotz)
		#skirting_inst = DP::update_laminate_axes skirting_inst, rotz if rotz!=0
		
		comp.set_attribute(:rio_atts, 'skirting', skirting_inst.persistent_id)
	end

	def self.add_skirting comp
		comp_trans = comp.transformation
		rotz = comp_trans.rotz 
		carcass_code = comp.get_attribute :rio_atts, 'carcass-code'
		carcass_comp = comp.definition.entities.select{|x| x.definition.name.start_with?(carcass_code)}[0]
		
		prev_ents	=[];
		Sketchup.active_model.entities.each{|ent| prev_ents << ent}
	
		carcass_origin = carcass_comp.transformation.origin
		bbox = carcass_comp.bounds
		
		new_trans = carcass_comp.transformation * comp.transformation
		origin = new_trans.origin
		# puts "origin : #{origin}"

		case rotz
		when 0
			pt1 = origin
			pt2 = pt1.offset(Geom::Vector3d.new(0,1,0), 	18.mm)
			pt3	= pt2.offset(Geom::Vector3d.new(1,0,0), 	bbox.width)
			pt4 = pt1.offset(Geom::Vector3d.new(1,0,0), 	bbox.width)
		when 90
			pt1	= comp.transformation.origin;pt1.x-=carcass_origin.y;pt1.y-=carcass_origin.x;
			pt2 = pt1.offset(Geom::Vector3d.new(-1,0,0), 	18.mm)
			pt3	= pt2.offset(Geom::Vector3d.new(0,1,0), 	bbox.width)
			pt4 = pt1.offset(Geom::Vector3d.new(0,1,0), 	bbox.width)
		when -90
			pt1	= comp.transformation.origin;pt1.x+=carcass_origin.y;pt1.y+=carcass_origin.x;
			pt2 = pt1.offset(Geom::Vector3d.new(1,0,0), 	18.mm)
			pt3	= pt2.offset(Geom::Vector3d.new(0,-1,0), 	bbox.width)
			pt4 = pt1.offset(Geom::Vector3d.new(0,-1,0), 	bbox.width)
		when 180, -180
			pt1 = comp.transformation.origin;pt1.x-=carcass_origin.x;pt1.y-=carcass_origin.y;
			pt2 = pt1.offset(Geom::Vector3d.new(0,-1,0), 	18.mm)
			pt3	= pt2.offset(Geom::Vector3d.new(-1,0,0), 	bbox.width)
			pt4 = pt1.offset(Geom::Vector3d.new(-1,0,0), 	bbox.width)
		end
		
		filler_left 	= comp.get_attribute(:rio_atts, 'filler_left')
		filler_right 	= comp.get_attribute(:rio_atts, 'filler_right')
		
		if filler_left  
			filler_comp = DP::get_comp_pid filler_left.to_i
			if !filler_comp.nil?
				DP::add_filler_skirting filler_comp if !filler_comp.deleted?
			end
		end
		if filler_right
			filler_comp = DP::get_comp_pid filler_right.to_i
			if filler_comp.nil?
				DP::add_filler_skirting filler_comp if !filler_comp.deleted?
			end
		end
		
		# puts pt1,pt2,pt3,pt4
		skirting_face = Sketchup.active_model.entities.add_face([pt1,pt2,pt3,pt4])
		skirting_face.pushpull 100.mm
		
		post_ents 	= [];
		Sketchup.active_model.entities.each{|ent| post_ents << ent}
	
		new_ents = post_ents - prev_ents
		new_ents<<skirting_face
		
		if new_ents.empty?
			return nil
		else
			new_ents.flatten!
			new_ents.uniq!
			new_ents.select!{|x| x.is_a?(Sketchup::Face)}
			new_ents.select!{|x| !x.deleted?}
		end
		
		skirting_group 		= Sketchup.active_model.entities.add_group(new_ents)

		#filler_group 		= Sketchup.active_model.entities.add_group(filler_face.all_connected)
		skirting_inst 		= skirting_group.to_component #Change in MRP get_room_view_components
		
		skirting_inst.layer = Sketchup.active_model.layers['DP_Cust_Comp_layer']
		skirting_inst.set_attribute(:rio_atts, 'custom_type', 'skirting')
		pers_id 			= comp.persistent_id
		skirting_inst.set_attribute(:rio_atts, 'associated_comp', pers_id)

		room_name = comp.get_attribute :rio_atts, 'space_name'
		skirting_inst.set_attribute(:rio_atts, 'space_name', room_name)

		skirting_inst.set_attribute(:rio_atts, 'filler_rotz', rotz)
		#skirting_inst = DP::update_laminate_axes skirting_inst, rotz if rotz!=0
		
		comp.set_attribute(:rio_atts, 'skirting', skirting_inst.persistent_id)
		return skirting_inst
	end

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

	def self.get_space_names
		if V2_V3_CONVERSION_FLAG
			return RIO::CivilHelper::get_room_names
		end
		spaces = Sketchup.active_model.entities.grep(Sketchup::Group).select{|gp| (gp.get_attribute :rio_atts, 'space_name') != nil}
		space_names = []
		spaces.each{|space| space_names << space.get_attribute(:rio_atts, 'space_name')}
		space_names.uniq!
		space_names
	end

	def self.check_comp_floor_overlap(comp, room_name)
		
		floor_gp 		= Sketchup.active_model.entities.select{|ent| ent.layer.name == 'DP_Floor_'+room_name.to_s}[0]
		floor_origin 	= floor_gp.transformation.origin

		comp_origin 	= comp.transformation.origin

		z_offset 	= 0
		if comp_origin.z < floor_origin.z
			res = DP::get_intersect_area comp, floor_gp
			if res[0] != false
				z_offset = floor_origin.z - comp_origin.z
				puts "Component below the floor and intersect the floor"
			else
				puts "Component below the room"
			end
			return true
		end
		return false
	end

	def self.check_comp_ceiling_overlap(comp, room_name)
		floor_gp 		= Sketchup.active_model.entities.select{|ent| ent.layer.name == 'DP_Floor_'+room_name.to_s}[0]
		floor_origin 	= floor_gp.transformation.origin
		wall_height 	= floor_gp.get_attribute(:rio_atts, 'wall_height').to_i.mm

		comp_origin 	= comp.transformation.origin

		component_top_end 	= comp_origin.z + comp.bounds.depth
		room_top_end		= floor_origin.z + wall_height
		if comp_origin.z > room_top_end
			puts "Component above ceiling"
			return true
		elsif component_top_end > room_top_end
			z_offset = room_top_end - component_top_end
			puts "Component intersects ceiling"
			return true
		end
		return false
	end

	#Before lamination run check this 
	def self.check_comp_overlap comp, room_name
		room_comps = MRP::get_room_components room_name
		other_comps = room_comps - [comp]
		other_comps.each{ |o_comp|
			res = DP::get_intersect_area comp, o_comp
			if res[0]=='volume'	
				Sketchup.active_model.selection.clear
				Sketchup.active_model.selection.add comp
				Sketchup.active_model.selection.add o_comp
				return true 
			end
		}
		return false
	end

	def self.manual_check_comp_overlap room_name
		room_comps = MRP::get_room_components room_name
		$lastcomp = room_comps.last
		other_comps = room_comps - [$lastcomp]
		other_comps.each {|ocomp|
			res = DP::get_intersect_area $lastcomp, ocomp
			if res[0] == 'volume'
				rmcomp = remove_overlap_comp $lastcomp
				#Sketchup.active_model.selection.clear
				#Sketchup.active_model.selection.add $lastcomp
				#Sketchup.active_model.selection.add ocomp
				#UI.messagebox "Component Overlaps with another component. Removing the new instance.", MB_OK
				#Sketchup.active_model.entities.erase_entities $lastcomp
				# puts "rmcomp----#{rmcomp}"
				return true
			end
		}
		return false
	end

	def self.remove_overlap_comp comp
		UI.messagebox "Component Overlaps with another component. Removing the new instance.", MB_OK
		Sketchup.active_model.entities.erase_entities comp
		return true
	end

	#Before working drawing check this......
	#Add this to utilities too.....
	def self.check_room_overlap room_name
		room_comps 		= MRP::get_room_components room_name
		no_overlaps 	= true
		room_comps.each {|comp|
			res = check_comp_overlap comp, room_name
			return false unless res
		}
		return true
	end

	def self.check_wall_overlap comp, room_name
		walls 		= DP::get_walls room_name

		walls.each {|wall|
			res = get_intersect_area comp, wall
			return true if res[0] == 'volume'
		}
		return false
	end

	def self.delete_room room_name
		puts "Deleting room"
		floor_layer_name = 'DP_Floor_'+room_name
		wall_layer_name = 'DP_Wall_'+room_name
	
		room_ents 		= Sketchup.active_model.entities.select{|ent| ent.layer.name==floor_layer_name} 
		room_ents 		<< Sketchup.active_model.entities.select{|ent| ent.layer.name==wall_layer_name}
		room_ents.flatten!
		Sketchup.active_model.entities.erase_entities room_ents
	
		Sketchup.active_model.layers.remove floor_layer_name
		Sketchup.active_model.layers.remove wall_layer_name

		wall_ents = Sketchup.active_model.entities.grep(Sketchup::Edge).select{|edge| edge.layer.name=='Wall'}
		wall_ents.each{|ent| ent.find_faces}
		true
	end

	def self.update_all_room_components 
		room_names 	= DP::get_space_names
		rio_comps 	= Sketchup.active_model.entities.select{|comp| !comp.get_attribute(:rio_atts, 'rio_comp').nil?}
		zvector		= Geom::Vector3d.new(0, 0, 1)

		visible_comps = []
		Sketchup.active_model.entities.each{|x| visible_comps<<x if x.visible? ==true}

		rio_comps.each{|comp| comp.set_attribute :rio_atts, 'room_scanned', 'false'}
		room_names.each { |room_name|
			floor_face 	= MRP::get_room_face room_name
			
			floor_gp 		= Sketchup.active_model.entities.select{|ent| ent.layer.name == 'DP_Floor_'+room_name.to_s}[0]
			floor_origin 	= floor_gp.transformation.origin
			
			room_face_pts = []
			floor_face.outer_loop.vertices.each{|vert|
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
			
			inside_comps = []
			rio_comps.each{ |comp|
				inside = true
				
				#---------------------Test 1-------------------------------
				comp.visible = true
				[4, 5, 6, 7].each{|index|
					ray = [comp.bounds.corner(index), zvector]
					hit_item 	= Sketchup.active_model.raytest(ray, true)
					if hit_item && hit_ents.include?(hit_item[1][0])
					
					else
						sel.add(hit_item[1][0]) if hit_item
						inside = false
					end
				}
				comp.visible = false
				
				if inside
					comp.set_attribute :rio_atts, 'space_name', room_name
					comp.set_attribute :rio_atts, 'room_scanned', 'true'
					inside_comps << comp
				end
			}
			inside_comps.each{ |x| rio_comps.delete(x)}

			Sketchup::active_model.entities.erase_entities hit_face.edges
		}
		rio_comps 	= Sketchup.active_model.entities.select{|comp| !comp.get_attribute(:rio_atts, 'rio_comp').nil?}
		
		#For component to which we cant find the boundaries.
		unknown_bounds_comps = rio_comps.select{ |comp| comp.get_attribute(:rio_atts, 'room_scanned')!='true'}
		unknown_bounds_comps.each{|comp| comp.set_attribute(:rio_atts, 'space_name', 'unknown')}

		visible_comps.each{|x| x.visible=true if !x.deleted?}
	end

	def self.update_entity_bounds comp
		room_names 	= DP::get_space_names
		
		rio_comps 	= Sketchup.active_model.entities.select{|comp| !comp.get_attribute(:rio_atts, 'rio_comp').nil?}
		zvector		= Geom::Vector3d.new(0, 0, 1)

		visible_comps = []
		Sketchup.active_model.entities.each{|x| visible_comps<<x if x.visible? ==true}

		rio_comps.each{|comp| comp.set_attribute :rio_atts, 'room_scanned', 'false'}
		
		comp_room_found_flag = false
		room_names.each { |room_name|
			floor_face 	= MRP::get_room_face room_name
			
			floor_gp 		= Sketchup.active_model.entities.select{|ent| ent.layer.name == 'DP_Floor_'+room_name.to_s}[0]
			floor_origin 	= floor_gp.transformation.origin
			
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
			
			#puts "rio_comps : #{rio_comps}"
			inside = true
			
			#---------------------Test 1-------------------------------
			#First test to check component within the 2d floor face....
			#raytest with the face created similar to floor face
			comp.visible = true
			[4, 5, 6, 7].each{|index|
				ray = [comp.bounds.corner(index), zvector]
				hit_item 	= Sketchup.active_model.raytest(ray, true)
				#puts "hit_item :-------- #{hit_item}"
				if hit_item && hit_ents.include?(hit_item[1][0])
				
				else
					sel.add(hit_item[1][0]) if hit_item
					inside = false
				end
			}
			comp.visible = false
			
			#puts "comp : #{comp} : #{room_name} : #{inside}"
			if inside
				comp_room_found_flag = true
				comp.set_attribute :rio_atts, 'space_name', room_name
				comp.set_attribute :rio_atts, 'room_scanned', 'true'
			end

			Sketchup::active_model.entities.erase_entities hit_face.edges
			#break
		}
		unless comp_room_found_flag
			comp.set_attribute :rio_atts, 'room_scanned', 'unknown'
		end
		
		visible_comps.each{|x| x.visible=true if !x.deleted?}
	end

	def self.has_door_windows? space_name
		#puts "has_door_windows : #{space_name}"
		space_group 	= get_space_group space_name
		face_arr		= space_group.entities.select{|ent| ent.is_a?(Sketchup::Face)}

		resp_h = {:window=>false, :door=>false}
		window_edge = face_arr[0].edges.select{|edge| edge.layer.name=='Window'}
		resp_h[:window] = true unless window_edge.empty?
		face_edge = face_arr[0].edges.select{|edge| edge.layer.name=='Door'}
		resp_h[:door] = true unless face_edge.empty?
		return resp_h
	end

	def self.get_space_group name
		group = Sketchup.active_model.entities.grep(Sketchup::Group).select{|group| (group.get_attribute :rio_atts, 'space_name')==name}
		group[0]
	end

	def self.check_region_name name
		space_names = get_space_names
		return true unless space_names.include?(name)
		return false
	end

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

	def self.add_face_attributes
		# puts "add_face_attributes"
		color_array 		= Sketchup::Color.names
	
		Sketchup.active_model.entities.grep(Sketchup::Face).each{ |comp|
			next if comp.get_attribute(:rio_atts, 'space_name')
			face_area = comp.area*645.16
			if face_area > 2200000
				comp_flag = false
				comp.edges.each{ |ent|
					comp_flag = true if ent.layer.name != 'Wall'
				}
				if comp_flag
					face_color = color_array.shuffle!.shift
					#sel.add(comp) 
					comp.set_attribute(:rio_atts, 'material', comp.material.name) if comp.material
					comp.set_attribute(:rio_atts, 'back_material', comp.back_material.name) if comp.back_material
					comp.material =  face_color
					comp.back_material =  face_color
				end
			end
		}
		Sketchup.active_model.active_view.refresh
	end

	def self.clear_face_attributes
		Sketchup.active_model.entities.grep(Sketchup::Face).each { |comp|
			material = comp.get_attribute(:rio_atts, 'material')
			if material
				comp.material =  material
				comp.back_material =  comp.get_attribute(:rio_atts, 'back_material')
				comp.set_attribute(:rio_atts, 'material', nil) 
					comp.set_attribute(:rio_atts, 'back_material', nil)
			end
		}
		Sketchup.active_model.active_view.refresh
	end
	
	def self.add_spacetype space_inputs, space_face=nil
		begin
			Sketchup.active_model.start_operation '2d_to_3d'
			# puts "add_spacetype : #{space_inputs}"
			space_type 		= space_inputs['space_type']
			space_name		= space_inputs['space_name']
			wall_height		= space_inputs['wall_height']

			# puts "space_name : #{space_name}"
			
			floor_layer		= Sketchup.active_model.layers.add 'DP_Floor_'+space_name
			
			model			= Sketchup.active_model
			ents			= model.entities
			seln 			= model.selection
			layers			= model.layers

			space_face 		= seln[0] if space_face.nil?
			space_face.set_attribute :rio_atts, 'space_name', space_name

			material = Sketchup.active_model.materials['rio_floor_color']
			fcolor    			= Sketchup::Color.new "#23d8d4"
			space_face.material=fcolor
			space_face.back_material=fcolor
			
			prev_active_layer 	= Sketchup.active_model.active_layer.name
			model.active_layer 	= floor_layer
			text_inst 			= add_text_to_face space_face, space_name
			floor_group 		= model.active_entities.add_group(space_face, text_inst)
			floor_group.set_attribute :rio_atts, 'space_name', space_name
			floor_group.set_attribute :rio_atts, 'wall_height', wall_height
			floor_group.set_attribute :rio_atts, 'floor_face_pid', space_face.persistent_id
			Sketchup.active_model.active_layer = prev_active_layer
		rescue Exception=>e 
			raise e
			Sketchup.active_model.abort_operation
		else
			Sketchup.active_model.commit_operation
		end
	end

	def self.add_wall_to_floor space_inputs
		begin
			Sketchup.active_model.start_operation '2d_to_3d'
			#puts "space_inputs : #{space_inputs}"
			space_name		= space_inputs['space_name']
			wall_height		= space_inputs['wall_height'].to_i.mm
			door_height		= space_inputs['door_height'].to_i.mm
			window_height	= space_inputs['window_height'].to_i.mm
			window_offset	= space_inputs['window_offset'].to_i.mm
			wall_color		= space_inputs['wall_color']
			wall_layer		= Sketchup.active_model.layers.add 'DP_Wall_'+space_name

			space_group 	= get_space_group space_name 
			if space_group == 0
				puts "No space with the name found"
				return false
			end

			model			= Sketchup.active_model
			ents			= model.entities
			seln 			= model.selection
			layers			= model.layers

			space_face 		= space_group.entities.grep(Sketchup::Face)[0]
			space_edges		= space_face.outer_loop.edges 
			zvector 		= Geom::Vector3d.new(0, 0, 1)
			
			#----------------------------Add Walls--------------------
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

			#----------------------------Add Window top face-----------------------------
			if window_height
				#puts "window h :#{window_height}"
				#puts "window o :#{window_offset}"
				combined_ht = (window_offset+window_height).mm
				height_arr = [window_offset, combined_ht, wall_height]
				#puts "height_arr : #{height_arr}"
				#This algorithm will create a single 
				space_edges.each {|edge|
					if edge.layer.name == 'Window' 
						vertices	= edge.vertices
						
						#Normal wall rise for Window
						pt1 		= vertices[0].position
						pt2			= vertices[1].position

						pt3			= pt2.offset(zvector, window_offset)
						pt4			= pt1.offset(zvector, window_offset)

						wall_face 	= ents.add_face pt1, pt2, pt3, pt4
						wall_face.layer = 'DP_Wall'
						wall_faces << wall_face
						wall_face.edges.each{|ed|
							#puts "wall_face..........."
							if (ed.line[1] == zvector || ed.line[1] == zvector.reverse)
								#puts "ed : #{ed}"
								ed_faces 	= ed.faces
								if  ed_faces == 2
									#puts "2222"
									(ents.erase_entities ed) if ed_faces[0].normal == ed_faces[1].normal
								end							
							end
						}

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
			model.active_layer 	= wall_layer
			
			color_array 		= Sketchup::Color.names
			wall_color			= color_array[rand(140)] if wall_color.nil?
			
			wall_faces.each{|wall|
				wall.material 		= wall_color
				wall.back_material 	= wall_color
			}
			wall_group 			= model.active_entities.add_group(wall_faces)
			wall_group.set_attribute(:rio_atts, 'wall_space_name', space_name)

			model.active_layer 	= prev_active_layer
			Sketchup.active_model.commit_operation
		rescue Exception=>e 
			raise e
			Sketchup.active_model.abort_operation
			return false
		else
			Sketchup.active_model.commit_operation
		end
		return true
	end

	def self.test_mod_fun
		puts "test_mod_fun"
	end
	
	def self.test_fun
		test_mod_fun
		puts "test fun"
	end
end