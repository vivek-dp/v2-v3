#-------------------------------------------------------------------------------    
# 
# File containing code for working drawing
# #load 'E:\git\poc_demo\dp_library\working_drawing.rb'
# #DecorPot.new.working_drawing
#-------------------------------------------------------------------------------    

# require_relative '../lib/code/dp_core.rb'
# require "prawn"
require_relative "dp_core.rb"

module WorkingDrawing
	include DP
	
	@@drawing_image_offset 		= 500
	@@rio_component_list 		= {}
	@@rio_comp_count 			= 0
	@@section_component_list 	= {}
	@top_section_count			= 0
	
	def self.reset_component_count
		@@rio_component_list 		= {}
		@@rio_comp_count 			= 0
		@@section_component_list 	= {}
		@top_section_count			= 0
	end

	def self.get_component_list
		return [@@rio_component_list, @@rio_comp_count]
	end

	def self.get_section_list
		@@section_component_list
	end

    def self.initialize
        DP::create_layers
        @add_menu = false
		add_menu_items
    end
    
    def self.get_outline_pts comp, view, offset
        return nil unless comp.valid?
        bounds = comp.bounds
        hit_pts = []
		case view
		when "top"
			indexes = [4,5,7,6]
			vector 	= Geom::Vector3d.new(0,0,1)
            offset  = offset - bounds.max.z 
		when "right"
			indexes = [1,3,7,5]
			vector 	= Geom::Vector3d.new(1,0,0)
            offset  = offset - bounds.max.x 
		when "left"
			indexes = [0,2,6,4]
			vector 	= Geom::Vector3d.new(-1,0,0)
            offset  = offset + bounds.min.x
		when "front"
			indexes = [0,1,5,4]
			vector 	= Geom::Vector3d.new(0,-1,0)
            offset  = offset + bounds.min.y
		when "back"
			indexes = [2,3,7,6]
			vector 	= Geom::Vector3d.new(0,1,0)
            offset  = offset - bounds.max.y
		end
		indexes.each { |i|
			hit_pts << TT::Bounds.point(bounds, i)
		}
        face_pts = []
        hit_pts.each{|pt| 
			pt = pt.offset(vector, offset)
			#pt.z += 1000.mm
			face_pts << pt
        }
        face_pts
    end
    
    def self.set_lamination comp, value
		return nil unless comp.valid?
		visi_arr 	= DP::get_visible_sides comp
        dict_name 	= :rio_atts
		keys = ['left_lamination', 'right_lamination', 'top_lamination']
		visi_arr.each_index{|i|
			comp.set_attribute(dict_name, keys[i], value[i])
		}
    end

    def self.get_lamination comp, key
		return nil unless comp.valid?
        dict_name = :rio_atts
        lam_code = comp.get_attribute(dict_name, key)
        return lam_code
    end
    
	def self.add_menu_items
        #puts "add_lamination_menu"
        if (!@add_menu)
            UI.add_context_menu_handler do |popup|
                sel = Sketchup.active_model.selection[0]
                if sel.is_a?(Sketchup::ComponentInstance)
                    #lam_code = get_lamination sel
					#lam_code = "" unless lam_code
					left, right, top = DP::get_visible_sides sel

					#If selected component has atleast one visible side add lamination code to visible face
					if left||right||top
						popup.add_item('Lamination Code') {
							prompts = []
							defaults = []
							if left
								prompts << "Left  " 
								defaults << (get_lamination sel, 'left_lamination')
							end
							if right 
								prompts << "Right "
								defaults << (get_lamination sel, 'right_lamination')
							end
							if top
								prompts << "Top   "
								defaults << (get_lamination sel, 'top_lamination')
							end
							if !prompts.empty?
								#defaults = [lam_code]
								input = UI.inputbox(prompts, defaults, "Lamination code.")
								set_lamination sel, input if input
							end
						}
					end

					#Add Component to the selected component-------------------------------------------
                    popup.add_item('Add Rio component') {
                        prompts = ["Placement"]
                        defaults = ["Left"]
                        list = ["Left|Right|Top"]
                        input = UI.inputbox(prompts, defaults, list, "Lamination code.")

                        DP::set_state 'comp-clicked:'+input[0].downcase if input
                        RioAWSComponent::decor_import_comp
					}
					
					#If component Instance is a wall......This is deprecated....Wall should be a group
                    posn = sel.get_attribute :rio_atts, "position"
                    if posn
                        popup.add_item('Add Rio component') {

                            posn = sel.get_attribute :rio_atts, "position"
                            DP::set_state 'wall-clicked:'+posn
                        }
					end
				elsif sel.is_a?(Sketchup::Group)
					popup.add_item('Add Rio Component') {
						posn = sel.get_attribute :rio_atts, "position"
						DP::set_state 'wall-clicked:'+posn
						RioAWSComponent::decor_import_comp
					}
                end
            end  
            @add_menu=true
        end
	end
    
	def self.add_dimension_pts pt1, pt2, vector
		# puts "add_dimension_pts : #{pt1} : #{pt2} : #{vector}"
		#pt1.z += 1000.mm
		#pt2.z += 1000.mm
		dim_l 	= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, vector)
		dim_l.material.color = 'red'
		dim_l
	end
    
    def self.get_comp_rows comp_h, view
        corners = []
		singles = []
		comp_h.each_pair{|x, y| 
			if y[:type]==:corner
				corners<<x 
			elsif y[:type]==:single 
				singles<<x
			end
		}
		rows = []
		#puts "comp_h : #{comp_h} #{Time.now}"
        corners.each{|id| comp_h[id][:type]=:corner}
		corners.each{|cor|
			adjs = comp_h[cor][:adj]
			row = []
			adjs.each{|adj_comp|
				row  = [cor]
				curr = adj_comp
				#comp_h[cor][:adj].delete curr
				comp_h[curr][:adj].delete cor
				#puts "comp_h[curr] : #{comp_h[curr]}"
				while comp_h[curr][:type] == :double
					break if comp_h[curr][:adj].nil?
					row << curr
					adj_next = comp_h[curr][:adj][0]
					comp_h[adj_next][:adj].delete curr
					comp_h[curr][:adj].delete adj_next
					curr = adj_next
				end
				row << curr
                row.sort_by!{|r| comp=DP.get_comp_pid r; comp.transformation.origin.x}
				rows << row
			}
        } 
		row_elems = rows.flatten
