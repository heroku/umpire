var leechQuery = "";
var leechSearchId = "";
var leechHits = 0;
var leechLatency = 0;
var leechTimeoutId = 0;

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
  return $("<p></p>").addClass(ev.source).text(ev.line);
}

function leechApply(evs) {
  if (leechSearchId != "") {
    log("fn=apply at=start num=" + evs.length);
    var results = $("#results");
    $.each(evs, function(i, ev) {
      results.append(leechInflate(ev));
    });
    $("#status").text("(" + leechLatency + " / " + leechHits + ")");
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
        log("fn=update at=finish search_id=" + leechSearchId + " num=" + data.length);
        leechApply(data);
      },
      complete: function(status, xhr) {
        var elapsed = millis() - start;
        log("fn=update at=finish search_id=" + leechSearchId + " elapsed=" + elapsed);
        leechHits += 1;
        leechLatency = elapsed;
        leechTimeoutId = setTimeout(leechUpdate, 500);
      }
    });
  }
}

function leechUpdateNow() {
  log("fn=update_now at=start");
  clearTimeout(leechTimeoutId);
  leechUpdate();
  log("fn=update_now at=finish");
}

function leechSubmit() {
  log("fn=submit at=start");
  var leechQueryNew = $("#query input").val();
  if (leechQueryNew.match(/^\s*$/)) {
    leechSearchId = "";
    $("#results").empty();
    $("#status").text("(_ / _)");
  } else if (leechQueryNew != leechQuery) {
    leechQuery = leechQueryNew;
    leechSearchId = uuid();
    leechHits = 0;
    leechLatency = 0;
    $("#results").empty();
    $("#status").text("(0 / 0)");
    leechUpdateNow();
  }
  log("fn=submit at=finish");
  return false;
}

function leechStart() {
  log("fn=start at=start");
  $("#query form").ajaxForm({beforeSubmit: leechSubmit});
  leechUpdate();
  log("fn=start at=finish");
}

$(document).ready(leechStart);
