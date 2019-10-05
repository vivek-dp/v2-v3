require "csv"
require 'C:\RioSTD\external_libs\sqlite3.rb'

module Decor_Standards
	@dbname = 'rio_std'
	@db = SQLite3::Database.new(@dbname)
	@table = 'rio_standards'
	@int_table = 'rio_slidings'
	@bucket_name = 'rio-bucket-1'

	def self.get_main_space(input)
		getval = @db.execute("select distinct space from #{@table} order by space asc;")
		mainspace = ""
		getval.each {|val|
			spval = val[0].gsub("_", " ")
			if val[0] == input
				mainspace += '<option value="'+val[0]+'" selected="selected">'+spval+'</option>'
			else
				mainspace += '<option value="'+val[0]+'">'+spval+'</option>'
			end
		}
		mainspace1 = '<select class="ui dropdown" id="main-space" onchange="changeSpaceCategory(this.value)"><option value="0">Select...</option>'+mainspace+'</select>'
		return mainspace1
	end

	def self.add_option(input, type)
		values = DP::get_space_names
		arrval = []
		if values.count != 0
			mainspace = ""
			values.each {|val|
				if type == 1
					if val == input
						mainspace += '<option value="'+val+'" selected="selected">'+val+'</option>'
					else
						mainspace += '<option value="'+val+'">'+val+'</option>'
					end
				else
					mainspace += '<option value="'+val+'">'+val+'</option>'
				end
			}
			mainspace1 = '<select class="ui dropdown" id="space_list" onchange="changeSpaceList(this.value)"><option value="0">Select...</option>'+mainspace+'</select>'
			arrval.push(mainspace1)
		end
		return arrval
	end

	def self.get_main_cat
		maincat = @db.execute("select distinct space from #{@table} order by space asc;")
		mainarr = []
		maincat.each {|v|
			mainarr.push(v[0])
		}
		return mainarr
	end

	def self.get_sub_cat(val)
		subcat = @db.execute("select distinct category from #{@table} where space='#{val}' order by category asc;")
		subarr = []
		subcat.each {|sc|
			subarr.push(sc[0])
		}
		return subarr
	end

	def self.get_sub_space(input, type)
		if type == 1
			getsub = @db.execute("select distinct category from #{@table} where space='#{input[0]}' order by category asc;")
		else
			getsub = @db.execute("select distinct category from #{@table} where space='#{input}' order by category asc;")
		end

		subspace = ""
		getsub.each{|subc|
			spval = subc[0].gsub("_", " ")
			if type.to_i == 1
				if subc[0] == input[1]
					subspace += '<option value="'+subc[0]+'" selected="selected">'+spval+'</option>' 
				else
					subspace += '<option value="'+subc[0]+'">'+spval+'</option>' 
				end
			else
				subspace += '<option value="'+subc[0]+'">'+spval+'</option>' 
			end
		}
		subspace1 = '<select class="ui dropdown" id="sub-space" onchange="changesubSpace(this.value)"><option value="0">Select...</option>'+subspace+'</select>'
		return subspace1
	end

	def self.check_carcass_image(inp1, inp2)
		chkimg = @db.execute("select distinct carcass_code, category from #{@table} where space='#{inp1}' and category='#{inp2}';" )
		cararr = []
		for i in chkimg
			carcass_image = i[0] + '.jpg'
			aws_carcass_path = File.join('carcass',inp1,carcass_image)
			local_carcass_path = File.join(RIO_ROOT_PATH,'cache',carcass_image)
			RioAwsDownload::download_file @bucket_name, aws_carcass_path, local_carcass_path

			if File.exist?(local_carcass_path) != false
				cararr.push(i[0]+"|"+i[1]+"|"+local_carcass_path)
			end			
		end
		return cararr
	end

	def self.get_pro_code(inp, type)
		getco = @db.execute("select distinct carcass_code from #{@table} where space='#{inp[0]}' and category='#{inp[1]}';" )
		proco = ""
		getco.each{|cod|
			spval = cod[0].gsub("_", " ")
			if type == 1
				if inp[2] == cod[0]
					proco += '<option value="'+cod[0]+'" selected="selected">'+spval+'</option>' 
				else
					proco += '<option value="'+cod[0]+'">'+spval+'</option>' 
				end
			else
				proco += '<option value="'+cod[0]+'">'+spval+'</option>' 
			end
		}
		proco1 = '<select class="ui dropdown" id="carcass-code" onchange="changeProCode()"><option value="0">Select...</option>'+proco+'</select>'
		return proco1
	end

	def self.get_comp_image(options)
		main_category = options[0]
		main_category = 'Crockery_Unit' if main_category.start_with?('Crockery')
		sub_category = options[1] #options['sub-category'] #We will use it for decription
		carcass_code = options[2]
		
		#------------------------------------------------------------------------------------------------
		carcass_jpg = carcass_code+'.jpg'
		aws_carcass_path = File.join('carcass',main_category,carcass_jpg)
		local_carcass_path = File.join(RIO_ROOT_PATH,'cache',carcass_jpg)

		RioAwsDownload::download_file @bucket_name, aws_carcass_path, local_carcass_path
		#skppath = DECORPOT_CUST_ASSETS + "/" + input[0] + "/" + imgname + ".jpg"
		# puts skppath
		#return skppath
		return local_carcass_path
	end

	def self.get_carcass_image(input, type)
		maincat = input[0]
		maincat = 'Crockery_Unit' if maincat.start_with?('Crockery')
		getimg = @db.execute("select distinct carcass_code, height, depth, width from #{@table} where space='#{input[0]}' and category='#{input[1]}' order by carcass_code asc;" )
		cararr = []
		for i in getimg
			carcass_image = i[0] + '.jpg'
			aws_carcass_path = File.join('carcass',maincat,carcass_image)
			local_carcass_path = File.join(RIO_ROOT_PATH,'cache',carcass_image)
			RioAwsDownload::download_file @bucket_name, aws_carcass_path, local_carcass_path

			if File.exist?(local_carcass_path) != false
				cararr.push(i[0]+","+i[1]+","+i[2]+","+i[3]+","+local_carcass_path)
			end			
		end

		dircarcase = ""
		path_length = (cararr.length/3)+1
		path_length.times{|index|
			images_arr = cararr.shift(3)
			splitval1 = images_arr[0].split(",") if !images_arr[0].nil?
			val1 = splitval1 if !splitval1.nil?
			splitval2 = images_arr[1].split(",") if !images_arr[1].nil?
			val2 = splitval2 if !splitval2.nil?
			splitval3 = images_arr[2].split(",") if !images_arr[2].nil?
			val3 = splitval3 if !splitval3.nil?

			dircarcase += '<div class="ui equal width grid" style="border:1px solid grey;">'
			dircarcase += '<div class="column" style="border-right:1px solid grey;"><div class="carname"><span style="color:chocolate;">'+input[1]+'_'+val1[0]+'</span><br>Height:'+val1[1]+'<span class="mandatory"> | </span>Depth:'+val1[2]+'<span class="mandatory"> | </span>Width:'+val1[3]+'</div><div class="carimage"><div class="container"><img src="'+val1[4]+'" width="150" height="150" value="'+val1[0]+'"><div class="middle"><div class="text" value="'+val1[4]+'" onclick="getCarImg(this)"><i class="search plus icon"></i></div></div></div></div><div class="sel-carcass"><div class="ui radio checkbox"><input type="radio" name="car_img" value="'+val1[0]+'" onclick="checkCar(this.value)"><label style="color:white;">Select</label></div></div></div>' if !val1.nil?
			dircarcase += '<div class="column" style="border-right:1px solid grey;"><div class="carname"><span style="color:chocolate;">'+input[1]+'_'+val2[0]+'</span><br>Height:'+val2[1]+'<span class="mandatory"> | </span>Depth:'+val2[2]+'<span class="mandatory"> | </span>Width:'+val2[3]+'</div><div class="carimage"><div class="container"><img src="'+val2[4]+'" width="150" height="150" value="'+val2[0]+'"><div class="middle"><div class="text" value="'+val2[4]+'" onclick="getCarImg(this)"><i class="search plus icon"></i></div></div></div></div><div class="sel-carcass"><div class="ui radio checkbox"><input type="radio" name="car_img" value="'+val2[0]+'" onclick="checkCar(this.value)"><label style="color:white;">Select</label></div></div></div>' if !val2.nil?
			dircarcase += '<div class="column"><div class="carname"><span style="color:chocolate;">'+input[1]+'_'+val3[0]+'</span><br>Height:'+val3[1]+'<span class="mandatory"> | </span>Depth:'+val3[2]+'<span class="mandatory"> | </span>Width:'+val3[3]+'</div><div class="carimage"><div class="container"><img src="'+val3[4]+'" width="150" height="150" value="'+val3[0]+'"><div class="middle"><div class="text" value="'+val3[4]+'" onclick="getCarImg(this)"><i class="search plus icon"></i></div></div></div></div><div class="sel-carcass"><div class="ui radio checkbox"><input type="radio" name="car_img" value="'+val3[0]+'" onclick="checkCar(this.value)"><label style="color:white;">Select</label></div></div></div>' if !val3.nil?
			dircarcase += '</div>'
		}

		return dircarcase
	end

	def self.get_carcass_details(main, subc, car, ptype)
		val_arr = []
		get_name = @db.execute("select shutter_code, type, solid, glass, alu, ply, shutter_origin, opening, carcass_name from #{@table} where space='#{main}' and category='#{subc}' and carcass_code='#{car}';")
		if ptype.to_i == 1
			val_arr.push('shutter_code|'+fsel.get_attribute(:rio_atts, 'shutter-code'))
		else
			val_arr.push('shutter_code|'+get_name[0][0])
		end
		val_arr.push('type|'+get_name[0][1])
		val_arr.push('solid|'+get_name[0][2])
		val_arr.push('glass|'+get_name[0][3])
		val_arr.push('alu|'+get_name[0][4])
		val_arr.push('ply|'+get_name[0][5])
		val_arr.push('shut_org|'+get_name[0][6])
		#if !get_name[0][1].include?('Drawer')
			if ptype.to_i == 1 && get_name[0][7] != 'No'
				val_arr.push('opening|'+fsel.get_attribute(:rio_atts, 'shutter-open'))
			else
				val_arr.push('opening|'+get_name[0][7])
			end
		#else
		#	val_arr.push('opening|'+'No')
		#end
		val_arr.push('car_name|'+get_name[0][8])
		val_arr.push('car_code|'+car)

		return val_arr
	end

	def self.get_shutter_image(input)
		getimg = @db.execute("select shutter_code from #{@table} where space='#{input[0]}' and category='#{input[1]}' and carcass_code='#{input[2]}';")
		inp = getimg[0][0].split("/")
		shutarr = []
		for i in inp
			shutter_image = i + '.jpg'
			aws_shutter_path = File.join('shutter',shutter_image)
			local_shut_path = File.join(RIO_ROOT_PATH,'cache', shutter_image)
			RioAwsDownload::download_file @bucket_name, aws_shutter_path, local_shut_path
			shutarr.push(i + '|' + local_shut_path)
		end
		return shutarr
	end

	def self.get_internal_data(val1, val2)
		val2 = val2.split("_")
		json = []
		getint = @db.execute("select left, center, right from #{@int_table} where door_type="+val2[1]+" and slide_width="+val2[2]+" and category="+val1+";")
		json.push("left|"+getint[0][0])
		json.push("center|"+getint[0][1])
		json.push("right|"+getint[0][2])
		return json
	end

	def self.get_intnal(internal, edit)
		json = []
		int_arr = ['left_internal', 'right_internal'] if internal.to_i == 2
		int_arr = ['left_internal', 'center_internal', 'right_internal'] if internal.to_i == 3

		int_arr.each{|int|
			key = int.gsub('_internal', '|')
			json.push(key+fsel.get_attribute(:rio_atts, int))
		}
		return json
	end

	def self.get_internal_codes main_category, sub_category, carcass_code
		if (main_category.include?("Sliding") == true || main_category.include?("sliding") == true)
			getcat 	= carcass_code.split("_")
			get_val = @db.execute("select distinct category from #{@int_table} where door_type=#{getcat[1]} and slide_width=#{getcat[2]};")
		end

		if get_val.nil?
			return {}
		else
			return get_val 
		end
	end

	def self.place_component options
		comp_origin = nil
		return false if options.empty?
		bucket_name     = 'rio-bucket-1'

		# puts "comp_options : #{options}"
		if options['edit'] == 1
			sel = Sketchup.active_model.selection[0]
			comp_origin = sel.transformation.origin
			comp_trans = sel.transformation
			Sketchup.active_model.entities.erase_entities sel
		end

		space_name = options['space_name']
		main_category = options['main-category']
		main_category = 'Crockery_Unit' if main_category.start_with?('Crockery') #Temporary mapping ....Move crockery to base unit and top unit later in the AWS server
		sub_category = options['sub-category']   #We will use it for decription
		carcass_code = options['carcass-code']
		shutter_code = options['shutter-code']||''
		internal_code = options['internal-category']||''
		shutter_origin = options['shutter-origin']||''


		#------------------------------------------------------------------------------------------------
		carcass_skp         = carcass_code+'.skp'
		aws_carcass_path    = File.join('carcass',main_category,carcass_skp)
		local_carcass_path  = File.join(RIO_ROOT_PATH,'cache',carcass_skp)

		if File.exists?(local_carcass_path)
		  puts "File already present "
		else
	    # puts "Downloading carcass..."
	    resp = RioAwsDownload::download_file bucket_name, aws_carcass_path, local_carcass_path
	    if resp.nil?
	        puts "Carcass file download error  : "+aws_carcass_path
	        return false
	    end
		end
		#------------------------------------------------------------------------------------------------
		if shutter_code.empty?
		  local_shutter_path = ''
		else
	    shutter_skp         = shutter_code+'.skp'
	    aws_shutter_path    = File.join('shutter',shutter_skp)
	    local_shutter_path  = File.join(RIO_ROOT_PATH,'cache',shutter_skp)
	    # puts shutter_skp, aws_shutter_path
			unless File.exists?(local_shutter_path)
				# puts "Downloading shutter....."
				RioAwsDownload::download_file bucket_name, aws_shutter_path, local_shutter_path
				if resp.nil?
	        puts "Shutter file download error  : "+aws_shutter_path
	        return false
	    	end
	    end
		end
		dict_name = 'carcase_spec'
		k2 = 'attr_product_name'
		v2 = sub_category
		k1 = 'attr_product_code'
		v1 = carcass_code

		defn = DP::create_carcass_definition local_carcass_path, local_shutter_path, shutter_origin, options['right_internal'], options['left_internal'], options['center_internal']
		# defn = DP::create_carcass_definition local_carcass_path, local_shutter_path, shutter_origin, internal_code
		defn.set_attribute(:rio_atts, 'rio_comp', 'true')
		defn.set_attribute(:rio_atts, 'space_name', space_name)
    defn.set_attribute(:rio_atts, 'carcass-code', carcass_code)
    defn.set_attribute(:rio_atts, 'shutter-code', shutter_code)
        
		defn.set_attribute(dict_name, k2, v2)
		defn.set_attribute(dict_name, k1, v1)

		options.each{|k, v|
			defn.set_attribute(:rio_atts, k, v)
		}
		prev_active_layer = Sketchup.active_model.active_layer.name
		Sketchup.active_model.active_layer = 'DP_Comp_layer'

		inst = nil
		if V2_V3_CONVERSION_FLAG
			if options['auto_mode'] == "true"
				sel_comp = Sketchup.active_model.selection[0]
				if sel_comp.nil?
					UI.messagebox 'Component not selected for auto mode. Select component and retry or switch off auto mode.', MB_OK
					return false
				end 
				if sel_comp.layer.name != 'DP_Comp_layer'
					UI.messagebox 'Select Rio component for auto mode', MB_OK
					return false
				end
				rotz = sel_comp.transformation.rotz
				comp_origin = sel_comp.transformation.origin
				cdef = defn
				sel_bounds = sel_comp.bounds
				comp = sel_comp 

				posn = options['auto_position']
				case posn
				when 'bottom_left'
					# puts "bottom_left : #{rotz}"
					z_depth 	= comp.bounds.depth-cdef.bounds.depth
					y_depth     = comp.bounds.height-cdef.bounds.height
					x_depth		= comp.bounds.width-cdef.bounds.height
					case rotz
					when 0
						trans   = Geom::Transformation.new([comp_origin.x-cdef.bounds.width, comp_origin.y+y_depth, comp_origin.z])
						inst    = Sketchup.active_model.active_entities.add_instance cdef, trans
					when 90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x-x_depth, comp_origin.y-cdef.bounds.width, comp_origin.z])
						inst.transfor m!(trans)
					when 180, -180
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x+cdef.bounds.width, comp_origin.y-y_depth, comp_origin.z])
						inst.transform!(trans)
					when -90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x+x_depth, comp_origin.y+cdef.bounds.width, comp_origin.z])
						inst.transform!(trans)
					end
				when 'front'
					z_depth 	= comp.bounds.depth-cdef.bounds.depth
					y_depth     = comp.bounds.height-cdef.bounds.height
					x_depth		= comp.bounds.width-cdef.bounds.height
									
									rotz.abs==180 ? corner_rotz=rotz+90 : corner_rotz=-90
					# puts "corner_rotz : #{corner_rotz}"
					
					case rotz
					when 0
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, 90.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x+cdef.bounds.height, comp_origin.y-cdef.bounds.width, comp_origin.z])
						inst.transform!(trans)
					when 90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, 180.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x+cdef.bounds.width, comp_origin.y+cdef.bounds.height, comp_origin.z])
						inst.transform!(trans)
					when 180, -180
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, 270.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x-cdef.bounds.height, comp_origin.y+cdef.bounds.width, comp_origin.z])
						inst.transform!(trans)
					when -90
						#tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, 0.degrees)
						#inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x-cdef.bounds.width, comp_origin.y-cdef.bounds.height, comp_origin.z])
						inst    = Sketchup.active_model.active_entities.add_instance cdef, trans
						#inst.transform!(trans)
					end
				when 'top_left'
					z_depth 	= comp.bounds.depth-cdef.bounds.depth
					y_depth     = comp.bounds.height-cdef.bounds.height
					x_depth		= comp.bounds.width-cdef.bounds.height
					case rotz
					when 0
						trans   = Geom::Transformation.new([comp_origin.x-cdef.bounds.width, comp_origin.y+y_depth, comp_origin.z+z_depth])
						inst    = Sketchup.active_model.active_entities.add_instance cdef, trans
					when 90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x-x_depth, comp_origin.y-cdef.bounds.width, comp_origin.z+z_depth])
						inst.transform!(trans)
					when 180, -180
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x+cdef.bounds.width, comp_origin.y-y_depth,  comp_origin.z+z_depth])
						inst.transform!(trans)
					when -90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x+x_depth, comp_origin.y+cdef.bounds.width,  comp_origin.z+z_depth])
						inst.transform!(trans)
					end
				when 'bottom_right'
					z_depth 	= comp.bounds.depth-cdef.bounds.depth
					y_depth     = comp.bounds.height-cdef.bounds.height
					x_depth		= comp.bounds.width-cdef.bounds.height
					# puts "x_depth : #{x_depth} : #{comp.bounds.width} : #{cdef.bounds.width}"
					case rotz
					when 0
						trans   = Geom::Transformation.new([comp_origin.x+sel_comp.bounds.width, comp_origin.y+y_depth, comp_origin.z])
						inst    = Sketchup.active_model.active_entities.add_instance cdef, trans
					when 90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x-x_depth, comp_origin.y+sel_comp.bounds.height, comp_origin.z])
						inst.transform!(trans)
					when 180, -180
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans = Geom::Transformation.new([comp_origin.x-sel_comp.bounds.width, comp_origin.y-y_depth, comp_origin.z])
						inst.transform!(trans)
					when -90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans = Geom::Transformation.new([comp_origin.x+x_depth, comp_origin.y-sel_comp.bounds.height, comp_origin.z])
						inst.transform!(trans)
					end
				when 'top_right'
					z_depth 	= comp.bounds.depth-cdef.bounds.depth
					y_depth     = comp.bounds.height-cdef.bounds.height
					x_depth		= comp.bounds.width-cdef.bounds.height
					case rotz
					when 0
						trans   = Geom::Transformation.new([comp_origin.x+sel_comp.bounds.width, comp_origin.y+y_depth, comp_origin.z+z_depth])
						inst    = Sketchup.active_model.active_entities.add_instance cdef, trans
					when 90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x-x_depth, comp_origin.y+comp.bounds.height, comp_origin.z+z_depth])
						inst.transform!(trans)
					when 180, -180
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans = Geom::Transformation.new([comp_origin.x-sel_comp.bounds.width, comp_origin.y-y_depth,  comp_origin.z+z_depth])
						inst.transform!(trans)
					when -90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans = Geom::Transformation.new([comp_origin.x+x_depth, comp_origin.y-sel_comp.bounds.height,  comp_origin.z+z_depth])
						inst.transform!(trans)
					end
				when 'top'
					z_depth 	= comp.bounds.depth-cdef.bounds.depth
					y_depth     = comp.bounds.height-cdef.bounds.height
					x_depth		= comp.bounds.width-cdef.bounds.height
					# puts "comp_origin.x : #{comp_origin.x} : #{x_depth}"
					case rotz
					when 0
						trans   = Geom::Transformation.new([comp_origin.x, comp_origin.y+y_depth, comp_origin.z+comp.bounds.depth])
						inst    = Sketchup.active_model.active_entities.add_instance cdef, trans
					when 90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x-x_depth, comp_origin.y, comp_origin.z+comp.bounds.depth])
						inst.transform!(trans)
					when 180, -180
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans = Geom::Transformation.new([comp_origin.x, comp_origin.y-y_depth, comp_origin.z+comp.bounds.depth])
						inst.transform!(trans)
					when -90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans 	= Geom::Transformation.new([comp_origin.x+x_depth, comp_origin.y, comp_origin.z+comp.bounds.depth])
						inst.transform!(trans)
					end
				when 'bottom'
					z_depth 	= comp.bounds.depth-cdef.bounds.depth
					y_depth     = comp.bounds.height-cdef.bounds.height
					x_depth		= comp.bounds.width-cdef.bounds.height
					case rotz
					when 0
						trans   = Geom::Transformation.new([comp_origin.x, comp_origin.y+y_depth, comp_origin.z-cdef.bounds.depth])
						inst    = Sketchup.active_model.active_entities.add_instance cdef, trans
					when 90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x-x_depth, comp_origin.y, comp_origin.z-cdef.bounds.depth])
						inst.transform!(trans)
					when 180, -180
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans = Geom::Transformation.new([comp_origin.x, comp_origin.y-y_depth, comp_origin.z-cdef.bounds.depth])
						inst.transform!(trans)
					when -90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans = Geom::Transformation.new([comp_origin.x+x_depth, comp_origin.y, comp_origin.z-cdef.bounds.depth])
						inst.transform!(trans)
					end
				end
				if inst && !V2_V3_CONVERSION_FLAG
					wall_overlap_flag 	= DP::check_wall_overlap(inst, space_name)
					comp_over_flag 		= DP::check_comp_overlap(inst, space_name)
					comp_floor_overlap 	= DP::check_comp_floor_overlap(inst, space_name)
					comp_ceiling_overlap 	= DP::check_comp_ceiling_overlap(inst, space_name)

					# puts "wall_overlap_flag : #{wall_overlap_flag} : #{comp_over_flag}, "
					if wall_overlap_flag
						UI.messagebox "Component Overlaps the wall. Cannot place it."
						Sketchup.active_model.entities.erase_entities inst
					elsif comp_over_flag
						UI.messagebox "Component Overlaps the selected component. Cannot place it. Removing the new instance."
						Sketchup.active_model.entities.erase_entities inst 
					elsif comp_floor_overlap
						UI.messagebox "Component placement will make it go below room bounds. Cannot place it."
						Sketchup.active_model.entities.erase_entities inst
					elsif comp_ceiling_overlap
						UI.messagebox "Component placement will make it go above room ceiling bounds. Cannot place it."
						Sketchup.active_model.entities.erase_entities inst
					else
						Sketchup.active_model.selection.clear
						Sketchup.active_model.selection.add(inst)
					end
				end

			else
				wall_offset_point   = Sketchup.active_model.get_attribute(:rio_atts, 'wall_offset_pt')
				if wall_offset_point
					place_type = 'wall'
				else
					place_type = 'manual'
				end
				RIO::CivilHelper::place_component defn, place_type
			end
		else
			if options['auto_mode'] == "true"
				sel_comp = Sketchup.active_model.selection[0]
				if sel_comp.nil?
					UI.messagebox 'Component not selected for auto mode. Select component and retry or switch off auto mode.', MB_OK
					return false
				end 
				if sel_comp.layer.name != 'DP_Comp_layer'
					UI.messagebox 'Select Rio component for auto mode', MB_OK
					return false
				end
				rotz = sel_comp.transformation.rotz
				comp_origin = sel_comp.transformation.origin
				cdef = defn
				sel_bounds = sel_comp.bounds
				comp = sel_comp 

				posn = options['auto_position']
				case posn
				when 'bottom_left'
					# puts "bottom_left : #{rotz}"
					z_depth 	= comp.bounds.depth-cdef.bounds.depth
					y_depth     = comp.bounds.height-cdef.bounds.height
					x_depth		= comp.bounds.width-cdef.bounds.height
					case rotz
					when 0
						trans   = Geom::Transformation.new([comp_origin.x-cdef.bounds.width, comp_origin.y+y_depth, comp_origin.z])
						inst    = Sketchup.active_model.active_entities.add_instance cdef, trans
					when 90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x-x_depth, comp_origin.y-cdef.bounds.width, comp_origin.z])
						inst.transform!(trans)
					when 180, -180
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x+cdef.bounds.width, comp_origin.y-y_depth, comp_origin.z])
						inst.transform!(trans)
					when -90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x+x_depth, comp_origin.y+cdef.bounds.width, comp_origin.z])
						inst.transform!(trans)
					end
				when 'front'
					z_depth 	= comp.bounds.depth-cdef.bounds.depth
					y_depth     = comp.bounds.height-cdef.bounds.height
					x_depth		= comp.bounds.width-cdef.bounds.height
									
									rotz.abs==180 ? corner_rotz=rotz+90 : corner_rotz=-90
					# puts "corner_rotz : #{corner_rotz}"
					
					case rotz
					when 0
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, 90.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x+cdef.bounds.height, comp_origin.y-cdef.bounds.width, comp_origin.z])
						inst.transform!(trans)
					when 90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, 180.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x+cdef.bounds.width, comp_origin.y+cdef.bounds.height, comp_origin.z])
						inst.transform!(trans)
					when 180, -180
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, 270.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x-cdef.bounds.height, comp_origin.y+cdef.bounds.width, comp_origin.z])
						inst.transform!(trans)
					when -90
						#tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, 0.degrees)
						#inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x-cdef.bounds.width, comp_origin.y-cdef.bounds.height, comp_origin.z])
						inst    = Sketchup.active_model.active_entities.add_instance cdef, trans
						#inst.transform!(trans)
					end
				when 'top_left'
					z_depth 	= comp.bounds.depth-cdef.bounds.depth
					y_depth     = comp.bounds.height-cdef.bounds.height
					x_depth		= comp.bounds.width-cdef.bounds.height
					case rotz
					when 0
						trans   = Geom::Transformation.new([comp_origin.x-cdef.bounds.width, comp_origin.y+y_depth, comp_origin.z+z_depth])
						inst    = Sketchup.active_model.active_entities.add_instance cdef, trans
					when 90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x-x_depth, comp_origin.y-cdef.bounds.width, comp_origin.z+z_depth])
						inst.transform!(trans)
					when 180, -180
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x+cdef.bounds.width, comp_origin.y-y_depth,  comp_origin.z+z_depth])
						inst.transform!(trans)
					when -90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x+x_depth, comp_origin.y+cdef.bounds.width,  comp_origin.z+z_depth])
						inst.transform!(trans)
					end
				when 'bottom_right'
					z_depth 	= comp.bounds.depth-cdef.bounds.depth
					y_depth     = comp.bounds.height-cdef.bounds.height
					x_depth		= comp.bounds.width-cdef.bounds.height
					# puts "x_depth : #{x_depth} : #{comp.bounds.width} : #{cdef.bounds.width}"
					case rotz
					when 0
						trans   = Geom::Transformation.new([comp_origin.x+sel_comp.bounds.width, comp_origin.y+y_depth, comp_origin.z])
						inst    = Sketchup.active_model.active_entities.add_instance cdef, trans
					when 90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x-x_depth, comp_origin.y+sel_comp.bounds.height, comp_origin.z])
						inst.transform!(trans)
					when 180, -180
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans = Geom::Transformation.new([comp_origin.x-sel_comp.bounds.width, comp_origin.y-y_depth, comp_origin.z])
						inst.transform!(trans)
					when -90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans = Geom::Transformation.new([comp_origin.x+x_depth, comp_origin.y-sel_comp.bounds.height, comp_origin.z])
						inst.transform!(trans)
					end
				when 'top_right'
					z_depth 	= comp.bounds.depth-cdef.bounds.depth
					y_depth     = comp.bounds.height-cdef.bounds.height
					x_depth		= comp.bounds.width-cdef.bounds.height
					case rotz
					when 0
						trans   = Geom::Transformation.new([comp_origin.x+sel_comp.bounds.width, comp_origin.y+y_depth, comp_origin.z+z_depth])
						inst    = Sketchup.active_model.active_entities.add_instance cdef, trans
					when 90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x-x_depth, comp_origin.y+comp.bounds.height, comp_origin.z+z_depth])
						inst.transform!(trans)
					when 180, -180
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans = Geom::Transformation.new([comp_origin.x-sel_comp.bounds.width, comp_origin.y-y_depth,  comp_origin.z+z_depth])
						inst.transform!(trans)
					when -90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans = Geom::Transformation.new([comp_origin.x+x_depth, comp_origin.y-sel_comp.bounds.height,  comp_origin.z+z_depth])
						inst.transform!(trans)
					end
				when 'top'
					z_depth 	= comp.bounds.depth-cdef.bounds.depth
					y_depth     = comp.bounds.height-cdef.bounds.height
					x_depth		= comp.bounds.width-cdef.bounds.height
					# puts "comp_origin.x : #{comp_origin.x} : #{x_depth}"
					case rotz
					when 0
						trans   = Geom::Transformation.new([comp_origin.x, comp_origin.y+y_depth, comp_origin.z+comp.bounds.depth])
						inst    = Sketchup.active_model.active_entities.add_instance cdef, trans
					when 90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x-x_depth, comp_origin.y, comp_origin.z+comp.bounds.depth])
						inst.transform!(trans)
					when 180, -180
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans = Geom::Transformation.new([comp_origin.x, comp_origin.y-y_depth, comp_origin.z+comp.bounds.depth])
						inst.transform!(trans)
					when -90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans 	= Geom::Transformation.new([comp_origin.x+x_depth, comp_origin.y, comp_origin.z+comp.bounds.depth])
						inst.transform!(trans)
					end
				when 'bottom'
					z_depth 	= comp.bounds.depth-cdef.bounds.depth
					y_depth     = comp.bounds.height-cdef.bounds.height
					x_depth		= comp.bounds.width-cdef.bounds.height
					case rotz
					when 0
						trans   = Geom::Transformation.new([comp_origin.x, comp_origin.y+y_depth, comp_origin.z-cdef.bounds.depth])
						inst    = Sketchup.active_model.active_entities.add_instance cdef, trans
					when 90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans   = Geom::Transformation.new([comp_origin.x-x_depth, comp_origin.y, comp_origin.z-cdef.bounds.depth])
						inst.transform!(trans)
					when 180, -180
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans = Geom::Transformation.new([comp_origin.x, comp_origin.y-y_depth, comp_origin.z-cdef.bounds.depth])
						inst.transform!(trans)
					when -90
						tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, rotz.degrees)
						inst    = Sketchup.active_model.active_entities.add_instance cdef, tr
						trans = Geom::Transformation.new([comp_origin.x+x_depth, comp_origin.y, comp_origin.z-cdef.bounds.depth])
						inst.transform!(trans)
					end
				end
				if inst && !V2_V3_CONVERSION_FLAG
					wall_overlap_flag 	= DP::check_wall_overlap(inst, space_name)
					comp_over_flag 		= DP::check_comp_overlap(inst, space_name)
					comp_floor_overlap 	= DP::check_comp_floor_overlap(inst, space_name)
					comp_ceiling_overlap 	= DP::check_comp_ceiling_overlap(inst, space_name)

					# puts "wall_overlap_flag : #{wall_overlap_flag} : #{comp_over_flag}, "
					if wall_overlap_flag
						UI.messagebox "Component Overlaps the wall. Cannot place it."
						Sketchup.active_model.entities.erase_entities inst
					elsif comp_over_flag
						UI.messagebox "Component Overlaps the selected component. Cannot place it. Removing the new instance."
						Sketchup.active_model.entities.erase_entities inst 
					elsif comp_floor_overlap
						UI.messagebox "Component placement will make it go below room bounds. Cannot place it."
						Sketchup.active_model.entities.erase_entities inst
					elsif comp_ceiling_overlap
						UI.messagebox "Component placement will make it go above room ceiling bounds. Cannot place it."
						Sketchup.active_model.entities.erase_entities inst
					else
						Sketchup.active_model.selection.clear
						Sketchup.active_model.selection.add(inst)
					end
				end

				# puts "trans: #{trans}"
			else
				xy_point 		= Sketchup.active_model.get_attribute :rio_global, 'wall_xy_point'
				offset_side 	= Sketchup.active_model.get_attribute :rio_global, 'wall_offset_side'
				if xy_point
					sel 		= Sketchup.active_model.selection[0]
					if sel.nil?
						pid = Sketchup.active_model.get_attribute :rio_global, 'wall_selected'
						sel = DP::get_comp_pid pid.to_i
					end
					wall_trans 	= sel.get_attribute :rio_atts, 'wall_trans'
					z_offset	= xy_point[0].to_i.mm
					if offset_side == 'left'
						case wall_trans.to_i.round
						when 0
							x_offset 	= sel.bounds.corner(0).x + xy_point[1].to_i.mm
							y_offset 	= sel.bounds.corner(0).y-defn.bounds.height 
						when 90
							x_offset 	= sel.bounds.corner(1).x + defn.bounds.height
							y_offset  	= sel.bounds.corner(1).y+xy_point[1].to_i.mm
						when -90
							x_offset 	= sel.bounds.corner(2).x - defn.bounds.height
							y_offset  	= sel.bounds.corner(2).y-xy_point[1].to_i.mm
						when 180
							x_offset 	= sel.bounds.corner(1).x - xy_point[1].to_i.mm
							y_offset    = sel.bounds.corner(3).y + defn.bounds.height
						end
					elsif offset_side == 'right'
						wall_length = sel.get_attribute(:rio_atts, 'view_wall_length').to_i.mm
						case wall_trans.to_i.round 
						when 0
							x_offset 	= sel.bounds.corner(0).x - xy_point[1].to_i.mm + wall_length - defn.bounds.width
							y_offset 	= sel.bounds.corner(0).y - defn.bounds.height 
						when 90
							x_offset 	= sel.bounds.corner(1).x + defn.bounds.height 
							y_offset 	= sel.bounds.corner(1).y + wall_length - defn.bounds.width - xy_point[1].to_i.mm
						when -90
							x_offset 	= sel.bounds.corner(2).x - defn.bounds.height 
							y_offset 	= sel.bounds.corner(2).y - wall_length + defn.bounds.width + xy_point[1].to_i.mm
						when 180, -180
							x_offset 	= sel.bounds.corner(3).x - wall_length + defn.bounds.width + xy_point[1].to_i.mm
							y_offset 	= sel.bounds.corner(3).y + defn.bounds.height
						end
					end
					# puts x_offset, y_offset, z_offset
					#comp_trans 	= Geom::Transformation.new([x_offset, y_offset, z_offset])
					#Sketchup.active_model.entities.add_instance defn, comp_trans
					tr      = Geom::Transformation.rotation([0, 0, 0], Z_AXIS, wall_trans.degrees)
					inst    = Sketchup.active_model.active_entities.add_instance defn, tr
					comp_trans 	= Geom::Transformation.new([x_offset, y_offset, z_offset])
					inst.transform!(comp_trans)
					flag = false
					if inst
						wall_overlap_flag 	= DP::check_wall_overlap(inst, space_name)
						comp_over_flag 		= DP::check_comp_overlap(inst, space_name)
						comp_floor_overlap 	= DP::check_comp_floor_overlap(inst, space_name)
						comp_ceiling_overlap 	= DP::check_comp_ceiling_overlap(inst, space_name)
						# puts "wall_overlap_flag : #{wall_overlap_flag} : #{comp_over_flag}, "
						if wall_overlap_flag
							UI.messagebox "Component Overlaps the wall. Cannot place it."
							Sketchup.active_model.entities.erase_entities inst
						elsif comp_over_flag
							UI.messagebox "Component Overlaps the selected component. Cannot place it. Removing the new instance."
							Sketchup.active_model.entities.erase_entities inst 
						elsif comp_floor_overlap
							UI.messagebox "Component placement will make it go below room bounds. Cannot place it."
							Sketchup.active_model.entities.erase_entities inst
						elsif comp_ceiling_overlap
							UI.messagebox "Component placement will make it go above room ceiling bounds. Cannot place it."
							Sketchup.active_model.entities.erase_entities inst
						else
							Sketchup.active_model.selection.clear
							Sketchup.active_model.selection.add(inst)
							inst.set_attribute :rio_atts, 'space_name', space_name
							DP::update_all_room_components
						end
					end
					Sketchup.active_model.set_attribute(:rio_global, 'wall_xy_point', nil)
				else
					puts "Manual Comp placement "
					if options['edit'] == 1
						inst = Sketchup.active_model.entities.add_instance defn, comp_trans
					else
						inst = Sketchup.active_model.place_component defn
					end
				end
			end
		end
		puts "inst : #{inst} : #{options}"
		if inst
			if inst.is_a?(Sketchup::ComponentInstance) && !inst.deleted?
				dictionaries = ['carcass_spec', 'rio_atts']
				inst.definition.attribute_dictionaries.each{|dict|
					next if !dictionaries.include?(dict.name)
					dict.each_pair {|key,val| 
						puts "comp_group : #{key} : #{val} : #{dict_name}"
						inst.set_attribute dict.name, key, val 
					}
				}
			end
		end
		Sketchup.active_model.active_layer = prev_active_layer
		return true
  end

	def self.get_datas(inp, type)
		valhash = []
		getdat = @db.execute("select shutter_code, type, solid, glass, alu, ply, shutter_origin, opening from #{@table} where space='#{inp[0]}' and category='#{inp[1]}' and carcass_code='#{inp[2]}';")
		if type == 1
			if !$shutter_code.nil?
				valhash.push('shutter_code|'+$shutter_code)
			else
				valhash.push('shutter_code|'+'No')
			end
		else
			valhash.push('shutter_code|'+getdat[0][0])
		end
		valhash.push('type|'+getdat[0][1])
		valhash.push('solid|'+getdat[0][2])
		valhash.push('glass|'+getdat[0][3])
		valhash.push('alu|'+getdat[0][4])
		valhash.push('ply|'+getdat[0][5])
		valhash.push('shut_org|'+getdat[0][6])
		if type == 1
			if !Sketchup.active_model.selection[0].get_attribute(:rio_atts, 'shutter-open').nil?
				valhash.push('opening|'+Sketchup.active_model.selection[0].get_attribute(:rio_atts, 'shutter-open'))
			else
				valhash.push('opening|'+'No')
			end
		else
			valhash.push('opening|'+getdat[0][7])
		end

		return valhash
	end

	def self.get_internal_category(input)
		if (input[1].include?("Sliding") == true || input[1].include?("sliding") == true)
			getcat = input[2].split("_")
			get_val = @db.execute("select distinct category, left, right, center,category_name from #{@int_table} where door_type=#{getcat[1]} and slide_width=#{getcat[2]};")
		
			int_img = ''
			for i in get_val
				img_left = RIO_ROOT_PATH + '/webpages/images/internals/' + i[1] + '.jpg'
				img_right = RIO_ROOT_PATH + '/webpages/images/internals/' + i[2] + '.jpg'
				img_center = RIO_ROOT_PATH + '/webpages/images/internals/' + i[3] + '.jpg' if getcat[1].to_i == 3

				int_img += '<div class="row brow">'
				int_img += '<div class="column bright" style="padding-top:5em;color:orange;word-wrap:break-word;">'+i[4]+'</div>'
				int_img += '<div class="column bright"><div class="container"><img src="'+img_left+'"><div class="middle"><div class="text" value="'+img_left+'" onclick="intImgSrc(this)"><i class="search plus icon"></i></div></div></div><div class="sel-int"><div class="ui radio checkbox"><input type="radio" name="'+getcat[1]+'_lhs" value="'+i[1]+'" onclick="checkleft(this.value)" class="checkRadio"><label style="color:white;">Select</label></div></div></div>' if !i[1].nil?
				int_img += '<div class="column bright"><div class="container"><img src="'+img_center+'"><div class="middle"><div class="text" value="'+img_center+'" onclick="intImgSrc(this)"><i class="search plus icon"></i></div></div></div><div class="sel-int"><div class="ui radio checkbox"><input type="radio" name="'+getcat[1]+'_lhs_rhs" value="'+i[3]+'" onclick="checkcen(this.value)" class="checkRadio"><label style="color:white;">Select</label></div></div></div>' if getcat[1].to_i == 3
				int_img += '<div class="column bright"><div class="container"><img src="'+img_right+'"><div class="middle"><div class="text" value="'+img_right+'" onclick="intImgSrc(this)"><i class="search plus icon"></i></div></div></div><div class="sel-int"><div class="ui radio checkbox"><input type="radio" name="'+getcat[1]+'_rhs" value="'+i[2]+'" onclick="checkright(this.value)" class="checkRadio"><label style="color:white;">Select</label></div></div></div>' if !i[2].nil?
				cat2 = i[1]+','+i[2]
				cat3 = i[1]+','+i[3]+','+i[2]
				int_img += '<div class="column bright" style="padding-top:5em;"><div class="ui radio checkbox"><input type="radio" name="'+getcat[1]+'_all" value="'+cat2+'" onclick="checkboth(this.value)" class="checkAll"><label style="color:white;">Select All</label></div></div>' if getcat[1].to_i == 2
				int_img += '<div class="column bright" style="padding-top:5em;"><div class="ui radio checkbox"><input type="radio" name="'+getcat[1]+'_all" value="'+cat3+'" onclick="checkboth(this.value)" class="checkAll"><label style="color:white;">Select All</label></div></div>' if getcat[1].to_i == 3
				int_img += '</div>'
			end
		end

		if get_val.nil?
			return {}
		else
			return int_img 
		end
	end
end