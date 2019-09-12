$(document).ready(function(){
	window.location = 'skp:loaddatas@' + 1;
	// window.location = 'skp:load_attr@' + 1;
	$('#applyall').on('click', function(){
		if ($('#applyall').is(':checked') == true){
			for (var c = 0; c < $appall.length; c++){
				if ($appall[c] != $addlam){
					$('#'+$appall[c]+'_name').text($('#'+$addlam+'_name').text());
					$('#'+$appall[c]+'_lam_value').val($('#'+$addlam+'_lam_value').val());
					$('#'+$appall[c]+'_mat_type').val($('#'+$addlam+'_mat_type').val());
					var mat_type = $('#'+$addlam+'_mat_type').val();
					if (mat_type.includes('material') == true){
						$('#'+$appall[c]+'_frame').html('');
						var imgpath = $('#'+$addlam+'_lam_value').val();
						$('#'+$appall[c]+'_frame').html('<img src="'+imgpath+'"><div style="padding-top:3em;"><button class="mini ui blue button" value="'+$appall[c]+'" onclick="openLam(this.value)">Change</button></div>');
						$('#'+$appall[c]+'_frame img').width(100).height(120);
					}else{
						var color_name = $('#'+$appall[c]+'_lam_value').val()
						// $('#'+$appall[c]+'_frame').html('');
						$('#'+$appall[c]+'_frame').html('<div style="padding-top:3em;"><button class="mini ui blue button" value="'+$appall[c]+'" onclick="openLam(this.value)">Change</button></div>');
						$('#'+$appall[c]+'_frame').css('background', color_name)
						$('#'+$appall[c]+'_frame').width(100).height(120);
					}
				}
			}
		}else{
			for (var c = 0; c < $appall.length; c++){
				if ($appall[c] != $addlam){
					$('#'+$appall[c]+'_frame').html('');
					if ($('#'+$appall[c]+'_mat_type').val() == 'color'){
						$('#'+$appall[c]+'_frame').css('background', '');
					}
					var preval = $('#'+$appall[c]+'_preval').val();
					$('#'+$appall[c]+'_lam_value').val(preval);
					$('#'+$appall[c]+'_mat_type').val('material');

					var last = preval.substring(preval.lastIndexOf("/") + 1, preval.length);
	 				var name = last.replace(/.jpg/g, "").replace(/.JPG/g, "");
					$('#'+$appall[c]+'_name').text(name);
					$('#'+$appall[c]+'_frame').html('<img src="'+preval+'"><div><button class="mini ui blue button" value="'+$appall[c]+'" onclick="openLam(this.value)">Change</button></div>');
					$('#'+$appall[c]+'_frame img').width(100).height(120);
				}
			}
		}
	})
});

function readOly(){
	toastr.info('This field is disabled!', 'Info')
}

$slval = []
$ids = []
$lam = []
$apply = []
$addlam = []
$appall = []
function passValToJs(val){
	var showfin = 0;
	for(var i = 0; i < val.length; i++){
		spval = val[i].split("|")
		$ids.push(spval[0])
		if (spval[0].includes("left") == true){
			$('#show_leftlam').css('display', 'block');
			$('#show_view').val(1);
			$('#left_lam_value').val(spval[1])
			$lam.push('left|'+spval[1])
			$appall.push('left')
		}else if (spval[0].includes("right") == true){
			$('#show_rightlam').css('display', 'block');
			$('#show_view').val(1);
			$('#right_lam_value').val(spval[1])
			$lam.push('right|'+spval[1])
			$appall.push('right')
		}else if (spval[0].includes("top") == true){
			$('#show_toplam').css('display', 'block');
			$('#show_view').val(1);
			$('#top_lam_value').val(spval[1])
			$lam.push('top|'+spval[1])
			$appall.push('top')
		}else if (spval[0].includes("front") == true){
			if (spval[1] != 'No'){
				$lam.push('front|'+spval[1])
				$('#show_shutter').css('display', 'block')
			}else{
				$('#show_shutter').css('display', 'none')
			}
		}else{$('#show_view').val(0);}
		if ((spval[0] == "attr_soft_close" || spval[0] == "attr_finish_type") && spval[1] == ""){
			$('#'+spval[0]).val(0);
		}else{
			$('#'+spval[0]).val(spval[1]);
		}
	}

	if ($('#show_view').val() == 1 && $('#attr_finish_type').val() != 0){
		$('#finish_head').css('display', 'block');
	}else{
		$('#finish_head').css('display', 'none');
	}

	if ($('#attr_product_name').val().includes("Sliding") || $('#attr_product_name').val().includes("sliding")){
		$('#show_int').css('display', 'block');
	}else{
		$('#show_int').css('display', 'none');
	}
	updateLamVal($lam)
}

