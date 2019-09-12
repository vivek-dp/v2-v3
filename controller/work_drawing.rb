require_relative 'rio_logger.rb'

module WD
    extend self
    # include RIOLOG
    # include DP
    
    @view_name  = nil
    @room_name  = nil
    @wall_trans = nil
    @view_comps = []
    @offset_wall_face = nil
    @trav_comp  = nil
    @sub_comps = []
    @sub_comp_name = nil
    #@shutter_code = nil
    
    @dimension_ent_array = {}
    
    #unless defined?(COMP_DIMENSION_OFFSET)
        COMP_DIMENSION_OFFSET 	= 20000.mm unless defined?(COMP_DIMENSION_OFFSET)
        WALL_OUTLINE_OFFSET 	= 20000.mm unless defined?(WALL_OUTLINE_OFFSET)
        WALL_DIMENSION_OFFSET 	= 20000.mm unless defined?(WALL_DIMENSION_OFFSET)
        WALL_SHADE_OFFSET 		= 20000.mm unless defined?(WALL_SHADE_OFFSET)
        
        SHUTTER_DIMENSION_LENGTH = 3 unless defined?(SHUTTER_DIMENSION_LENGTH)
    #end


    def add_depth_dimension entity, rotz=nil, color='red'
        rotz = entity.transformation.rotz unless rotz

        @dimension_ent_array[color] = [] unless @dimension_ent_array[color]
        
        pt1 = TT::Bounds.point(entity.bounds, 0)
        pt2 = TT::Bounds.point(entity.bounds, 4)
        distance = pt1.distance pt2
        if distance > 99.mm
            trans_hash = DP::get_transformation_hash(rotz)
            front_vector = trans_hash[:int_dim_vector].clone
            front_vector.length=100.mm
            dim_l = Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, front_vector)
            @dimension_ent_array[color] << dim_l
            dim_l.arrow_type = Sketchup::Dimension::ARROW_CLOSED
        end
    end

    # def add_rio_dimension start_pt, end_pt, dim_vector=X_AXIS, color='red'
    #     puts "------------------------------------------------------------1"
    #     @dimension_ent_array[color] = [] unless @dimension_ent_array[color]
    #     dim_l = Sketchup.active_model.entities.add_dimension_linear(start_pt, end_pt, dim_vector)
    #     dim_l.set_attribute :rio_atts, 'dimension_entity', 'true'
    #     dim_l.arrow_type = Sketchup::Dimension::ARROW_CLOSED
    #     @dimension_ent_array[color] << dim_l
    #     dim_l
    # end
    
    # def get_shutter_comps(entity, transformation = IDENTITY, add_comp=false)
    #     add_comp_flag = false
    #     if entity.is_a?(Sketchup::Group)
    #         transformation *= entity.transformation
    #         #puts "cgroup : #{entity.definition.name} : #{transformation.origin}"
    #         @shutter_comps << entity
    #         entity.definition.entities.each{ |child_entity|
    #             traverse_comp(child_entity, transformation.clone)
    #         }
    #     elsif entity.is_a?(Sketchup::ComponentInstance)
    #         transformation *= entity.transformation
    #         #puts "cinst : #{entity.definition.name} : #{transformation.origin} : #{@shutter_code}"
    #         if entity.definition.name == @shutter_code
    #             entity.definition.entities.each{ |child_entity|
    #                 traverse_comp(child_entity, transformation.clone)
    #             }
    #         end
    #     end
    # end
    
    def get_rendered_image
        @view_comps.each {|comp| comp.visible=true}
        @wall_face.edges.each{ |edge| edge.visible=true}
        
        file_name       = DP::get_current_file_name #DP function
        
        image_file_name = RIO_TEMP_PATH+file_name+'_'+@room_name+'_'+@view_name+'_render'+RIO_IMAGE_FILE_TYPE

        trans_hash      = DP::get_transformation_hash(@wall_trans)
        cam_pos         = trans_hash[:camera_position]
        cam_targ        = trans_hash[:camera_target]
        cam_up          = trans_hash[:camera_up]

        view_cam_hash   = DP::get_camera_details_hash
        view_cam_hash[:filename] = image_file_name
        
        Sketchup.active_model.active_view.camera.set cam_pos, cam_targ, cam_up
        Sketchup.active_model.active_view.zoom_extents
        Sketchup.active_model.active_view.write_image image_file_name #view_cam_hash

        @wall_face.hidden = false
        @view_comps.each {|comp| comp.visible=false}
        image_file_name
    end
    
    def add_rio_dimension start_pt, end_pt, dim_vector=X_AXIS, color='red'
        dim_l = Sketchup.active_model.entities.add_dimension_linear(start_pt, end_pt, dim_vector)
        dim_l.set_attribute :rio_atts, 'dimension_entity', 'true'
        dim_l.arrow_type = Sketchup::Dimension::ARROW_CLOSED
        dim_l.material.color = color
        dim_l
    end
    
    def add_wall_offset_lines
        Sketchup.active_model.entities.erase_entities(@offset_wall_face.edges) if @offset_wall_face && !@offset_wall_face.deleted?
        
        trans_hash = DP::get_transformation_hash @wall_trans
        front_pts   = trans_hash[:front_bounds]
        wall_pts = []
        #@wall_face.vertices.each{|vert| wall_pts << vert.position.offset(@wall_face.normal, WALL_OUTLINE_OFFSET)}
        @wall_face.vertices.each do |vert|
            pt = vert.position
            trans_hash[:set_x] ? pt.x=WALL_OUTLINE_OFFSET : pt.y=WALL_OUTLINE_OFFSET
            wall_pts << pt
        end
        #puts "wall_pts #{wall_pts}"
        
        @offset_wall_face = Sketchup.active_model.entities.add_face(wall_pts)
        wall_bbox = @offset_wall_face.bounds
        
        pt1, pt2, pt3 = front_pts.first(3)
        add_rio_dimension(wall_bbox.corner(pt1), wall_bbox.corner(pt2), Z_AXIS.reverse, 'blue')
        add_rio_dimension(wall_bbox.corner(pt3), wall_bbox.corner(pt2), trans_hash[:front_dim_vector] , 'blue')
        
        @offset_wall_face.hidden = true
    end
    

    def take_screenshot rotz
        trans_hash  = DP::get_transformation_hash rotz
    end

    #Function to get the background wall face
    def get_wall_face
        wall_length = @view_wall.get_attribute(:rio_atts, 'view_wall_length').to_i.mm
        wall_bbox   = @view_wall.bounds
        case @wall_trans
        when 0
            dim_vector = Geom::Vector3d.new(0,1,0)
            pt1 	= wall_bbox.corner(0)
            pt2 	= pt1.offset(Geom::Vector3d.new(1,0,0), wall_length)
            pt4 	= wall_bbox.corner(4)
            pt3 	= pt4.offset(Geom::Vector3d.new(1,0,0), wall_length)
        when 90
            dim_vector = Geom::Vector3d.new(-1,0,0)
            pt1 	= wall_bbox.corner(1)
            pt2 	= pt1.offset(Geom::Vector3d.new(0,1,0), wall_length)
            pt4 	= wall_bbox.corner(5)
            pt3 	= pt4.offset(Geom::Vector3d.new(0,1,0), wall_length)
        when -90
            dim_vector = Geom::Vector3d.new(1,0,0)
            pt1 	= wall_bbox.corner(2)
            pt2 	= pt1.offset(Geom::Vector3d.new(0,-1,0), wall_length)
            pt4 	= wall_bbox.corner(6)
            pt3 	= pt4.offset(Geom::Vector3d.new(0,-1,0), wall_length)
        when 180, -180
            dim_vector = Geom::Vector3d.new(0,-1,0)
            pt1 	= wall_bbox.corner(3)
            pt2 	= pt1.offset(Geom::Vector3d.new(-1,0,0), wall_length)
            pt4 	= wall_bbox.corner(7)
            pt3 	= pt4.offset(Geom::Vector3d.new(-1,0,0), wall_length)
        else
            @wall_face = nil
            return false
        end

        wpts = [pt1,pt2,pt3,pt4]; wall_pts=[];
        wpts.each{|pt| wall_pts << pt.offset(dim_vector, 30.mm)}
        @wall_face = Sketchup.active_model.entities.add_face wall_pts
        @wall_face.hidden = true
        @wall_face
    end

    def add_top_wall_face
        trans_hash  = DP::get_transformation_hash @wall_trans
        top_points  = trans_hash[:top_bounds]

        wall_length = @view_wall.get_attribute(:rio_atts, 'view_wall_length').to_i.mm
        
        pt1 = @view_wall.bounds.corner(top_points[0]);pt1.z=WALL_OUTLINE_OFFSET
        pt2 = @view_wall.bounds.corner(top_points[1]);pt2.z=WALL_OUTLINE_OFFSET
        pt3 = pt2.offset(trans_hash[:front_dim_vector], wall_length)
        pt4 = pt1.offset(trans_hash[:front_dim_vector], wall_length)
       
        wall_pts        = [pt1, pt2, pt3, pt4]
        #puts wall_pts
        top_wall_face   = Sketchup.active_model.entities.add_face(wall_pts)

        lower_vector    = trans_hash[:front_dim_vector].clone.reverse
        side_vector     = trans_hash[:front_side_vector].clone.reverse
        add_rio_dimension(pt1, pt2, lower_vector, 'blue')
        add_rio_dimension(pt2, pt3, side_vector, 'blue')
        
        #DP::add_rect_face_lines top_wall_face
    end
    
    def add_top_comp_outline view_comp
        if view_comp.get_attribute(:rio_atts, 'rio_comp').to_s == 'true'
            trans_hash = DP::get_transformation_hash @wall_trans #view_comp.transformation.rotz
            if view_comp.definition.get_attribute(:rio_atts, 'door-type') != 'Open'
                carcass_ent = view_comp.definition.entities.select{|e| e.definition.get_attribute(:rio_atts, 'comp_type')=='carcass'}[0]
            else
                carcass_ent = view_comp
            end
            comp_trans = view_comp.transformation
            carcass_bounds_origin = Geom::Transformation.new(carcass_ent.bounds.corner(0))
            carcass_trans = comp_trans * carcass_bounds_origin
            carcass_ent.definition.entities.each{ |carcass_sub_ent|
                next unless carcass_sub_ent.get_attribute(:rio_atts, 'top_outline_visible_flag')
                carcass_subentity_pts = []
                trans_hash[:top_bounds].each do |index|
                    carcass_sub_ent_trans       = carcass_trans * Geom::Transformation.new(carcass_sub_ent.bounds.corner(index))
                    pt                          = carcass_sub_ent_trans.origin
                    pt.z                        = WALL_OUTLINE_OFFSET
                    carcass_subentity_pts << pt
                end
                Sketchup.active_model.entities.add_face(carcass_subentity_pts)
            }
            
            carcass_ent_pts = []
            trans_hash[:top_bounds].each do |index|
                carcass_ent_trans       = carcass_trans * Geom::Transformation.new(carcass_ent.bounds.corner(index))
                pt                      = carcass_ent_trans.origin
                pt.z                    = WALL_OUTLINE_OFFSET
                carcass_ent_pts << pt
            end
            
            lower_vector    = trans_hash[:front_side_vector].clone.reverse
            side_vector     = trans_hash[:front_dim_vector].clone.reverse

            #Hard coded ...change
            if @wall_trans == 0
                lower_vector    = trans_hash[:front_dim_vector].clone.reverse
                side_vector     = trans_hash[:front_side_vector].clone.reverse
            end
            
            lower_vector.length=SHUTTER_DIMENSION_LENGTH
            side_vector.length=SHUTTER_DIMENSION_LENGTH
            
            #puts "carcass_pytrs : #{@view_name} : #{carcass_ent_pts} : #{lower_vector} : #{side_vector}"
            
            add_rio_dimension(carcass_ent_pts[3], carcass_ent_pts[2], lower_vector, 'green')
            add_rio_dimension(carcass_ent_pts[1], carcass_ent_pts[2], side_vector, 'green')
        else

        end
    end
    
    def get_top_internal_image
        add_top_wall_face
        
        @view_comps.each{ |view_comp| add_top_comp_outline view_comp }

        # ents_arr = []
        # Sketchup.active_model.entities.each{|ent| ents_arr << ent if ent.visible=true}
        
        # temp_group = Sketchup.active_model.entities.add_group(ents_arr)
        # temp_group.transformation = Geom::Transformation.new(ORIGIN)
        @cPos = [0, 0, 0]
        @cTarg = [0, 0, -1]
        @cUp = [0, 1, 0]

        Sketchup.active_model.active_view.camera.set @cPos, @cTarg, @cUp
        Sketchup.active_model.active_view.zoom_extents
        
        file_name       = DP::get_current_file_name
        image_file_name = RIO_TEMP_PATH+file_name+'_'+@room_name+'_'+@view_name+'_top_outline'+RIO_IMAGE_FILE_TYPE
        Sketchup.active_model.active_view.write_image image_file_name
        image_file_name
    end

    def add_component_outline view_comp, dimension_flag=false
        #Add component outline
        trans_hash  = DP::get_transformation_hash view_comp.transformation.rotz #wall_trans
    
        comp_bbox       = view_comp.bounds
        comp_pts        = []
        trans_hash[:front_bounds].first(4).each do |index|
            #[0, 1, 5, 4].each do |index|
            pt = comp_bbox.corner(index)
            trans_hash[:set_x] ? pt.x=WALL_OUTLINE_OFFSET : pt.y=WALL_OUTLINE_OFFSET
            comp_pts << pt
        end
        Sketchup.active_model.entities.add_face(comp_pts)
    
        #Add component dimension
        if dimension_flag
            add_rio_dimension(comp_pts[0], comp_pts[1], Z_AXIS, 'red')
            add_rio_dimension(comp_pts[2], comp_pts[1], trans_hash[:front_dim_vector].reverse, 'red')
        end
    end
    
    def add_shutter_outline view_comp, dimension_flag=true
        shutter_code   = view_comp.get_attribute(:rio_atts, 'shutter-code')
        if shutter_code.length.to_i != 0
            shutter_ent     = view_comp.definition.entities.select{|e| e.definition.name.start_with?(shutter_code)}[0]
            shutter_comps  = []
            comp_trans      =view_comp.transformation
        
            trans_hash      = DP::get_transformation_hash view_comp.transformation.rotz
        
            #The algorithm will make sure it wont show component of same dimension if they are same
            shutter_volume_arr= []
            show_dimension  = true
            shutter_origin  = Geom::Transformation.new(shutter_ent.bounds.corner(0))
            shutter_trans   = comp_trans * shutter_origin
            lower_vector    = Z_AXIS.clone;lower_vector.length=SHUTTER_DIMENSION_LENGTH
            side_vector     = trans_hash[:front_dim_vector].clone.reverse;side_vector.length=SHUTTER_DIMENSION_LENGTH
        
            shutter_ent.definition.entities.each do |sh_ent|
                shutter_volume  = DP::get_comp_volume(sh_ent).round
                show_dimension  = false if shutter_volume_arr.include?(shutter_volume)
                shutter_subentity_pts = []
            
                #trans_hash[:front_bounds].each do |index|
                [0, 1, 5, 4].each do |index|
                    sh_ent_trans    =  shutter_trans * Geom::Transformation.new(sh_ent.bounds.corner(index))
                    pt              = sh_ent_trans.origin
                    #puts "pt : #{pt}"
                    trans_hash[:set_x] ? pt.x=WALL_OUTLINE_OFFSET : pt.y=WALL_OUTLINE_OFFSET
                    shutter_subentity_pts << pt
                end
                # puts "shutter_subentity_pts : #{shutter_subentity_pts}"
                Sketchup.active_model.entities.add_face(shutter_subentity_pts)
            
                if show_dimension && dimension_flag
                    shutter_volume_arr << shutter_volume
                    add_rio_dimension(shutter_subentity_pts[3], shutter_subentity_pts[2], lower_vector.reverse, 'green')
                    add_rio_dimension(shutter_subentity_pts[3], shutter_subentity_pts[0], side_vector.reverse, 'green')
                end
            end
        end
    end
    
    def add_opening_sides comp
        opening_side    = comp.get_attribute(:rio_atts, 'shutter-open')
        return false unless opening_side
        if opening_side.include?('RHS') || opening_side.include?('LHS')
            puts comp.get_attribute(:rio_atts, 'sub-category')
            trans_hash      = DP::get_transformation_hash comp.transformation.rotz
            front_bounds    = trans_hash[:front_all_points]
            
            comp_bbox = comp.bounds
            if opening_side == 'LHS'
                index_arr = [3, 7, 0]
            elsif opening_side == 'RHS'
                index_arr = [2, 6, 1]
            end
            pts = []
            
            if comp.get_attribute(:rio_atts, 'door-type').to_s == 'Single/Drawer' || comp.get_attribute(:rio_atts, 'sub-category').include?('Microwave')
                cmp_car = comp.definition.entities.select {|e|
                    e.definition.get_attribute(:rio_atts, 'comp_type').to_s == "shutter"
                }[0]
                comp_origin = comp.transformation.origin
                comp_bound = comp.bounds
                puts "comp_origin---- #{comp.transformation.rotz.to_i}"
                # gbound = cmp_car.bounds
                cmp_count = cmp_car.definition.entities.count
                cmp_car.definition.entities.each{|s| 
                    if s.layer.name.split('_IM_').last.include?('DOOR_NORM')
                        gbound = s.bounds
                        index_arr.each do |index|
                            if comp.transformation.rotz.to_i != -180
                                index == 7 ? cb = comp_bound.height : cb = 0 if opening_side.to_s == 'LHS'
                                index != 6 ? cb = comp_bound.height : cb = 0 if opening_side.to_s == 'RHS'
                            else
                                cb = comp_bound.height
                                # index != 7 ? cb = comp_bound.height : cb = 0 if opening_side.to_s == 'LHS'
                                # index != 6 ? cb = comp_bound.height : cb = 0 if opening_side.to_s == 'RHS'
                            end
                            pt = TT::Bounds.point(gbound, front_bounds[index])
                            trans_hash[:set_x] ? pt.x=WALL_OUTLINE_OFFSET : pt.y=WALL_OUTLINE_OFFSET

                            if comp.transformation.rotz.to_i == 90
                                trans_hash[:set_x] ? pt.y += (comp_origin.y + cb) : pt.x += comp_origin.x
                            else
                                if comp.transformation.rotz.to_i == -180
                                    puts "cb---------: #{cb}"
                                    trans_hash[:set_x] ? pt.y += (comp_origin.y - cb) : pt.x += (comp_origin.x - cb)
                                else
                                    trans_hash[:set_x] ? pt.y += (comp_origin.y - cb) : pt.x += comp_origin.x
                                end
                            end

                            # pt.x += comp_origin.x
                            # pt.y += comp_origin.y
                            # pt.z += comp_origin.z
                            pts << pt
                        end
                        puts "pts---#{pts[0]} : #{pts[1]} : #{pts[2]}"
                        Sketchup.active_model.entities.add_cline pts[0] , pts[1]
                        Sketchup.active_model.entities.add_cline pts[2] , pts[1]
                        pts = [] if cmp_count.to_i >= 1
                    end
                }
            else
                index_arr.each do |index|
                    pt = TT::Bounds.point(comp_bbox, front_bounds[index])
                    trans_hash[:set_x] ? pt.x=WALL_OUTLINE_OFFSET : pt.y=WALL_OUTLINE_OFFSET
                    pts << pt
                end
                puts "pts---#{pts[0]} : #{pts[1]} : #{pts[2]}"
                Sketchup.active_model.entities.add_cline pts[0] , pts[1]
                Sketchup.active_model.entities.add_cline pts[2] , pts[1]
            end
        else
            return false
        end
    end
    
    def get_front_outline_image
        #@view_comps.each {|comp| comp.visible=false}
    
        add_wall_offset_lines
        trans_hash  = DP::get_transformation_hash @wall_trans
        front_pts   = trans_hash[:front_bounds]
        pt1, pt2, pt3   = front_pts.first(3)
    
        @view_comps.each do |view_comp|
            rio_atts_dict   = view_comp.attribute_dictionaries['rio_atts']

            add_component_outline view_comp, true
            add_shutter_outline view_comp, true if rio_atts_dict['shutter-code']
            add_opening_sides view_comp
        end
    
        file_name       = DP::get_current_file_name
        image_file_name = RIO_TEMP_PATH+file_name+'_'+@room_name+'_'+@view_name+'_front_outline'+RIO_IMAGE_FILE_TYPE
        cam_pos         = trans_hash[:camera_position]
        cam_targ        = trans_hash[:camera_target]
        cam_up          = trans_hash[:camera_up]
    
        Sketchup.active_model.active_view.camera.set cam_pos, cam_targ, cam_up
        Sketchup.active_model.active_view.zoom_extents
        Sketchup.active_model.active_view.write_image image_file_name
        image_file_name
    end

    def add_internal_comp_outline view_comp
        if view_comp.get_attribute(:rio_atts, 'rio_comp') && view_comp.get_attribute(:rio_atts, 'rio_comp').to_s != 'filler'
            trans_hash      = DP::get_transformation_hash view_comp.transformation.rotz
            if view_comp.definition.get_attribute(:rio_atts, 'door-type') != 'Open'
                carcass_ent     = view_comp.definition.entities.select{|e| e.definition.get_attribute(:rio_atts, 'comp_type')=='carcass'}[0]
            else
                carcass_ent = view_comp
            end
            comp_trans      = view_comp.transformation
            carcass_bounds_origin  = Geom::Transformation.new(carcass_ent.bounds.corner(0))
            carcass_trans   = comp_trans * carcass_bounds_origin
        
            comp_edges = []
            sel.add(view_comp)
            carcass_ent.definition.entities.each{ |carcass_sub_ent|
                next unless carcass_sub_ent.get_attribute(:rio_atts, 'outline_visible_flag')
                
                carcass_subentity_pts = []
                [0,1,5,4].each do |index|
                    carcass_sub_ent_trans       = carcass_trans * Geom::Transformation.new(carcass_sub_ent.bounds.corner(index))
                    pt                          = carcass_sub_ent_trans.origin
                    trans_hash[:set_x] ? pt.x=WALL_OUTLINE_OFFSET : pt.y=WALL_OUTLINE_OFFSET
                    carcass_subentity_pts << pt
                end

                carcass_sub_face = Sketchup.active_model.entities.add_face(carcass_subentity_pts)
                ent_layer_name      = carcass_sub_ent.layer.name
                ent_layer_ending    = ent_layer_name.split('_IM_')[1]
            
                if ent_layer_ending == 'DRAWER_FRONT'
                    carcass_sub_face.set_attribute(:rio_atts, 'drawer_face', true)
                    RioIntDim::add_extra_offset_faces carcass_sub_face, 1
                    RioIntDim::add_depth_dimension carcass_sub_face, comp_trans.rotz
                elsif ent_layer_ending == 'SHELF_INT'
                    carcass_sub_face.set_attribute(:rio_atts, 'shelf_face', true)
                    RioIntDim::add_extra_offset_faces carcass_sub_face, 0.5
                elsif ent_layer_ending == 'SHELF_FIX' || ent_layer_ending == 'SHELF_NORM'
                    carcass_sub_face.set_attribute(:rio_atts, 'shelf_face', true)
                elsif ent_layer_ending =='SIDE_NORM'
                    carcass_sub_face.set_attribute(:rio_atts, 'side_norm_face', true)
                end
                comp_edges << carcass_sub_face.edges
            }
            prev_ents = [];Sketchup.active_model.entities.each{|x| prev_ents << x}
            unless comp_edges.empty?
                comp_edges.flatten!.uniq!
                comp_edges.each{|c_edge|
                    c_edge.find_faces unless c_edge.deleted?
                }
            end
            curr_ents = [];Sketchup.active_model.entities.each{|x| curr_ents << x}
            newer_ents = curr_ents - prev_ents
            # puts "newer_ents---------#{newer_ents.length}"
        
            newer_ents.select!{|x| x.is_a?(Sketchup::Face)}
            newer_ents.each{|ent_face| RioIntDim::add_depth_dimension(ent_face, comp_trans.rotz)}
        end
    end
    
    def get_front_internal_image
        @wall_face.edges.each{|edge| edge.visible=true}
        @view_comps.each{ |view_comp| add_internal_comp_outline view_comp }

        trans_hash  = DP::get_transformation_hash @wall_trans

        file_name       = DP::get_current_file_name
        image_file_name = RIO_TEMP_PATH+file_name+'_'+@room_name+'_'+@view_name+'_front_internal'+RIO_IMAGE_FILE_TYPE
        cam_pos         = trans_hash[:camera_position]
        cam_targ        = trans_hash[:camera_target]
        cam_up          = trans_hash[:camera_up]

        Sketchup.active_model.active_view.camera.set cam_pos, cam_targ, cam_up
        Sketchup.active_model.active_view.zoom_extents
        Sketchup.active_model.active_view.write_image image_file_name
        image_file_name
    end
    
    def get_floor_view_comps
        view_details_h  = {}
        view_h 		    = MRP::get_room_view_components @selected_room_name
    
        all_comps = view_h.keys.map{|x| view_h[x]['comps']}.flatten!
        count = 1
        all_comps.each {|room_comp| room_comp.set_attribute(:rio_atts, 'wd_name', 'C%d'%[count]); count+=1}
        
        #-------------------Floor view-------------------------------------
        view_h.each { |view_name, view_arr|
            @view_name      = view_name
            @view_comps     = view_arr['comps']
            @wall_trans     = view_arr['transform'].to_i
            @view_wall      = view_arr['wall']
            #------------------------------------------------------------------------------------
            render_image_flag = true
            if render_image_flag
                get_wall_face
                preop_entarray      = []
                preop_ents          = Sketchup.active_model.entities.each{|ent| preop_entarray << ent}
                
                front_rendered_image      = get_rendered_image
                
                postop_entarray     = []
                postop_ents         = Sketchup.active_model.entities.each{|ent| postop_entarray << ent}
                new_ents            = postop_entarray - preop_entarray
                #puts "new_ents : #{new_ents}"
                Sketchup.active_model.entities.erase_entities new_ents
                
                Sketchup.active_model.entities.erase_entities(@wall_face.edges)
            end

            #------------------------------------------------------------------------------------
            front_outline_flag = true
            if front_outline_flag
                get_wall_face
                preop_entarray      = []
                preop_ents          = Sketchup.active_model.entities.each{|ent| preop_entarray << ent}

                front_outline_image     = get_front_outline_image
                @dimension_ent_array = {}
                
                postop_entarray     = []
                postop_ents         = Sketchup.active_model.entities.each{|ent| postop_entarray << ent}
                new_ents            = postop_entarray - preop_entarray
                Sketchup.active_model.entities.erase_entities new_ents

                Sketchup.active_model.entities.erase_entities(@wall_face.edges)
            end
            
            #------------------------------------------------------------------------------------
            top_internal_flag = true
            if top_internal_flag
                preop_entarray      = []
                preop_ents          = Sketchup.active_model.entities.each{|ent| preop_entarray << ent}
            
                top_internal_file_name  = get_top_internal_image
                @dimension_ent_array = {}
                
               
                
                postop_entarray     = []
                postop_ents         = Sketchup.active_model.entities.each{|ent| postop_entarray << ent}
                new_ents            = postop_entarray - preop_entarray
                Sketchup.active_model.entities.erase_entities new_ents
            end
            
            #------------------------------------------------------------------------------------
            front_internal_flag = true
            if front_internal_flag
                get_wall_face
                
                preop_entarray      = []
                preop_ents          = Sketchup.active_model.entities.each{|ent| preop_entarray << ent}
            
                front_internal_file_name = get_front_internal_image
                @dimension_ent_array = {}
                
                postop_entarray     = []
                postop_ents         = Sketchup.active_model.entities.each{|ent| postop_entarray << ent}
                new_ents            = postop_entarray - preop_entarray
                Sketchup.active_model.entities.erase_entities new_ents
    
                Sketchup.active_model.entities.erase_entities(@wall_face.edges) if @wall_face && !@wall_face.deleted?
            end
            
            comp_hash = {}
            @view_comps.each {|comp|
                comp_name = comp.get_attribute(:rio_atts, 'wd_name')
                comp_hash[comp_name] = comp
            }
            
            view_details_h[view_name] = {
                :comp_list                      => comp_hash,
                :front_outline_image            => front_outline_image,
                :front_internal_file_name       => front_internal_file_name,
                :top_internal_file_name         => top_internal_file_name,
                :front_rendered_image           => front_rendered_image,
            }
        }

        view_details_h
    end
    
    def add_rio_text text, text_point
        return nil unless text
        text 		= Sketchup.active_model.entities.add_text text, text_point
        text.set_attribute :rio_atts, 'temp_component_name', 'true'
        return text
    end
    
    def get_top_room_image
        preop_entarray      = []
        preop_ents          = Sketchup.active_model.entities.each{|ent| preop_entarray << ent}
        
        model_groups = Sketchup.active_model.entities.grep(Sketchup::Group)
        room_walls = model_groups.select{|gp| gp.get_attribute(:rio_atts, 'room_name')==@selected_room_name}
        room_walls.each do |wall|
            wall_pts = []
            VG::RIO_TOP_POINTS.first(4).each{|index|
                pt = wall.bounds.corner(index); pt.z=WALL_OUTLINE_OFFSET
                wall_pts << pt
            }
            wall_face = Sketchup.active_model.entities.add_face(wall_pts)
        end
        top_comps = MRP::get_top_room_comps @selected_room_name
        top_comps.each do |tcomp|
            comp_pts = []
            VG::RIO_TOP_POINTS.first(4).each{|index|
                pt = tcomp.bounds.corner(index); pt.z=WALL_OUTLINE_OFFSET
                comp_pts << pt
            }
            comp_face = Sketchup.active_model.entities.add_face(comp_pts)
            face_bbox = comp_face.bounds
            add_rio_dimension(face_bbox.corner(0), face_bbox.corner(1), Y_AXIS, 'red')
            add_rio_dimension(face_bbox.corner(3), face_bbox.corner(1), X_AXIS.reverse, 'red')
            
            text_position   = Geom.linear_combination( 0.5, TT::Bounds.point(face_bbox, 6), 0.5, TT::Bounds.point(face_bbox, 24))
            text_position.z = WALL_OUTLINE_OFFSET
            comp_name = tcomp.get_attribute(:rio_atts, 'wd_name')
            add_rio_text(comp_name, text_position)
        end

        @cPos = [0, 0, 0]
        @cTarg = [0, 0, -1]
        @cUp = [0, 1, 0]

        Sketchup.active_model.active_view.camera.set @cPos, @cTarg, @cUp
        Sketchup.active_model.active_view.zoom_extents

        file_name       = DP::get_current_file_name
        image_file_name = RIO_TEMP_PATH+file_name+'_'+@room_name+'_'+@view_name+'_top_room'+RIO_IMAGE_FILE_TYPE
        Sketchup.active_model.active_view.write_image image_file_name

        postop_entarray     = []
        postop_ents         = Sketchup.active_model.entities.each{|ent| postop_entarray << ent}
        new_ents            = postop_entarray - preop_entarray
        Sketchup.active_model.entities.erase_entities new_ents
        
        image_file_name
    end
    
    #-----------------------------------------------------
    # Description   : Function for generating the working drawing images
    # params        : room_name(String)
    # -----------------------------------------------------
    def generate_wd_images rname=nil
        return {} unless rname
        
        start_time = Time.now
        
        @selected_room_name = rname
        @room_name          = @selected_room_name.gsub('#', '_')
        # rinfo "Starting Image generation : %s"%(@selected_room_name)

        #Pre Operation things
        exception_raised = false
        #-----------Get previous stuffs--------------------------
        curr_active_layer       = Sketchup.active_model.active_layer
        edge_render_option      = Sketchup.active_model.rendering_options["EdgeColorMode"]
        active_camera           = Sketchup.active_model.active_view.camera
        cam_perspective         = Sketchup.active_model.active_view.camera.perspective?
        unit_display            = Sketchup.active_model.options["UnitsOptions"]["SuppressUnitsDisplay"]

        Sketchup.active_model.options["UnitsOptions"]["SuppressUnitsDisplay"]=true
        Sketchup.active_model.active_view.camera.perspective=false
        Sketchup.active_model.rendering_options["EdgeColorMode"] = 0
        
        begin
            # puts "--------------------------hide"
            Sketchup::active_model::start_operation "RIO Image Generation"
            DP::hide_all_entities

            view_details_h = get_floor_view_comps
            
            view_details_h["top_view"] = {:top_room_image => get_top_room_image}
        rescue Exception => e
            # rerror "Exception raised during image generation"
            raise e
            Sketchup.active_model.abort_operation
            exception_raised = true
        ensure
            DP::unhide_all_entities

            Sketchup.active_model.rendering_options["EdgeColorMode"] = edge_render_option
            Sketchup.active_model.options["UnitsOptions"]["SuppressUnitsDisplay"]=unit_display
            Sketchup.active_model.active_view.camera=active_camera
            Sketchup.active_model.active_view.camera.perspective=cam_perspective
            Sketchup.active_model.active_view.zoom_extents
            Sketchup.active_model.commit_operation
        end

        end_time = Time.now
        # puts "Time taken : #{end_time - start_time}"
        result = exception_raised ? {} : view_details_h
    end
    
    def test_functions
    
    end
    
    def set_test_params
        seln    = Sketchup.active_model.selection
        if seln.length < 1
            puts "Nothing selected........."
            return false
        end
        
        @view_comps     = []
        @wall_trans     = nil
        @view_wall      = nil
        @room_name      = nil
        @view_name      = "test_view"
        seln.each do |entity|
            next unless entity.attribute_dictionaries
            
            rio_dict = entity.attribute_dictionaries['rio_atts']
            if rio_dict
                if rio_dict[:rio_comp]
                    @view_comps << entity
                elsif rio_dict[:wall_trans]
                    @wall_trans = rio_dict[:wall_trans]
                    @room_name  = rio_dict[:room_name]
                    @view_wall  = entity
                end
            end
        end
        
        if @view_comps.empty?
            puts "No rio component selected"
            return false
        end
        if @view_wall.nil?
            puts "No wall selected"
            return false
        end
        rinfo "Test : Wall %s - Comps %s"%[@view_wall, @view_comps.length]
    end
    
end