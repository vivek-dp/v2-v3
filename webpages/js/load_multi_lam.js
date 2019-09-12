$(document).ready(function(){
	window.location = 'skp:multi-load-material@'+1;

	$('#clkmat').on('click', function(){
		$(this).addClass('btnactive');
		$('#clkcol').removeClass('btnactive');
		$('#multi_lam_block').css('display', 'block');
		$('#multi_col_block').css('display', 'none');
		$('#material_type').val('material')
		$('#lam-category').val(0);
		$('#multi_lam_types').css('display', 'none');
	});

	$('#clkcol').on('click', function(){
		$(this).addClass('btnactive');
		$('#clkmat').removeClass('btnactive');
		$('#multi_lam_block').css('display', 'none');
		$('#multi_col_block').css('display', 'block');
		$('#material_type').val('color')
		$('#multi_lam_types').css('display', 'none');
	});

	$('#multi_search_val').on('keyup', function(){
		var i = $(this).val().toLowerCase();
		$('.column .lam_name').each(function(){
			var s = $(this).text().toLowerCase();
			$(this).closest('.column')[ s.indexOf(i) !== -1 ? 'show' : 'hide' ]();
		})
	});

	$('#multi_color').click(function(){
		mt = $('#material_type').val();
		cc = $('#valueInput').val();
		str = mt+','+cc
		window.location = 'skp:multi-col@'+str;
	})
});

function update(jscolor) {
  $('#react').css('backgroundColor', '#' + jscolor);
}

function multiLamCat(input){
	$('#multi_lam_block').html('<div class="ui form"><div class="field"><div class="ui labeled input"><div class="ui label">Category:</div>'+input+'</div></div></div>')
}

function changeLaminate(val){
	$('#lam_types').css('display', 'block');
	window.location = 'skp:multi-get-material@'+val;
}

function multiLamImg(val){
	$('#multi_lam_types').css('display', 'block');
	$('#multi-place-img').html(val)
}

function getImgSrc(val){
	mt = $('#material_type').val();
	var imgSrc = $(val).attr("src");
	str = mt+','+imgSrc
	window.location = 'skp:select-multi-lam@'+str;
}