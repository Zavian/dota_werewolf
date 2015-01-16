package {
	import flash.display.MovieClip;
	import flash.text.TextField;
	import flash.events.MouseEvent;
	import flash.utils.getDefinitionByName;
	import flash.filters.GlowFilter;
	import com.greensock.TweenLite;
	import com.greensock.easing.*;

	//import some stuff from the valve lib
	import ValveLib.*;
	//import scaleform.clik.controls.TextInput;
	import ValveLib.Controls.InputBox;
	import scaleform.clik.controls.Button;
	
	
	public class CustomUI extends MovieClip{
		
		//these three variables are required by the engine
		public var gameAPI:Object;
		public var globals:Object;
		public var elementName:String;
		//public var drpDown:MovieClip;
		
		//constructor, you usually will use onLoaded() instead
		public function CustomUI() : void {
		}
		
		public static function o (oObj:Object, sPrefix:String = ""):void  
		{  
		  
			sPrefix == "" ? sPrefix = "---" : sPrefix += "---";  
			  
			for (var i:* in oObj)  
			{  
				  
				trace (sPrefix , i + " : " + oObj[i], "  ");  
				  
				if (typeof( oObj[i] ) == "object") o ( oObj[i], sPrefix); // around we go again          
			}  
		  
		}  
		
		//this function is called when the UI is loaded
		public function onLoaded() : void {			
			//make this UI visible
			visible = true;
			this.allyModule.visible = false;
			this.notificationModule.getChildByName("newNotification").visible = false;
			trace();
			trace();
			o(gameAPI, "gameAPI");
			trace();
			o(globals, "globals");
			trace();
			o(elementName, "elementName");
			trace();
			//let the client rescale the UI
			Globals.instance.resizeManager.AddListener(this);
			trace(elementName);
			trace(elementName.toString());
			trace(elementName.length);
			//.addEventListener(ValveLib.Events.InputBoxEvent, onChat);
			
						
			//var oldMC = this.allyModule.getChildByName("placeholderRect")
			/*this.drpDown = replaceWithValveComponent(oldMC, "ComboBoxSkinned", true);
			this.drpDown.x = this.drpDown.x - (this.drpDown.width / 2);
			this.drpDown.y = this.drpDown.y - (this.drpDown.height / 2);*/
			//var obj = replaceWithValveComponent(oldMC, "TextInputSkinned", true);
			
			//this is not needed, but it shows you your UI has loaded (needs 'scaleform_spew 1' in console)
			trace("Custom UI loaded!");
			this.lumber.setup(gameAPI, globals);
			this.btnOpenAlly.setup(gameAPI, globals);
			this.allyModule.setup(gameAPI, globals);
			this.notificationModule.setup(gameAPI, globals);
			
			this.btnOpenAlly.addEventListener(MouseEvent.CLICK, btnOpenAllyClick);
			this.allyModule.getChildByName("btnCloseAlly").addEventListener(MouseEvent.CLICK, btnCloseMenuClick);
			this.allyModule.getChildByName("btnAddAllies").addEventListener(MouseEvent.CLICK, btnAddAlliesClick);
			
			this.gameAPI.SubscribeToGameEvent("returning_players", this.onReceivingPlayers);
			
			trace("Entering the for");
			for(var i = 0; i < 10; i++) {
				trace("setting: strPlayer" + i);
				this.allyModule.getChildByName("strPlayer" + i).addEventListener(MouseEvent.MOUSE_OVER, overStrPlayer);
				this.allyModule.getChildByName("strPlayer" + i).addEventListener(MouseEvent.MOUSE_OUT, outStrPlayer);
				this.allyModule.getChildByName("strPlayer" + i).addEventListener(MouseEvent.CLICK, clickStrPlayer);
				(this.allyModule.getChildByName("strPlayer" + i) as TextField).text = ""
				(this.allyModule.getChildByName("strPlayer" + i) as TextField).wordWrap = false
			}
			
		}
		
		function onChat(args:Object) {
			trace("wutwutwutwutwutwutwutwutwutwutwutwutwutwutwutwutwutwutwutwutwutwutwutwut");
		}
		
		function clickStrPlayer(evt:MouseEvent) {
			trace("click: " + evt.target.name);
			evt.target.wordWrap = !evt.target.wordWrap
			
			var i = 0;
			var exit = false;
			do 
			{
				exit = (this.allyModule.getChildByName("strPlayer" + i) as TextField).wordWrap;
				i++;
			}while(i < 10 && !exit);
			trace("exit: " + exit);
			(this.allyModule.getChildByName("btnAddAllies") as Button).mouseEnabled = exit;
		}
		
		function overStrPlayer(evt:MouseEvent) {
			trace("over: " + evt.target.name);
			if(evt.target.text != "") {
				var glowArray:Array = [new GlowFilter()];
				evt.target.filters = glowArray;
			}
		}
		
		function outStrPlayer(evt:MouseEvent) {
			trace("out: " + evt.target.name);
			if(!evt.target.wordWrap) {
				evt.target.filters = [];
			}
		}
		
		function btnAddAlliesClick(evt:MouseEvent) {
			trace("Clicked btnAddAllies");
		}
		
		function btnOpenAllyClick(evt:MouseEvent) {
			trace("Clicked btnOpenAlly");
			this.btnOpenAlly.visible = false;
			this.allyModule.visible = true;
			
			this.gameAPI.SendServerCommand("GetAllPlayers");		
			
			trace(elementName);
			trace(elementName.toString());
			trace(elementName.length);
			for(var i:int = 0; i < elementName.length; i++) {
				trace(elementName[i]);
				trace(elementName[i].toString());
			}
		}
		
		function btnCloseMenuClick(evt:MouseEvent) {
			trace("Clicked btnCloseAlly");
			this.allyModule.visible = false;
			this.btnOpenAlly.visible = true;
		}
		
		function onReceivingPlayers(args:Object) : void {
			var array = [args.player0, args.player1, args.player2,
						 args.player3, args.player4, args.player5,
						 args.player6, args.player7, args.player8,
						 args.player9]
			for(var i = 0; i < array.length; i++) {
				if(array[i] != "") {
					var item = array[i].split(" ");
					var playerID = item[0];
					var player = item[1];
					(this.allyModule.getChildByName("strPlayer" + playerID) as TextField).text = player;
				}
				
			}
		}
		
		
		
		//this handles the resizes - credits to Nullscope
		public function onResize(re:ResizeManager) : * {
			trace("onResize triggered");
			var rm = Globals.instance.resizeManager;
            var currentRatio:Number =  re.ScreenWidth / re.ScreenHeight;
            var divided:Number;

            // Set this to your stage height, however, if your assets are too big/small for 1024x768, you can change it
			// Your original stage height
            var originalHeight:Number = 1080;
                    
            if(currentRatio < 1.5)
            {
 				// 4:3
                divided = currentRatio / 1.333;
            }
            else if(re.Is16by9()){
				// 16:9
                divided = currentRatio / 1.7778;
            } else {
				//16:10
                divided = currentRatio / 1.6;
            }
			
                    
            var correctedRatio:Number =  re.ScreenHeight / originalHeight * divided;
  			this.lumber.screenResize(re.ScreenWidth, re.ScreenHeight, correctedRatio);
			trace("Resized lumberModule");
			this.btnOpenAlly.screenResize(re.ScreenWidth, re.ScreenHeight, correctedRatio);
			trace("Resized openButtonMC");			
			this.allyModule.screenResize(re.ScreenWidth, re.ScreenHeight, correctedRatio);
			trace("Resized allyModuleMC");
			this.notificationModule.screenResize(re.ScreenWidth, re.ScreenHeight, correctedRatio);
			trace("Resized notidicationModule");
		}
		
		public function replaceWithValveComponent(mc:MovieClip, type:String, keepDimensions:Boolean = false) : MovieClip {
			var parent = mc.parent;
			var oldx = mc.x;
			var oldy = mc.y;
			var oldwidth = mc.width;
			var oldheight = mc.height;
			
			var newObjectClass = getDefinitionByName(type);
			var newObject = new newObjectClass();
			newObject.x = oldx;
			newObject.y = oldy;
			if (keepDimensions) {
				newObject.width = oldwidth;
				newObject.height = oldheight;
			}
			
			parent.removeChild(mc);
			parent.addChild(newObject);
			
			return newObject;
		}
		

	}
}