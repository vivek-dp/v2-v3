require 'json'

module Decor_Standards

	UI.add_context_menu_handler do |menu|
		model = Sketchup.active_model
		selection = model.selection[0]
		if selection 
			case selection
			when Sketchup::ComponentInstance
				rio_comp = selection.definition.get_attribute(:rio_atts, 'rio_comp')
				rio_comp = selection.get_attribute(:rio_atts, 'rio_comp') if rio_comp.nil?

				if selection.layer.name.start_with?('RIO_Civil_Wall')
					#menu.add_item("Add Rio Component") {self.get_wall_point}
				elsif rio_comp.nil?
					rbm = menu.add_submenu("Rio Tools")
					rbm.add_item("Add to Rio Component") { DP::add_to_rio_components selection}
				else
					rbm = menu.add_submenu("Rio Tools")
					rbm.add_item("Add Attribute") { self.add_attr_from_menu }
					rbm.add_item("Add Filler") { DP::check_filler selection }
					rbm.add_item("Add Skirting") { DP::add_skirting selection }
					rbm.add_item("Add Adjacent Component") { self.comp_auto_placement }
					rbm.add_item("Edit/View Component") { self.edit_view_component } if rio_comp == 'true'

					# rac = menu.add_submenu("Add Rio Component")
					# @getcat = self.get_main_cat
					# @getcat.each{|mc|
					# 	m = mc.gsub("_", " ")
					# 	rasc = rac.add_submenu(m)
					# 	@subcat = self.get_sub_cat(mc)
					# 	@subcat.each {|sc|
					# 		s = sc.gsub("_", " ")
					# 		rasc.add_item(s) { self.add_comp_from_menu(mc, sc) }
					# 	}
					# }
				end
			when Sketchup::Group
        if selection.layer.name.start_with?('DP_Wall')
          #menu.add_item("Add Rio Component") {self.get_wall_point}
        else
          rio_comp = selection.definition.get_attribute(:rio_atts, 'rio_comp')
          rio_comp = selection.get_attribute(:rio_atts, 'rio_comp') if rio_comp.nil?
          if rio_comp.nil?
            rbm = menu.add_submenu("Rio Tools")
            rbm.add_item("Add to Rio Component") { DP::add_to_rio_components selection}
          else
            rbm = menu.add_submenu("Rio Tools")
            #rbm.add_item("Add Component") { self.add_comp_from_menu } if rio_comp == true
            rbm.add_item("Add Attribute") { self.add_attr_from_menu }
            rbm.add_item("Add Filler") { DP::check_filler selection }
            rbm.add_item("Edit/View Component") { self.edit_view_component } if rio_comp == 'true'
          end
        end
			end
		end
	end

	def self.get_wall_point
		if $current_page && !$current_page.include?("add_comp")
			js_page = "document.getElementById('add_comp').click();"
			$rio_dialog.execute_script(js_page)
		end
		type = 2
		chval = "passAutoOff()"
		$rio_dialog.execute_script(chval)
		sleep 0.1
		walloffset_dlg = UI::HtmlDialog.new({:dialog_title=>"RioSTD - Wall Offset Point", :preferences_key=>"com.rio.plugin", :scrollable=>false, :resizable=>false, :style=>UI::HtmlDialog::STYLE_DIALOG})
		html_path = File.join(WEBDIALOG_PATH, 'load_walloffset.html')
		walloffset_dlg.set_file(html_path)
		walloffset_dlg.set_size(280, 250)
		walloffset_dlg.center
		walloffset_dlg.show

		walloffset_dlg.add_action_callback("send_walloffset"){|dlg, params|
			walloffset_dlg.close
			param = JSON.parse(params)

			Sketchup.active_model.set_attribute(:rio_global, 'wall_xy_point', param['xy_point'])
			Sketchup.active_model.set_attribute(:rio_global, 'wall_offset_side', param['offset_side']) if param['offset_side'] != '0'
			seln = Sketchup.active_model.selection
			Sketchup.active_model.set_attribute(:rio_global, 'wall_selected', seln[0].persistent_id)

			rom_attr = Sketchup.active_model.selection[0].get_attribute(:rio_atts, 'room_name')
			update_space = self.add_option(rom_attr, 1)
			jspag = "passSpaceName("+[update_space].to_s+","+type.to_s+")"
			$rio_dialog.execute_script(jspag)
		}
  end

	def self.add_attr_from_menu
		$rio_dialog.show
		js_page = "document.getElementById('add_attr').click();"
		$rio_dialog.execute_script(js_page)
		sleep 0.1
		jsupt = "document.getElementById('rootpath').value='#{RIO_ROOT_PATH}';"
		$rio_dialog.execute_script(jsupt)
	end

	def self.add_comp_from_menu(maincat, subcat)
		$rio_dialog.show
		jscomp = "document.getElementById('add_comp').click();"
		$rio_dialog.execute_script(jscomp)
		sleep 0.1
		$add_rio_comp = 1
		$main_category = maincat
		$sub_category = subcat
	end

	def self.comp_auto_placement
		jspage = "document.getElementById('add_comp').click();"
		$rio_dialog.execute_script(jspage)
		sleep 0.5
		corner = Sketchup.active_model.selection[0].get_attribute(:rio_atts, 'sub-category')
		if corner.include?("Bifolding")
			show_front = 1
		else
			show_front = 0
		end
		jsact = "turnOnAuto("+[show_front].to_s+")"
		$rio_dialog.execute_script(jsact)
		sleep 0.1
		rom_attr = Sketchup.active_model.selection[0].get_attribute(:rio_atts, 'space_name')
		get_space = self.add_option(rom_attr, 1)
		# puts "get_spa=-------------#{get_space}"
		jspag = "passSpaceName("+[get_space].to_s+","+2.to_s+")"
    	$rio_dialog.execute_script(jspag)
	end

	def self.edit_view_component
		$edit_val = 1
		$rio_dialog.show
		js_page = "document.getElementById('add_comp').click();"
		$rio_dialog.execute_script(js_page)
		sleep 0.1
		jspage = "document.getElementById('page_type').value=1;"
		$rio_dialog.execute_script(jspage)

		model = Sketchup.active_model
		selection = model.selection[0]

		$space_name = selection.definition.get_attribute(:rio_atts, 'space_name')
		$main_category = selection.definition.get_attribute(:rio_atts, 'main-category')
		$sub_category = selection.definition.get_attribute(:rio_atts, 'sub-category')
		$carcass_code = selection.definition.get_attribute(:rio_atts, 'carcass-code')
		$shutter_code = selection.definition.get_attribute(:rio_atts, 'shutter-code')
		$door_type = selection.definition.get_attribute(:rio_atts, 'door-type')
		$shutter_type = selection.definition.get_attribute(:rio_atts, 'shutter-type')
		$internal_category = selection.definition.get_attribute(:rio_atts, 'internal-category')
	end

	def self.set_window(inp_page, key, value)
	 	js_cpage = "document.getElementById('#{inp_page}').click();"
		$rio_dialog.execute_script(js_cpage)
		sleep 0.1
		js_1page = "document.getElementById('#{key}').value='#{value}';"
		$rio_dialog.execute_script(js_1page)
	end

	def self.enable_wall_radio
		jsenable = "document.getElementById('wall_mode').style.display='block';"
		$wall_dialog.execute_script(jsenable)
	end

	def self.decor_index(*args)
		$edit_val = 0
		$rio_dialog = UI::HtmlDialog.new({:dialog_title=>"RioSTD", :preferences_key=>"com.sample.plugin", :scrollable=>false, :resizable=>true, :style=>UI::HtmlDialog::STYLE_DIALOG})
		html_path = File.join(WEBDIALOG_PATH, 'index.html')
		$rio_dialog.set_file(html_path)
		$rio_dialog.set_position(0, 80)
		$rio_dialog.set_size(650, 780)
		$rio_dialog.show 

		$rio_dialog.add_action_callback("current-page"){|dlg, param|
			$current_page = param
			if !$current_page.include?("add_comp")
				Sketchup.active_model.layers.each{|lay|
					lay.visible = true if lay.name.include?("DP_Wall_")
				}
			end
		}

		$rio_dialog.add_action_callback("get_detail"){|a, b|
			$current_page = 'add_pro_detail'
			nametit = Sketchup.active_model.get_attribute(:rio_global, 'name_title')
			cliname = Sketchup.active_model.get_attribute(:rio_global, 'client_name')
			proname = Sketchup.active_model.get_attribute(:rio_global, 'project_name')
			tdate = Sketchup.active_model.get_attribute(:rio_global, 'target_date')
			cli_name = "#{nametit}. #{cliname}"
			jscli = "document.getElementById('cliname').innerHTML='#{cli_name}'"
			$rio_dialog.execute_script(jscli)
			sleep 0.1
			jspro = "document.getElementById('proname').innerHTML='#{proname}'"
			$rio_dialog.execute_script(jspro)
			sleep 0.1
			if !tdate.nil?
				date = Date.parse tdate
				jsdate = "document.getElementById('datenote').innerHTML='Target Completion Date: #{date.strftime('%d-%B-%Y')}'"
				$rio_dialog.execute_script(jsdate)
			end
		}

		$rio_dialog.add_action_callback("uptdetail"){|a, b|
			uptdval = self.uptdetail()
			jsupt = "uptAttrValue("+uptdval.to_s+")"
			$rio_dialog.execute_script(jsupt)
		}

		$rio_dialog.add_action_callback("check-bifold"){|dlg, param|
			begin
				if Sketchup.active_model.selection[0].get_attribute(:rio_atts, 'sub-category').include?("Bifolding")
					show_front = 1
				else
					show_front = 0
				end
			rescue
				show_front = 0
			end
			jshow = "turnOnAuto("+[show_front].to_s+")"
			$rio_dialog.execute_script(jshow)
		}

		$rio_dialog.add_action_callback("pro_details"){|a, b|
			params = JSON.parse(b)
			for k in params
				Sketchup.active_model.set_attribute(:rio_global, k[0], k[1])
			end
			nametit = Sketchup.active_model.get_attribute(:rio_global, 'name_title')
			cliname = Sketchup.active_model.get_attribute(:rio_global, 'client_name')
			proname = Sketchup.active_model.get_attribute(:rio_global, 'project_name')
			tdate = Sketchup.active_model.get_attribute(:rio_global, 'target_date')
			cli_name = "#{nametit}. #{cliname}"

			jscli = "document.getElementById('cliname').innerHTML='#{cli_name}'"
			$rio_dialog.execute_script(jscli)
			sleep 0.1
			jspro = "document.getElementById('proname').innerHTML='#{proname}'"
			$rio_dialog.execute_script(jspro)
			sleep 0.1

			if !tdate.nil?
				tar_date = Date.parse tdate
			 	jsdate = "document.getElementById('datenote').innerHTML='Target Completion Date: #{tar_date.strftime('%d-%B-%Y')}'"
			 	$rio_dialog.execute_script(jsdate)
			end

			jscpage = "document.getElementById('add_space').click();"
			$rio_dialog.execute_script(jscpage)
		}

		$rio_dialog.add_action_callback("getspacelist"){|a, b|
			mainval = []
			values = DP::get_space_names
			values.each {|val|
				getsp = MRP::get_room_components val
				mainval.push(val) if getsp.length != 0
			}
			jsadd = "passSpaceList("+mainval.to_s+")"
		 	$rio_dialog.execute_script(jsadd)
		}

		$rio_dialog.add_action_callback("get-spdetail"){|a, b|
			spdetail = self.get_space_detail(b)
			if spdetail['door'] == true
				jsdoor = "document.getElementById('show_doorheight').style.display='block';"
				$rio_dialog.execute_script(jsdoor)
			end
			if spdetail['window'] == true
				jswino = "document.getElementById('show_winoff').style.display='block';"
				$rio_dialog.execute_script(jswino)
				sleep 0.1
				jswinh = "document.getElementById('show_winheight').style.display='block';"
				$rio_dialog.execute_script(jswinh)
			end
		}

		$rio_dialog.add_action_callback("create_space_walls"){|dialog, params|
			inputs = JSON.parse(params)
			# puts "create : #{inputs}"
			DP::add_wall_to_floor inputs
		}

		$rio_dialog.add_action_callback("selectRoomTool") {|dialog, params|
			room_tool_inst = RoomTool.instance
			Sketchup.active_model.select_tool(room_tool_inst)
		}

		$rio_dialog.add_action_callback("submitval"){|i, j|
			# creat_wall = self.creating_wall(j)
			param = JSON.parse(j)
			creat_wall = DP::create_wall param
			js_done = "page_comp()"
			$rio_dialog.execute_script(js_done)
		}

		$rio_dialog.add_action_callback("method_addwall"){|dialog, params|
			alval = []
			wall_layer = Sketchup.active_model.layers.add "Wall"
			['Wall', 'Door', 'Window'].each {|layer_name|
				layer = Sketchup.active_model.layers[layer_name]
				layer.name=layer_name if layer
			}
			['RIO_Wall', 'RIO_Door', 'RIO_Window'].each {|layer_name|
				layer = Sketchup.active_model.layers[layer_name]
				layer.name=layer_name if layer
			}
			edges = Sketchup.active_model.selection.select{|ent| ent.is_a?(Sketchup::Edge)}
			wall_layer_name = V2_V3_CONVERSION_FLAG ? 'RIO_Wall' : 'Wall'
			if edges.count != 0
				edges.each {|edg|
					edg.layer = Sketchup.active_model.layers[wall_layer_name]
				}
				alval.push(wall_layer_name)
				alval.push(1)
			else
				alval.push(wall_layer_name)
				alval.push(0)
			end
			jswall = "spaceAlert("+alval.to_s+")"
			$rio_dialog.execute_script(jswall)
		}

		$rio_dialog.add_action_callback("method_adddoor"){|dialog, params|
			alval = []
			door_layer = Sketchup.active_model.layers.add "Door"
			['Wall', 'Door', 'Window'].each {|layer_name|
				layer = Sketchup.active_model.layers[layer_name]
				layer.name=layer_name if layer
			}
			['RIO_Wall', 'RIO_Door', 'RIO_Window'].each {|layer_name|
				layer = Sketchup.active_model.layers[layer_name]
				layer.name=layer_name if layer
			}
			edges = Sketchup.active_model.selection.select{|ent| ent.is_a?(Sketchup::Edge)}
			door_layer_name = V2_V3_CONVERSION_FLAG ? 'RIO_Door' : 'Door'
			if edges.count != 0
				edges.each {|edg|
					edg.layer = Sketchup.active_model.layers[door_layer_name]
				}
				alval.push(door_layer_name)
				alval.push(1)
			else
				alval.push(door_layer_name)
				alval.push(0)
			end
			jsdoor = "spaceAlert("+alval.to_s+")"
			$rio_dialog.execute_script(jsdoor)
		}

		$rio_dialog.add_action_callback("method_addwindow"){|dialog, params|
			alval = []
			window_layer = Sketchup.active_model.layers.add "Window"
			['Wall', 'Door', 'Window'].each {|layer_name|
				layer = Sketchup.active_model.layers[layer_name]
				layer.name=layer_name if layer
			}
			['RIO_Wall', 'RIO_Door', 'RIO_Window'].each {|layer_name|
				layer = Sketchup.active_model.layers[layer_name]
				layer.name=layer_name if layer
			}
			edges = Sketchup.active_model.selection.select{|ent| ent.is_a?(Sketchup::Edge)}
			window_layer_name = V2_V3_CONVERSION_FLAG ? 'RIO_Window' : 'Window'
			if edges.count != 0
				edges.each {|edg|
					edg.layer = Sketchup.active_model.layers[window_layer_name]
				}
				alval.push(window_layer_name)
				alval.push(1)
			else
				alval.push(window_layer_name)
				alval.push(0)
			end
			jswin = "spaceAlert("+alval.to_s+")"
			$rio_dialog.execute_script(jswin)
		}

		$rio_dialog.add_action_callback("method_addroom"){|dialog, params|
			['Wall', 'Door', 'Window'].each {|layer_name|
				layer = Sketchup.active_model.layers[layer_name]
				layer.name=layer_name if layer
			}
			['RIO_Wall', 'RIO_Door', 'RIO_Window'].each {|layer_name|
				layer = Sketchup.active_model.layers[layer_name]
				layer.name=layer_name if layer
			}
			
			room_tool_inst = RoomTool.instance
			Sketchup.active_model.select_tool(room_tool_inst)
			Sketchup.set_status_text(("Please click on a space to add room, otherwise press Esc button to deactivate tool." ),SB_PROMPT)
		}

		$rio_dialog.add_action_callback("method_addface"){|dialog, params|
			Sketchup.active_model.entities.grep(Sketchup::Edge).each{|edge| edge.find_faces}
		}		

		$rio_dialog.add_action_callback("loadmaincatagory"){|a, b|
			mainarr = []
			value = self.load_main_category()
			mainarr.push(value)
			js_maincat = "passMainCategoryToJs("+mainarr.to_s+")"
			$rio_dialog.execute_script(js_maincat)
		}

		$rio_dialog.add_action_callback("get_category"){|a, b|
			subarr = []
			subval = self.load_sub_category(b.to_s)
			subarr.push(subval)
			js_subcat = "passSubCategoryToJs("+subarr.to_s+")"
			$rio_dialog.execute_script(js_subcat)
		}

		$rio_dialog.add_action_callback("load-sketchupfile"){|a, b|
			cat = b.split(",")
			# puts "cat-----#{cat}"
			skpval = self.load_skp_file(cat)
			js_command = "passSkpToJavascript("+ skpval.to_s + ")"
			$rio_dialog.execute_script(js_command)
		}

		$rio_dialog.add_action_callback("place_model"){|a, b|
			self.place_Defcomponent(b)
		}

		# $rio_dialog.add_action_callback("load_attr"){|dlg, par|
		# 	$attr_page = 1
		# }

		$rio_dialog.add_action_callback("loaddatas"){|a, b|
			lam_default = RIO_ROOT_PATH+'/webpages/images/'
			jsupt = "document.getElementById('rootpath').value='#{RIO_ROOT_PATH}/webpages/images';"
			$rio_dialog.execute_script(jsupt)
			sleep 0.1
			# Sketchup.active_model.selection.add_observer(MySelectionObserver.new)
			@model = Sketchup.active_model
			@selection = @model.selection[0]
			if @selection.nil?
				UI.messagebox 'Component not selected!', MB_OK
			elsif Sketchup.active_model.selection[1] != nil then
				UI.messagebox 'More than one component selected!', MB_OK
			else
				getval = self.get_attr_value()
				js_maincat = "passValToJs("+getval.to_s+")"
				$rio_dialog.execute_script(js_maincat)
			end
		}

		$rio_dialog.add_action_callback("upd_attribute"){|a, b|
			uptval = self.update_attr(b)
			if uptval.to_i == 1
				js_maincat = "passUpdateToJs(1)"
	 			$rio_dialog.execute_script(js_maincat)
	 		end
		}

		$rio_dialog.add_action_callback("updlamdiv"){|a, b|
			arrval = []
			spval = b.split(",")
			check = 0
			for i in spval
				lamval = i+'_lampath'
				getlam = @selection.get_attribute(@dict_name, lamval)
				if !getlam.nil?
					arrval.push(i+'|'+getlam)
					check = 1
				end
			end
			if check == 1
				jsulv = "updateLamVal("+arrval.to_s+")"
		 		$rio_dialog.execute_script(jsulv)
		 	end
		}

		$rio_dialog.add_action_callback("exporthtml"){|a, b|
			$rio_dialog.set_size(50, 50)
			$rio_dialog.set_position(0, 80)
			inp_h =	JSON.parse(b)
			passval = self.export_index(inp_h)
			if passval != false
				js_exped = "htmlDone("+[passval].to_s+")"
				$rio_dialog.execute_script(js_exped)
			else
				jshide = "hideLoadGen()"
				$rio_dialog.execute_script(jshide)
			end
		}

		$rio_dialog.add_action_callback("openfile"){|a, b|
			$rio_dialog.set_size(650, 780)
			sleep 0.2
			system('start %s' % (b))
		}

		$rio_dialog.add_action_callback("upt_client"){|a, b|
			newarr = []
			@views = ["left", "back", "right", "front"]
			@views.each {|view|
				comps 	= DP::get_visible_comps view
				if !comps.empty? == true
					newarr.push(view)
				end
			}
			js_view = "passViews("+newarr.to_s+")"
			$rio_dialog.execute_script(js_view)
		}

		$rio_dialog.add_action_callback("placejpg"){|a, b|
			imgarr = []
			iname = b + '_jpg'
			path = RIO_ROOT_PATH + '/webpages/images/'+b+'.gif'
			imgarr.push(path)
			jsjpg = "passJpgImg("+imgarr.to_s+")"
			$rio_dialog.execute_script(jsjpg)
		}

		$rio_dialog.add_action_callback("spacelist"){|dialog, params|
			mainsp = []
			if $edit_val == 1
				params = $space_name
				type = 1
			else
				params = 0
				type = 0
			end
			splist = self.add_option(params, type)
			mainsp.push(splist)
			jspass = "passSpaceName("+mainsp.to_s+","+type.to_s+")"
			$rio_dialog.execute_script(jspass)
		}

		$rio_dialog.add_action_callback("change-space"){|dlg, param|
			lyrs = Sketchup.active_model.layers.each{|lay|
			if param != '0'
				if lay.name.include?("DP_Wall_")
					if !lay.name.include?(param)
						lay.visible = false
					else
						lay.visible = true
					end
				end
			else
				lay.visible = true
			end
		}
		}

		$rio_dialog.add_action_callback("getspace"){|a, b|
			values = DP::get_space_names
			if values.length != 0
				if $edit_val == 1 || $add_rio_comp == 1
					params = $main_category
					sparams = $space_name
					type = 1
				else
					sparams = 0
					params = 0
					type = 0
				end
				mainsp = []
				splist = self.add_option(sparams, type)
				mainsp.push(splist)			
				maincat = self.get_main_space(params);
				mainsp.push(maincat)
				js_sp = "passSpace("+mainsp.to_s+", "+type.to_s+")"
				$rio_dialog.execute_script(js_sp)
			else
				jsnospace = "spaceAlert()"
				$rio_dialog.execute_script(jsnospace)
			end
		}

		$rio_dialog.add_action_callback("allshowlay"){|a, b|
			layrs = Sketchup.active_model.layers.each{|lays|
				lays.visible = true
			}
		}

		$rio_dialog.add_action_callback("get_cat"){|a, b|
			subcat = []
			if $edit_val == 1 || $add_rio_comp == 1
				params = []
				params.push($main_category)
				params.push($sub_category)
				type = 1
			else
				params = b
				type = 0
			end
			subsp = self.get_sub_space(params, type)
			subcat.push(subsp)
			js_sub = "passsubCat("+subcat.to_s+")"
			$rio_dialog.execute_script(js_sub)
			$add_rio_comp = 0
		}

		$rio_dialog.add_action_callback("select-carcass"){|a, b|
			@spval = b.split(",")
			@title = "RioSTD | Select Carcass"
			cardialog = UI::HtmlDialog.new({:dialog_title=>@title, :preferences_key=>"com.sample.plugin", :scrollable=>false, :resizable=>false, :style=>UI::HtmlDialog::STYLE_DIALOG})
			html_path = File.join(WEBDIALOG_PATH, 'load_carcass.html')
			cardialog.set_file(html_path)
			cardialog.set_position(20, 150)
			cardialog.set_size(600, 600)
			cardialog.bring_to_front
			cardialog.show

			cardialog.add_action_callback("load_carimg"){|d, v|
				getcar = self.get_carcass_image(@spval, 1)
				jscar = "passCarImage("+[getcar].to_s+")"
				cardialog.execute_script(jscar)
			}

			cardialog.add_action_callback('pre_carimage'){|dlg, param|
				dlg = UI::HtmlDialog.new({:dialog_title=>'RioSTD | Carcass Preview', :preferences_key=>"com.sample.plugin", :scrollable=>false, :resizable=>true, :style=>UI::HtmlDialog::STYLE_DIALOG})
				dlg.set_url(param)
				dlg.set_size(550, 550)
				dlg.center
				dlg.show
			}

			cardialog.add_action_callback("load_detail"){|d, v|
				cardialog.close
				type = $edit_val
				get_carname = self.get_carcass_details(@spval[0], @spval[1], v, type)
				jscar = "passCarDetails("+get_carname.to_s+", "+type.to_s+")"
				$rio_dialog.execute_script(jscar)
			}
		}

		$rio_dialog.add_action_callback("check_car"){|a, b|
			spval = b.split(",")
			@space = spval[0]
			@category 	= spval[1]
			auto_mode 	= spval[2]

			resp = true
			if auto_mode == 'true'
				seln = Sketchup.active_model.selection[0]
				sub_category = seln.get_attribute :rio_atts, 'sub-category' 	
				unless sub_category.include?("Bifolding")
					resp = check_components @space, @category
				end
			end
			# puts "resp--------------------#{resp}"
			if resp
				carcount = self.get_carcass_image(spval, 0)
				if carcount.length != 0
					jscar = "showCarBtn(1)"
				else
					jscar = "showCarBtn(0)"
				end
				$rio_dialog.execute_script(jscar)
			else
				jscar = "showCarBtn(0)"
				$rio_dialog.execute_script(jscar)
			end	
		}

		$rio_dialog.add_action_callback("update_car"){|a, b|
			type = $edit_val
			get_carname = self.get_carcass_details($main_category, $sub_category, $carcass_code, type)
			# puts "get_carname-----#{get_carname}"
			jscar = "showCarBtn(1)"
			$rio_dialog.execute_script(jscar)
			sleep 0.1
			jsval = "passCarDetails("+get_carname.to_s+", "+type.to_s+")"
			$rio_dialog.execute_script(jsval)
		}

		$rio_dialog.add_action_callback("load-code"){|a, b|
			sp = b.split(",")
			parr = []
			if $edit_val == 1
				params = []
				params.push($main_category)
				params.push($sub_category)
				params.push($carcass_code)
				type = 1
			else
				params = sp
				type = 0
			end
			getcode = self.get_pro_code(params, type)
			parr.push(getcode)
			js_pro = "passCarCass("+parr.to_s+", "+type.to_s+")"
			$rio_dialog.execute_script(js_pro)
		}

		$rio_dialog.add_action_callback("load-datas"){|a, b|
			spinp = b.split(',')
			$intval = spinp
			newarr = []

			if $edit_val == 1
				type = 1
			else
				type = 0
			end
			# puts "spinp--------------#{spinp}"
			get_int = self.get_internal_category(spinp)
			newarr.push(get_int)
			getval = self.get_datas(spinp, type)
			# puts "getval------#{getval}"
			newarr.push(getval)

			js_data = "passDataVal("+newarr.to_s+", "+type.to_s+")"
			$rio_dialog.execute_script(js_data)
		}

		$rio_dialog.add_action_callback("send_compval"){|a, b|
			inph =	JSON.parse(b)
			comps = Sketchup.active_model.entities.grep(Sketchup::ComponentInstance)
			puts "inph : #{inph}"
			self.place_component(inph)
			js_sent = "document.getElementById('loadicon').style.display='none';"
			$rio_dialog.execute_script(js_sent)
		}

		$rio_dialog.add_action_callback("show_int_html"){|a, b|
			@splitval = b.split(',')
			if @splitval[3].to_i == 2
				@html = "2_intcategory.html"
				@title = "RioSTD | 2 Door Sliding Internal Categories"
			elsif @splitval[3].to_i == 3
				@html = "3_intcategory.html"
				@title = "RioSTD | 3 Door Sliding Internal Categories"
			end
			int_dialog = UI::HtmlDialog.new({:dialog_title=>@title, :preferences_key=>"com.sample.plugin", :scrollable=>false, :resizable=>false, :style=>UI::HtmlDialog::STYLE_DIALOG})
			html_path = File.join(WEBDIALOG_PATH, @html)
			int_dialog.set_file(html_path)
			int_dialog.set_position(20, 150)
			int_dialog.set_size(600, 610)
			int_dialog.bring_to_front
			int_dialog.show

			int_dialog.add_action_callback("load_cat"){|k, l|
				getint = self.get_internal_category(@splitval)
				jsint = "passintval("+[getint].to_s+")"
				int_dialog.execute_script(jsint)
			}

			int_dialog.add_action_callback('internal-preview'){|dl, src|
				dlg = UI::HtmlDialog.new({:dialog_title=>'RioSTD | Internal Preview', :preferences_key=>"com.sample.plugin", :scrollable=>false, :resizable=>true, :style=>UI::HtmlDialog::STYLE_DIALOG})
				dlg.set_url(src)
				dlg.set_size(550, 550)
				dlg.center
				dlg.show
			}

			int_dialog.add_action_callback("getintcat"){|k, l|
				int_dialog.close
				params = JSON.parse(l)
				newarr = []
				params.each{|key, val|
					newarr.push(key+'|'+val)
				}
				cat = params.length
				if $internal_category == l
					type = 0
				else
					type = 2
				end
				# getvals = self.get_internal_data(l, $intval[2])
				js_val = "passIntJs("+newarr.to_s+","+cat.to_s+", "+type.to_s+")"
				$rio_dialog.execute_script(js_val)
			}
		}

		$rio_dialog.add_action_callback("show_shutter"){|a, b|
			@title = "RioSTD | Shutter Type"
			shutdialog = UI::HtmlDialog.new({:dialog_title=>@title, :preferences_key=>"com.sample.plugin", :scrollable=>false, :resizable=>false, :style=>UI::HtmlDialog::STYLE_DIALOG})
			html_path = File.join(WEBDIALOG_PATH, 'select_shutter.html')
			shutdialog.set_file(html_path)
			shutdialog.set_size(600, 370)
			shutdialog.set_position(20, 150)
			shutdialog.bring_to_front
			shutdialog.show

			shutdialog.add_action_callback("load_shutimg"){|k, v|
				spval = b.split(",")
				getimg = self.get_shutter_image(spval)
				jsshut = "shutterPass("+getimg.to_s+")"
				shutdialog.execute_script(jsshut)
			}

			shutdialog.add_action_callback("select_shutter"){|k, v|
				shutdialog.close
				arr = []
				arr.push(v)
				if $shutter_code == v
					arr.push(0)
				else
					arr.push(1)
				end
				jsval = "passShutJs("+arr.to_s+")"
				$rio_dialog.execute_script(jsval)
			}
		}

		$rio_dialog.add_action_callback("load-internal"){|a, b|
			getd = self.get_intnal($internal_category, $edit_val)
			js_val = "passIntJs("+getd.to_s+","+$internal_category.to_s+", "+1.to_s+")"
			$rio_dialog.execute_script(js_val)
		}

		$rio_dialog.add_action_callback("updateglobal"){|a, b|
			$edit_val = 0
		}

		$rio_dialog.add_action_callback("rotate-comp"){|a, b|
			DP::zrotate
		}

		$rio_dialog.add_action_callback('check_open'){|a, b|
			pre_val = fsel.get_attribute(:rio_atts, 'shutter-open')
			if pre_val.to_s == b.to_s
				update_edit = 0
			else
				update_edit = 1
			end
			jsopen = "passOpen("+[update_edit].to_s+")"
			$rio_dialog.execute_script(jsopen)
		}

		$rio_dialog.add_action_callback("select-wall"){|a, b|
			$wall_dialog = UI::HtmlDialog.new({:dialog_title=>"RioSTD - Select Wall", :preferences_key=>"com.rio.plugin", :scrollable=>false, :resizable=>false, :style=>UI::HtmlDialog::STYLE_DIALOG})
			html_path = File.join(WEBDIALOG_PATH, 'load_wall.html')
			$wall_dialog.set_file(html_path)
			$wall_dialog.set_size(300, 350)
			$wall_dialog.set_position($screen_width+50,$screen_height+100)
			$wall_dialog.bring_to_front
			$wall_dialog.show

			$wall_dialog.add_action_callback("skipdlg"){|d, p|
				$wall_dialog.close
			}

			$wall_dialog.add_action_callback("select-wall-btn"){|a, b|
				wall_tool = WallTool.new
				Sketchup.active_model.select_tool(wall_tool)
			}

			$wall_dialog.add_action_callback("submit_wall"){|dlg, params|
				$wall_dialog.close
				# puts "param----#{params}"
			}
		}


		$rio_dialog.add_action_callback("laminate_view"){|a, b|
			@title = "RioSTD | Choose Lamination"
			lamdialog = UI::HtmlDialog.new({:dialog_title=>@title, :preferences_key=>"com.sample.plugin", :scrollable=>false, :resizable=>false,:style=>UI::HtmlDialog::STYLE_DIALOG})
			html_path = File.join(WEBDIALOG_PATH, 'load_laminate.html')
			lamdialog.set_file(html_path)
			lamdialog.set_size(600, 650)
			lamdialog.set_position(20, 150)
			lamdialog.bring_to_front
			lamdialog.show

			lamdialog.add_action_callback("load-material"){|i, j|
				lamarr = []
				getlam = self.get_laminate_cat
				lamarr.push(getlam)
				jslam = "passLamCat("+lamarr.to_s+")"
				lamdialog.execute_script(jslam)
			}

			lamdialog.add_action_callback("get-material"){|i, j|
				lamimg = self.get_laminate_img(j)
				jsimg = "passLamImg("+[lamimg].to_s+")"
				lamdialog.execute_script(jsimg)
			}

			lamdialog.add_action_callback("select-lam"){|i, j|
				spval = j.split(",")
				uparr = []
				lamdialog.close
				getname = spval[1].split("/").last
				getname = getname.gsub(".jpg", "").gsub(".JPG", "")
				uparr.push(b)
				uparr.push(getname)
				uparr.push(spval[0])
				uparr.push(spval[1])
				jslamval = "passLaminateVal("+uparr.to_s+")"
				$rio_dialog.execute_script(jslamval)
			}

			lamdialog.add_action_callback("select-col"){|i, j|
				uparr = []
				lamdialog.close
				spval = j.split(",")
				uparr.push(b)
				uparr.push('#'+spval[1])
				uparr.push(spval[0])
				uparr.push('#'+spval[1])
				jslamval = "passLaminateVal("+uparr.to_s+")"
				$rio_dialog.execute_script(jslamval)
			}
		}

		$rio_dialog.add_action_callback("view_room_comp"){|dlg, param|
			prompts = ["Space Name"]
			list = [DP::get_space_names.join('|')]
			defaults = [DP::get_space_names.first]
			inputs = UI.inputbox(prompts,defaults, list, "Select Space Name")
			if !inputs[0].nil?
				scan_room = scan_room_components inputs[0], true
			end
		}

		$rio_dialog.add_action_callback('delete_room'){|dlg, param|
			prompts = ["Room Name"]
			list = [DP::get_space_names.join('|')]
			defaults = [DP::get_space_names.first]
			if DP::get_space_names.length.to_i !=0
				inputs = UI.inputbox(prompts,defaults, list, "Select Room Name")
				room_name = inputs[0]
				puts "Deleting Room : #{room_name}"
				if !room_name.nil?
					if V2_V3_CONVERSION_FLAG
						delete_room = RIO::CivilHelper::remove_room_entities room_name
					else
						delete_room = DP::delete_room room_name
					end
				end
			else
				UI::messagebox 'Not found rooms!', MB_OK
			end
		}

		$rio_dialog.add_action_callback("get_setting_cal"){|a, b|
			Sketchup.active_model.attribute_dictionaries['rio_settings'].each{|key, val|
				jsobj = "document.getElementById('#{key}').value=#{val};"
				$rio_dialog.execute_script(jsobj)
			}
		}

		$rio_dialog.add_action_callback("uptsetting"){|a, b|
			params = JSON.parse(b)
			params.each_pair{|k, v|
				Sketchup.active_model.set_attribute(:rio_settings, k, v)
			}
			set_val = DS::update_setting params
			jsload = "hideLoad()"
			$rio_dialog.execute_script(jsload)
		}

		$rio_dialog.add_action_callback("minimize_dialog"){|dlg, param|
			if params == 1
				DS::dialog_minimize
			else
				DS::dialog_maximize
			end
		}

		$rio_dialog.add_action_callback('multi_laminate'){|dlg, param|
			multilam_dialog = UI::HtmlDialog.new({:dialog_title=>'RioSTD | Multi Laminates', :preferences_key=>"com.sample.plugin", :scrollable=>false, :resizable=>false,:style=>UI::HtmlDialog::STYLE_DIALOG})
			html_path = File.join(WEBDIALOG_PATH, 'load_multilam.html')
			multilam_dialog.set_file(html_path)
			multilam_dialog.set_size(600, 650)
			multilam_dialog.set_position(20, 150)
			multilam_dialog.bring_to_front
			multilam_dialog.show

			multilam_dialog.add_action_callback('getroot'){|d, p|
				lam_default = RIO_ROOT_PATH+'/webpages/images/'
				jsupt = "document.getElementById('root_path').value='#{lam_default}';"
				multilam_dialog.execute_script(jsupt)
			}

			multilam_dialog.add_action_callback('load_multilam_view'){|d, pa|
				@title = "RioSTD | Choose Lamination"
				multilam = UI::HtmlDialog.new({:dialog_title=>@title, :preferences_key=>"com.sample.plugin", :scrollable=>false, :resizable=>false,:style=>UI::HtmlDialog::STYLE_DIALOG})
				html_path = File.join(WEBDIALOG_PATH, 'load_multi_lam.html')
				multilam.set_file(html_path)
				multilam.set_size(550, 600)
				multilam.set_position(40, 170)
				multilam.bring_to_front
				multilam.show

				multilam.add_action_callback('multi-load-material'){|k, l|
					getlam = self.get_laminate_cat
					jslam = "multiLamCat("+[getlam].to_s+")"
					multilam.execute_script(jslam)
				}

				multilam.add_action_callback("multi-get-material"){|i, j|
					lamimg = self.get_laminate_img(j)
					jsimg = "multiLamImg("+[lamimg].to_s+")"
					multilam.execute_script(jsimg)
				}

				multilam.add_action_callback("select-multi-lam"){|i, j|
					spval = j.split(",")
					uparr = []
					multilam.close
					getname = spval[1].split("/").last
					getname = getname.gsub(".jpg", "").gsub(".JPG", "")
					uparr.push(pa)
					uparr.push(getname)
					uparr.push(spval[0])
					uparr.push(spval[1])
					jslamval = "multiLaminateVal("+uparr.to_s+")"
					multilam_dialog.execute_script(jslamval)
				}

				multilam.add_action_callback('multi-col'){|i, j|
					spval = j.split(",")
					uparr = []
					multilam.close
					uparr.push(pa)
					uparr.push('#'+spval[1])
					uparr.push(spval[0])
					uparr.push('#'+spval[1])
					jslamval = "multiLaminateVal("+uparr.to_s+")"
					multilam_dialog.execute_script(jslamval)
				}
			}

			multilam_dialog.add_action_callback('upt_multi_laminate'){|dlg, param|
				multilam_dialog.close
				params = JSON.parse(param)
				multilam = self.update_multi_laminate(params['multi_laminate'][0])
			}

		}

	end

	def self.check_components space, category
		@dbname = 'rio_std'
		@db 	= SQLite3::Database.new(@dbname)
		@table 	= 'rio_standards'

		arr = @db.execute("select DEPTH, SHUTTER_HEIGHT from #{@table} where space='#{space}' and category='#{category}';" )
		
		carcass_depth, shutter_depth = arr[0][0].to_i, arr[0][1].to_i
		# puts "carcass_depth-----#{carcass_depth}"
		# puts "shutter_depth-------#{shutter_depth}"

		total_depth = carcass_depth.to_i + shutter_depth.to_i + 2
		comp = Sketchup.active_model.selection[0]
		rotz = comp.transformation.rotz
		case rotz
		when 0, 180, -180
			selected_comp_depth = comp.bounds.height
		when 90, -90
			selected_comp_depth = comp.bounds.width
		end
		# puts "selected_comp_depth----#{selected_comp_depth}"
		# puts "total_depth-------#{total_depth}"
		#total_depth = total_depth.ceil
		#selected_comp_depth = selected_comp_depth.ceil
		# puts "selected_comp_depth....----#{selected_comp_depth.to_i} : #{total_depth.mm.to_i}"
		if selected_comp_depth.to_i != total_depth.mm.to_i
			resp = UI.messagebox "The selected sub category depth is not same as the component selected in the model. Do you want to continue?", MB_OKCANCEL
			# puts "1111-----resp---------#{resp}----#{MB_OKCANCEL}"
			return false if resp != MB_OKCANCEL
		end
		return true
	end
end

