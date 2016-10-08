/*
    -- Credit to: #Gmzorz
    DESC:
        Rotates the sky over time. Changes every frame. Likely too fast.
        I would suggest changing it too 0.8; or moving down too 0.001 incerments
        to get to 360 degrees 
*/
function rotSky(){
	t = 0;
	for(;;){
		t += 1;
		if(t > 359) {
			t = 1;
		}
		setDvar("r_skyrotation", t);
		wait 0.05;
	}
}
