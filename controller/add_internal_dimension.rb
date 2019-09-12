module RioDIM

	@edges = []
	COMP_DIMENSION_OFFSET 	= 5000.mm unless defined?(COMP_DIMENSION_OFFSET)

	def self.add_carcass_dimension comp
		begin
			Sketchup.active_model.start_operation '2d_to_3d'
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

			Sketchup.active_model.start_operation('Internal dimension')
			shutter_code 	= comp.get_attribute(:rio_atts, 'shutter-code')
			carcass_name 	= comp.get_attribute(:rio_atts, 'carcass-code')
			#carcass_group 	= comp

			if true
				prev_ents	=[];
				Sketchup.active_model.entities.each{|ent| prev_ents << ent}

				comp.make_unique
				comp.explode

				post_ents 	= [];
				Sketchup.active_model.entities.each{|ent| post_ents << ent}

				exploded_ents = post_ents - prev_ents
				exploded_ents.select!{|x| !x.deleted?}

				#Explode again if shutter is present
				shutter_code = true
				if shutter_code
					carcass_group = exploded_ents.grep(Sketchup::Group).select{|x| x.definition.name.start_with?(carcass_name)}[0]
					carcass_group = exploded_ents.grep(Sketchup::ComponentInstance).select{|x| x.definition.name.start_with?(carcass_name)}[0] if carcass_group.nil?

					prev_ents	=[];
					Sketchup.active_model.entities.each{|ent| prev_ents << ent}

					carcass_group.explode

					post_ents 	= [];
					Sketchup.active_model.entities.each{|ent| post_ents << ent}

					exploded_ents = post_ents - prev_ents
					exploded_ents.select!{|x| !x.deleted?}
				end

				carcass_flag 	= true
				if carcass_flag
					shelf_fix_entities 	= exploded_ents.grep(Sketchup::Group).select{|x| x.layer.name.start_with?('72IMOSXD01_IM_SHELF_FIX')}
					shelf_fix_entities.sort_by!{|x| x.bounds.corner(0).z}

					lower_shelf_fix 	= shelf_fix_entities.first
					upper_shelf_fix		= shelf_fix_entities.last

					# puts "shelf_fix_entities : #{shelf_fix_entities} : #{lower_shelf_fix}"

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
								ray_comp = hit_item[1][0]
								lshelf_fix_ray_entities << ray_comp
								pt1 	= bound_point
								pt2 	= hit_item[0]
								pt1.z+=COMP_DIMENSION_OFFSET
								pt2.z+=COMP_DIMENSION_OFFSET
								if (pt1.distance pt2) > 20.mm
									Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, Geom::Vector3d.new(1,0,0))
									# puts "points : #{pt1} : #{pt2}"
								end
								if ray_comp.layer.name.end_with?('DRAWER_FRONT')
									pt1 	= ray_comp.bounds.corner(0)
									pt2 	= ray_comp.bounds.corner(4)
									pt1.z+=COMP_DIMENSION_OFFSET
									pt2.z+=COMP_DIMENSION_OFFSET
									dim_l 	= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
									dim_l.material.color = 'red'
								end
							end
						end
					}

					lshelf_fix_ray_entities.flatten!

					side_vector = Geom::Vector3d.new(1,0,0)
					# puts "lshelf_fix_ray_entities------ : #{lshelf_fix_ray_entities}"
					lshelf_fix_ray_entities.each{|internal_comp|
						# puts "-------------------+++++++++ : #{internal_comp}\n\n"
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
									# puts "inner comps : #{hit_item[0]} : #{pt} : #{bound_point}"
									sel.add(hit_item[1][0])
									if dim_ents.include?(hit_item[1][0])
										hit_comp 	= hit_item[1][0]
										pt1 	= bound_point
										pt2 	= hit_item[0]

										#pt1 	= internal_comp.bounds.corner(4).offset(side_vector, 40.mm)
										pt1 	= pt.offset(side_vector, 40.mm)
										pt2 	= pt1.clone
										pt2.z 	= hit_item[0].z

										#pt1		= internal_comp.bounds.corner(0).offset(side_vector, 40.mm)
										#pt2 	= hit_item[0]
										# pt2 	= pt1;
										# pt2.z 	= hit_item[0].z
										# pt2 	= hit_item[0]
										pt1.z+=COMP_DIMENSION_OFFSET
										pt2.z+=COMP_DIMENSION_OFFSET
										internal_comp = hit_comp

										# puts "Add dimension : #{pt1} : #{pt2}"
										if (pt1.distance pt2) > 20.mm
											dim_l = Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
											dim_l.material.color = 'red'
										end
										#puts "comp : #{internal_comp} : #{internal_comp.layer.name}"
										if internal_comp.layer.name.end_with?('DRAWER_FRONT')
											pt1 	= internal_comp.bounds.corner(0)
											pt2 	= internal_comp.bounds.corner(4)
											pt1.z+=COMP_DIMENSION_OFFSET
											pt2.z+=COMP_DIMENSION_OFFSET
											dim_l 	= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
											dim_l.material.color = 'red'
											# puts "Add dimension....... : #{internal_comp} : #{pt1} : #{pt2}"
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




				internal_flag 	= false
				if internal_flag
					#For internal components of sliding door
					carcass_group = exploded_ents.grep(Sketchup::Group).select{|x| x.definition.name.start_with?(carcass_name)}[0]
					carcass_group = exploded_ents.grep(Sketchup::ComponentInstance).select{|x| x.definition.name.start_with?(carcass_name)}[0] if carcass_group.nil?

					shelf_fix_entities = carcass_group.definition.entities.grep(Sketchup::Group).select{|x| x.layer.name.start_with?('72IMOSXD01_IM_SHELF_FIX')}
					shelf_fix_entities.sort_by!{|x| x.bounds.corner(0).z}
					lower_shelf_fix 	= shelf_fix_entities.first
					upper_shelf_fix		= shelf_fix_entities.last

					# puts "exploded_ents.. : #{exploded_ents}"
					exploded_ents.select!{|ent| !ent.nil?}
					internal_groups = exploded_ents.grep(Sketchup::ComponentInstance).select{|x|
						x.definition.get_attribute(:rio_atts,'comp_type').end_with?('internal') if x.definition.get_attribute(:rio_atts,'comp_type')
					}
					# puts "internal_groups : #{internal_groups}"

					internal_groups.each{|int_group|

						#int_group = fsel
						internal_origin = int_group.bounds.corner(0)
						center_pt 		= TT::Bounds.point(int_group.bounds, 9)
						internal_end 	= int_group.bounds.corner(1)
						internal_top 	= int_group.bounds.corner(4)

						prev_ents	=[];
						Sketchup.active_model.entities.each{|ent| prev_ents << ent}

						int_group.make_unique
						int_group.explode

						post_ents 	= [];
						Sketchup.active_model.entities.each{|ent| post_ents << ent}

						internal_ents = post_ents - prev_ents
						internal_ents.select!{|x| !x.deleted?}
						internal_ents.select!{|x| x.is_a?(Sketchup::Group)}


						dim_ents 		= []
						other_ents	 	= []

						internal_ents.each{ |shelf_ent|
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
						# puts "dim_ents :#{dim_ents}"
						dim_ents.each{|ent|
							y_offset 	= internal_origin.y - ent.bounds.corner(0).y
							trans 		= Geom::Transformation.new([0, y_offset, 0])
							ent.transform!(trans)
						}

						#---------------------------------------------------------
						ray_pt1 	= Geom.linear_combination(0.5, internal_origin, 0.5, center_pt)
						ray_pt2 	= Geom.linear_combination(0.5, internal_end, 0.5, center_pt)
						# puts "ray_pt : #{ray_pt1} : #{ray_pt2}"
						internal_ray_entities = []

						[ray_pt1, ray_pt2].each{ |ray_pt|
							ray 		= [ray_pt, zvector]
							hit_item 	= Sketchup.active_model.raytest(ray, true)

							#Get the lower most shelf entities
							if hit_item && hit_item[1][0]
								sel.add(hit_item[1][0])
								# puts "hittt : #{hit_item}"
								if dim_ents.include?(hit_item[1][0])
									ray_comp = hit_item[1][0]
									internal_ray_entities << ray_comp
									pt1 	= ray_pt
									pt2 	= hit_item[0]
									pt1.z+=COMP_DIMENSION_OFFSET
									pt2.z+=COMP_DIMENSION_OFFSET

									#puts
									if (pt1.distance pt2) > 20.mm
										Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, Geom::Vector3d.new(1,0,0))
										# puts "points : #{pt1} : #{pt2}"
									end
									if ray_comp.layer.name.end_with?('DRAWER_FRONT')
										pt1 	= ray_comp.bounds.corner(0)
										pt2 	= ray_comp.bounds.corner(4)
										pt1.z+=COMP_DIMENSION_OFFSET
										pt2.z+=COMP_DIMENSION_OFFSET
										dim_l 	= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
										dim_l.material.color = 'blue'
									end
								end
							end

						}
						internal_ray_entities.flatten!

						# puts "internal_ray_entities : #{internal_ray_entities}"
						#---------------------------------------------------------

						internal_ray_entities.each{|internal_comp|
							# puts "-------------------+++++++++ : #{internal_comp}\n\n"
							continue_ray 	= true
							hit_comp 		= nil
							pt1 			= TT::Bounds.point(internal_comp.bounds, 9)
							# puts "------------------------"
							# puts internal_comp.bounds.center
							# puts lower_shelf_fix.bounds.corner(4)

							a=internal_comp.bounds.center.z
							b=lower_shelf_fix.bounds.corner(4).z

							high_offset 	=  a - b
							pt2 = pt1.offset(zvector.reverse, high_offset)

							pt1.z+=COMP_DIMENSION_OFFSET
							pt2.z+=COMP_DIMENSION_OFFSET

							dim_l = Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
							dim_l.material.color = 'blue'

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
										# puts "inner comps : #{hit_item[0]} : #{pt} : #{bound_point}"
										sel.add(hit_item[1][0])
										if dim_ents.include?(hit_item[1][0])
											hit_comp 	= hit_item[1][0]
											pt1 	= bound_point
											pt2 	= hit_item[0]

											#pt1 	= internal_comp.bounds.corner(4).offset(side_vector, 40.mm)
											pt1 	= pt.offset(side_vector, 40.mm)
											pt2 	= pt1.clone
											pt2.z 	= hit_item[0].z

											#pt1		= internal_comp.bounds.corner(0).offset(side_vector, 40.mm)
											#pt2 	= hit_item[0]
											# pt2 	= pt1;
											# pt2.z 	= hit_item[0].z
											# pt2 	= hit_item[0]
											pt1.z+=COMP_DIMENSION_OFFSET
											pt2.z+=COMP_DIMENSION_OFFSET


											# puts "Add dimension : #{pt1} : #{pt2}"
											if (pt1.distance pt2) > 20.mm
												dim_l = Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
												dim_l.material.color = 'red'
											end
											#puts "comp : #{internal_comp} : #{internal_comp.layer.name}"
											if hit_comp.layer.name.end_with?('DRAWER_FRONT')
												pt1 	= hit_comp.bounds.corner(0)
												pt2 	= hit_comp.bounds.corner(4)
												pt1.z+=COMP_DIMENSION_OFFSET
												pt2.z+=COMP_DIMENSION_OFFSET
												dim_l 	= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
												dim_l.material.color = 'red'
												# puts "Add dimension....... : #{hit_comp} : #{pt1} : #{pt2}"
											end
											internal_comp = hit_comp
											next_pt 	= false
										else
											continue_ray = false
										end
									else
										continue_ray = false
									end
								}
							end#While

							if hit_comp
								# puts "hit_comp : #{hit_comp} : #{internal_top}"
								high_offset =  internal_top.z - hit_comp.bounds.corner(4).z
								if high_offset > 20.mm
									# puts "high_offset : #{high_offset} : #{internal_top.z} : #{hit_comp.bounds.corner(4).z}"

									pt1 = TT::Bounds.point(hit_comp.bounds, 10)
									pt2 = pt1.offset(zvector, high_offset)
									# puts "pt........ #{pt1} : #{pt2}"
									pt1.z+=COMP_DIMENSION_OFFSET
									pt2.z+=COMP_DIMENSION_OFFSET
									dim_l = Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
									dim_l.material.color = 'green'
								end
							end


						}

					}#internal_groups

				end #internal flag

				sliding_flag = false
				if sliding_flag
					if internal_flag

					# puts "exploded_ents.. : #{exploded_ents}"
					exploded_ents.select!{|ent| !ent.nil?}
					#exploded_ents.select!{|ent| !ent.definition.nil?}
					#exploded_ents.select!{|ent| !ent.definition.get_attribute(:rio_atts,'comp_type').nil?}
					#exploded_ents.each{|x| puts x.nil?}
					internal_groups = exploded_ents.grep(Sketchup::ComponentInstance).select{|x|
						x.definition.get_attribute(:rio_atts,'comp_type').end_with?('internal') if x.definition.get_attribute(:rio_atts,'comp_type')
					}
					# puts "internal_groups : #{internal_groups}"

					internal_groups.each{|int_group|

						#int_group = fsel
						internal_origin = int_group.bounds.corner(0)
						center_pt 		= TT::Bounds.point(int_group.bounds, 9)
						internal_end 	= int_group.bounds.corner(1)

						prev_ents	=[];
						Sketchup.active_model.entities.each{|ent| prev_ents << ent}

						int_group.make_unique
						int_group.explode

						post_ents 	= [];
						Sketchup.active_model.entities.each{|ent| post_ents << ent}

						internal_ents = post_ents - prev_ents
						internal_ents.select!{|x| !x.deleted?}
						internal_ents.select!{|x| x.is_a?(Sketchup::ComponentInstance)}


						dim_ents 		= []
						other_ents	 	= []

						internal_ents.each{ |shelf_ent|
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
						# puts "dim_ents :#{dim_ents}"
						dim_ents.each{|ent|
							y_offset 	= internal_origin.y - ent.bounds.corner(0).y
							trans 		= Geom::Transformation.new([0, y_offset, 0])
							ent.transform!(trans)
						}

						#---------------------------------------------------------
						ray_pt1 	= Geom.linear_combination(0.5, internal_origin, 0.5, center_pt)
						ray_pt2 	= Geom.linear_combination(0.5, internal_end, 0.5, center_pt)
						# puts "ray_pt : #{ray_pt1} : #{ray_pt2}"
						internal_ray_entities = []

						[ray_pt1, ray_pt2].each{ |ray_pt|
							ray 		= [ray_pt, zvector]
							hit_item 	= Sketchup.active_model.raytest(ray, true)

							#Get the lower most shelf entities
							if hit_item && hit_item[1][0]
								sel.add(hit_item[1][0])
								# puts "hittt : #{hit_item}"
								if dim_ents.include?(hit_item[1][0])
									ray_comp = hit_item[1][0]
									internal_ray_entities << ray_comp
									pt1 	= bound_point
									pt2 	= hit_item[0]
									pt1.z+=COMP_DIMENSION_OFFSET
									pt2.z+=COMP_DIMENSION_OFFSET
									if (pt1.distance pt2) > 20.mm
										Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, Geom::Vector3d.new(1,0,0))
										# puts "points : #{pt1} : #{pt2}"
									end
									if ray_comp.layer.name.end_with?('DRAWER_FRONT')
										pt1 	= ray_comp.bounds.corner(0)
										pt2 	= ray_comp.bounds.corner(4)
										pt1.z+=COMP_DIMENSION_OFFSET
										pt2.z+=COMP_DIMENSION_OFFSET
										dim_l 	= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
										dim_l.material.color = 'red'
									end
								end
							end

						}
						internal_ray_entities.flatten!

						# puts "internal_ray_entities : #{internal_ray_entities}"
						#---------------------------------------------------------
						internal_ray_entities.each{|internal_comp|
							# puts "-------------------+++++++++ : #{internal_comp}\n\n"
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
										# puts "inner comps : #{hit_item[0]} : #{pt} : #{bound_point}"
										sel.add(hit_item[1][0])
										if dim_ents.include?(hit_item[1][0])
											hit_comp 	= hit_item[1][0]
											pt1 	= bound_point
											pt2 	= hit_item[0]

											#pt1 	= internal_comp.bounds.corner(4).offset(side_vector, 40.mm)
											pt1 	= pt.offset(side_vector, 40.mm)
											pt2 	= pt1.clone
											pt2.z 	= hit_item[0].z

											#pt1		= internal_comp.bounds.corner(0).offset(side_vector, 40.mm)
											#pt2 	= hit_item[0]
											# pt2 	= pt1;
											# pt2.z 	= hit_item[0].z
											# pt2 	= hit_item[0]
											pt1.z+=COMP_DIMENSION_OFFSET
											pt2.z+=COMP_DIMENSION_OFFSET
											internal_comp = hit_comp

											# puts "Add dimension : #{pt1} : #{pt2}"
											if (pt1.distance pt2) > 20.mm
												dim_l = Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
												dim_l.material.color = 'red'
											end
											# puts "comp : #{internal_comp} : #{internal_comp.layer.name}"
											if internal_comp.layer.name.end_with?('DRAWER_FRONT')
												pt1 	= internal_comp.bounds.corner(0)
												pt2 	= internal_comp.bounds.corner(4)
												pt1.z+=COMP_DIMENSION_OFFSET
												pt2.z+=COMP_DIMENSION_OFFSET
												dim_l 	= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
												dim_l.material.color = 'red'
												# puts "Add dimension....... : #{internal_comp} : #{pt1} : #{pt2}"
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

					}
					end

				end
			end


		rescue Exception=>e
			raise e
			Sketchup.active_model.abort_operation
		else
			Sketchup.active_model.commit_operation
		end
	end

	def self.shutter_internal_dimension comp, add_dimension_flag=true
		zvector = Geom::Vector3d.new(0, 0, 1)

		#Internal shelf fix entities
		shelf_fix_entities     = comp.definition.entities.select{|x| x.layer.name.start_with?('72IMOSXD01_IM_SHELF_FIX')}
		shelf_fix_entities.sort_by!{|x| x.transformation.origin.z}
		lower_shelf_fix    = shelf_fix_entities.first
		upper_shelf_fix       = shelf_fix_entities.last

		#Shutter outline
		shutter_code    = comp.get_attribute(:rio_atts, 'shutter-code')
		shutter_code    = comp.definition.get_attribute(:rio_atts, 'shutter-code') if shutter_code.nil?

		shutter_origin  = comp.get_attribute(:rio_atts, 'shutter-origin')
		shutter_origin    = comp.definition.get_attribute(:rio_atts, 'shutter-origin') if shutter_origin.nil?

		side_vector = Geom::Vector3d.new(1,0,0)
		trans = comp.transformation.rotz
		case trans
		when 0
			@cPos  = [0, 0, 0]
			@cTarg     = [0, 1, 0]
			@cUp   = [0, 0, 1]
			@pts   = [0, 1, 5, 4]
			@pts   = [2, 3, 7, 6]
			@side_vector = Geom::Vector3d.new(-1,0,0)
			@side_offset_wall_vector = Geom::Vector3d.new(-10,0,0)
			dim_vector = Geom::Vector3d.new(0,1,0)
		when 90
			@cPos  = [0, 0, 0]
			@cTarg     = [-1, 0, 0]
			@cUp   = [0, 0, 1]
			@pts   = [2, 0 , 4, 6]
			@pts   = [1, 3, 7, 5]
			@side_vector = Geom::Vector3d.new(0,1,0)
			@side_offset_wall_vector = Geom::Vector3d.new(0,10,0)
			dim_vector = Geom::Vector3d.new(-1,0,0)
		when -90
			@cPos  = [0, 0, 0]
			@cTarg     = [1, 0, 0]
			@cUp   = [0, 0, 1]
			@pts   = [1, 3, 7, 5]
			@pts   = [2, 0 , 4, 6]
			@side_vector = Geom::Vector3d.new(0,-1,0)
			@side_offset_wall_vector = Geom::Vector3d.new(0,-10,0)
			dim_vector = Geom::Vector3d.new(1,0,0)
		when -180, 180
			@cPos  = [0, 0, 0]
			@cTarg     = [0, -1, 0]
			@cUp   = [0, 0, 1]
			@pts   = [0, 1, 5, 4]
			@side_vector = Geom::Vector3d.new(1,0,0)
			@side_offset_wall_vector = Geom::Vector3d.new(10,0,0)
			dim_vector = Geom::Vector3d.new(0,-1,0)
		end

		comp_trans = comp.transformation

		if shutter_code
			shutter_z_origin = shutter_origin.split('_')[1].to_i.mm
			shutter_ent = comp.definition.entities.select{|e| e.definition.name.start_with?(shutter_code)}[0]
			
			#Check if shutter entities more than one.
			prev_shutter = nil
			show_dimension = true
			show_dimension_ents = shutter_ent.definition.entities.to_a.uniq{|x| x.volume.round}

			shutter_ent.definition.entities.each{ |sh_ent|
				if prev_shutter
					show_dimension     = false if DP::get_comp_volume(sh_ent).round==DP::get_comp_volume(prev_shutter).round
				end
				prev_shutter   = sh_ent
					
				comp_pts      = []
				@pts   = [2, 3, 7, 6] #Hard codeddddddddddddddddd
				@pts.each{|index|
					new_trans  =  comp_trans * Geom::Transformation.new(TT::Bounds.point(sh_ent.bounds, index))
					comp_pts << new_trans.origin
				}
				sh_ent_bounds      = sh_ent.bounds
				sh_org     = comp.transformation.origin
				shade_pts = []
				dim_vector           = Geom::Vector3d.new(0,0,1)

				4.times{|i|
					pt1, pt2 = comp_pts[0].offset(dim_vector, COMP_DIMENSION_OFFSET+shutter_z_origin), comp_pts[1].offset(dim_vector, COMP_DIMENSION_OFFSET+shutter_z_origin)
					shade_pts << [pt1.offset(dim_vector, COMP_DIMENSION_OFFSET.mm)]#, pt2.offset(dim_vector, COMP_DIMENSION_OFFSET.mm)]
					comp_outline = Sketchup.active_model.entities.add_line pt1, pt2
					comp_outline.set_attribute :rio_atts, 'dimension_entity', 'true'

					if show_dimension_ents.include?(sh_ent) && add_dimension_flag
						if i==1
							dim_l  = Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, @side_vector)
							dim_l.material.color = 'green'
							dim_l.set_attribute :rio_atts, 'dimension_entity', 'true'
							dim_l
						elsif i==0
							dim_l  = Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, zvector)
							dim_l.material.color = 'green'
							dim_l.set_attribute :rio_atts, 'dimension_entity', 'true'
						end
					end
					comp_pts.rotate!
				}
			}
		end
	#Sketchup.active_model.selection.clear
	#Sketchup.active_model.selection.add(shutter_ent)
	end

	def self.find_outer_edges(entity, transformation = IDENTITY)
		#puts entity
		if entity.is_a?( Sketchup::Model)
			# puts "Modellll."
			entity.entities.each{ |child_entity|
			  find_outer_edges(child_entity, transformation)
			}
		elsif entity.is_a?(Sketchup::Group)
			# puts "Group : #{transformation.origin} : #{entity.transformation.origin} : #{entity.definition.name} : #{entity.persistent_id}"

			entity_origin = entity.transformation.origin
			trans = entity.transformation
