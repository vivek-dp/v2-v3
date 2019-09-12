$(document).ready(function(){
	$(".allownumeric").keypress(function (e) {
		if ((event.which != 46 || $(this).val().indexOf('.') != -1) && (event.which < 48 || event.which > 57)) {
      toastr.info("Numbers only allowed!", "Info");
      return false;
    }
  });
});

function passLoadToJs(inp){
	document.getElementById("load").style.display = "none";
	// toastr.success("Created successfully!", "Success")
}

function checkdor(){
	var checkDo = document.getElementById("checkdoor");
	var dropDoo = document.getElementById("doorblock");
	if (checkDo.checked == true){
		dropDoo.style.display = "block"
	}else{
		dropDoo.style.display = "none"
	}
}

function checkwin(){
	var checkWin = document.getElementById("checkwindow");
	var blockwin = document.getElementById("winblock");
	if (checkWin.checked == true){
		blockwin.style.display = "block";
	}else {
		blockwin.style.display = "none";
	}
}

function checkheight(dheight){
	var wh = document.getElementById("wheight").value;
	if (parseInt(dheight) >= parseInt(wh)){
		toastr.error("Door height should be less than wall height!", "Error");
		document.getElementById("door_height").value = "";
		document.getElementById("door_height").focus();
		return false;
	}
}

function SubmitVal(){
	// var array = [];
	var json = {};
	var ids = new Array ("wall1", "wall2", "wheight")
	var idval = ["Wall 1", "Wall 2", "Wall Height"]
	for (i in ids){
		var inval = document.getElementById(ids[i]).value;
		if (inval == ""){
			toastr.error(idval[i]+" can't be empty!", "Error");
			document.getElementById(ids[i]).focus();
			return false;
		}else {
			json[ids[i]] = inval
		}
	}
	
	var door_check = document.getElementById("checkdoor");
	if (door_check.checked == true){
		var doorids = new Array ("door_view", "door_position", "door_height", "door_length")
		var doorval = ["Door View", "Door Position", "Door Height", "Door Length"]
		var json1 = {};
		for (j in doorids){
			var getval = document.getElementById(doorids[j]).value;
			if (getval != 0 && getval != ""){
				json1[doorids[j]] = getval
			} else {
				toastr.error(doorval[j]+" can't be empty!", "Error");
				document.getElementById(doorids[j]).focus();
				return false;
			}
		}
		var j1 = JSON.stringify(json1)
		json["door"] = json1
	}

	var win_check = document.getElementById("checkwindow");
	if (win_check.checked == true){
		var winids = new Array ("window_view", "win_lftposition", "win_btmposition", "win_height", "win_length")
		var winval = ["Window View", "Window Left Posotion", "Window Bottom Position", "Window Height", "Window Length"]
		var json2 = {};
		for (k in winids){
			var GetWin = document.getElementById(winids[k]).value;
			if (GetWin != 0 && GetWin != ""){
				json2[winids[k]] = GetWin
			}else{
				toastr.error(winval[k]+" can't be empty!", "Error");
				document.getElementById(winids[k]).focus();
				return false;
			}
		}
		var j2 = JSON.stringify(json2)
		json["windows"] = json2
	}
	var str = JSON.stringify(json);
	document.getElementById("load").style.display = "block";
	// sketchup.submitval(str)
	setTimeout(function() {window.location = 'skp:submitval@'+ str;}, 500);
}

function page_comp(){
	document.getElementById("load").style.display = "none";
	document.getElementById('add_comp').click();
}