function updateLamVal(val){
	for (var i = 0; i < val.length; i++){
 		var spval = val[i].split("|")
 		if (spval[1].length != 0){
 			if (spval[1].includes("#") == true){
 				$('#'+spval[0]+'_frame').html('<div style="padding-top:3em;"><button class="mini ui blue button" value="'+spval[0]+'" onclick="openLam(this.value)">Change</button></div>');
 				$('#'+spval[0]+'_frame').css('background', spval[1])
				$('#'+spval[0]+'_frame').width(100).height(120);
				$('#'+spval[0]+'_mat_type').val('color')
				$('#'+spval[0]+'_name').html(spval[1])
				if (spval[0].includes('front') == true) $('#'+spval[0]+'_frame').addClass('lamimg');
 			}else{
 				$('#'+spval[0]+'_frame').html('<img src="'+spval[1]+'"><div style="padding-top:3em;"><button class="mini ui blue button" value="'+spval[0]+'" onclick="openLam(this.value)">Change</button></div>');
 				$('#'+spval[0]+'_frame img').width(100).height(120);
 				$('#'+spval[0]+'_mat_type').val('material')
 				var last = spval[1].substring(spval[1].lastIndexOf("/") + 1, spval[1].length);
 				name = last.replace(/.jpg/g, "").replace(/.JPG/g, "");
 				$('#'+spval[0]+'_name').html(name)
 				$('#'+spval[0]+'_frame').removeClass('lamimg');
 			}
 		}else{
 			dval = $('#rootpath').val();
 			var imgpath = dval + '/SketchUp_Default_M00.jpg'
 			$('#'+spval[0]+'_frame').html('<img src="'+imgpath+'"><div><button class="mini ui blue button" value="'+spval[0]+'" onclick="openLam(this.value)">Change</button></div>');
 			$('#'+spval[0]+'_frame img').width(100).height(120);
 			$('#'+spval[0]+'_mat_type').val('material')
 			$('#'+spval[0]+'_lam_value').val(imgpath)
 			$('#'+spval[0]+'_name').html('SketchUp_Default_M00')
 			if (spval[0] != 'front'){
 				$('#'+spval[0]+'_preval').val(imgpath)
 			}
 		}
	}
	if ($('#apply_all').is(':hidden') == true){
		$('#uptbtn').css('margin-top', '3em');
	}
}

function openLam(val){
	window.location = 'skp:laminate_view@' + val;
}

function changeFinish(val){
	if (val != 0){
		if ($('#show_view').val() == 1){
			if ($('#apply_all').is(':hidden') == true){
				$('#uptbtn').css('margin-top', '3em');
			}
			$('#finish_head').css('display', 'block');
		}else{$('#finish_head').css('display', 'none');}
	}else{
		$('#finish_head').css('display', 'none');
	}
}

String.prototype.capitalize = function() {
  return this.charAt(0).toUpperCase() + this.slice(1);
}

