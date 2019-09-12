$(document).ready(function(){
	window.location = 'skp:getspacelist@' + 0;

	$('#exportbtn').click(function(){
		json = {}
		spacearr = []
		$('.checkOne:checked').each(function(){
			spacearr.push(this.value);
		});
		json['space'] = spacearr
		var str = JSON.stringify(json);
		$('#loadgen').css('display', 'block');
		setTimeout(function() {window.location = 'skp:exporthtml@' + str}, 500);
	});

	$('#checkAll').change(function(){
		if (this.checked){
			$('.checkOne').each(function(){this.checked = true;})
			$('#exportbtn').removeClass('disabled');
		}else{
			$('.checkOne').each(function(){this.checked = false;})
			$('#exportbtn').addClass('disabled');
		}
	});
});

function passSpaceList(val){
	val = val.sort();
	if (val.length != 0){
		$('#showspace').css('display', 'block');
		spname = '';
		for (var i = 0; i < val.length; i++){
			spname += '<div class="field"><div class="ui checkbox"><input type="checkbox" value="'+val[i]+'" onclick="checkOne(this)" class="checkOne"><label>'+val[i]+'</label></div></div>'
		}
		$('#load_list').html('<div style="overflow-y: scroll;height: 130px;">'+spname+'</div>')
	}else{
		toastr.info('Spaces are not found!', 'Info');
	}
}

function checkOne(val){
	var expbtn = 0;
	if (val.checked){
		expbtn = 1;
		var isAllChecked = 0;
		$("input:checkbox.checkOne").each(function(){
			if (!this.checked){
				isAllChecked = 1;
			}
		})
    if(isAllChecked == 0){ $("#checkAll").prop("checked", true); }
	}else{
		$("#checkAll").prop("checked", false);
	}
	if ($("input:checkbox.checkOne:checked").length != 0){
		$('#exportbtn').removeClass('disabled');
	}else if ($("input:checkbox.checkOne:checked").length == 0){
		$('#exportbtn').addClass('disabled');
	}
}