=begin
			if entity_origin.z < -20.mm
				new_t = Geom::Transformation.new([0, 0, -entity_origin.z])
				trans*= new_t
				puts trans
			end
=end
			transformation *= trans
			# puts "Group : #{transformation.origin}"
			sel.add(entity) if entity.transformation.origin.x < -100
			entity.definition.entities.each{ |child_entity|
			  find_outer_edges(child_entity, transformation.clone)
			}
		elsif entity.is_a?(Sketchup::ComponentInstance)
			# puts "ComponentInstance : #{transformation.origin} #{entity.persistent_id}"
			# Multiply the outer coordinate system with the group's/component's local coordinate system.
			entity_origin = entity.transformation.origin
			trans = entity.transformation
=begin
			if entity_origin.z < -20.mm
				new_t = Geom::Transformation.new([0, 0, -entity_origin.z])
				trans*= new_t
				puts trans
			end
=end
			transformation *= trans
			#transformation *= entity.transformation
			entity.definition.entities.each{ |child_entity|
				find_outer_edges(child_entity, transformation.clone)
			}
		elsif entity.is_a?(Sketchup::Face)
			#puts "Face : "
			#@verts << entity.vertices
			e_edges 	= entity.edges

			entity_origin=transformation.origin
			# puts "entity_origin : #{entity_origin}"
			if entity_origin.z < -20.mm
				new_t = Geom::Transformation.new([0, 0, -entity_origin.z])
				#transformation*= new_t
				# puts trans
			end

			e_edges.each { |edge|
				efaces 	= edge.faces
				if efaces.length == 1
					pt1 = edge.vertices[0].position
					pt2 = edge.vertices[1].position
					if entity_origin.z.abs > 20.mm
						pt1.z += entity_origin.z
						pt2.z += entity_origin.z
					end
					#edge = Sketchup.active_model.entities.add_line(pt1, pt2)
					@edges << [transformation, [pt1, pt2]]
				else
					pt1 = edge.vertices[0].position
					pt2 = edge.vertices[1].position
					if entity_origin.z.abs > 20.mm
						pt1.z += entity_origin.z
						pt2.z += entity_origin.z
					end
					#edge = Sketchup.active_model.entities.add_line(pt1, pt2)
					@edges << [transformation, [pt1, pt2]] if efaces[0].normal != efaces[1].normal
				end
			}
		end
	end

	def self.show_outer_edges comp
		@edges = []
		find_outer_edges(comp)

		@edges.each {|arr|
			parent = arr[0]
			e = arr[1]

			#puts "parent : #{parent} #{parent.origin}"
			sh_org = parent.origin
			#pt1, pt2 = e.vertices[0].position, e.vertices[1].position
			pt1, pt2 = arr[1][0], arr[1][1]
		#=begin
			pt1.x+=sh_org.x
			pt2.x+=sh_org.x
			pt1.y+=sh_org.y
			pt2.y+=sh_org.y
			pt1.z+=COMP_DIMENSION_OFFSET
			pt2.z+=COMP_DIMENSION_OFFSET
		#=end
			#puts "possns : #{e.vertices[0].position} , #{e.vertices[0].position}"
			edge_line = Sketchup.active_model.entities.add_line(pt1, pt2)

		}
	end

	# @param [Sketchup::ComponentInstance] comp
	def self.add_sliding_3door_carcass_dimension comp
		begin
			Sketchup.active_model.start_operation 'Adding dimension to carcass'
			zvector = Geom::Vector3d.new(0, 0, 1)

			shutter_code 	= comp.get_attribute(:rio_atts, 'shutter-code')
			carcass_name 	= comp.get_attribute(:rio_atts, 'carcass-code')
			carcass_group 	= comp

			comp_origin 	= comp.transformation.origin
			comp_trans 		= comp.transformation.rotz

			dimension_points = []
			#
			dim_x_offset = 0.mm
			dim_y_offset = 0.mm
			dim_x_origin 	= 0.mm
			dim_y_origin 	= 0.mm
			if true

				pts 	= []
				case comp_trans
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


				#----Explode part----------------------------
				prev_ents	=[];
				Sketchup.active_model.entities.each{|ent| prev_ents << ent}

				comp.make_unique
				comp.explode

				post_ents 	= [];
				Sketchup.active_model.entities.each{|ent| post_ents << ent}

				exploded_ents = post_ents - prev_ents
				exploded_ents.select!{|x| !x.deleted?}
				#----Explode part----------------------------

				# puts "exploded_ents.. : #{exploded_ents}"
				exploded_ents.select!{|ent| !ent.nil?}
				internal_groups = exploded_ents.grep(Sketchup::ComponentInstance).select{|x|
					x.definition.get_attribute(:rio_atts,'comp_type').end_with?('internal') if x.definition.get_attribute(:rio_atts,'comp_type')
				}

				carcass_group = exploded_ents.grep(Sketchup::Group).select{|x| x.definition.name.start_with?(carcass_name)}[0]
				carcass_group = exploded_ents.grep(Sketchup::ComponentInstance).select{|x| x.definition.name.start_with?(carcass_name)}[0] if carcass_group.nil?

				shelf_fix_entities 	= carcass_group.definition.entities.grep(Sketchup::Group).select{|x| x.layer.name.start_with?('72IMOSXD01_IM_SHELF_FIX')}
				shelf_fix_entities.sort_by!{|x| x.bounds.corner(0).z}
				lower_shelf_fix 	= shelf_fix_entities.first
			end

			# puts "internal_groups : #{internal_groups}"

			internal_groups.each{|int_group|
				# puts "=============..===================================#{int_group.definition.name}"
				#int_group = fsel

				#Adjusting components to find ray test
				if true
					internal_origin = int_group.bounds.corner(0) #int_group.bounds.corner(0)
					center_pt 		= TT::Bounds.point(int_group.bounds, 9)
					internal_end 	= int_group.bounds.corner(1)
					internal_top 	= int_group.bounds.corner(4)

					prev_ents	=[];
					Sketchup.active_model.entities.each{|ent| prev_ents << ent}

					int_group.make_unique
					int_group.explode

					post_ents 	= [];
					Sketchup.active_model.entities.each{|ent| post_ents << ent}

					internal_ents = post_ents - prev_ents
					internal_ents.select!{|x| !x.deleted?}
					internal_ents.select!{|x| x.is_a?(Sketchup::Group)}

					case comp_trans
					when 90, -90
						dim_y_origin 	= internal_origin.y
					when 0, 180, -180
						dim_x_origin 	= internal_origin.x
					end

					# puts "dim_x_origin : #{dim_x_origin} : #{dim_y_origin} : #{internal_origin} : #{comp_trans}"
					dim_ents 		= []
					other_ents	 	= []

					internal_ents.each{ |shelf_ent|
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

					dim_ents.each{|ent|
						y_offset 	= internal_origin.y - ent.bounds.corner(0).y
						trans 		= Geom::Transformation.new([0, y_offset, 0])
						ent.transform!(trans)
					}
				end

				#Find the internal entities.
				if true
					internal_ray_entities = []

					dim_ents.sort_by!{|x| x.bounds.corner(0).z}

					#Usually component origin is fully upto the carcass group
					lowest_component = dim_ents.first
					# puts "lowest_component.layer.name : #{lowest_component.layer.name}"
					internal_zoffset = internal_origin.z - comp_origin.z

					if internal_zoffset < 120.mm && lowest_component.layer.name.end_with?('DRAWER_FRONT')
						internal_ray_entities << lowest_component

						pt1 	= lowest_component.bounds.corner(0)
						pt2 	= lowest_component.bounds.corner(4)
						pt1.z+=COMP_DIMENSION_OFFSET
						pt2.z+=COMP_DIMENSION_OFFSET
						if dim_x_origin != 0.mm
							pt1.x = dim_x_origin
							pt2.x = dim_x_origin
							dim_l 					= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
						else
							pt1.y = dim_y_origin
							pt2.y = dim_y_origin
							dim_l 					= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
						end
						dim_l.material.color 	= 'blue'
						# puts "#--dim_l dim.. : #{pt1} : #{pt2} : #{dim_l.text}"
					else
						if internal_zoffset < 120.mm
							ray_pt1 	= Geom.linear_combination(0.5, internal_origin, 0.5, center_pt)
							ray_pt2 	= Geom.linear_combination(0.5, internal_end, 0.5, center_pt)
						else
							#For trans 0
							lowest_component_start 	= lowest_component.bounds.corner(4)
							lowest_component_end 	= lowest_component.bounds.corner(5)

							ray_pt1 	= Geom.linear_combination(0.5, lowest_component_start, 0.5, center_pt)
							ray_pt2 	= Geom.linear_combination(0.5, lowest_component_end, 0.5, center_pt)
						end

						# puts "ray_pt : #{internal_origin} : #{ray_pt1} : #{ray_pt2}"
						[ray_pt1, ray_pt2].each{ |ray_pt|
							ray 		= [ray_pt, zvector]
							hit_item 	= Sketchup.active_model.raytest(ray, true)

							#Get the lower most shelf entities
							if hit_item && hit_item[1][0]
								sel.add(hit_item[1][0])
								# puts "hittt : #{hit_item[1][0]} : #{hit_item[1][0].layer.name}"
								if dim_ents.include?(hit_item[1][0])
									ray_comp = hit_item[1][0]
									internal_ray_entities << ray_comp
									pt1 	= ray_pt
									pt2 	= hit_item[0]
									pt1.z	+=COMP_DIMENSION_OFFSET
									pt2.z	+=COMP_DIMENSION_OFFSET
									#puts
									if (pt1.distance pt2) > 10.mm
										if dim_x_origin != 0.mm
											pt1.x = dim_x_origin
											pt2.x = dim_x_origin
											dim_l 					= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
										else
											pt1.y = dim_y_origin
											pt2.y = dim_y_origin
											dim_l 					= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
										end
										dim_l.material.color = 'blue'
										# puts "points : #{pt1} : #{pt2}"
									end
									if ray_comp.layer.name.end_with?('DRAWER_FRONT')
										pt1 	= ray_comp.bounds.corner(0)
										pt2 	= ray_comp.bounds.corner(4)
										pt1.z+=COMP_DIMENSION_OFFSET
										pt2.z+=COMP_DIMENSION_OFFSET
										if dim_x_origin != 0.mm
											pt1.x = dim_x_origin
											pt2.x = dim_x_origin
											dim_l 					= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
										else
											pt1.y = dim_y_origin
											pt2.y = dim_y_origin
											dim_l 					= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
										end
										dim_l.material.color = 'blue'
										# puts "#--dim_l dim : #{pt1} : #{pt2}"
									end
								end
							end

						}
					end
				end

				# puts "internal_zoffset : #{internal_zoffset}"
				#Add dimension to components
				if true
					#----------Internal ray entities loop start-----------------------
					internal_ray_entities.each{|internal_comp|
						# puts "-------------------+++++++++ : #{internal_comp}\n\n"
						continue_ray 	= true
						hit_comp 		= nil
						pt1 			= TT::Bounds.point(internal_comp.bounds, 8)
						# puts "------------------------"
						# puts internal_comp.bounds.center
						# puts lower_shelf_fix.bounds.corner(4)
						if internal_zoffset > 120.mm
							a=internal_comp.bounds.corner(0).z
							b=lower_shelf_fix.bounds.corner(4).z

							high_offset 	=  a - b
							pt2 = pt1.offset(zvector.reverse, high_offset)
							pt1.z+=COMP_DIMENSION_OFFSET
							pt2.z+=COMP_DIMENSION_OFFSET

							if dim_x_origin != 0.mm
								pt1.x = dim_x_origin
								pt2.x = dim_x_origin
								dim_l 					= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
							else
								pt1.y = dim_y_origin
								pt2.y = dim_y_origin
								dim_l 					= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
							end
							dim_l.material.color = 'blue'
							# puts "#--dim_l dim#### : #{pt1} : #{pt2}"
							# puts "comp initial : #{dim_l.text}"
						end

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
									#puts "inner comps : #{hit_item[0]} : #{pt} : #{bound_point}"
									sel.add(hit_item[1][0])
									if dim_ents.include?(hit_item[1][0])
										hit_comp 	= hit_item[1][0]
										pt1 	= bound_point
										pt2 	= hit_item[0]

										#pt1 	= internal_comp.bounds.corner(4).offset(side_vector, 40.mm)
										pt1 	= pt.offset(side_vector, 40.mm)
										pt2 	= pt1.clone
										pt2.z 	= hit_item[0].z

										#pt1		= internal_comp.bounds.corner(0).offset(side_vector, 40.mm)
										#pt2 	= hit_item[0]
										# pt2 	= pt1;
										# pt2.z 	= hit_item[0].z
										# pt2 	= hit_item[0]
										pt1.z+=COMP_DIMENSION_OFFSET
										pt2.z+=COMP_DIMENSION_OFFSET


										#puts "Add dimension : #{pt1} : #{pt2}"
										if (pt1.distance pt2) > 10.mm
											if dim_x_origin != 0.mm
												pt1.x = dim_x_origin
												pt2.x = dim_x_origin
												dim_l 					= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
											else
												pt1.y = dim_y_origin
												pt2.y = dim_y_origin
												dim_l 					= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
											end
											# puts "#--dim_l dim : #{pt1} : #{pt2}"
											dim_l.material.color = 'red'
										end
										#puts "comp : #{internal_comp} : #{internal_comp.layer.name}"
										if hit_comp.layer.name.end_with?('DRAWER_FRONT')
											pt1 	= hit_comp.bounds.corner(0)
											pt2 	= hit_comp.bounds.corner(4)
											pt1.z+=COMP_DIMENSION_OFFSET
											pt2.z+=COMP_DIMENSION_OFFSET
											if dim_x_origin != 0.mm
												pt1.x = dim_x_origin
												pt2.x = dim_x_origin
												dim_l 					= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
											else
												pt1.y = dim_y_origin
												pt2.y = dim_y_origin
												dim_l 					= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
											end
											# puts "#--dim_l dim : #{pt1} : #{pt2}"
											dim_l.material.color = 'red'
											#puts "Add dimension....... : #{hit_comp} : #{pt1} : #{pt2}"
										end
										internal_comp = hit_comp
										next_pt 	= false
									else
										continue_ray = false
									end
								else
									continue_ray = false
								end
							}
						end#While

						if hit_comp
							# puts "hit_comp : #{hit_comp} : #{internal_top}"
							high_offset =  internal_top.z - hit_comp.bounds.corner(4).z
							if high_offset > 20.mm
								# puts "high_offset : #{high_offset} : #{internal_top.z} : #{hit_comp.bounds.corner(4).z} : #{dim_x_origin}"

								pt1 = TT::Bounds.point(hit_comp.bounds, 10)
								pt2 = pt1.offset(zvector, high_offset)
								# puts "pt........ #{pt1} : #{pt2}"
								pt1.z+=COMP_DIMENSION_OFFSET
								pt2.z+=COMP_DIMENSION_OFFSET
								if dim_x_origin != 0.mm
									pt1.x = dim_x_origin
									pt2.x = dim_x_origin
									dim_l 					= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
								else
									pt1.y = dim_y_origin
									pt2.y = dim_y_origin
									dim_l 					= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
								end
								dim_l.material.color = 'orange'
							end
						end


					}
				end


				#----------Internal ray entities loop end -----------------------
				# puts "internal_ray_entities : #{internal_ray_entities}"
				internal_ray_entities.flatten!

				# puts "dim_ents :#{dim_ents}"
				dim_ents.each { |x| puts x.layer.name}
				# puts "+++++++++++++++++++++++++++++++++++++++++"
			}
		rescue Exception=>e
			raise e
			Sketchup.active_model.abort_operation
		else
			#Sketchup.active_model.abort_operation
		end
		return true
	end

    def self.add_sliding_2door_carcass_dimension comp

		begin
			Sketchup.active_model.start_operation 'Adding dimension to carcass'
			zvector = Geom::Vector3d.new(0, 0, 1)

			shutter_code 	= comp.get_attribute(:rio_atts, 'shutter-code')
			carcass_name 	= comp.get_attribute(:rio_atts, 'carcass-code')
			carcass_group 	= comp

			comp_origin 	= comp.transformation.origin
			comp_trans 			= comp.transformation.rotz

			dimension_points = []
			#
			dim_x_offset 	= 0.mm
			dim_y_offset 	= 0.mm
			dim_x_origin 	= 0.mm
			dim_y_origin 	= 0.mm
			if true

				pts 	= []
				case comp_trans
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


				#----Explode part----------------------------
				prev_ents	=[];
				Sketchup.active_model.entities.each{|ent| prev_ents << ent}

				comp.make_unique
				comp.explode

				post_ents 	= [];
				Sketchup.active_model.entities.each{|ent| post_ents << ent}

				exploded_ents = post_ents - prev_ents
				exploded_ents.select!{|x| !x.deleted?}
				#----Explode part----------------------------

				# puts "exploded_ents.. : #{exploded_ents}"
				exploded_ents.select!{|ent| !ent.nil?}
				internal_groups = exploded_ents.grep(Sketchup::ComponentInstance).select{|x|
					x.definition.get_attribute(:rio_atts,'comp_type').end_with?('internal') if x.definition.get_attribute(:rio_atts,'comp_type')
				}

				carcass_group = exploded_ents.grep(Sketchup::Group).select{|x| x.definition.name.start_with?(carcass_name)}[0]
				carcass_group = exploded_ents.grep(Sketchup::ComponentInstance).select{|x| x.definition.name.start_with?(carcass_name)}[0] if carcass_group.nil?

				shelf_fix_entities = carcass_group.definition.entities.grep(Sketchup::Group).select{|x| x.layer.name.start_with?('72IMOSXD01_IM_SHELF_FIX')}
				shelf_fix_entities.sort_by!{|x| x.bounds.corner(0).z}
				lower_shelf_fix 	= shelf_fix_entities.first
			end

			internal_groups.each{|int_group|

				# puts "\n\n------------------#{int_group}"
				#int_group = fsel
				internal_origin = int_group.bounds.corner(0)
				center_pt 		= TT::Bounds.point(int_group.bounds, 8)
				internal_end 	= int_group.bounds.corner(1)
				internal_top 	= int_group.bounds.corner(4)

				prev_ents	=[];
				Sketchup.active_model.entities.each{|ent| prev_ents << ent}

				int_group.make_unique
				int_group.explode

				post_ents 	= [];
				Sketchup.active_model.entities.each{|ent| post_ents << ent}

				internal_ents = post_ents - prev_ents
				internal_ents.select!{|x| !x.deleted?}
				internal_ents.select!{|x| x.is_a?(Sketchup::Group)}


				dim_ents 		= []
				other_ents	 	= []

				internal_ents.each{ |shelf_ent|
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
				# puts "dim_ents... :#{dim_ents}"
				dim_ents.each{|dim_ent|
					y_offset 	= lower_shelf_fix.bounds.corner(0).y - dim_ent.bounds.corner(0).y
					# puts "y_offset : #{y_offset} : #{dim_ent}"
					trans 		= Geom::Transformation.new([0, y_offset, 0])
					# puts "trans : #{trans.origin} : #{dim_ent.bounds.corner(0)}"
					dim_ent.transform!(trans)
					# puts "post trans #{dim_ent.bounds.corner(0)}"
				}
				internal_origin.y 	= lower_shelf_fix.bounds.corner(0).y
				internal_end.y		= lower_shelf_fix.bounds.corner(0).y
				#---------------------------------------------------------
				ray_pt1 	= Geom.linear_combination(0.5, internal_origin, 0.5, center_pt)
				ray_pt2 	= Geom.linear_combination(0.5, internal_end, 0.5, center_pt)
				# puts "ray_pt : #{ray_pt1} : #{ray_pt2}"
				internal_ray_entities = []

				[ray_pt1, ray_pt2].each{ |ray_pt|
					ray 		= [ray_pt, zvector]
					hit_item 	= Sketchup.active_model.raytest(ray, true)

					#Get the lower most shelf entities
					if hit_item && hit_item[1][0]
						sel.add(hit_item[1][0])
						# puts "hittt : #{hit_item[1][0].layer.name}"
						if dim_ents.include?(hit_item[1][0])
							ray_comp = hit_item[1][0]
							internal_ray_entities << ray_comp
							pt1 	= ray_pt
							pt2 	= hit_item[0]
							pt1.z+=COMP_DIMENSION_OFFSET
							pt2.z+=COMP_DIMENSION_OFFSET

							#puts
							if (pt1.distance pt2) > 20.mm
								dim_l = Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, Geom::Vector3d.new(1,0,0))
								dim_l.material.color = 'orange'
								# puts "points : #{pt1} : #{pt2}"
							end
							if ray_comp.layer.name.end_with?('DRAWER_FRONT')
								pt1 	= ray_comp.bounds.corner(0)
								pt2 	= ray_comp.bounds.corner(4)
								pt1.z+=COMP_DIMENSION_OFFSET
								pt2.z+=COMP_DIMENSION_OFFSET
								dim_l 	= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
								dim_l.material.color = 'orange'
							end
						end
					end

				}
				internal_ray_entities.flatten!

				# puts "internal_ray_entities : #{internal_ray_entities}"
				#---------------------------------------------------------

				internal_ray_entities.each{|internal_comp|
					# puts "-------------------+++++++++ : #{internal_comp}\n\n"
					continue_ray 	= true
					hit_comp 		= nil
					pt1 			= TT::Bounds.point(internal_comp.bounds, 8)
					# puts "------------------------"
					# puts internal_comp.bounds.center
					# puts lower_shelf_fix.bounds.corner(4)

					a=internal_comp.bounds.center.z
					b=lower_shelf_fix.bounds.corner(4).z

					high_offset 	=  a - b
					pt2 = pt1.offset(zvector.reverse, high_offset)

					pt1.z+=COMP_DIMENSION_OFFSET
					pt2.z+=COMP_DIMENSION_OFFSET

					dim_l = Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
					dim_l.material.color = 'blue'

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
								# puts "inner comps : #{hit_item[0]} : #{pt} : #{bound_point}"
								sel.add(hit_item[1][0])
								if dim_ents.include?(hit_item[1][0])
									hit_comp 	= hit_item[1][0]
									pt1 	= bound_point
									pt2 	= hit_item[0]

									#pt1 	= internal_comp.bounds.corner(4).offset(side_vector, 40.mm)
									pt1 	= pt.offset(side_vector, 40.mm)
									pt2 	= pt1.clone
									pt2.z 	= hit_item[0].z

									#pt1		= internal_comp.bounds.corner(0).offset(side_vector, 40.mm)
									#pt2 	= hit_item[0]
									# pt2 	= pt1;
									# pt2.z 	= hit_item[0].z
									# pt2 	= hit_item[0]
									pt1.z+=COMP_DIMENSION_OFFSET
									pt2.z+=COMP_DIMENSION_OFFSET


									# puts "Add dimension : #{pt1} : #{pt2}"
									if (pt1.distance pt2) > 20.mm
										dim_l = Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
										dim_l.material.color = 'red'
									end
									#puts "comp : #{internal_comp} : #{internal_comp.layer.name}"
									if hit_comp.layer.name.end_with?('DRAWER_FRONT')
										pt1 	= hit_comp.bounds.corner(0)
										pt2 	= hit_comp.bounds.corner(4)
										pt1.z+=COMP_DIMENSION_OFFSET
										pt2.z+=COMP_DIMENSION_OFFSET
										dim_l 	= Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
										dim_l.material.color = 'red'
										# puts "Add dimension....... : #{hit_comp} : #{pt1} : #{pt2}"
									end
									internal_comp = hit_comp
									next_pt 	= false
								else
									continue_ray = false
								end
							else
								continue_ray = false
							end
						}
					end#While

					if hit_comp
						# puts "hit_comp : #{hit_comp} : #{internal_top}"
						high_offset =  internal_top.z - hit_comp.bounds.corner(4).z
						if high_offset > 20.mm
							# puts "high_offset : #{high_offset} : #{internal_top.z} : #{hit_comp.bounds.corner(4).z}"

							pt1 = TT::Bounds.point(hit_comp.bounds, 10)
							pt2 = pt1.offset(zvector, high_offset)
							# puts "pt........ #{pt1} : #{pt2}"
							pt1.z+=COMP_DIMENSION_OFFSET
							pt2.z+=COMP_DIMENSION_OFFSET
							dim_l = Sketchup.active_model.entities.add_dimension_linear(pt1, pt2, side_vector)
							dim_l.material.color = 'green'
						end
					end


				}

			}#internal_groups
		rescue Exception=>e
			raise e
			Sketchup.active_model.abort_operation
		else
			Sketchup.active_model.commit_operation
		end
	end

    def self.show_outlines_and_dimension comp
		add_carcass_dimension comp
	end
end