#=begin		
		singles.reject!{|x| row_elems.include?(x)}
		singles.each{|cor|
			adjs = comp_h[cor][:adj]
			row = []
			adjs.each{|adj_comp|
				row  = [cor]
				curr = adj_comp
				
				#comp_h[cor][:adj].delete curr
				comp_h[curr][:adj].delete cor
				count = 0
				while comp_h[curr][:type] == :double
					count+=1
					break if count == 10
					row << curr
					adj_next = comp_h[curr][:adj][0]
					#puts "curr : #{curr} : #{comp_h[curr]} : #{comp_h[adj_next]} : #{adj_next}"
					if adj_next
						comp_h[adj_next][:adj].delete curr 
						comp_h[curr][:adj].delete adj_next
						curr = adj_next
						#puts "curraaa : ---- #{curr}"
					else
						break if curr.nil?
					end
				end
				row << curr
                row.sort_by!{|r| comp=DP.get_comp_pid r; comp.transformation.origin.x}
				rows << row
			}
        } 
#=end		
		
        rows
	end

	def self.add_comp_dimension comp,  view='top', lamination_pts=[], show_dimension=true
		# puts "comp dim : #{comp} "
		sel = Sketchup.active_model.selection		
		sel.add comp
        return nil unless comp.valid?
        bounds = comp.bounds
        
        layer_name = 'DP_dimension_'+view
		dim_off = 4*rand + 1
		
		offset = @@drawing_image_offset

		rotz = comp.transformation.rotz
        case view
        when 'top'   
            case rotz
            when 0
                st_index, end_index, vector, lvector = 2,3, Geom::Vector3d.new(0,dim_off,0), Geom::Vector3d.new(0,2*dim_off,0)
                pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
                pt1.z=offset;pt2.z=offset
                mid_point = Geom.linear_combination( 0.5, pt1, 0.5, pt2 )
                dim_l = add_dimension_pts(pt1, pt2, vector)
                dim_l.layer = layer_name
                if show_dimension
                    st_index, end_index, vector = 0,2, Geom::Vector3d.new(-dim_off,0,0)
                    pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
                    pt1.z=offset;pt2.z=offset
                    dim_l = add_dimension_pts(pt1, pt2, vector)
                    dim_l.layer = layer_name
                end
            when 90
                st_index, end_index, vector, lvector = 0,2, Geom::Vector3d.new(-dim_off,0,0), Geom::Vector3d.new(0,-dim_off*2,0)
                pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
                pt1.z=offset;pt2.z=offset
                mid_point = Geom.linear_combination( 0.5, pt1, 0.5, pt2 )
                dim_l = add_dimension_pts(pt1, pt2, vector)
                dim_l.layer = layer_name
                if show_dimension
                    st_index, end_index, vector = 0,1, Geom::Vector3d.new(0,dim_off,0)
                    pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
                    pt1.z=offset;pt2.z=offset
                    dim_l = add_dimension_pts(pt1, pt2, vector)
                    dim_l.layer = layer_name
                end
            when 180, -180
                st_index, end_index, vector, lvector = 0,1, Geom::Vector3d.new(0,-dim_off,0), Geom::Vector3d.new(0,-dim_off*2,0)
                pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
                pt1.z=offset;pt2.z=offset
                mid_point = Geom.linear_combination( 0.5, pt1, 0.5, pt2 )
                dim_l = add_dimension_pts(pt1, pt2, vector)
                dim_l.layer = layer_name
                if show_dimension
                    st_index, end_index, vector = 0,2, Geom::Vector3d.new(-dim_off,0,0)
                    pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
                    pt1.z=offset;pt2.z=offset
                    dim_l = add_dimension_pts(pt1, pt2, vector)	
                    dim_l.layer = layer_name
                end
            when -90
                st_index, end_index, vector, lvector = 1,3, Geom::Vector3d.new(dim_off,0,0), Geom::Vector3d.new(2*dim_off,0,0)
                pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
                pt1.z=offset;pt2.z=offset
                mid_point = Geom.linear_combination( 0.5, pt1, 0.5, pt2 )
                dim_l = add_dimension_pts(pt1, pt2, vector)
                dim_l.layer = layer_name
                if show_dimension
                    st_index, end_index, vector = 0,1, Geom::Vector3d.new(0,-dim_off,0)
                    pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
                    pt1.z=offset;pt2.z=offset
                    dim_l = add_dimension_pts(pt1, pt2, vector)
                    dim_l.layer = layer_name
                end
            end	
			#lam_code = get_lamination comp
			#midpoint = comp.bounds.
			# if lamination_pts && !lamination_pts.empty?
			# 	['left_lamination', 'right_lamination', 'top_lamination'].each {|lam_value|
			# 		lam_code = get_lamination comp, lam_value
			# 		case rotz
			# 		when 0
			# 			if lam_value.start_with?('left')
			# 				midpoint = lamination_pts[:left]
			# 				lvector = Geom::Vector3d.new(10, 0, 0)
			# 			elsif lam_value.start_with?('right')
			# 				midpoint = lamination_pts[:right]
			# 				lvector = Geom::Vector3d.new(-10, 0, 0)
			# 			else
			# 				midpoint = lamination_pts[:top]
			# 				lvector = Geom::Vector3d.new(0,10,0)
			# 			end
			# 		when 90
			# 		when 180, -180
			# 		when -90
			# 		end
			# 		#puts "midpoint : #{midpoint}  : #{lam_code}  : #{lvector}" if lam_code && !lam_code.empty?
			# 		text = Sketchup.active_model.entities.add_text lam_code, mid_point, lvector if lam_code && !lam_code.empty?
			# 		if text
			# 			text.layer = 'DP_lamination' 
			# 			text.material.color = 'green'
			# 		end
			# 	}
			# end
            
        when 'left'
			if show_dimension
				st_index, end_index, vector = 2,6, Geom::Vector3d.new(0,dim_off,0)
				pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
				pt1.x=-offset;pt2.x=-offset
				dim_l = add_dimension_pts(pt1, pt2, vector)
				dim_l.layer = layer_name
			end

			st_index, end_index, vector = 2,0, Geom::Vector3d.new(0,0,-dim_off)
			pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
			pt1.x=-offset;pt2.x=-offset
			dim_l = add_dimension_pts(pt1, pt2, vector)
			dim_l.layer = layer_name
        when 'right'
			if show_dimension
				st_index, end_index, vector = 1,5, Geom::Vector3d.new(0,-dim_off,0)
				pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
				pt1.x=offset;pt2.x=offset
				dim_l = add_dimension_pts(pt1, pt2, vector)
				dim_l.layer = layer_name
			end
			
			st_index, end_index, vector = 1,3, Geom::Vector3d.new(0,0,-dim_off)
			pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
			pt1.x=offset;pt2.x=offset
			dim_l = add_dimension_pts(pt1, pt2, vector)
			dim_l.layer = layer_name
        when 'front'
			
			st_index, end_index, vector = 0,1, Geom::Vector3d.new(0,0,-dim_off)
			pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
			pt1.y=-offset;pt2.y=-offset
			dim_l = add_dimension_pts(pt1, pt2, vector)
			dim_l.layer = layer_name
			
			if show_dimension
				st_index, end_index, vector = 0,4, Geom::Vector3d.new(-dim_off,0,0)
				pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
				pt1.y=-offset;pt2.y=-offset
				dim_l = add_dimension_pts(pt1, pt2, vector)
				dim_l.layer = layer_name
			end
        when 'back'
            st_index, end_index, vector = 2,3, Geom::Vector3d.new(0,0,-dim_off)
            pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
            pt1.y=offset;pt2.y=offset
            dim_l = add_dimension_pts(pt1, pt2, vector)
            dim_l.layer = layer_name
			if show_dimension	
				st_index, end_index, vector = 2,6, Geom::Vector3d.new(dim_off,0,0)
				pt1, pt2 = TT::Bounds.point(comp.bounds, st_index), TT::Bounds.point(comp.bounds, end_index)
				pt1.y=offset;pt2.y=offset
				dim_l = add_dimension_pts(pt1, pt2, vector)
				dim_l.layer = layer_name
			end
		end
		Sketchup.active_model.layers[layer_name].visible=true
        
    end
    
	def self.add_row_dimension row, view
		#puts "add_row_dimension"
        comp_names = []
		return comp_names if row.empty?

		row_len = row.length
		dim_off = (7*rand) + 1
		vector  = Geom::Vector3d.new(0,0,-dim_off)
		offset = @@drawing_image_offset

		case view
		when 'front'
			row.sort_by!{|x| -DP::get_comp_pid(x).transformation.origin.x}
			start 	= 5
			last 	= 4
			start_point = DP::get_comp_pid(row[0]).bounds.corner(start)
			end_point	= DP::get_comp_pid(row[row_len-1]).bounds.corner(last)
			start_point.y	= -offset
			end_point.y 	= -offset 
		when 'left'
			row.sort_by!{|x| DP::get_comp_pid(x).transformation.origin.y}
			start 	= 4
			last 	= 6
			start_point = DP::get_comp_pid(row[0]).bounds.corner(start)
			end_point	= DP::get_comp_pid(row[row_len-1]).bounds.corner(last)
			start_point.x	= -offset
			end_point.x 	= -offset
		when 'right'
			row.sort_by!{|x| -DP::get_comp_pid(x).transformation.origin.y}
			start 	= 7
			last 	= 5
			start_point = DP::get_comp_pid(row[0]).bounds.corner(start)
			end_point	= DP::get_comp_pid(row[row_len-1]).bounds.corner(last)
			start_point.x	= offset
			end_point.x 	= offset
		when 'back'
			row.sort_by!{|x| DP::get_comp_pid(x).transformation.origin.x}
			start 	= 6
			last 	= 7
			start_point = DP::get_comp_pid(row[0]).bounds.corner(start)
			end_point	= DP::get_comp_pid(row[row_len-1]).bounds.corner(last)
			start_point.y	= offset
			end_point.y 	= offset
		end
		#start_point = DP::get_comp_pid(row[0]).bounds.corner(start)
		#end_point	= DP::get_comp_pid(row[row_len-1]).bounds.corner(last)
		if view != 'top'
			dim_l = add_dimension_pts(start_point, end_point, vector)
			dim_l.material.color = '1D8C2C'
		end
		#sorted_rows = sort_rows side

        row.each{ |id|
            comp = DP::get_comp_pid(id)
            defn_name   = comp.definition.name
            if comp_names.include?(defn_name)
                add_comp_dimension comp, view, false
            else
                comp_names << defn_name
                add_comp_dimension comp, view
            end
		}
		return comp_names
    end
    
	def self.add_dimensions comp_h, view='top'
        #outline_drawing comp_h, view
        #corners = get_corners view
        rows = get_comp_rows comp_h, view
		row_elems = rows.flatten.uniq
		comp_names = []
        comp_h.keys.each { |id|
            comp_h[id][:row_elem] = true if row_elems.include?(id)
        }
        rows.each{|row|
            comp_names << (add_row_dimension row, view)
        }
		comp_names.flatten!
		
        comp_h.each { |comp_details|
            comp_id = comp_details[0]
			comp = DP::get_comp_pid comp_id
			#puts comp_details
            add_comp_dimension comp, view, comp_h[comp_id][:lamination_pts]  unless comp_h[comp_id][:row_elem]
		}
	end
	
	def self.outline_drawing view, comps=[] #comp_h not needed
		if comps.empty?
			if view == 'top'
				comps 	= DP::get_top_visible_comps 
			else
				comps 	= DP::get_visible_comps view
			end
		end
		offset = @@drawing_image_offset

		view_comps = {}
		if comps.empty?
			puts "No component for the "+view+" View"
			return view_comps
		end
		comp_h 	= DP::parse_components comps 
		count = 0
		
		if view != 'top'
			puts "@@rio_component_list : #{view} : #{@@rio_component_list}"
			
		end
		
		comp_h.keys.each{|cid|
			comp = DP::get_comp_pid cid
			next if comp.nil?
			# if view == 'top'
			# 	count += 1
			# 	comp_name = "C#"+@@rio_component_count.to_s
			# end
			if view=='top'
				@@rio_comp_count 				+= 1
				comp_name 						= "C#"+@@rio_comp_count.to_s
				@@rio_component_list[comp_name] = comp
				@@section_component_list[comp]	= @top_section_count
			else
				@@rio_component_list.each_pair{ |key, value|
					if value == comp
						comp_name = key 
						break
					end
				}
			end
			view_comps[comp_name] = comp
            
            pts = get_outline_pts comp, view, offset


            face = Sketchup.active_model.entities.add_face(pts)
            face.edges.each{|edge| edge.layer = 'DP_outline_'+view}
			face.layer 	= 	'DP_outline_'+view
			coordinates = face.bounds.center
			model 	= Sketchup.active_model
			entities= model.entities
			point 	= Geom::Point3d.new coordinates
			#point.z += 1000.mm
			# puts "view : #{}"
			Sketchup.active_model.active_layer= Sketchup.active_model.layers['DP_dimension_'+view]
			#if view != 'top'
				text 	= entities.add_text comp_name, point
				text.material.color = '7A003D'
			#end
			count 	+=1
			
			rotz = comp.transformation.rotz
			case rotz
			when 0
				lamination_pts = {	:left	=> TT::Bounds.point(face.bounds, TT::BB_CENTER_FRONT_BOTTOM),
									:right	=> TT::Bounds.point(face.bounds, TT::BB_CENTER_BACK_BOTTOM),
									:top	=> TT::Bounds.point(face.bounds, TT::BB_CENTER_CENTER_CENTER)}
			when 90
				lamination_pts = {:left	=> TT::Bounds.point(face.bounds, TT::BB_CENTER_BACK_BOTTOM),
					:right	=> TT::Bounds.point(face.bounds, TT::BB_CENTER_FRONT_BOTTOM),
					:top	=> TT::Bounds.point(face.bounds, TT::BB_CENTER_CENTER_CENTER)}
			when -90
				lamination_pts = {:left	=> TT::Bounds.point(face.bounds, TT::BB_CENTER_FRONT_BOTTOM),
					:right	=> TT::Bounds.point(face.bounds, TT::BB_CENTER_BACK_BOTTOM),
					:top	=> TT::Bounds.point(face.bounds, TT::BB_CENTER_CENTER_CENTER)}
			when 180, -180
				lamination_pts = {	:left	=> TT::Bounds.point(face.bounds, TT::BB_RIGHT_CENTER_BOTTOM),
					:right	=> TT::Bounds.point(face.bounds, TT::BB_LEFT_CENTER_BOTTOM),
					:top	=> TT::Bounds.point(face.bounds, TT::BB_CENTER_CENTER_CENTER)}
			end
			comp_h[cid][:lamination_pts] = lamination_pts
			face.hidden	=	true
		}
		#puts comp_h
		add_dimensions comp_h, view
		#puts "view.......#{view}"

		#To add background wall or floor outline in working drawing
		background_ent 	= view
		background_ent 	= 'floor' if view == 'top'
		
		floor 			= DP.ents.select{|x| x.get_attribute(:rio_atts, 'position')==background_ent}
		if floor && floor[0].is_a?(Sketchup::Group)
			background_face = floor[0].entities.select{|temp| temp.is_a?(Sketchup::Face)}[0]
			if background_face
				#Make this a function
				background_face.edges.each{|edge| 
					edge.layer 	= 'DP_outline_'+view
					
					other_edges = background_face.edges - [edge]
					verts 		= edge.vertices

					adj_edge 	= other_edges.select{|b_edge| b_edge.vertices.include?(verts[0])}[0]
					
					adj_vert 	= adj_edge.vertices	- [verts[0]]				
					vector 		= verts[0].position.vector_to adj_vert[0].position

					nv 				= vector.reverse.normalize
					normal_vector 	= Geom::Vector3d.new(nv.x*10, nv.y*10, nv.z*10)
					dim_l 			= Sketchup.active_model.entities.add_dimension_linear(verts[0], verts[1], normal_vector) 						
					dim_l.material.color = 'blue'
					dim_l.layer = 'DP_outline_'+view
				}
				face = Sketchup.active_model.entities.add_face(background_face.vertices) 
				#puts "face : #{view} :  #{floor} : #{face}"
				#puts "--------------------------------------"
				Sketchup.active_model.entities.erase_entities face
			end
		end
		view_comps
	end
	
    #Create the working drawing for the specific view
	def self.working_drawing view='top', comps=[]
		views = ['top', 'left', 'right', 'back', 'front']
		return nil unless views.include?(view)

		# if view=='top'
		# 	layer_name = 'DP_lamination'
		# 	Sketchup.active_model.layers.add(layer_name) if Sketchup.active_model.layers[layer_name].nil?
		# 	delete_layer_entities layer_name
		# end
		
        layer_name = 'DP_outline_'+view
        Sketchup.active_model.layers.add(layer_name) if Sketchup.active_model.layers[layer_name].nil?
		delete_layer_entities layer_name
        
        layer_name = 'DP_dimension_'+view
        Sketchup.active_model.layers.add(layer_name) if Sketchup.active_model.layers[layer_name].nil?
		delete_layer_entities layer_name
		
        outline_comps = outline_drawing view, comps
        return outline_comps
	end
    
	def self.get_layer_entities layer_name
		model = Sketchup::active_model
		ents = model.entities
		layer_ents = []
		layer_ents = ents.select{|x| x.layer.name==layer_name}
	end
	
	def self.delete_layer_entities layer_name
		layer_ents = get_layer_entities layer_name
		layer_ents.each{|ent| 
			unless ent.deleted?
				Sketchup::active_model.entities.erase_entities ent
			end
		}
	end
    
    def self.get_all_views
        views = ['top', 'left', 'right', 'back', 'front']
        views.each { |v|  working_drawing v  }
    end
    
    def self.get_single_adj comp_h
        singles=[]; comp_h.each_pair{|x, y| singles<<x if y[:type] == :single}; return singles
    end
    
    def self.get_corners comp_h
        corners = []
        comp_h.each_pair{|x, y| 
            if y[:type] == :double
                adj_comps = y[:adj]
                cor_comp =  DP.get_comp_pid x
                comp1 = DP.get_comp_pid adj_comps[0]
                comp2 = DP.get_comp_pid adj_comps[1]
                if (comp1.transformation.rotz+comp2.transformation.rotz)%180 != 0
                    #This check when its row component but the adjacents are rotated
                    f1 = DP.ents.add_face(DP::get_xn_pts cor_comp, comp1)
                    f2 = DP.ents.add_face(DP::get_xn_pts cor_comp, comp2)
                    if f2.normal.perpendicular? f1.normal
                        corners<<x 
                        #DP.sel.add cor_comp
                    end
                    DP.ents.erase_entities f1, f2
                end
            end
        }
        return corners
    end
			
	def self.check_xn check_comp, comp_a
		comp_a.each { |comp|
			next if comp == check_comp
			xn = comp.bounds.intersect check_comp.bounds
			return true if xn.width * xn.height * xn.depth != 0
		}
		return false
	end
			
	def self.scan_components
		comp_a = DP::get_rio_components
		adj_comps = []
		unless comp_a.empty?	
			comp_a.each{|comp|
				resp = check_xn comp, comp_a
				adj_comps << comp if resp
			}
			return adj_comps
		end
		#puts "adj_comps : #{adj_comps}"
		
		adj_comps
	end	

	def self.get_offset view, comps
		offset 	= 0
		case view
		when 'top'
			comps.each {|comp|
				z = comp.bounds.corner(4).z
				offset = z if z > offset
			}
		when 'left'
			comps.each {|comp|
				x = comp.bounds.corner(1).x
				offset = x if x > offset
			}
			offset = -offset
		when 'right'
			offset = 1000000
			comps.each {|comp|
				x = comp.bounds.corner(1).x
				offset = x if x < offset
			}
		when 'front'
			comps.each {|comp|
				y = comp.bounds.corner(2).y
				offset = y if y > offset
			}
			offset = -offset
		when 'back'
			offset = 1000000
			comps.each {|comp|
				y = comp.bounds.corner(0).y
				offset = y if y < offset
			}
		end
		offset
	end 

	def self.get_working_image view, options=[]
		puts "get_working : #{view}"
		include_background_flag = true if options.include?('act_backgrd')
		#include_background_flag = true

		last_active_view = Sketchup.active_model.active_view
		if view == 'top'
			comps 	= DP::get_top_visible_comps 
		else
			comps 	= DP::get_visible_comps view
		end

		visible_comps = []

		if include_background_flag #options[act_backgrd] #check options of background image
			if view == 'top'
				comps 	= DP::get_top_visible_comps 
			else
				comps 	= DP::get_visible_comps view
			end
			@@drawing_image_offset = get_offset view, comps
		else
			@@drawing_image_offset = 500
		end
		visible_comps = []
		return [] if comps.empty?

		layers = Sketchup.active_model.layers
		visible_layers = ['DP_outline_'+view, 'DP_dimension_'+view]
		visible_layers << 'DP_Comp_layer' if include_background_flag
		#visible_layers << 'DP_lamination' if view=='top'
		layers.each {|x| visible_layers << x.name if x.name.start_with?('72IMOS')}
	
		# if include_background_flag
		# 	visible_comps = DP::get_visible_comps view
		# 	layer_comps = Sketchup.active_model.entities.grep(Sketchup::ComponentInstance).select{|x| x.layer.name=='DP_Comp_layer'}
		# 	layer_comps.each{|x| x.visible=false if !visible_comps.include?(x)}
		# end
		if view =='top'
			rio_comps = DP::get_rio_components
			DP::get_multi_layer_top_components rio_comps
			top_comps = DP::get_multi_layer_top_view_components
			#puts "top_comps : #{top_comps}"
		end

		if view == 'top' && top_comps.length>1
			puts "Starting section plane"
			section_count = 0
			result_arr = []
			top_comps.each {|comp_list|
				@top_section_count += 1
				@top_section_count
				comp_list.uniq!
				comps = working_drawing view, comp_list
				
				outpath = File.join(RIO_ROOT_PATH, "cache/")
				end_format = ".jpg"
				Dir::mkdir(outpath) unless Dir::exist?(outpath)
				image_file_name = outpath+view+'_section'+@top_section_count.to_s+end_format

				Sketchup.active_model.active_layer=visible_layers[1]
				layers.each{|layer| layer.visible=false unless visible_layers.include?(layer.name)}
				# puts visible_layers
				visible_layers.each{|l| 
					Sketchup.active_model.layers[l].visible=true if Sketchup.active_model.layers[l]}

				visible_comps.each{|c| c.visible=true}
				
				#return
				if view == "top"
					@cPos = [0, 0, 0]
					@cTarg = [0, 0, -1]
					@cUp = [0, 1, 0]
				elsif view == "front"
					@cPos = [0, 0, 0]
					@cTarg = [0, 1, 0]
					@cUp = [0, 0, 1]
				elsif view == "right"
					@cPos = [0, 0, 0]
					@cTarg = [1, 0, 0]
					@cUp = [0, 0, 1]
				elsif view == "left"
					@cPos = [0, 0, 0]
					@cTarg = [-1, 0, 0]
					@cUp = [0, 0, 1]
				elsif view == "back"
					@cPos = [0, 0, 0]
					@cTarg = [0, 1, 0]
					@cUp = [0, 0, 1]
				end
				
				Sketchup.active_model.active_view.camera.set @cPos, @cTarg, @cUp
				Sketchup.active_model.active_view.zoom_extents
				keys = {
					:filename => image_file_name,
					:width => 1920,
					:height => 1080,
					:antialias => true,
					:compression => 0,
					:transparent => true
				}
				
				Sketchup.active_model.active_view.camera.perspective = false
				
				#Sketchup.active_model.active_view.write_image keys
				Sketchup.active_model.active_view.write_image image_file_name
	 
				#Sketchup.active_model.active_view.write_image outpath+"j"+view+".jpg"
				layer_comps = Sketchup.active_model.entities.grep(Sketchup::ComponentInstance).select{|x| x.layer.name=='DP_Comp_layer'}
				layer_comps.each{|x| x.visible=true}

				layers.each{|layer| layer.visible=true}

				dim_out_layers = Sketchup.active_model.layers.select{|x| x.name.start_with?('DP_dimension')}
				dim_out_layers << Sketchup.active_model.layers.select{|x| x.name.start_with?('DP_outline')}
				dim_out_layers.flatten!

				ents = Sketchup.active_model.entities
				ents.each{|ent| ents.erase_entities ent if ent.layer.name.start_with?('DP_dimension')}
				ents.each{|ent| ents.erase_entities ent if ent.layer.name.start_with?('DP_outline')}

				['DP_outline_'+view, 'DP_dimension_'+view].each{|layer_name| 
					#layer = Sketchup.active_model.layers[layer_name]
					delete_layer_entities layer_name
				}

				#Sketchup.active_model.active_view.zoom_extents
				result_arr << [comp_list, image_file_name]
				#return result_arr
			}
			@top_section_count = 0
			#puts "result_arr : #{result_arr}"
			#puts "----------------------------------------"
			#puts "comp _result : #{DP::get_multi_layer_top_view_components}"
			DP::set_multi_layer_top_view_components []
			return result_arr
		else
			comps = working_drawing view
			
			outpath = File.join(RIO_ROOT_PATH, "cache/")
			end_format = ".jpg"
			Dir::mkdir(outpath) unless Dir::exist?(outpath)
			image_file_name = outpath+view+end_format

			Sketchup.active_model.active_layer=visible_layers[1]
			layers.each{|layer| layer.visible=false unless visible_layers.include?(layer.name)}
			# puts visible_layers
			visible_layers.each{|l| 
				Sketchup.active_model.layers[l].visible=true if Sketchup.active_model.layers[l]}

			visible_comps.each{|c| c.visible=true}
			
			#return
			if view == "top"
				@cPos = [0, 0, 0]
				@cTarg = [0, 0, -1]
				@cUp = [0, 1, 0]
			elsif view == "front"
				@cPos = [0, 0, 0]
				@cTarg = [0, 1, 0]
				@cUp = [0, 0, 1]
			elsif view == "right"
				@cPos = [0, 0, 0]
				@cTarg = [1, 0, 0]
				@cUp = [0, 0, 1]
			elsif view == "left"
				@cPos = [0, 0, 0]
				@cTarg = [-1, 0, 0]
				@cUp = [0, 0, 1]
			elsif view == "back"
				@cPos = [0, 0, 0]
				@cTarg = [0, 1, 0]
				@cUp = [0, 0, 1]
			end
			
			Sketchup.active_model.active_view.camera.set @cPos, @cTarg, @cUp
			Sketchup.active_model.active_view.zoom_extents
			keys = {
				:filename => image_file_name,
				:width => 1920,
				:height => 1080,
				:antialias => true,
				:compression => 0,
				:transparent => true
			}
			Sketchup.active_model.active_view.camera.perspective = false
			
			#Sketchup.active_model.active_view.write_image keys
			Sketchup.active_model.active_view.write_image image_file_name
			#Sketchup.active_model.active_view.write_image outpath+"j"+view+".jpg"
			layer_comps = Sketchup.active_model.entities.grep(Sketchup::ComponentInstance).select{|x| x.layer.name=='DP_Comp_layer'}
			layer_comps.each{|x| x.visible=true}

			layers.each{|layer| layer.visible=true}

			dim_out_layers = Sketchup.active_model.layers.select{|x| x.name.start_with?('DP_dimension')}
			dim_out_layers << Sketchup.active_model.layers.select{|x| x.name.start_with?('DP_outline')}
			dim_out_layers.flatten!

			ents = Sketchup.active_model.entities
			ents.each{|ent| ents.erase_entities ent if ent.layer.name.start_with?('DP_dimension')}
			ents.each{|ent| ents.erase_entities ent if ent.layer.name.start_with?('DP_outline')}

			['DP_outline_'+view, 'DP_dimension_'+view].each{|layer_name| 
				#layer = Sketchup.active_model.layers[layer_name]
				delete_layer_entities layer_name
			}

			Sketchup.active_model.active_view.zoom_extents
			return [comps, image_file_name]
		end
	end
	
	def self.export_working_drawing
		adj_comps = scan_components
		if !adj_comps.empty?
			Sketchup.active_model.selection.clear
			#adj_comps.each{|comp| Sketchup.active_model.selection.add comp}
			UI.messagebox("The selected components overlap each other. Working drawing doesnt allow component overlap.")
			#return false
		end
		viloop = []
		views_to_process = ["top","front","right","left","back"]
		#views_to_process = ["Top"]
		
		if Sketchup.active_model.title != ""
			@title = Sketchup.active_model.title
		else
			@title = "Untitled"
		end

		outpath = File.join(RIO_ROOT_PATH,"cache")
		Dir::mkdir(outpath) unless Dir::exist?(outpath)
	

		views_to_process.each {|vi|
			viloop.push(vi)
			
			view = vi.downcase
			get_working_image view
		}

		# FileUtils.cd(outpath)
		# f = File.open("#{@title}.pdf", 'w')
		# if f.is_a?(File)
		# 	f.close
		# 	Prawn::Document.generate("#{@title}.pdf", :page_size=>"A4", :page_layout=>:landscape) do
		# 		viloop.each {|vp|
		# 			image outpath+vp+end_format, width: 750, height: 500, resolution: 1920
		# 		}
		# 	end
		# 	UI.messagebox 'Export successful',MB_OK
		# else
		# 	UI.messagebox 'Cannot write to pdf.Please Close and try again if pdf is open.',MB_OK
		# end
		#system('explorer %s' % (outpath))
	end
end


