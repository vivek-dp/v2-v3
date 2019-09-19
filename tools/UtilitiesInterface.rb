require 'singleton'
require_relative '../core/CivilHelper.rb'
module RIO
	module Utilities
		class Helpers
			include Singleton
			@@rio_utility_dialog = nil
			
			def initialize
				@utility_dialog_width = 400
				@utility_dialog_height = 420
				@utility_dialog_url = 'E:/V3/Working/tools/utilities.html'
				@utility_style_window = UI::HtmlDialog::STYLE_WINDOW
				@utility_style_dialog = UI::HtmlDialog::STYLE_DIALOG
			end
			
			def get_params_from_string param_str
				#Benchmark fast
				param_str = param_str[3..-2]
				elements_a = param_str.split('"@"')
				elements_a
			end

			def load_tools
				dialog_hash = {}
				dialog_hash[:dialog_title] 	= 'Rio Dev Tools'
				dialog_hash[:scrollable]	= true
				dialog_hash[:resizable]		= true
				dialog_hash[:width]			= @utility_dialog_width
				dialog_hash[:height]		= @utility_dialog_height
				dialog_hash[:min_width]		= 50
				dialog_hash[:min_height]	= 50
				dialog_hash[:style]			= @utility_style_dialog
				dialog_hash[:left]			= 100
				dialog_hash[:right]			= 100
				
				@@utility_rio_dialog = UI::HtmlDialog.new(dialog_hash)
				@@utility_rio_dialog.set_url(@utility_dialog_url)
				@@utility_rio_dialog.show()
				
				@@utility_rio_dialog.add_action_callback("create_beam") {|dialog, params|
					puts "Creating beam"
					sel_face = Sketchup.active_model.selection[0]
					if sel_face.nil?
						puts "Nothing selected"
					elsif !sel_face.is_a?(Sketchup::Face)
						puts "Selection is not a Sketchup face"
					else
						beam_inst = RIO::CivilHelper::create_beam sel_face
					end
				}
				@@utility_rio_dialog.add_action_callback("add_perimeter_wall") { |dialog, params|
					puts "Adding perimeter wall"
					RIO::CivilHelper::add_perimeter_wall
				}
				@@utility_rio_dialog.add_action_callback("remove_perimeter_wall") { |dialog, params|
					puts "Adding perimeter wall"
					RIO::CivilHelper::remove_perimeter_wall
				}
			end#load_tools
			
			
			
		end #Class helpers
		class ModalBox
			include Singleton
			def self.no_layer_added
				dialog_hash = {}
				dialog_hash[:dialog_title] 	= 'Rio Dev Tools'
				dialog_hash[:scrollable]	= true
				dialog_hash[:resizable]		= true
				dialog_hash[:width]			= 350
				dialog_hash[:height]		= 150
				dialog_hash[:min_width]		= 50
				dialog_hash[:min_height]	= 50
				dialog_hash[:style]			= @utility_style_dialog
				dialog_hash[:left]			= 100
				dialog_hash[:right]			= 100
				
				no_layer_added_url		= File.join(RIOV3_ROOT_PATH, 'tools/html/no_layer_added.html')
				no_layer_added_dialog 	= UI::HtmlDialog.new(dialog_hash)
				no_layer_added_dialog.set_url(no_layer_added_url)
				no_layer_added_dialog.show()
			end
		end
		class DeleteRooms
			include Singleton
			@@rio_roomdelete_dialog = nil
			
			def initialize
				@roomdelete_dialog_width = 400
				@roomdelete_dialog_height = 400
				@roomdelete_dialog_url = 'E:/V3/Working/tools/html/room_details.html'
				@roomdelete_style_window = UI::HtmlDialog::STYLE_WINDOW
				@roomdelete_style_dialog = UI::HtmlDialog::STYLE_DIALOG
			end
			
			def room_details
				dialog_hash = {}
				dialog_hash[:dialog_title] 	= 'Rio Dev Tools'
				dialog_hash[:scrollable]	= true
				dialog_hash[:resizable]		= true
				dialog_hash[:width]			= @roomdelete_dialog_width
				dialog_hash[:height]		= @roomdelete_dialog_height
				dialog_hash[:min_width]		= 50
				dialog_hash[:min_height]	= 50
				dialog_hash[:style]			= @roomdelete_style_dialog
				dialog_hash[:left]			= 100
				dialog_hash[:right]			= 100
			
			
				@@rio_roomdelete_dialog = UI::HtmlDialog.new(dialog_hash)
				@@rio_roomdelete_dialog.set_url(@roomdelete_dialog_url)
				@@rio_roomdelete_dialog.show()
				
				@@rio_roomdelete_dialog.add_action_callback("rioGetRoomNames") {|dialog, params|
					puts "Room name : ...rioGetRoomNames"
					room_names = RIO::CivilHelper::get_room_names
					js_command="passRoomNames(" + room_names.to_s + ")";
					puts "js_command : #{js_command}"
					@@rio_roomdelete_dialog.execute_script(js_command);
				}

				@@rio_roomdelete_dialog.add_action_callback("rioDeleteMultiRoom"){|dialog, params|
					puts "RB delete these rooms : #{params}"
					room_names = params.split(",")
					room_names.each { |room_name|
						RIO::CivilHelper.remove_room_entities(room_name)
					}
				}
			end
		end
	end #module Utilities
end#RIO