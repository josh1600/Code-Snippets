/*
    -- Credit to: Liam?
    DESC
        Spawns the player into the game in a Homefront style
    NOTE:
        LINK: https://youtu.be/CghuBii09HQ
*/
function homefront()
{
    self endon("death");
    self endon("disconnect");
    self endon("welcone_Done");
    for(;;)
    {
        self EnableInvulnerability();
           self disableWeapons();
           self hide();
           self freezeControls( true );
           zoomHeight = 5000;
           zoomBack = 4000;
          yaw = 55;
           origin = self.origin;
           self.origin = origin+vector_scale(anglestoforward(self.angles+(0,-180,0)),zoomBack)+(0,0,zoomHeight);
           ent = spawn("script_model",(0,0,0));
           ent.angles = self.angles+(yaw,0,0);
           ent.origin = self.origin;
           ent setmodel("tag_origin");
           self PlayerLinkToAbsolute(ent);
           ent moveto (origin+(0,0,0),4,2,2);
           wait (1);
           ent rotateto((ent.angles[0]-yaw,ent.angles[1],0),3,1,1);
           wait (0.5);
           self playlocalsound("ui_camera_whoosh_in");
           wait (2.5);
           self unlink();
           wait (0.2);
           ent delete();
           self Show();
           self enableWeapons();
           self disableInvulnerability();
           self notify("welcone_Done");
    }
}

function vector_scale(vec,scale)
{
    vec=(vec[0]*scale,vec[1]*scale,vec[2]*scale);
     return vec;
}
