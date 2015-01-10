package  {
	
	import flash.display.MovieClip;
	
	
	public class notificationModuleMC extends MovieClip {
		var gameAPI:Object;
		var globals:Object;
		var originalXScale = null;
		var originalYScale = null;
		
		public function setup(api:Object, globals:Object) {
			this.gameAPI = api;
			this.globals = globals;
			trace("notificationModule loaded!");
			
		}
		
		public function notificationModuleMC() {
		}
		
		public function screenResize(stageW:int, stageH:int, scaleRatio:Number){
			trace("Resizing notificationModule");
			this.x = stageW - this.width / 2;
			this.y = this.height + (30 * scaleRatio);
			
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
