# Namespace for RIO Sketchup 
# @since 3.0.0  
module RIO
	# module for Sketchup Helper methods
	# @since 3.0.0
    module SketchupHelper
		# The Method to check if two edges are perpendicular
		# @author VG
        def self.check_perpendicular edge1, edge2
            angle 	= edge1.line[1].angle_between edge2.line[1] 
            angle 	= angle*(180/Math::PI)
            return true if angle.round == 90
            return false
        end

        #Angle between the edges with repsect to the face.
        def self.angle_between_face_edges edge1, edge2, normal
            valid_edges = false
            if edge1 && edge1.is_a?(Sketchup::Edge)
                if edge2 && edge2.is_a?(Sketchup::Edge)
                    if normal && normal.is_a?(Geom::Vector3d)
                        valid_edges = true 
                    end
                end
            end
            if valid_edges
                vector1 = edge1.line[1]
                vector2 = edge2.line[1]
                cross = vector1 * vector2
                direction = cross % normal
                angle = vector1.angle_between( vector2 )
                angle = 360.degrees - angle if direction > 0.0
                return angle
            end
            RIODEBUG("Invalid parameters : angle_between_face_edges #{edge1} : #{edge2} : #{normal}")
            return false
        end

        #Method to get the adjacent edges of the edge within the face
        def self.get_adjacent_edges input_edge, input_face 
            adjacent_edges  = []
            iedge_vertices  = input_edge.vertices
            other_edges     = input_face.edges - [input_edge]
            other_edges.each { |oedge|
                adjacent_edges << oedge if(oedge.vertices && iedge_vertices)
            }
            return adjacent_edges
        end

        def self.get_current_entities
            Sketchup.active_model.entities.to_a
        end
        
        def self.get_comp_pid id;
            Sketchup.active_model.entities.each{|x| return x if x.persistent_id == id};
            return nil;
        end

        def self.check_params
            #Link : https://stackoverflow.com/questions/9211813/is-there-a-way-to-access-method-arguments-in-ruby
            args = method(__method__).parameters.map { |arg| arg[1].to_s }
            logger.error "Method failed with " + args.map { |arg| "#{arg} = #{eval arg}" }.join(', ')
        end

        def self.get_corner_points comp_inst
            defn        = comp_inst.definition
            inst_trans  = comp_inst.transformation

            actual_bounds   = defn.bounds
            comp_height     = actual_bounds.corner(4).z
            
            pts = []
            (0..7).each {|index|
                bound_pt    = actual_bounds.corner(index)    
                actual_pt   = bound_pt.transform(inst_trans)
                pts << actual_pt
            }
            pts
        end

        def self.get_comp_raytest_points comp_inst
            defn        = comp_inst.definition
            inst_trans  = comp_inst.transformation
        
            actual_bounds   = defn.bounds
            comp_height     = actual_bounds.corner(4).z
        
            pts = []
            #For raytest we are going to add extra distance for the components
            #Beacause when the bounds check the raytest hits the corner wall for corner component 
            (0..3).each { |index|
                bound_pt    = actual_bounds.corner(index)
                case index
                when 0
                    bound_pt.x += 2.mm
                    bound_pt.y += 2.mm
                when 1
                    bound_pt.x -= 2.mm
                    bound_pt.y += 2.mm
                when 2
                    bound_pt.x += 2.mm
                    bound_pt.y -= 2.mm
                when 3
                    bound_pt.x -= 2.mm
                    bound_pt.y -= 2.mm
                end
                actual_pt   = bound_pt.transform(inst_trans)
                pts << actual_pt
                #es.add_cline(actual_pt, Z_AXIS)
            }
            
            pts
        end

        #Creates a manifold group based on the component
        def self.get_manifold_group comp_inst, z_offset=0.mm    
            model = Sketchup.active_model
            
            defn        = comp_inst.definition
            inst_trans  = comp_inst.transformation
            bounds      = comp_inst.bounds
            
            (0..7).each {|index|
                bound_pt    = bounds.corner(index) 
                #puts "False Point : #{index} : #{bound_pt}"
            }
            
            actual_bounds   = defn.bounds
            comp_height     = actual_bounds.corner(4).z
            
            pts = []
            (0..7).each {|index|
                bound_pt    = actual_bounds.corner(index)    
                actual_pt   = bound_pt.transform(inst_trans)

                actual_pt.z += z_offset

                #puts "Point : #{index} : #{actual_pt}"
                #actual_pt.z=0.mm
                pts << actual_pt
            }
            pre_ents = model.entities.to_a
            bottom_face = model.entities.add_face(pts[0], pts[1], pts[3], pts[2])
            puts "comp height : #{comp_height}"
            bottom_face.reverse! if bottom_face.normal.z < 0
            bottom_face.pushpull(comp_height, true)
            post_ents = model.entities.to_a
            
            group_ents = post_ents-pre_ents
            manifold_group = model.entities.add_group(group_ents)
            manifold_group
        end
		
    end # SketchupHelper
end # RIO