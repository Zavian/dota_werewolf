package  {
	
	import flash.display.MovieClip;
	import flash.events.MouseEvent;
	import flash.text.TextFormat; 
	import flash.utils.getDefinitionByName;
	import flash.text.TextField;
	import flash.text.AntiAliasType;
	
	
	public class lumberModule extends MovieClip {
		var gameAPI:Object;
		var globals:Object;
		var originalXScale = null;
		var originalYScale = null;
		
		public function setup(api:Object, globals:Object) {
			this.gameAPI = api;
			this.globals = globals;
			trace("lumberModule loaded!");
			this.gameAPI.SubscribeToGameEvent("wwt_lumber_changed", this.onLumberUpdate);
			trace("subscribed");
		}
		
		public function lumberModule() {
		}
		
		public function onLumberUpdate(args:Object) : void {
			//trace("Lumber updated " + args.lumber);
			var playerID:int = globals.Players.GetLocalPlayer();
			
			//trace("args: " + args.player);
			//trace("player: " + playerID);
			//trace();
			
			if(args.player == playerID) {
				this.lumberLabel.text = args.lumber;
			}
		}

		
		public function screenResize(stageW:int, stageH:int, scaleRatio:Number){
			trace("Resizing lumberModule");
			this.x = stageW - this.width / 2;
			this.y = stageH - (292 * scaleRatio);
			
			//save this movieClip's original scale
			if(this["originalXScale"] == null)
			{
				this["originalXScale"] = this.scaleX;
				this["originalYScale"] = this.scaleY;
			}
			
			//Let's say we want our element to scale proportional to the screen height, scale like this:
			this.scaleX = this.originalXScale * scaleRatio;
			this.scaleY = this.originalYScale * scaleRatio;
		}
	}
	
}
