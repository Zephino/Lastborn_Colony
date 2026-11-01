## Settings → Fullscreen, Install app, Update app (adapted from Mythriven).
## Fullscreen works in the browser and on desktop. Install app and Update app
## are for the web version: the browser can install it like an app (the export
## preset turns on "progressive web app"), which keeps a copy of the game on
## the device. Update app clears that copy and reloads, so the newest version
## is one click away. The page also updates itself: for 30 s after opening it
## checks the online version and switches to a newer one (web/update.js).
## Saves are kept separately and are not affected.
extends RefCounted


static func can_fullscreen() -> bool:
	return OS.has_feature("web") or not OS.has_feature("mobile")


static func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


static func toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen() else DisplayServer.WINDOW_MODE_FULLSCREEN)


static func is_web() -> bool:
	return OS.has_feature("web")


## "ready" (the browser can install it now), "installed" (running as an app),
## "ios" (Safari: Share → Add to Home Screen), or "unavailable".
static func install_state() -> String:
	if not is_web():
		return "unavailable"
	return str(JavaScriptBridge.eval("""(function(){
		var m=function(q){return window.matchMedia&&window.matchMedia(q).matches;};
		if(m('(display-mode: fullscreen)')||m('(display-mode: standalone)')||navigator.standalone)return 'installed';
		if(window.lastbornInstall)return 'ready';
		if(/iPad|iPhone|iPod/.test(navigator.userAgent)||(navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1))return 'ios';
		return 'unavailable';})()""", true))


## Shows the browser's own "Install Lastborn Colony?" box.
static func install() -> void:
	if is_web():
		JavaScriptBridge.eval("(function(){var e=window.lastbornInstall;if(e){window.lastbornInstall=null;e.prompt();}})()", true)


## Forgets the saved copy of the game and reloads it from the internet.
static func update_now() -> void:
	if not is_web():
		return
	if bool(JavaScriptBridge.eval("typeof window.lastbornForceUpdate === 'function'", true)):
		JavaScriptBridge.eval("window.lastbornForceUpdate()", true)
		return
	JavaScriptBridge.eval("""(async function(){
		try{
			if(navigator.serviceWorker){var r=await navigator.serviceWorker.getRegistrations();for(var i=0;i<r.length;i++){await r[i].unregister();}}
			if(window.caches){var k=await caches.keys();for(var j=0;j<k.length;j++){await caches.delete(k[j]);}}
		}catch(e){}
		var u=new URL(location.href);u.searchParams.set('v',Date.now());location.replace(u.toString());})()""", true)
