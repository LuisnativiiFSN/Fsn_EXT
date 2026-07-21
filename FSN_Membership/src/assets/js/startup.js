
var ControlAddIn = document.getElementById("controlAddIn");

var headerDiv = document.createElement("div");
headerDiv.id = "hDiv";
headerDiv.className = "container";
var br = document.createElement('br');	
headerDiv.appendChild(br);

var h3 = document.createElement('h3');	
var tituloh = document.createTextNode("Escanear VIP");
h3.appendChild(tituloh);
h3.className="center";
headerDiv.appendChild(h3);

ControlAddIn.appendChild(headerDiv);

//texbox
var textDiv = document.createElement("div");
textDiv.id = "txtDiv";
textDiv.className = "container mt-3";

var br2 = document.createElement('br');	
textDiv.appendChild(br2);

var inputtag = document.createElement("input");
inputtag.className = "form-control";
inputtag.id = "codeVip";
inputtag.type = "text";
inputtag.placeholder ="Escanee Código VIP...";
inputtag.onselectstart =  new Function ("return false");
inputtag.autocomplete = "off";

textDiv.appendChild(inputtag);

var spn = document.createElement("span");
spn.id = "segundos";
spn.style.display = "none";
spn.textContent = "2";
textDiv.appendChild(spn);

ControlAddIn.appendChild(textDiv);


var spn2 = document.createElement("span");
textDiv.appendChild(spn2);

//Botones
var btnDiv = document.createElement("div");
btnDiv.id = "bntDiv";
btnDiv.className = "container mt-3 textbox";

var btnAceptar = document.createElement("button");
var txtAceptar = document.createTextNode("Aceptar");
btnAceptar.id = "btnAceptar";
btnAceptar.className = "button-primary medium-plus-font center";

btnAceptar.appendChild(txtAceptar);
btnDiv.appendChild(btnAceptar);

var txt = document.createTextNode(' ');	
btnDiv.appendChild(txt);

var btnCancelar= document.createElement("button");
var txtCancelar = document.createTextNode("Cancelar");
btnCancelar.id = "btnCancelar";
btnCancelar.className = "button-secondary medium-plus-font center";

btnCancelar.appendChild(txtCancelar);
btnDiv.appendChild(btnCancelar);
ControlAddIn.appendChild(btnDiv);
var control;
var segundos=2;

$(document).ready(function(){
    $("#txtDiv")
    $('#codeVip').focus();
    var value;
  
   /*$("#codeVip").on("keyup", function() {
      value = $(this).val().toLowerCase();
      //interval();
      if ($("#codeVip").is(":focus") && (e.keyCode == 13)) {
        //value = $(this).val().toLowerCase();
        GetVIP($("#codeVip").val().toLowerCase());
    }*/
    

     /*$('#codeVip').bind('keyup keydown keypress', function (evt) {
       return false;
        });*/
 
    $(document).keyup(function (e) {

      var texto = $("#codeVip").val().toLowerCase();
      var letra = texto.charAt(0);
      alphanumeric(letra);
   
        if ($("#codeVip").is(":focus") && (e.keyCode == 13)) {
            GetVIP($("#codeVip").val().toLowerCase(), null);
        }
    });

    //no permite copiar pegar cortar
    $('#codeVip').bind("cut copy paste", function(e) {
        e.preventDefault();
        alert("Acción no permitida.");
        /*$('#inputCode').bind("contextmenu", function(e) {
            e.preventDefault();
        });*/
        });

        //No permite uso de teclado
    /* $('input[type=text]').bind('keyup keydown keypress', function (evt) {
            return false;
        });*/

        $("#btnAceptar").click(function(){
           // var texto = $(this).val().toLowerCase();
            GetVIP($("#codeVip").val().toLowerCase(), null);
        });
        $("#btnCancelar").click(function(){
            CancelPressed();
        });
});


function alphanumeric(letra)
{
  var regex = /^[A-Za-z0-9]+$/;
  var isValid = regex.test(letra);
 
   if (isValid) 
   {
      //console.log("timer");
      control = setInterval(initCount,2000);
   }
    else
   { 
     // console.log("reset");
      clearInterval(control);
      document.getElementById("codeVip").value = "";
   }
}

function initCount(){
  let elem = document.getElementById("segundos");
  segundos = parseInt(elem.textContent);
  segundos = segundos-1;
  elem.textContent=segundos;
  
  if(segundos==0){
   endTime();
   }
 }
 function endTime(){
   let elem = document.getElementById("segundos")
   elem.textContent="0";
   elem.style.color = "red";
   StopAlertForMe();
   
  }

  function resetCount(){
    segundos = 0;
    document.getElementById("segundos").textContent = 0;
    clearInterval(control);
  }

  function StopAlertForMe() {
    segundos = 0;
    clearTimeout(control);
   // document.getElementById("segundos").textContent = 0;
    $('#codeVip').focus();
  }

function CancelPressed()
{
    Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('OnCancel','');
}

function GetVIP(VipCode, timer)
{
    if (VipCode != "" && segundos > 0){
      Microsoft.Dynamics.NAV.InvokeExtensibilityMethod("RecivedDataToAL", [VipCode]);
    }
    else{
      Microsoft.Dynamics.NAV.InvokeExtensibilityMethod("OnTimeOut", [VipCode]);
      StopAlertForMe();
    }
}
