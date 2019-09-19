rioload_ruby '/core/SketchupHelper'
rioload_ruby '/core/DirectionHelper'
module RIO
    module CivilHelper
		def self.get_room_names
			room_names = []
			ents = Sketchup.active_model.entities
			ents.grep(Sketchup::Face).each{|sface|
				rname = sface.get_attribute(:rio_atts, 'room_name')
				room_names<<rname if rname
			}
			room_names.flatten!
			room_names.uniq!
			room_names
			
            # room_names = [ "room_name1", "room_name22", "room_name33", "room_name444",]
            # room_names
		end
		
        def self.add_wall_corner_lines
            model 	    = Sketchup.active_model
            wall_layer  = model.layers['RIO_Wall']
            pts = []; wall_faces = []
            all_faces = Sketchup.active_model.entities.grep(Sketchup::Face)

            #Get faces with all wall sides
            all_faces.each{|sk_face|
                wall_face_flag = true
                sk_face.edges.each{|edge|
                    wall_face_flag = false if edge.layer.name != 'RIO_Wall'
                }
                wall_faces << sk_face if wall_face_flag
            }

            if true #Core algo for finding the corner lines
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
                        #tputs "hit_item : #{hit_item}"

                        if hit_item && hit_item[1][0].is_a?(Sketchup::Edge)
                            if hit_item[1][0].layer.name == 'RIO_Wall'
                                distance = first_vert.position.distance hit_item[0]
                                #puts distance
                                if distance < 251.mm
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
                            if hit_item[1][0].layer.name == 'RIO_Wall'
                                distance = second_vert.position.distance hit_item[0]
                                #puts distance
                                if distance < 251.mm
                                    #puts "Draw line......."
                                    wall_line = Sketchup.active_model.entities.add_line second_vert.position, hit_item[0]
                                    wall_line.layer = wall_layer
                                end
                            end
                        end
                    }
                }

            end
        end

        def self.check_clockwise_edge edge, face
            edge, face = face, edge if edge.is_a?(Sketchup::Face)
            conn_vector = find_edge_face_vector(edge, face)
            dot_vector	= conn_vector * edge.line[1]
            clockwise = dot_vector.z > 0
            return clockwise
        end

        def self.check_edge_vector input_edge, input_face
            if !input_edge.is_a?(Sketchup::Edge)
                puts "check_edge_vector : First input should be an Edge : #{input_edge}"
                return false
            end
            if !input_face.is_a?(Sketchup::Face)
                puts "check_edge_vector : Second input should be an Face : #{input_face}"
                return false
            end

            puts "check_edge : #{input_edge} : #{input_face}"
            edge_vector = input_edge.line[1]
            perpendicular_vector = Geom::Vector3d.new(-edge_vector.y, edge_vector.x, edge_vector.z)

            center_pt   = input_edge.bounds.center

            offset_pt 	= center_pt.offset(perpendicular_vector, 10.mm)
            res     	= input_face.classify_point(offset_pt)
            if res == Sketchup::Face::PointInside || res == Sketchup::Face::PointOnFace
                return perpendicular_vector
            end

            offset_pt 	= center_pt.offset(perpendicular_vector.reverse, 10.mm)
            res     	= input_face.classify_point(offset_pt)
            if res == Sketchup::Face::PointInside || res == Sketchup::Face::PointOnFace
                return perpendicular_vector.reverse
            end

            return false
        end

        def self.create_cuboidal_entity length, width, height
            defn_name = 'rio_temp_defn_' + Time.now.strftime("%T%m")

            model		= Sketchup.active_model
            entities 	= model.entities
            defns		= model.definitions
            comp_defn	= defns.add defn_name

            pt1 		= ORIGIN
            pt2			= ORIGIN.offset(Y_AXIS, width)
            pt3 		= pt2.offset(X_AXIS, length.to_mm)
            pt4 		= pt1.offset(X_AXIS, length.to_mm)

            wall_temp_group 	= comp_defn.entities.add_group
            wall_temp_face 		= wall_temp_group.entities.add_face(pt1, pt2, pt3, pt4)

            ent_list1 	= SketchupHelper::get_current_entities
            wall_temp_face.pushpull -height
            ent_list2 	= SketchupHelper::get_current_entities

            new_entities 	= ent_list2 - ent_list1

            new_entities.grep(Sketchup::Face).each { |tface|
                wall_temp_group.entities.add_face tface
            }
            comp_defn
        end

        #-------------------------------------------------------------------------------------
        # The function will be used to create a cuboid component and placed on the edge
        # start point will be the origin for the cuboid component
        # End point will be used to calculate the distance and vector
        # comp height will refer to depth of the component
        # at_offset will refer to the height at which the component has to be placed with reference to the start_point
        #--------------------------------------------------------------------------------------
        def self.place_cuboidal_component( start_point, end_point,
                        comp_width: 50.mm,
                        comp_height: 2000.mm,
                        at_offset: 0.mm)

            start_point = start_point.position if start_point.is_a?(Sketchup::Vertex)
            end_point   = end_point.position if end_point.is_a?(Sketchup::Vertex)
            length 		= start_point.distance(end_point).mm

            #create
            comp_defn 	= create_cuboidal_entity length, comp_width, comp_height

            #Add instance
            comp_inst        = Sketchup.active_model.entities.add_instance comp_defn, start_point

            extra = 0
            #Rotate instance
            trans_vector = start_point.vector_to(end_point)
            if trans_vector.y < 0
                trans_vector.reverse!
                extra = Math::PI
            end
            angle 	= extra + X_AXIS.angle_between(trans_vector)
            comp_inst.transform!(Geom::Transformation.rotation(start_point, Z_AXIS, angle))

            if at_offset > 0.mm
                comp_inst.transform!(Geom::Transformation.new([0,0,at_offset]))
            end

            comp_inst.set_attribute :rio_atts, 'wall_block', 'true'
            comp_inst
        end

        def self.find_adj_window_face arr=[]
            face = arr.last
            face.edges.each{|edge|
                edge.faces.each{|face|
                    window_edges = face.edges.select{|face_edge| face_edge.layer.name=='RIO_Window'}
                    # puts window_edges.count
                    if window_edges.count > 1 && !arr.include?(face)
                        if face.edges.count == 4
                            arr.push(face)
                            find_adj_window_face arr
                        end
                    end
                }
            }
            return arr
        end

        def self.find_edge_face_vector edge, face
            return false if edge.nil? || face.nil?
            edge_vector = edge.line[1]
            perp_vector = Geom::Vector3d.new(edge_vector.y, -edge_vector.x, edge_vector.z)
            offset_pt 	= edge.bounds.center.offset(perp_vector, 2.mm)
            res = face.classify_point(offset_pt)
            return perp_vector if (res == Sketchup::Face::PointInside||res == Sketchup::Face::PointOnFace)
            return perp_vector.reverse
        end

        def self.find_edges sel_edge, sel_face
            puts "find_edges : #{sel_edge} : #{sel_face}"
            #sel.add(sel_edge)
            #sel.add(sel_face)

            edge_arr = []
            sel_edge.vertices.each{|ver|
                #puts ver.edges&sel_face.edges
                common_edges = ver.edges&sel_face.edges
                edge_arr << common_edges
            }
            edges = edge_arr.flatten!
            edges = edges.uniq!
            edges = edges - [sel_edge]
            edges.select!{|ed| ed.layer.name!='RIO_Column'}
            #sel.clear
            edges
        end

        def self.get_wall_views room_face
            unless room_face.is_a?(Sketchup::Face)
                puts "get_views : Not a Sketchup Face"
                return false
            end

            unknown_edges = []
            room_face.edges.each{ |redge| unknown_edges << redge unless redge.layer.name.start_with?('RIO_')}
            unless unknown_edges.empty?
                seln = Sketchup.active_model.selection; seln.clear; seln.add(unknown_edges)
                puts "The following are unknown edges in the floor."
                resp = UI.messagebox("The selections are unknown edges in the room. Click Ok to add them to Walls or Cancel to choose their layers manually.", MB_OKCANCEL)
                case resp
                when 1
                    unknown_edges.each{ |uedge|
                        uedge.layer = Sketchup.active_model.layers['RIO_Wall']
                    }
                when 2
                    return false
                end
            end


            # ----------------------------------------------------------------
            # get corner edge
            corner_found = false
            floor_edges_arr = room_face.outer_loop.edges
            puts "floor_edges_arr1 : #{floor_edges_arr}"

            #Find the door adjacents
            # floor_edges_arr.length.times do
            #     if f_edge.layer.name == 'RIO_Wall'
            # }
            floor_edges_arr.length.times do
                f_edge = floor_edges_arr[0]
                #puts "f_edge : #{f_edge.layer.name} : #{floor_edges_arr[1].layer.name}"
                #Corner algo 1 : Check for perpendicular walls
                if f_edge.layer.name == 'RIO_Wall'
                    next_edge = floor_edges_arr[1]
                    if f_edge.get_attribute(:rio_atts, 'door_adjacent') || next_edge.get_attribute(:rio_atts, 'door_adjacent')
                        #If the current or next wall is a door adjacent wall.....Skip.....
                    else
                        if next_edge.layer.name == 'RIO_Wall'
                            if f_edge.line[1].perpendicular?(next_edge.line[1]) || f_edge.line[1].perpendicular?(next_edge.line[1].reverse)
                                
                                if f_edge.length > 400.mm
                                    corner_found = true
                                end
                                    #sel.add(f_edge, next_edge)
                            end
                        end
                    end
                end
                #puts "corner_found : #{corner_found}"
                floor_edges_arr.rotate!
                break if corner_found
            end
            puts "floor_edges_arr2 : #{floor_edges_arr}"
            if floor_edges_arr[1].layer.name == 'RIO_Door'
                #floor_edges_arr.reverse!
            end
            #floor_edges_arr.rotate!

            #puts "get_views : #{floor_edges_arr}"
            room_views = []
            #parse each edge
            while_count = 0
            while while_count < 20
                while_count += 1
                view_comps 	= get_wall_view(floor_edges_arr)
                floor_edges_arr = floor_edges_arr - view_comps
                room_views << view_comps
                floor_edges_arr.flatten!
                break if floor_edges_arr.empty?
            end
            sel.add(floor_edges_arr)
            #puts "room : floor_edges_arr : #{floor_edges_arr}"
            room_views
        end #get_views

        def self.get_wall_view floor_edge_arr
            last_viewed_wall = nil
            view_components = []
            #puts "floor_edge_arr : #{floor_edge_arr}"
            floor_edge_arr.each {|floor_edge|
                case floor_edge.layer.name
                when 'RIO_Wall'
                    if last_viewed_wall
                        if floor_edge.get_attribute(:rio_atts, 'door_adjacent')
                            view_components << floor_edge
                        else
                            if floor_edge.line[1].perpendicular?(last_viewed_wall.line[1])
                                return view_components
                            elsif !floor_edge.line[1].parallel?(last_viewed_wall.line[1])
                                return view_components
                            else
                                view_components << floor_edge
                            end
                        end
                    else
                        last_viewed_wall = floor_edge unless floor_edge.get_attribute(:rio_atts, 'door_adjacent')
                        view_components << floor_edge
                    end
                when 'RIO_Door', 'RIO_Window'
                    if last_viewed_wall && floor_edge.line[1].perpendicular?(last_viewed_wall.line[1])
                        return view_components
                    else
                        view_components << floor_edge
                    end
                when 'RIO_Column'
                    view_components << floor_edge
                end
            }
            return view_components
        end

        def self.create_beam input_face
            puts "create_beam : #{input_face}"
            wall_blocks = es.grep(Sketchup::ComponentInstance).select{|inst| inst.definition.name.start_with?('rio_temp_defn')}
            
            intersecting_blocks = []
            beam_wall_block = nil
            wall_blocks.each{|wblock|
                if wblock.bounds.intersect(input_face.bounds).width > 10.mm
                    beam_wall_block = wblock
                    break
                end
            }
            # puts "intersecting_blocks : #{intersecting_blocks}"
            # intersecting_blocks.sort_by{|iblock| iblock.bounds.intersect(input_face.bounds).diagonal.to_f}
            # puts "intersecting_blocks2 : #{intersecting_blocks}"
            # beam_wall_block = intersecting_blocks.last

            unless beam_wall_block
                face_cent_pt = input_face.bounds.center
                test1_pt, test1_item = Sketchup.active_model.raytest(face_cent_pt, input_face.normal)
                if test1_pt
                    distance1 = test1_pt.distance(face_cent_pt)       
                end
                test2_pt, test2_item = Sketchup.active_model.raytest(face_cent_pt, input_face.normal.reverse)
                if test2_pt
                    distance2 = test2_pt.distance(face_cent_pt)       
                end
                if distance1.nil?&distance2.nil?
                    puts "The wall beams face is not glued to any wall properly"
                    return false
                end

                if !distance1.nil?&!distance2.nil?
                    beam_wall_block = distance1<distance2 ? test1_item[0] : test2_item[0]  
                end
                if distance1.nil?
                    beam_wall_block = test2_item[1][0]
                elsif distance2.nil?
                    beam_wall_block = test1_item[1][0]
                end
            end

            if beam_wall_block.nil?
                puts "Could not identify where the beam starts from. Please draw the face on some wall or column."
                return false
            else
                room_name = beam_wall_block.get_attribute(:rio_block_atts, 'room_name')
                view_name = beam_wall_block.get_attribute(:rio_block_atts, 'view_name')
                start_block_id = beam_wall_block.persistent_id
            end
            
            block_vector = beam_wall_block.get_attribute :rio_block_atts, 'towards_wall_vector'
            input_face.reverse! if input_face.normal != block_vector #Instead reversing the normal
            
            face_center = input_face.bounds.center
            fnorm 		= input_face.normal
            #fnorm.reverse! if input_face.normal != block_vector

            beam_hit_found = false
            distance = 0.mm

            start_pts = [face_center]
            input_face.vertices.each { |face_vertex|
                face_point = face_vertex.position
                center_vector = face_point.vector_to(face_center)
                start_pt = face_point.offset(center_vector, 10.mm)
                start_pts << start_pt
            }
            start_pts.flatten!
            start_pts.uniq! #Not needed

            beam_components = Sketchup.active_model.entities.select{|ent| ent.layer.name=='RIO_Civil_Beam'}
            beam_components.each{|ent| ent.hidden=true}

           

            beam_algorithm = 2
            case beam_algorithm
            when 1

                #   First finish checking all opposite walls
                #   This algorithm follows below
                # - Hide all beams and columns except corner columns.
                # - Take 5 pts on the face and find a point each offset at 10mm to the center-- To avoid the overlap on the corners
                # - When u find a point hitting the wall or the corner column stop.
                allowed_intersections = ['column', 'wall']
                
                column_components = Sketchup.active_model.entities.select{|ent| ent.layer.name=='RIO_Civil_Column'}
                column_components.each{|ent| ent.hidden=true unless ent.get_attribute(:rio_block_atts, 'corner_column_flag')}

                start_pts.each { |start_pt|
                    start_pt = start_pt.position if start_pt.is_a?(Sketchup::Vertex)
                    hit_point, hit_item     = Sketchup.active_model.raytest(start_pt, fnorm)
                    if hit_item && hit_item[0].is_a?(Sketchup::ComponentInstance)
                        block_type = hit_item[0].get_attribute(:rio_block_atts, 'block_type')
                        if block_type && allowed_intersections.include?(block_type)
                            beam_hit_found = hit_item[0]
                            distance = start_pt.distance(hit_point)
                            break
                        end
                    end
                }
                puts "beam_components : #{beam_components}"
                puts "column components : #{column_components}"

                column_components.each{|ent| ent.hidden=false}
            when 2
                beam_length = 0
                start_pts.each { |start_pt|
                    start_pt = start_pt.position if start_pt.is_a?(Sketchup::Vertex)
                    last_point, hit_entity = find_last_hit_point start_pt, fnorm, room_name
                    if last_point
                        offset_distance = last_point.distance start_pt
                        if offset_distance > beam_length
                            beam_hit_found = hit_entity
                            beam_length = offset_distance 
                        end
                    end
                }
            end
            beam_components.each{|ent| ent.hidden=false}

            puts "beam_wall_block : #{beam_wall_block} : #{beam_hit_found}"
            puts "beam_hit_found : #{beam_hit_found} at distance #{beam_length}"
            unless beam_hit_found
                puts "Cannot find the last end point for the beam. Could be possibly because the last hit element is not RIO Wall or column"
                return false
            end
            sel.add(beam_wall_block)
            sel.add(beam_hit_found)
            if beam_wall_block == beam_hit_found
                beam_components.each{|ent| ent.hidden=false}
                column_components.each{|ent| ent.hidden=false}
                create_beam input_face
            else
                if beam_hit_found
                    input_face.set_attribute(:rio_block_atts, 'beam_face', 'true')
                    input_face.set_attribute(:rio_block_atts, 'room_name', room_name) 
                    input_face.set_attribute(:rio_block_atts, 'view_name', view_name)
                    input_face.set_attribute(:rio_block_atts, 'block_type', 'face')

                    input_face.edges.each { |i_edge|
                        i_edge.set_attribute(:rio_block_atts, 'beam_edge', 'true')
                        i_edge.set_attribute(:rio_block_atts, 'room_name', room_name) 
                        i_edge.set_attribute(:rio_block_atts, 'view_name', view_name)
                        i_edge.set_attribute(:rio_block_atts, 'block_type', 'edge')
                    }

                    pre_entities = Sketchup.active_model.entities.to_a
                    input_face.pushpull(beam_length, true)
                    Sketchup.active_model.entities.erase_entities(input_face)
                    post_entities = Sketchup.active_model.entities.to_a
                    new_entities 	= post_entities - pre_entities
                    temp_group 		= Sketchup.active_model.entities.add_group(new_entities)
                    Sketchup.active_model.layers.add('RIO_Civil_Beam') if Sketchup.active_model.layers['RIO_Civil_Beam'].nil?
                    temp_group.layer = Sketchup.active_model.layers['RIO_Civil_Beam']
                    beam_component = temp_group.to_component
                    
                    beam_component.set_attribute(:rio_block_atts, 'block_type', 'beam')
                    beam_component.set_attribute(:rio_block_atts, 'view_name', view_name)
                    #beam_component.set_attribute(:rio_block_atts, 'face_id', input_face.persistent_id)
                    beam_component.set_attribute(:rio_block_atts, 'room_name', room_name)
                    beam_component.set_attribute(:rio_block_atts, 'beam_length', beam_length)
                    beam_component.set_attribute(:rio_block_atts, 'start_block', start_block_id)
                    beam_component.set_attribute(:rio_block_atts, 'end_block', beam_hit_found.persistent_id)
                    return beam_component
                else
                    puts "No opposite Wall found.Cannot draw Beam"
                    return false
                end

                # if false
                #     ray_res 		= Sketchup.active_model.raytest(face_center, fnorm)
                #     reverse_ray_res = Sketchup.active_model.raytest(face_center, fnorm.reverse)
                    
                #     puts "ray_res : #{ray_res}"
                #     #puts "reverse ray : #{reverse_ray_res}"
                    
                #     pre_entities = []; post_entities=[];
                #     Sketchup.active_model.entities.each{|ent| pre_entities << ent}
                #     if ray_res
                #         distance = ray_res[0].distance(face_center)
                #         puts "ray distance : #{distance}"
                #         if distance > 60.mm
                #             if ray_res[1][0].get_attribute(:rio_atts,'wall_block')
                #                 puts "ray res : #{ray_res} : #{ray_res[1][0].get_attribute(:rio_atts,'wall_block')}"
                #                 input_face.pushpull(distance, true)
                #             end
                #         end
                #     end
                #     Sketchup.active_model.entities.each{|ent| post_entities << ent}
                # end

                
                # if reverse_ray_res
                    # distance = reverse_ray_res[0].distance(face_center)
                    # puts "reverse ray distance : #{distance}"
                    # if distance > 60.mm
                        # if ray_res[1][0].get_attribute(:rio_atts,'wall_block')
                            # puts "Rev ray res : #{ray_res} : #{ray_res[1][0].get_attribute(:rio_atts,'wall_block')}"
                            # input_face.pushpull(distance, true)
                        # end
                    # end
                # end
            end
        end

        def self.get_room_civil_entities room_name
            entities_array = []
            entities_array << Sketchup.active_model.entities.select{|ent| ent.get_attribute(:rio_block_atts, 'room_name')==room_name}
            entities_array.flatten!
            entities_array.uniq!
            entities_array
        end

        def self.get_room_comp_entities room_name
            entities_array = []
            entities_array << Sketchup.active_model.entities.select{|ent| ent.get_attribute(:rio_comp_atts, 'room_name')==room_name}
            entities_array.flatten!
            entities_array.uniq!
            entities_array
        end

        def self.remove_room_entities room_name=nil
            puts "Func : remove_room_entities : #{room_name}"
            unless room_name
                puts "Room name cannot be empty"
                return false
            end
            
            puts "Room to be deleted : ++#{room_name}++"
            room_entities = get_room_civil_entities(room_name)
            comp_entities = get_room_comp_entities(room_name)

            if room_entities.empty? && comp_entities.empty?
                puts "Nothing to remove"
            else
                wall_entities   = room_entities.select{|ent| ent.get_attribute(:rio_block_atts, 'block_type')=='wall'}
                door_entities   = room_entities.select{|ent| ent.get_attribute(:rio_block_atts, 'block_type')=='door'}
                window_entities = room_entities.select{|ent| ent.get_attribute(:rio_block_atts, 'block_type')=='window'}
                column_entities = room_entities.select{|ent| ent.get_attribute(:rio_block_atts, 'block_type')=='column'}
                beam_entities   = room_entities.select{|ent| ent.get_attribute(:rio_block_atts, 'block_type')=='beam'}
                face_entities   = room_entities.select{|ent| ent.get_attribute(:rio_block_atts, 'block_type')=='face'}
                edge_entities   = room_entities.select{|ent| ent.get_attribute(:rio_block_atts, 'block_type')=='edge'}

                puts "-----------------Room entities --------------------------------"
                puts "Wall                      : #{wall_entities.length}"
                puts "Door                      : #{door_entities.length}"
                puts "Window                    : #{window_entities.length}"
                puts "Column                    : #{column_entities.length}"
                puts "Beam                      : #{beam_entities.length}"
                puts "Face                      : #{face_entities.length}"
                puts "Edge                      : #{edge_entities.length}"
                puts "Civil : #{room_entities.length} #{room_name} entities have been deleted"
                if !comp_entities.empty?
                    puts "Components : #{comp_entities.length} #{room_name} rio components have been deleted"
                    Sketchup.active_model.entities.erase_entities(comp_entities)
                end
                Sketchup.active_model.entities.erase_entities(room_entities)
            end

            room_face = get_room_face room_name
            if room_face
                room_face.material=nil
                room_face.back_material=nil
            end 

            all_faces = Sketchup.active_model.entities.select{|ent| ent.is_a?(Sketchup::Face)}
            room_faces = all_faces.select{|ent| ent.get_attribute(:rio_atts, 'room_name') == room_name}
            room_faces.each{ |rface|          
                rio_atts_dict = rface.attribute_dictionaries['rio_atts']
                puts "Dict : #{rio_atts_dict}"
                rio_atts_dict.keys.each {|key_name|
                    puts "Key : #{key_name}"
                    rface.delete_attribute 'rio_atts', key_name
                }
            }

            if room_face
                new_edges = room_face.outer_loop.edges.each { |fedge|
                    next unless fedge
                    next if fedge.deleted?
                    if fedge.get_attribute(:rio_edge_atts, 'new_edge')
                        Sketchup.active_model.entities.erase_entities(fedge)
                    end
                }
            end

            Sketchup.active_model.entities.grep(Sketchup::ComponentInstance).each{|cinst|
                if cinst.get_attribute(:rio_atts, 'room_name_text') == room_name
                    Sketchup.active_model.entities.erase_entities(cinst)
                    break
                end
            }

            return true
        end
        
        def self.get_view_entities room_name
            room_entities_a = get_room_civil_entities room_name
            view_hash = {}
            room_entities_a.each { |ent|
                room_view_name = ent.get_attribute(:rio_block_atts, 'view_name')
                if room_view_name.is_a?(Array)
                    room_view_name.each{ |vname|
                        view_hash[vname] = [] unless view_hash.key?(vname)
                        view_hash[vname] << ent
                    }
                else
                    view_hash[room_view_name] = [] unless view_hash.key?(room_view_name)
                    view_hash[room_view_name] << ent
                end
            }
            view_hash
        end

        # RIO::CivilHelper::find_last_hit_point fsel.center, X_AXIS, 'MBR'
        def self.find_last_hit_point input_pt, input_vector, room_name
            room_entities_a = get_room_civil_entities room_name
            continue_raytest = true
            count = 1 #Just to avoid infinite loop
            allowed_intersections = ['column', 'wall']
            hidden_items = []
            hit_points_a = []
            puts "Room entities : #{room_entities_a}"

            while continue_raytest
                puts "Loop raytest : #{count}"
                hit_point, hit_item     = Sketchup.active_model.raytest(input_pt, input_vector)
                if hit_item && hit_item[0].is_a?(Sketchup::ComponentInstance)
                    hit_entity = hit_item[0]
                    puts "Comp : #{hit_entity}"
                    block_type = hit_entity.get_attribute(:rio_block_atts, 'block_type')
                    if room_entities_a.include?(hit_entity)
                        puts "Allowed entity #{hit_entity}"
                        if allowed_intersections.include?(block_type)
                            puts "Adding to hidden items : #{hit_entity}"
                            hidden_items << hit_entity
                            hit_points_a << hit_point
                            hit_entity.hidden = true
                        else
                            puts "This is not a valid room entity where the beam can finish."
                            return nil
                        end
                    else
                        puts "Unallowed enity : #{hit_entity}"
                        continue_raytest = false
                    end
                else
                    puts "Nothing hit.Stopping raytest"
                    continue_raytest = false
                end
                count = count+1
                continue_raytest = false if count > 20
            end
            hidden_items.each { |ent| ent.hidden=false}
            puts "hit_points : #{hit_points_a}"
            if hit_points_a.empty?
                puts "No valid entities found in raytest"
                return nil
            else
                return hit_points_a.last, hidden_items.last
            end
        end

        def self.get_outer_walls
            outer_layers = ['RIO_Wall', 'RIO_Window']
            wall_edges 	= Sketchup.active_model.entities.grep(Sketchup::Edge).select{|edge| outer_layers.include?(edge.layer.name)} 
            walls 		= wall_edges.select{|x| x.faces.length == 1}
            walls
        end

        def self.add_perimeter_wall
            outer_walls = get_outer_walls
            wall_width 	= 30.mm 
            wall_height = Sketchup.active_model.get_attribute(:rio_atts, 'last_room_wall_height')
            if wall_height
                outer_walls.each { |wall_edge|
                    verts = wall_edge.vertices
                    
                    clockwise = check_clockwise_edge wall_edge, wall_edge.faces[0]
                    if clockwise
                        pt1, pt2 = verts[0].position, verts[1].position
                    else
                        pt1, pt2 = verts[1].position, verts[0].position
                    end
                    if wall_edge.layer.name == 'RIO_Wall'
                        wall_inst = CivilHelper::place_cuboidal_component(pt2, pt1, comp_height: wall_height, comp_width: wall_width)
						wall_inst.set_attribute(:rio_atts, "perimeter_wall", "true")
						wall_inst.set_attribute(:rio_atts, "block_type", "wall")
						wall_inst.set_attribute(:rio_atts, "edge_id", wall_edge.persistent_id)
						wall_inst.set_attribute(:rio_atts, "wall_height", wall_height)
						wall_inst.set_attribute(:rio_atts, "wall_width", wall_width)
						wall_inst.set_attribute(:rio_atts, "start_point", pt2)
						wall_inst.set_attribute(:rio_atts, "end_point", pt1)
						
						wall_edge.set_attribute(:rio_atts, "perimeter_edge", "true")
                    elsif wall_edge.layer.name == 'RIO_Window'
                        #create_window window_edge, room_face, window_height, window_offset, wall_height
                    end

                }
                return true
            else
                puts "Perimeter wall could not be done. Wall height not found"
                return false
            end
        end
		
		def self.remove_perimeter_wall 
			puts "Removing the perimeter walls....."
			ents = Sketchup.active_model.entities
			ents.grep(Sketchup::ComponentInstance).each{|inst|
				if inst.get_attribute(:rio_atts, "perimeter_wall") == "true"
					ents.erase_entities(inst)
				end
			}
			puts "Perimeter walls removed.."
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
            text_inst.set_attribute(:rio_atts, 'room_name_text', text)
            text_inst
        end

        def self.add_spacetype room_face, room_name
            begin
                model			= Sketchup.active_model
                model.start_operation 'create_floor_group'
                floor_layer		= model.layers.add 'RIO_Floor_'+room_name
                wall_height = room_face.get_attribute(:rio_atts, 'wall_height')

                fcolor    			= Sketchup::Color.new "#23d8d4"
                room_face.material=fcolor
                room_face.back_material=fcolor
                
                prev_active_layer 	= Sketchup.active_model.active_layer.name
                model.active_layer 	= floor_layer
                text_inst 			= add_text_to_face room_face, room_name
                text_inst.set_attribute :rio_atts, 'room_name_text', room_name
                floor_group 		= model.active_entities.add_group(room_face, text_inst)
                floor_group.set_attribute :rio_atts, 'room_name', room_name
                floor_group.set_attribute :rio_atts, 'wall_height', wall_height
                floor_group.set_attribute :rio_atts, 'floor_face_pid', room_face.persistent_id
                Sketchup.active_model.active_layer = prev_active_layer
            rescue Exception=>e 
                Sketchup.active_model.active_layer = prev_active_layer
                raise e
                Sketchup.active_model.abort_operation
            else
                Sketchup.active_model.commit_operation
            end
        end

        def self.delete_spacetype room_name
            all_inst = Sketchup.active_model.entities.grep(Sketchup::ComponentInstance)
            room_group = all_groups.select{|ent| ent.get_attribute(:rio_block_atts, 'room_name') == room_name}[0]
            exploded_entities = room_group.explode
            room_face = exploded_entities.grep(Sketchup::Face)[0]
            room_face.attribute_dictionaries.delete('rio_atts')

            text_inst = exploded_entities.grep(Sketchup::ComponentInstance)
            Sketchup.active_model.entities.erase_entities(text_inst)
        end
        
        def self.create_single_column (column_edge_arr, 
                                        column_face: nil, 
                                        wall_height: 3000.mm,
                                        room_face: nil)
            puts "create_single_column : #{column_edge_arr} : #{column_face}"
            intersect_pt 	    = nil
            corner_column_flag  = false
            #input_face          = @room_face
            column_layer = Sketchup.active_model.layers['RIO_Column']

            
            column_edge_arr.each{|c_edge|
                #puts "c_edge : #{c_edge.layer.name}"
                c_edge.layer=column_layer unless c_edge.layer.name=='RIO_Wall'
            }
            manual_draw = false

            if column_face
                column_edge_arr.select!{|edge| edge.layer.name=='RIO_Column'}
                column_face.edges.each{|col_edge|
                    puts "col_edge.layer.name : #{col_edge.layer.name}"
                    if col_edge.layer.name == 'RIO_Column'
                        col_edge.faces.each{ |col_face|
                        room_face = col_face if col_face.get_attribute(:rio_atts, 'room_name') 
                        }
                    end        
                }
                if room_face
                    puts "Room Face is : #{room_face}"
                    wall_height = room_face.get_attribute(:rio_atts, 'wall_height')
                    manual_draw = true
                else
                    puts "The room face could not be found"
                    return false
                end
            end

            room_name   = room_face.get_attribute(:rio_atts, 'room_name')

            case column_edge_arr.length
            when 1
                #Corner column with only one edge visible
                column_edge = column_edge_arr[0]
                adjacent_edges = CivilHelper::find_edges(column_edge_arr[0], room_face)
                intersect_pt = Geom.intersect_line_line(adjacent_edges[0].line, adjacent_edges[1].line)
                col_verts = column_edge.vertices
                column_face = Sketchup.active_model.entities.add_face(col_verts[0], col_verts[1], intersect_pt)
            when 2
                adjacent_edges = []
                column_edge_arr.each { |column_edge|
                    adjacent_edges << CivilHelper::find_edges(column_edge, room_face)
                }
                #puts "adj : #{adjacent_edges}"
                adjacent_edges.flatten!; adjacent_edges.uniq!
                view_name = []
                adjacent_edges.each{ |a_edge|
                    view_name << a_edge.get_attribute(:rio_edge_atts, 'view_name')
                }
                column_edge_arr.each { |column_edge|
                    column_edge.set_attribute(:rio_edge_atts, 'view_name', view_name)
                }
                intersect_pt = Geom.intersect_line_line(adjacent_edges[0].line, adjacent_edges[1].line)

                common_vertex = column_edge_arr[1].vertices&column_edge_arr[0].vertices
                vert_a = []
                vert_a << column_edge_arr[0].vertices-common_vertex
                vert_a << common_vertex
                vert_a << column_edge_arr[1].vertices-common_vertex
                vert_a << intersect_pt
                
                vert_a.flatten!; vert_a.uniq!

                pts_a = []; vert_a.each{|pt| 
                    pt = pt.position if pt.is_a?(Sketchup::Vertex)
                    pts_a <<  pt
                }
                #pts_a << intersect_pt; 
                pts_a.flatten!; pts_a.uniq!

                column_face = Sketchup.active_model.entities.add_face(pts_a)
                corner_column_flag = true
            when 3
                #This code has been written because the array of edges are not regular....They are not sorted sometimes.

                #Find the center edge
                center_index = 0 if (column_edge_arr[1].vertices&column_edge_arr[2].vertices).empty?
                center_index = 1 if (column_edge_arr[0].vertices&column_edge_arr[2].vertices).empty?
                center_index = 2 if (column_edge_arr[0].vertices&column_edge_arr[1].vertices).empty?
                arr = [0, 1, 2] - [center_index]
                center_edge = column_edge_arr[center_index]

                #Find the common vertex of side edges
                first_common_vertex = column_edge_arr[arr[0]].vertices&center_edge.vertices
                last_common_vertex  = column_edge_arr[arr[1]].vertices&center_edge.vertices

                #FInd the face points
                vert1 = column_edge_arr[arr[0]].vertices - [first_common_vertex[0]];vert1 = vert1[0].position
                vert2 = first_common_vertex.first.position
                vert3 = last_common_vertex.first.position
                vert4 = column_edge_arr[arr[1]].vertices - [last_common_vertex[0]];vert4 = vert4[0].position

                column_face = Sketchup.active_model.entities.add_face(vert1, vert2, vert3, vert4)
            when 4
                #Other columns
                adjacent_edges = []
                column_edge_arr.each { |column_edge|
                    if column_edge.layer.name == 'RIO_Column'
                        adjacent_edges << CivilHelper::find_edges(column_edge, room_face)
                    end
                }

                #puts "adjacent edges : #{adjacent_edges}"
                if adjacent_edges
                    adjacent_edges.flatten!; adjacent_edges.uniq!
                    puts "post adjacent edges : #{adjacent_edges}"
                    sel.add(adjacent_edges)
                    if adjacent_edges.length == 2
                        intersect_pt = Geom.intersect_line_line(adjacent_edges[0].line, adjacent_edges[1].line)
                        adjacent_edges.each { |adj_edge|
                            common_vertex=nil
                            column_edge_arr.each { |col_edge|
                                common_vertex = (col_edge.vertices&adj_edge.vertices)[0]
                                if common_vertex && intersect_pt
                                    puts "intersect pt : #{intersect_pt} : #{common_vertex}"
                                    Sketchup.active_model.entities.add_line(intersect_pt, common_vertex.position)
                                    break
                                end
                            }
                        }
                        column_edge_arr.each {|column_edge|
                            column_edge.find_faces
                        }
                        faces = column_edge_arr[0].faces
                        column_edge_arr.each {|column_edge|
                            faces = faces&(column_edge.faces-[room_face])
                        }
                        column_face = faces[0]
                    else
                        puts "4 : Something wrong with the adjacent edges"
                    end
                end

            else
                puts "Column edges more than 4 not supported."
            end
            column_edge_arr.each {|column_edge|
                column_edge.find_faces
            }

            #puts "column_face : #{column_face}"
            
            if column_face
                sel.clear
                sel.add(column_face)
                offset_pts = []
                column_face.edges.each{ |edge|
                    edge.layer.name='RIO_Wall' if edge.layer.name != 'RIO_Column'
                }
                column_face.vertices.each{|vert|
                    #puts "vert : #{vert} : #{vert.position} : #{wall_height}"
                    offset_pts << vert.position.offset(Z_AXIS, wall_height)
                }
                prev_ents = Sketchup.active_model.entities.to_a
                new_face = Sketchup.active_model.entities.add_face(offset_pts)
                #puts "new_face normal : #{new_face.normal}"
                new_face.reverse! if new_face.normal.z < 0
                pushpull_height = wall_height-(0.1.mm)
                new_face.pushpull(-pushpull_height, false)
                puts "changing pushpull"
                curr_ents = Sketchup.active_model.entities.to_a
                #puts "new_face normal after: #{new_face.normal}"
                new_ents = curr_ents - prev_ents
                new_ents = new_ents - [new_face]
                Sketchup.active_model.entities.erase_entities(new_face)
                column_group = Sketchup.active_model.entities.add_group(new_ents)
                column_group.layer = Sketchup.active_model.layers['RIO_Civil_Column']
                comp_inst = column_group.to_component
                
                #Find view for manual draw
                #puts "manual : #{manual_draw}"
                if manual_draw
                    unless view_name
                        #puts "view_name : #{view_name} : #{view_name.nil?}"
                        view_name  = []
                        room_entities = get_room_civil_entities room_name
                        #puts "room_entities : #{room_entities}"
                        room_entities.select{|ent| ent.layer.name=='RIO_Civil_Wall'}.each { |room_ent|
                            #puts "Room ent : #{room_ent} : #{comp_inst.bounds.intersect(room_ent.bounds).diagonal}"
                            if comp_inst.bounds.intersect(room_ent.bounds).diagonal > 0
                                view_name << room_ent.get_attribute(:rio_block_atts, 'view_name') 
                            end
                        }
                    end
                    #puts "view_name : #{view_name}"
                    if view_name
                        view_name = view_name[0] if view_name.length==1
                    end
                end
                
                sel.clear
                #Set attributes
                view_name = column_edge_arr[0].get_attribute(:rio_edge_atts, 'view_name') unless view_name
                comp_inst.set_attribute(:rio_block_atts, 'corner_column_flag', corner_column_flag)
                comp_inst.set_attribute(:rio_block_atts, 'block_type', 'column')
                comp_inst.set_attribute(:rio_block_atts, 'view_name', view_name)
                comp_inst.set_attribute(:rio_block_atts, 'edge_id', column_edge_arr[0].persistent_id)
                comp_inst.set_attribute(:rio_block_atts, 'room_name', room_name)
                comp_inst.set_attribute(:rio_block_atts, 'wall_block', 'true')
                return comp_inst
            end
            return nil
        end

        def self.wall_comp_placement selected_wall, comp
            unless selected_wall
                puts "WALL PLACEMENT : Wall not properly selected"
                return false
            end
            unless comp
                puts "WALL PLACEMENT : component not properly selected"
                return false
            end
            view_name = selected_wall.get_attribute(:rio_block_atts, 'view_name')
            unless view_name
                puts "WALL PLACEMENT : Wall doesnt have a view"
                return false
            end
            room_name = selected_wall.get_attribute(:rio_block_atts, 'room_name')
            unless room_name
                puts "WALL PLACEMENT : Room name not available"
            end
            room_entities_a = get_view_entities room_name
            view_entities   = room_entities_a[view_name]
            if view_entities.nil? || view_entities.empty?
                puts "WALL PLACEMENT : No entities available for this view"
            end

            return true
        end 

        def self.check_door_windows comp_inst, room_name
            model = Sketchup.active_model
            wall_id = model.get_attribute :rio_atts, 'wall_id'
            wall_component = get_comp_pid(wall_id)
            if wall_component
                view_name = wall_component.get_attribute(:rio_block_atts, 'view_name')
                civil_entities = get_view_entities room_name
                puts "view_ocmp : #{civil_entities} : #{view_name}"
                view_entities   = civil_entities[view_name]
                door_entities = view_entities.select{|view_ent| view_ent.get_attribute(:rio_block_atts, 'block_type') == 'wall'}
                comp_facing_vector = wall_component.get_attribute(:rio_block_atts, 'towards_wall_vector')
                
                cbounds = comp_inst.bounds
                corners = RIO::DirectionHelper::get_component_corners(comp_inst)
                back_center =  Geom.linear_combination(0.5, cbounds.corner(corners[3]), 0.5, cbounds.corner(corners[6]))
                back_corners = [
                                    back_center,
                                    cbounds.corner(corners[2]), 
                                    cbounds.corner(corners[3]),
                                    cbounds.corner(corners[6]),
                                    cbounds.corner(corners[7])
                                ]
                back_corners.each{|comp_pt|
                    hit_item = model.raytest(comp_pt, comp_facing_vector.reverse)
                    #puts "hit_item : #{hit_item}"
                    if hit_item 
                        hit_comp = hit_item[1][0]
                        if hit_comp.is_a?(Sketchup::ComponentInstance)
                            #sel.add(hit_comp)
                            #puts "id : #{hit_comp.persistent_id}"
                            block_type = hit_comp.get_attribute(:rio_block_atts, 'block_type')
                            #puts "Hit entity : #{hit_item[1][0]} : #{block_type}"
                            if block_type=="window"
                                UI.messagebox "Window behind the component"
                                Sketchup.active_model.entities.erase_entities comp_inst
                                sel.add(hit_comp)
                                return false
                            elsif block_type=="door"
                                UI.messagebox "Door behind the component."
                                Sketchup.active_model.entities.erase_entities comp_inst
                                sel.add(hit_comp)
                                return false
                            end
                        end
                    end
                }                              
            else
                puts "Wall component not found. Door & window check could not be done. Please do manual check."
                return false
            end
            return true
        end

        def self.check_room_bounds comp_inst, room_name
            room_face = get_room_face room_name
            comp_bounds = comp_inst.bounds

            floor_height    = room_face.local_transformation.origin.z
            comp_height     = comp_inst.transformation.origin.z
            puts "room_face : #{room_face}"
            if comp_height < floor_height
                puts "Component cannot go below floor"
                return false
            end

            intxn = comp_bounds.intersect(room_face.bounds)
            if intxn.diagonal > 1.mm
                puts "Component touches the floor"
                return true
            end

            comp_entities = get_room_comp_entities room_name
            comp_entities.each {|ent| ent.visible=false}

            civil_entities = get_room_civil_entities room_name
            civil_entities.each {|ent| ent.visible=false}

            corners = RIO::DirectionHelper::get_component_corners comp_inst
            # down_face_corners = [
            #                         comp_bounds.corner(corners[0]), 
            #                         comp_bounds.corner(corners[1]),
            #                         comp_bounds.corner(corners[2]),
            #                         comp_bounds.corner(corners[3])
            #                     ]
            raytest_pts = RIO::SketchupHelper::get_comp_raytest_points comp_inst

            bounds_check = true
            raytest_pts.each {|corner_pt|
                hit_item = Sketchup.active_model.raytest(corner_pt, Z_AXIS.reverse)
                if hit_item
                    if hit_item[1][0]!=room_face
                        #sel.add(hit_item[1][0])
                        sel.clear
                        sel.add(room_face)
                        UI.messagebox "Component not within bounds : #{hit_item[1][0].persistent_id} : #{room_face.persistent_id}"
                        Sketchup.active_model.entities.erase_entities(comp_inst)
                        bounds_check = false
                        break
                    end
                end
            }

            comp_entities.each {|ent| 
                ent.visible=true if ent && !ent.deleted?
            }
            civil_entities.each {|ent| 
                ent.visible=true if ent && !ent.deleted?
            }
            return bounds_check
        end

        def self.do_manifold_check entity1, entity2
            begin
                puts "do_manifold_check : #{entity1} : #{entity2}"
                model           = Sketchup.active_model
                overlap_flag    = false
                model.start_operation("Manifold check")
                continue_flag = false
                if entity1.is_a?(Sketchup::ComponentInstance) && entity2.is_a?(Sketchup::ComponentInstance)
                    continue_flag = true
                end
                return false unless continue_flag
                z_offset_for_test = 20000.mm
                manifold_group1 = SketchupHelper::get_manifold_group(entity1, z_offset_for_test)
                manifold_group2 = SketchupHelper::get_manifold_group(entity2, z_offset_for_test)
                algorithm_flag = 1
                case algorithm_flag
                when 1
                    comp1   = manifold_group1.to_component
                    comp2   = manifold_group2.to_component
                    intxn   = comp1.intersect(comp2)
                    puts "intxn : #{intxn} : #{intxn.volume}" if intxn
                    if intxn && intxn.volume > 1
                        sel.add(entity2)
                        overlap_flag = true
                    end
                when 2
                    total_faces     = manifold_group1.entities.grep(Sketchup::Face).length + manifold_group2.entities.grep(Sketchup::Face).length
                    shell_group     = manifold_group1.outer_shell(manifold_group2)
                    if shell_group
                        puts "shell_group.entities : #{shell_group.entities.to_a}"
                        shell_faces     = shell_group.entities.grep(Sketchup::Face).length
                        puts "Shell faces : #{shell_faces} : #{total_faces}"
                        if shell_faces != total_faces
                            sel.add(entity2)
                            puts "The #{entity2} is overlapping"
                            overlap_flag = true
                        end
                    end
                end
                Sketchup.active_model.abort_operation
                return overlap_flag
            rescue Exception=>e 
                raise e
                Sketchup.active_model.abort_operation
                return overlap_flag
            else
                Sketchup.active_model.abort_operation
                return overlap_flag
            end
        end

        #Check if the component is properly placed
        def self.check_component_placement comp_inst, room_name
            args = method(__method__).parameters.map { |arg| arg[1].to_s }
            puts args.map { |arg| "#{arg} = #{eval arg}" }.join(', ')

            room_entities   = get_room_civil_entities(room_name)
            comp_entities   = get_room_comp_entities(room_name)

            comp_bounds = comp_inst.bounds

            if !room_entities.empty?
                room_entities.each{ |room_entity|
                    next if room_entity.deleted?
                    intersect_bounds = comp_bounds.intersect(room_entity.bounds)
                    #puts "intersect_bounds.diagonal : #{intersect_bounds.diagonal}"
                    if intersect_bounds.valid?
                        slope_flag = true
                        if slope_flag
                            room_face = get_room_face(room_name)
                            room_face.visible = false
                            wall_overlap_flag = do_manifold_check room_entity, comp_inst
                            room_face.visible = true
                            if wall_overlap_flag
                                sel.clear
                                entity_type = room_entity.get_attribute(:rio_block_atts, 'block_type')
                                resp = UI.messagebox "Component Overlaps #{entity_type}. Removing Component"
                                Sketchup.active_model.entities.erase_entities comp_inst
                                sel.add(room_entity)
                                return false
                            end 
                        else    
                            intersect_volume = intersect_bounds.width * intersect_bounds.depth * intersect_bounds.height
                            puts "intersect_volume : #{intersect_volume}"
                            if intersect_volume > 1.mm
                                sel.clear
                                entity_type = room_entity.get_attribute(:rio_block_atts, 'block_type')
                                UI.messagebox "Component Overlaps this #{entity_type}"
                                Sketchup.active_model.entities.erase_entities comp_inst
                                sel.add(room_entity)
                                return false
                            end
                        end
                    end
                }
            end
            puts "Not intersecting with any civil components------------------------------"

            #****************************************************************************            
            if !comp_entities.empty?
                comp_entities = comp_entities-[comp_inst]
                puts "comp_entities : #{comp_entities}"
                comp_entities.each{ |comp_entity|
                    intersect_bounds = comp_bounds.intersect(comp_entity.bounds)
                    puts "Comp : intersect_bounds.diagonal : #{intersect_bounds.diagonal} : #{comp_entity}"
                    if intersect_bounds.valid?
                        slope_flag = true
                        if slope_flag
                            wall_overlap_flag = do_manifold_check comp_entity, comp_inst
                            if wall_overlap_flag
                                entity_type = comp_entity.get_attribute(:rio_block_atts, 'block_type')
                                UI.messagebox "Cannot place.Overlaps this RIO Component"
                                Sketchup.active_model.entities.erase_entities comp_inst
                                return false
                            end 
                        else
                            intersect_volume = intersect_bounds.width * intersect_bounds.depth * intersect_bounds.height
                            puts "intersect_volume : #{intersect_volume}"
                            if intersect_volume > 1.mm
                                sel.clear
                                UI.messagebox "New Component Overlaps the selected component"
                                Sketchup.active_model.entities.erase_entities comp_inst
                                sel.add(comp_entity)
                                return false
                            end
                        end
                    end
                }
            end

            puts "Not intersecting with any RIO components-------------------------------"

            #****************************************************************************
            puts "Checking doors and windows...."
            door_window_flag = check_door_windows(comp_inst, room_name)
            puts "Doors window : #{door_window_flag}"
            return door_window_flag unless door_window_flag

            #****************************************************************************
            puts "Checking room bounds"
            room_bounds_flag = check_room_bounds comp_inst, room_name

            return room_bounds_flag
        end
        
        #Input a fully created component and location
        def self.place_component comp_defn, placement_type='manual', placement_location=nil
            if comp_defn.nil?
                puts "Component definition is mandatory"
            end

            case placement_type
            when 'manual'
                comp_inst = Sketchup.active_model.entities.place_component comp_defn
            when 'wall'
                model               = Sketchup.active_model
                wall_offset_point   = model.get_attribute(:rio_atts, 'wall_offset_pt')
                movement_vector     = model.get_attribute(:rio_atts, 'movement_vector')
                wall_side           = model.get_attribute(:rio_atts, 'wall_side')
                room_name           = model.get_attribute(:rio_atts, 'room_name')
                
                from_floor          = model.get_attribute(:rio_atts, 'from_floor')
                wall_id             = model.get_attribute(:rio_atts, 'wall_id')

                wall_height         = model.get_attribute(:rio_atts, 'wall_height')


                unless wall_offset_point
                    puts "Wall offset point not found"
                    return false
                end  
                wall_trans = $rio_wall_trans
                unless wall_trans
                    puts "Wall transformation is missing"
                    return false
                end

                puts "Wall offset point : #{wall_offset_point} : #{wall_trans}"
                #comp_inst = Sketchup.active_model.active_entities.add_instance(comp_defn, wall_trans)

                extra_distance  = 0.mm
                temp_inst       = Sketchup.active_model.active_entities.add_instance comp_defn, ORIGIN
                move_distance   = temp_inst.bounds.height+extra_distance
                if wall_trans.rotz%90 != 0
                    #move_distance += 50.mm
                end
                comp_width      = temp_inst.bounds.width
                comp_height     = temp_inst.bounds.depth
                Sketchup.active_model.entities.erase_entities temp_inst

                comp_top = from_floor+comp_height
                if comp_top>wall_height
                    UI.messagebox "Placing the component at this height will hit the ceiling"
                    return false
                end
                wall_vector     = Sketchup.active_model.get_attribute :rio_atts, 'wall_vector'
                puts "wall_offset_point : #{wall_offset_point}"
                if wall_side=='right'
                    wall_offset_point.offset!(wall_vector.reverse, comp_width)
                end
                puts "right wall_offset_point : #{wall_offset_point}"

                tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, wall_trans.rotz.degrees)
                comp_inst    = Sketchup.active_model.active_entities.add_instance comp_defn, tr
                
                puts "movement_vector : #{movement_vector} : #{move_distance}"
                placement_point = wall_offset_point.offset(movement_vector, move_distance)
                comp_placement_trans = Geom::Transformation.new(placement_point)
                comp_inst.transform!(comp_placement_trans) 

                comp_inst.set_attribute(:rio_comp_atts, 'room_name', room_name)
                comp_inst.set_attribute(:rio_comp_atts, 'wall_id', wall_id)
                #comp_inst.set_attribute(:rio_comp_atts, '', )

                comp_flag = check_component_placement(comp_inst, room_name)
                if comp_flag
                    puts "Component placed successfully"
                end
            end
            Sketchup.active_model.layers.add('RIO_Lib_Comp') if Sketchup.active_model.layers['RIO_Lib_Comp'].nil?
            if comp_inst && !comp_inst.deleted?
                comp_inst.layer.name = 'RIO_Lib_Comp'
                comp_inst.set_attribute(:rio_comp_atts, 'rio_comp', 'true')
                return comp_inst
            end
            return false
        end

        def self.get_room_face room_name
            all_faces = Sketchup.active_model.entities.select{|ent| ent.is_a?(Sketchup::Face)}
            room_face = all_faces.select{|face_ent| face_ent.get_attribute(:rio_atts, 'room_name')==room_name}.sort_by!{|fc| -fc.area}.first
            room_face
        end

        def self.get_comp_pid persistent_id
            Sketchup.active_model.entities.each{|x| return x if x.persistent_id == persistent_id};
            return nil;
        end

        #To check the location of the entered value
        def self.get_comp_location selected_wall, relative_distance, from_floor, from_side='left'
            args = method(__method__).parameters.map { |arg| arg[1].to_s }
            puts args.map{ |arg| "get_comp_locn #{arg} = #{eval arg}" }.join(', ')

            #Input checks
            unless selected_wall
                puts "WALL PLACEMENT : Wall not properly selected"
                return false
            end

            # unless wall_component
            #     puts "No Component selected"
            #     return false
            # end

            unless relative_distance&&from_floor
                puts "Distance from the corner and from the floor is required"
                return false
            end

            view_name = selected_wall.get_attribute(:rio_block_atts, 'view_name')
            unless view_name
                puts "WALL PLACEMENT : Wall doesnt have a view"
                return false
            end

            room_name = selected_wall.get_attribute(:rio_block_atts, 'room_name')
            unless room_name
                puts "WALL PLACEMENT : Room name not available"
                return false
            end

            towards_wall_vector = selected_wall.get_attribute(:rio_block_atts, 'towards_wall_vector')
            unless towards_wall_vector
                puts "WALL PLACEMENT ; Towards wall vector not available"
                return false
            end

            room_face = get_room_face(room_name)
            unless room_face||room_face.is_a?(Sketchup::Face)
                puts "Room face not found"
                return false
            end

            room_entities_a = get_view_entities room_name
            view_entities   = room_entities_a[view_name]
            if view_entities.empty?
                puts "No view entities found"
                return false
            end

            sorted_entities, start_index    = RIO::DirectionHelper::sort_wall_items view_entities, towards_wall_vector, from_side
            first_entity = sorted_entities.first

            wall_start_point                = first_entity.bounds.corner(start_index)
            first_defn = first_entity.definition
            unless first_defn
                puts "The component definition could not be found."
                return false
            end
            bbox = first_defn.bounds
            if from_side=='left'
                wall_start_point    = bbox.corner(0).transform(first_entity.transformation) 
            else
                wall_start_point    = bbox.corner(1).transform(first_entity.transformation) 
            end
            puts first_entity.persistent_id
            puts "att_type : #{first_entity.get_attribute(:rio_block_atts, 'wall_type')}"
            if first_entity.get_attribute(:rio_block_atts, 'wall_type') == 'door_wall'
                wall_width = first_entity.get_attribute(:rio_block_atts, 'entity_width')
                puts "wall_width : #{wall_width}"
                #wall_start_point.offset!(towards_wall_vector, wall_width)
            end
            start_pt    = selected_wall.get_attribute(:rio_block_atts, 'start_point')
            end_pt      = selected_wall.get_attribute(:rio_block_atts, 'end_point')
            wall_directional_vector = start_pt.vector_to end_pt
            wall_directional_vector.reverse! if from_side=="right"

            offset_point    = wall_start_point.offset(wall_directional_vector, relative_distance)
            offset_point.z  = from_floor 
            return offset_point
        end
    end
end
