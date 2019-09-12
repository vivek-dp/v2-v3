class WallTool
	def initialize
		
	end

	def activate
		# puts 'Your tool has been activated.'
	end

	def deactivate(view)
	  # puts "Your tool has been deactivated in view: #{view}"
	end

	def clicked_face view, x, y
		ph = view.pick_helper
		ph.do_pick x, y
		group = ph.best_picked
		return nil unless group.is_a?(Sketchup::Group)
		return group
	end

	def update_last_click(group, view)
		last_attr = Sketchup.active_model.set_attribute(:rio_atts, 'last_wall_attr', group.persistent_id)
		Decor_Standards::enable_wall_radio
		Sketchup.active_model.select_tool(nil)
	end

	def onLButtonDown(flags,x,y,view)
		group = clicked_face view, x, y
		UI::messagebox 'Please click on a wall', MB_OK if group.nil?
		upt_attr = update_last_click(group, view)
	end
end