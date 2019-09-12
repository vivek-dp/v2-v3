$(document).ready(function(){
	window.location = 'skp:getroot@'+1;

	setTimeout(function() {
		dval = $('#root_path').val();
		var imgpath = dval + 'SketchUp_Default_M00.jpg'
		var valarr = ['shutter', 'left', 'right', 'top']
		for (var i = 0; i < valarr.length; i++){
			$('#multi_'+valarr[i]+'_frame').html('<img src="'+imgpath+'"><div><button class="mini ui blue button" value="multi_'+valarr[i]+'" onclick="openMultiLam(this.value)">Change</button></div>');
			$('#multi_'+valarr[i]+'_frame img').width(100).height(120);
			$('#multi_'+valarr[i]+'_type').val('material');
			$('#multi_'+valarr[i]+'_value').val(imgpath);
			if (!valarr[i].includes('shutter')) $('#multi_'+valarr[i]+'_preval').val(imgpath);
			$('#multi_'+valarr[i]+'_name').html('SketchUp_Default_M00');
			if (!valarr[i].includes('shutter')) $mlam.push('multi_'+valarr[i]);
		}
	}, 10);

	$('#mapplyall').on('click', function(){
		if ($('#mapplyall').is(':checked') == true){
			for (var c = 0; c < $mlam.length; c++){
				// alert($mlam[c])
				if ($mlam[c] != $adlam){
					$('#'+$mlam[c]+'_name').text($('#'+$adlam+'_name').text());
					$('#'+$mlam[c]+'_value').val($('#'+$adlam+'_value').val());
					$('#'+$mlam[c]+'_type').val($('#'+$adlam+'_type').val());
					var mat_type = $('#'+$adlam+'_type').val();
					if (mat_type.includes('material') == true){
						$('#'+$mlam[c]+'_frame').html('');
						var imgpath = $('#'+$adlam+'_value').val();
						$('#'+$mlam[c]+'_frame').html('<img src="'+imgpath+'"><div style="padding-top:3em;"><button class="mini ui blue button" value="'+$mlam[c]+'" onclick="openMultiLam(this.value)">Change</button></div>');
						$('#'+$mlam[c]+'_frame img').width(100).height(120);
					}else{
						var color_name = $('#'+$mlam[c]+'_value').val()
						$('#'+$mlam[c]+'_frame').html('');
						$('#'+$mlam[c]+'_frame').css('background', color_name)
						$('#'+$mlam[c]+'_frame').width(100).height(120);
					}
				}
			}
		}else{
			for (var c = 0; c < $mlam.length; c++){
				if ($mlam[c] != $adlam){
					$('#'+$mlam[c]+'_frame').html('');
					if ($('#'+$mlam[c]+'_type').val() == 'color'){
						$('#'+$mlam[c]+'_frame').css('background', '');
					}
					var preval = $('#'+$mlam[c]+'_preval').val();
					$('#'+$mlam[c]+'_value').val(preval);
					$('#'+$mlam[c]+'_type').val('material');

					var last = preval.substring(preval.lastIndexOf("/") + 1, preval.length);
	 				var name = last.replace(/.jpg/g, "").replace(/.JPG/g, "");
					$('#'+$mlam[c]+'_name').text(name);
					$('#'+$mlam[c]+'_frame').html('<img src="'+preval+'"><div><button class="mini ui blue button" value="'+$mlam[c]+'" onclick="openMultiLam(this.value)">Change</button></div>');
					$('#'+$mlam[c]+'_frame img').width(100).height(120);
				}
			}
		}
	})

	$('#upt_multilam').click(function(){
		var json2 = {};
		var valarr = ['front', 'left', 'right', 'top']
		var lamarr = [];
		var json1 = {};
		for (var k = 0; k < valarr.length; k++){
			json = {};
			jarr = [];
			json['side'] = valarr[k]
			if (valarr[k] == 'front'){path = 'shutter'}else{path = valarr[k]}
			json['image_path'] = $('#multi_'+path+'_value').val();
			json['lam_type'] = $('#multi_'+path+'_type').val();
			jarr.push(json)
			json1[valarr[k]] = jarr
		}
		lamarr.push(json1)
		json2['multi_laminate'] = lamarr
		var str = JSON.stringify(json2);
		window.location = 'skp:upt_multi_laminate@'+ str;
	});
});

var $adlam = [];
var $mlam = []
function openMultiLam(val){
	window.location = 'skp:load_multilam_view@' + val;
}

function multiLaminateVal(val){
	if (val[0] != "multi_shutter"){
		$adlam.push(val[0])
		if ($adlam.length > 1){
			$('#mapply_all').css('display', 'none');
		}else{
			if ($mlam.length != 2){
				$('#mapply_all').css('display', 'block');
			}else{
				$('#mapply_all').css('display', 'none');
			}
		}
	}	
	if (val[2].includes('color')){
		$('#'+val[0]+'_frame').html('');
		$('#'+val[0]+'_frame').css('background', val[1]);
		$('#'+val[0]+'_frame').width(100).height(120);
	}else{
		$('#'+val[0]+'_frame').html('<img src="'+val[3]+'"><div style="padding-top:3em;"><button class="mini ui blue button" value="'+val[0]+'" onclick="openMultiLam(this.value)">Change</button></div>');
		$('#'+val[0]+'_frame img').width(100).height(120);
	}
	$('#'+val[0]+'_name').html(val[1]);
	$('#'+val[0]+'_type').val(val[2])
	$('#'+val[0]+'_value').val(val[3])
}