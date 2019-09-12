module RioIntDim
    extend self
	extend DP
	
    sk_ents         = Sketchup.active_model.entities
    selected_comp   = fsel
    @parent_sub_comps = []
    @visible_comps  = []
    #COMP_DIMENSION_OFFSET   = 2000.mm #unless defined?(COMP_DIMENSION_OFFSET)

    def set_visible_comps comp, parent=nil
        @visible_comps << [comp, parent]
    end

    def unset_visible_comps
        @visible_comps=[]
    end

    def get_visible_comps
        @visible_comps
    end

    def get_face_edge_vectors face
        face_edges  = face.outer_loop.edges
        edge_array = []
        (0..face_edges.length-1).each{ |index|
            curr_edge = face_edges[index]
            next_egde = face_edges[index-1]

            common_vertex 	= (curr_edge.vertices & next_egde.vertices)[0]
            other_vertex    = curr_edge.vertices - [common_vertex]
            other_vertex    = other_vertex[0]

            vector  = common_vertex.position.vector_to other_vertex
            pt 		= next_egde.bounds.center.offset vector, 10.mm
            res  	= face.classify_point(pt)

            if res == Sketchup::Face::PointInside || res == Sketchup::Face::PointOnFace
                vector = vector.reverse
            end
            edge_array << [curr_edge, vector]
        }
        edge_array
    end

    def get_face_perpendicular_edge_vector face
        face_edges  = face.outer_loop.edges
        edge_array = []
        (0..face_edges.length-1).each{ |index|
            curr_edge = face_edges[index]
            next_edge = face_edges[index-1]
            vector = next_edge.line[1]

            pt 		= curr_edge.bounds.center.offset vector, 10.mm
            res  	= face.classify_point(pt)
            if res == Sketchup::Face::PointInside || res == Sketchup::Face::PointOnFace
                vector = vector.reverse
            end
            edge_array << [curr_edge, vector]
        }
        edge_array
    end

    def get_edge_vectors face
        face_edges  = face.outer_loop.edges

        edges_arr = []
        face_edges.each{|edge| edges_arr << edge}

        edges_arr.length.times {|index|
            curr_edge 	=  	edges_arr[0]
            next_edge 	=	edges_arr[1]
            if MRP::check_perpendicular(curr_edge, next_edge)
                break
            else
                edges_arr.rotate!
            end
        }

        #Start with the perpendicular edge
        edges_arr.rotate!

        edge_list  	= []
        last_edge 	= nil
        vector 		= nil
        first_edge  = edges_arr[0]


        face_edges.each{|edge|
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

                    #puts "edge_list #{edge_list} : #{vector}"
                    edge_list = [curr_edge]
                    last_edge = curr_edge
                else
                    edge_list << curr_edge
                    last_edge = curr_edge
                end
            end
        }

    end

    def add_extra_offset_lines face, offset_distance
        sk_ents     = Sketchup.active_model.entities
        edge_arr    = get_face_perpendicular_edge_vector face
        edge_arr.each{ |edge_pair|
            face_edge, offset_vector = edge_pair
            edge_vertices = face_edge.vertices
            edge_vertices.each { |edge_vert|
                current_pt = edge_vert.position
                offset_pt = current_pt.offset(offset_vector, offset_distance.mm)
                sk_ents.add_line(current_pt, offset_pt)
            }
        }
    end

    def add_extra_offset_faces face, offset_distance
        sk_ents     = Sketchup.active_model.entities
        edge_arr    = get_face_perpendicular_edge_vector face
        edge_arr.each{ |edge_pair|
            face_edge, offset_vector = edge_pair
            next if offset_vector.z != 0
            edge_vertices = face_edge.vertices
            pt1 = edge_vertices[0]
            pt2 = edge_vertices[1]
            pt3 = pt2.position.offset(offset_vector, offset_distance.mm)
            pt4 = pt1.position.offset(offset_vector, offset_distance.mm)
            offset_face = sk_ents.add_face(pt1, pt2, pt3, pt4)
            offset_face.set_attribute(:rio_atts, 'offset_face', true)
        }

    end

    def traverse_comp(entity, transformation = IDENTITY)
        #puts "Entity type : #{entity}"
        if entity.is_a?( Sketchup::Model)
            entity.entities.each{ |child_entity|
                traverse_comp(child_entity, transformation)
            }
        elsif entity.is_a?(Sketchup::Group)
            if entity.attribute_dictionaries
                if entity.attribute_dictionaries['rio_atts']
                    if entity.attribute_dictionaries['rio_atts']['inner_dimension_visible_flag']
                        set_visible_comps(entity, entity.parent)
                    end
                end
            end
            transformation *= entity.transformation
            entity.definition.entities.each{ |child_entity|
                traverse_comp(child_entity, transformation.clone)
            }
        elsif entity.is_a?(Sketchup::ComponentInstance)
            transformation *= entity.transformation
            entity.definition.entities.each{ |child_entity|
                traverse_comp(child_entity, transformation.clone)
            }
        elsif entity.is_a?(Sketchup::Face)
            #puts "Face : "
        end
    end

    def traverse_top_comp(entity, transformation = IDENTITY)
        #puts "Entity type : #{entity}"
        if entity.is_a?( Sketchup::Model)
            entity.entities.each{ |child_entity|
                traverse_top_comp(child_entity, transformation)
            }
        elsif entity.is_a?(Sketchup::Group)
            if entity.attribute_dictionaries
                if entity.attribute_dictionaries['rio_atts']
                    puts "entity.attribute_dictionaries['rio_atts'] : #{entity.attribute_dictionaries['rio_atts']}"
                    if entity.attribute_dictionaries['rio_atts']['top_outline_visible_flag']
                        set_visible_comps(entity, entity.parent)
                    end
                end
            end
            transformation *= entity.transformation
            entity.definition.entities.each{ |child_entity|
                traverse_top_comp(child_entity, transformation.clone)
            }
        elsif entity.is_a?(Sketchup::ComponentInstance)
            transformation *= entity.transformation
            entity.definition.entities.each{ |child_entity|
                traverse_top_comp(child_entity, transformation.clone)
            }
        elsif entity.is_a?(Sketchup::Face)
            #puts "Face : "
        end
    end

    #For side norm components
    def set_norm_dimension face
        pt1 = face.bounds.corner(0)
        pt2 = face.bounds.corner(4)
        distance = pt1.distance pt2
        if distance > 18.mm
            trans_hash = DP::get_transformation_hash
            front_vector = trans_hash[:front_dim_vector].clone
            front_vector.length=100.mm
            dim_l = Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, front_vector)
            dim_l.material.color = 'red'
        end
        pt1 = face.bounds.corner(0)
        pt2 = face.bounds.corner(1)
        distance = pt1.distance pt2
        if distance > 18.mm
            trans_hash = DP::get_transformation_hash
            front_vector = Z_AXIS.clone
            front_vector.length=100.mm
            dim_l = Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, front_vector)
            dim_l.material.color = 'red'
        end
    end

    def add_depth_dimension entity, rotz=nil
        index_arr = [0,4]
        rotz = entity.transformation.rotz unless rotz

        pt1 = TT::Bounds.point(entity.bounds, 0)
        pt2 = TT::Bounds.point(entity.bounds, 4)
        distance = pt1.distance pt2
        if distance > 99.mm
            #pt1.z    += 5000.mm; pt2.z    += 5000.mm
            trans_hash = DP::get_transformation_hash(rotz)
            front_vector = trans_hash[:int_dim_vector].clone
            #puts "front_vector : #{front_vector} : #{rotz}"
            front_vector.length=100.mm
            dim_l = Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, front_vector)
            #dim_l.material.color = 'red'
            dim_l.arrow_type = Sketchup::Dimension::ARROW_CLOSED
        end
    end

    def find_sub_components(entity, transformation = IDENTITY)
        #puts "Entity type : #{entity}"
        if entity.is_a?( Sketchup::Model)
            entity.entities.each{ |child_entity| find_sub_components(child_entity, transformation) }
        elsif entity.is_a?(Sketchup::Group)
            transformation *= entity.transformation
            entity.definition.entities.each{ |child_entity| find_sub_components(child_entity, transformation.clone)}
        elsif entity.is_a?(Sketchup::ComponentInstance)
            @parent_sub_comps << entity
            transformation *= entity.transformation
            entity.definition.entities.each{ |child_entity| find_sub_components(child_entity, transformation.clone)}
        end
    end

    def find_actual_component parent, sub_comp
        @parent_sub_comps = []
        find_sub_components(parent)
        ent_trans = Geom::Transformation.new(sub_comp.bounds.corner(0))
        new_trans = ent_trans * parent.transformation
        #puts "new_trans : #{new_trans.origin}"
        @parent_sub_comps
        actual_comp = @parent_sub_comps.select{ |parent_scomp| parent_scomp.bounds.corner(0) == new_trans.origin}[0]
        #puts "actual_comp : #{actual_comp}"
        actual_comp
    end

    def add_internal_outlines input_comp
        visible_layers      = ['SHELF_FIX', 'SHELF_NORM', 'SHELF_INT', 'SIDE_NORM', 'DRAWER_FRONT']
        comp_trans          = input_comp.transformation
        comp_origin         = comp_trans.origin

        trans_hash      = RioIntDim::get_transformation_hash(comp_trans.rotz)

        front_bounds    = trans_hash[:front_bounds]
        front_vector    = trans_hash[:front_side_vector]
        front_all_sides = trans_hash[:front_all_points]
        setx_flag       = trans_hash[:set_x]
        sety_flag       = trans_hash[:set_y]

        comp_edges = []

        RioIntDim::unset_visible_comps #Remove riodim
        #puts "visible_comps : #{get_visible_comps}"

        RioIntDim::traverse_comp(input_comp)
        visible_comps = RioIntDim::get_visible_comps #Remove riodim
        puts "visible_comps : #{visible_comps}"

        defn_hash = {}
        input_comp.definition.entities.each{|ent|
            defn_hash[ent.definition.name] = ent.transformation
        }

        extra_line_layers = ['SHELF_FIX', 'SHELF_INT', 'DRAWER_FRONT']
        visible_comps.each{ |visible_comp, parent|
            actual_comp     = find_actual_component input_comp, visible_comp
            comp_bbox       = visible_comp.bounds
            visible_comp_trans_hash      = DP::get_transformation_hash(comp_trans.rotz)
            front_bounds    = visible_comp_trans_hash[:front_bounds]

            #puts "front_bounds : #{front_bounds} : #{visible_comp.parent.name} : #{parent.name}"
            front_bounds = [0, 1, 5, 4]
            face_pts = []
            #puts "defn_hash : #{defn_hash}"
            original_transformation = comp_trans * defn_hash[parent.name]
            #puts "trans2 : #{original_transformation.origin} : #{defn_hash[parent.name].origin}"
            front_bounds.each{ |index|
                pt = comp_bbox.corner(index)
                # original_transformation = comp_trans * Geom::Transformation.new(pt)
                # puts "bounds point : #{pt}"

                res_vector              = pt.vector_to(original_transformation.origin)
                original_point          = Geom::Point3d.new(res_vector.to_a)
                #original_point = original_transformation.origin
                pt_trans                = original_transformation * Geom::Transformation.new(pt)
                original_point          = pt_trans.origin

                #puts "original_point : #{original_point} : #{original_transformation.origin}"
                # original_point.x += pt.x
                # original_point.y += pt.y
                # original_point.z += pt.z

                #puts "setx : #{setx_flag} : #{sety_flag}"
                #original_point = comp_bbox.corner(index)
                if setx_flag
                    original_point.x = MRP::COMP_DIMENSION_OFFSET-10.mm
                elsif sety_flag
                    original_point.y = MRP::COMP_DIMENSION_OFFSET-10.mm
                end
                #original_point.y = 0.mm
                #puts original_point
                #original_point.z += 5000.mm
                #pt = 0.000000;original_point.y     = pt.mm
                #original_point = pt
                face_pts << original_point
            }

            ent_layer_name      = visible_comp.layer.name
            ent_layer_ending    = ent_layer_name.split('_IM_')[1]

            puts "face_pts : #{face_pts}"
            visible_face = Sketchup.active_model.entities.add_face(face_pts)

            if ent_layer_ending == 'DRAWER_FRONT'
                visible_face.set_attribute(:rio_atts, 'drawer_face', true)
                add_extra_offset_faces visible_face, 1
                add_depth_dimension visible_face, comp_trans.rotz
            elsif ent_layer_ending == 'SHELF_INT'
                visible_face.set_attribute(:rio_atts, 'shelf_face', true)
                add_extra_offset_faces visible_face, 0.5
            elsif ent_layer_ending == 'SHELF_FIX' || ent_layer_ending == 'SHELF_NORM'
                visible_face.set_attribute(:rio_atts, 'shelf_face', true)
            elsif ent_layer_ending =='SIDE_NORM'
                visible_face.set_attribute(:rio_atts, 'side_norm_face', true)
                #set_norm_dimension visible_face
            end

            comp_edges << visible_face.edges
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
        puts "newer : #{newer_ents}"

        newer_ents.select!{|x| x.is_a?(Sketchup::Face)}
        newer_ents.each{|ent_face| add_depth_dimension(ent_face, comp_trans.rotz)}

    end

    def add_internal_gaps comp
    end

    def add_internal_dimensions comp
    end

    def add_top_outlines input_comp
        puts "add_top_outlines : #{input_comp}"
        visible_layers      = ['SHELF_FIX', 'SHELF_NORM', 'SHELF_INT', 'SIDE_NORM']
        comp_trans          = input_comp.transformation
        comp_origin         = comp_trans.origin

        trans_hash      = RioIntDim::get_transformation_hash(comp_trans.rotz)

        comp_edges = []
        defn_hash = {}
        input_comp.definition.entities.each{|ent|
            defn_hash[ent.definition.name] = ent.transformation
        }

        RioIntDim::unset_visible_comps
        RioIntDim::traverse_top_comp(input_comp)
        visible_comps = RioIntDim::get_visible_comps #Remove riodim

        top_bounds  = [4,5,7,6]
        face_pts    = []
        visible_comps.each do |visible_comp, parent|
            comp_bbox       = visible_comp.bounds
            original_transformation = comp_trans * defn_hash[parent.name]

            ent_layer_name      = visible_comp.layer.name
            ent_layer_ending    = ent_layer_name.split('_IM_')[1]

            face_pts = []
            top_bounds.each{ |index|
                pt = comp_bbox.corner(index)
                offset_pt = pt.offset(Z_AXIS, 5000.mm)
                pt_trans                = original_transformation * Geom::Transformation.new(pt)
                original_point          = pt_trans.origin
                original_point.z += 5000.mm
                face_pts << original_point
            }
            puts "face_pts : top : #{face_pts}"
            visible_face = Sketchup.active_model.entities.add_face(face_pts)
            visible_face_bounds = visible_face.bounds
            if ent_layer_ending.end_with?('SHELF_FIX')
                dim_l = Sketchup.active_model.entities.add_dimension_linear(visible_face_bounds.corner(0), visible_face_bounds.corner(1), Y_AXIS)
                dim_l.material.color = 'red'
                dim_l = Sketchup.active_model.entities.add_dimension_linear(visible_face_bounds.corner(1), visible_face_bounds.corner(3), X_AXIS.reverse)
                dim_l.material.color = 'red'
            end
        end
        RioIntDim::unset_visible_comps
    end

end
