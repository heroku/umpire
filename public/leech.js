var leechQuery = "";
var leechSearchId = "";

var log = function(msg) {
  console.log("app=leech ns=js " + msg);
}

var millis = function() {
  return (new Date).getTime();
}

function S4() {
   return (((1+Math.random())*0x10000)|0).toString(16).substring(1);
}
function uuid() {
   return (S4()+S4()+"-"+S4()+"-"+S4()+"-"+S4()+"-"+S4()+S4()+S4());
}

function leechInflate(ev) {
  return "<p class=\"" + ev.component + "\">" + ev.line + "</p>";
}

function leechApply(evs) {
  if (leechSearchId != "") {
    log("fn=apply at=start num=" + evs.length);
    var results = $("#results");
    $.each(evs, function(i, ev) {
      results.append(leechInflate(ev));
    });
    log("fn=apply at=finish");
  }
}

function leechUpdate() {
  if (leechSearchId != "") {
    log("fn=update at=start search_id=" + leechSearchId);
    var start = millis();
    $.ajax({
      data: {"search_id": leechSearchId, "query": leechQuery},
      dataType: "json",
      type: "GET",
      url: "/search",
      success: function(data, status, xhr) {
        log("fn=update at=finish search_id=" + leechSearchId + " elapsed=" (millis() - start));
        leechApply(data);
      }
    });
  }
}

function leechSubmit() {
  log("fn=submit at=start")
  var leechQueryNew = $("#query input").val();
  if (leechQueryNew.match(/^\s*$/)) {
    leechQuery = leechQueryNew;
    leechSearchId = "";
    $("#results").empty();
  } else if (leechQueryNew != leechQuery) {
    leechQuery = leechQueryNew;
    leechSearchId = uuid();
    $("#results").empty();
    leechUpdate();
  }
  log("fn=submit at=finish");
  return false;
}

function leechStart() {
  log("fn=start at=start");
  $("#query form").ajaxForm({beforeSubmit: leechSubmit});
  leechUpdate();
  setInterval(leechUpdate, 500);
  log("fn=start at=finish");
}

$(document).ready(leechStart);