function uptvalue(){
	ids = $ids
	json = {}
	for (var l = 0; l < ids.length; l++){
		var vals = document.getElementById(ids[l]).value;
		var res1 = ids[l].replace(/attr_/g, "");
		var res = res1.replace(/_/g, " ");
		var mname = res.capitalize();
		if (ids[l] == "attr_soft_close" || ids[l] == "attr_finish_type"){
			if (vals == 0){
				toastr.error(mname+" can't be blank!", "Error")
				return false;
			}else{
				json[ids[l]] = vals;
			}
		}else{
			if (vals == ""){
				var fval = '';
				if (mname.includes("Right") == true){
					fval = 'Left carcass finish code'
				}else if (mname.includes("Left") == true){
					fval = 'Right carcass finish code'
				}else if (mname.includes("Top") == true){
					fval = 'Top carcass finish code'
				}else{
					fval = mname
				}
				toastr.error(fval+" can't be blank!", "Error")
				document.getElementById(ids[l]).focus();
				return false;
			}else{
				json[ids[l]] = vals;
			}
		}
	}
	
	if ($lam.length != 0){
		jarr = []
		for (var i = 0; i < $lam.length; i++){
			lam = $lam[i].split("|")
			json1 = {}
			if (lam[0] == "left"){
				var val = 'right'
			}else if (lam[0] == "right"){
				var val = 'left'
			}else{var val = lam[0]}
			json1['side'] = val
			json1['image_path'] = $('#'+lam[0]+'_lam_value').val();
			json1['lam_type'] = $('#'+lam[0]+'_mat_type').val();
			jarr.push(json1)
		}
		if ($slval.length != 0){
			json2 = {}
			json2['side'] = 'front'
			json2['image_path'] = $('#front_lam_value').val();
			json2['lam_type'] = $('#front_mat_type').val();
			jarr.push(json2)
		}

		json['laminate'] = jarr
	}
	var str = JSON.stringify(json);
	$('#loadicon').css('display', 'block');
	setTimeout(function() {window.location = 'skp:upd_attribute@'+ str;}, 500);
}

function passUpdateToJs(inp){
	$('#loadicon').css('display', 'none');
	toastr.success("Attributes are updated successfully!", "Success")
}

function passLaminateVal(val){
	if (val[0] != "front"){
		if (!$addlam.includes(val[0])) $addlam.push(val[0])
		if ($addlam.length > 1){
			$('#apply_all').css('display', 'none');
			$('#uptbtn').css({'margin-top': '2em', 'border-top': '1px solid #424949', 'padding-top': '1em'});
		}else{
			if ($lam.length != 2){
				$('#apply_all').css('display', 'block');
			}else{
				$('#apply_all').css('display', 'none');
			}
		}
	}	
	if (val[2].includes("color")){
		$('#'+val[0]+'_frame').html('<div style="padding-top:3em;"><button class="mini ui blue button" value="'+val[0]+'" onclick="openLam(this.value)">Change</button></div>');
		$('#'+val[0]+'_frame').css('background', val[1]);
		$('#'+val[0]+'_frame').width(100).height(120);
		if (val[0].includes('front') == true) $('#'+val[0]+'_frame').addClass('lamimg');
	}else{
		$('#'+val[0]+'_frame').removeClass('lamimg');
		$('#'+val[0]+'_frame').html('<img src="'+val[3]+'"><div style="padding-top:3em;"><button class="mini ui blue button" value="'+val[0]+'" onclick="openLam(this.value)">Change</button></div>');
		$('#'+val[0]+'_frame img').width(100).height(120);
	}
	if (val[0] != "front")	$apply.push(val[0])
	$('#'+val[0]+'_name').html(val[1]);
	$('#'+val[0]+'_mat_type').val(val[2])
	$('#'+val[0]+'_lam_value').val(val[3])
	if ($('#apply_all').is(':hidden') == false){
		$('#uptbtn').css('margin-top', '0em');
	}
}