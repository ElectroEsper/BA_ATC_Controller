Feel free to use it in your scenarios. I would apreciate a credit mention if you do :)


# KNOWN ISSUES:

## CAS (Close Air Support)

:: Retargeting Behavior
CAS units can and will re-target enemy units they haven't seen in a while, as long as the target remains alive.

## CAP (Combat Air Patrol)

:: Idle RTB Behavior
CAP units will return to base if idle for any amount of time, including situations where:
- They lose sight of their target.
- No new targets are immediately available.

## Engine Limitations

:: Loadout Detection Limitation
The ATC cannot detect aircraft loadouts, meaning:
- Strike tasking cannot be adjusted based on ordnance type (e.g., bombs vs missiles).
- Leads to potential mismatch between mission profile and aircraft capability.


:: Unit Categorization Restriction
- ATC can only differentiate units by broad category (e.g., Infantry, Vehicle).
- Cannot distinguish between unit subtypes (e.g., light vs heavy armor).
- Limits precision in assigning optimal strike types.

# HOW TO USE:

1 - Make sure all .lua files are in your scenario folder
<img width="993" height="428" alt="Screenshot 2025-07-19 172507" src="https://github.com/user-attachments/assets/48be0b1f-6470-4c7f-bea4-7b89efe20a23" />

2 - Make sure the template ( .sgt) file is in your "boken_arrow > Scenarios > _subgraph_template" folder
<img width="1047" height="329" alt="Screenshot 2025-07-19 172534" src="https://github.com/user-attachments/assets/d2c6200e-4b81-457e-a140-569afde8f13e" />

3 - Open your scenario, then the node editor. To add the subgraph template, click on "Template", then select "ATC_Module" then apply.
![20250719172821_1](https://github.com/user-attachments/assets/cf8c1908-7134-4ced-9794-8080d90cb360)

4 - Make sure the newly created subgraph is enabled by having a flow line ("yellow") connected into is top yellow connector.

5 - Enter the "ATC_Module" subgraph, and its leftmost part, you'll have 4 nodes that needs to be setup. 
In order you'll to choose; 

1 : AI Player
2 : AI's Team
3 : AI's Air Spawn
4 : The AI's Enemy Team
![20250719171813_1](https://github.com/user-attachments/assets/d3b843bd-9734-4cb6-b508-a5bfb4131440)

6 - In the rightmost part, you'll have to set the AI's plane loadouts.

1 : CAS Plane, this one uses the strafing strike mode, something with missiles, guns and rockets works best
2 : CAP Plane, this one will go for enemy planes
![20250719171818_1](https://github.com/user-attachments/assets/34c52b28-e551-4799-aa10-de7a9deb1e6e)

7 - And finally, you'll have to configure your controllers. 

In the "atc_cap_controller.lua" and "atc_cas_controller" files near the top you'll have 3 values.

In "_G.assets" you can set the amount of "ready" aircraft the AI has. In this exemple, it is set to 2. This is the maximum amounts of plane the AI has.
Then "_G.rearming_time" and "_G.regen_time", respectively are in seconds, how long for a plane that returned to base to be ready again, or how long for a destroyed aircraft to be replaced.
If you do not want aircrafts to regenerate, feel free to set the number to something ridiculously high.

Defaults settings in the files are, 4 minutes to rearm, 10 minutes to regen, the same as for the player.
<img width="579" height="296" alt="Screenshot 2025-07-19 174505" src="https://github.com/user-attachments/assets/274619d9-fe0d-4687-9733-ba1b92e23f8a" />

This is provided as is, bugs and all. Feel free to modify, adapt, inspire, deconstruct, ect.
