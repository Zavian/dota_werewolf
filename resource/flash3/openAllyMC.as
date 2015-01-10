package  {
	
	import flash.display.MovieClip;
	
	
	public class openAllyMC extends MovieClip {
		var gameAPI:Object;
		var globals:Object;
		var originalXScale = null;
		var originalYScale = null;
		
		public function setup(api:Object, globals:Object) {
			this.gameAPI = api;
			this.globals = globals;
			trace("buttonAllyMC loaded!");
		}
		
		public function openAllyMC() {
			// constructor code
		}
		
		public function screenResize(stageW:int, stageH:int, scaleRatio:Number){
			trace("Resizing buttonAllyMC");
			//Position : 
			// x = (this.width / 2) * scaleRatio
			// y = height - (118 * scaleRatio)
			// This will take the button at the center of the health bar (bottom)
			this.x = (this.scaleX / 2) + 10 * scaleRatio;
			this.y = stageH/2 - (118 * scaleRatio);
			
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
